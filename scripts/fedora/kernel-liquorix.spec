# Version variables are provided by the build system via rpmbuild --define flags.
# For local builds, pass them manually:
#   rpmbuild -bb --define "version_upstream 7.1.8" \
#                --define "version_kernel 7.1" \
#                --define "version_lqx 4" \
#                --define "version_build 1" \
#                --define "fedora_release 43" \
#                kernel-liquorix.spec

# Disable frame pointers (RPM may inject these into CFLAGS)
%undefine _include_frame_pointers

# Disable LTO in userspace packages
%global _lto_cflags %{nil}

%global lqxversion       lqx%{version_lqx}
%global kversion         %{version_upstream}.%{lqxversion}-%{version_build}

Name:           kernel-liquorix
Version:        %{version_upstream}.%{lqxversion}
Release:        %{version_build}%{?dist}
Summary:        Liquorix Kernel - Zen-based desktop optimized kernel
License:        GPL-2.0-only
URL:            https://liquorix.net
ExclusiveArch:  x86_64

Source0:        linux-%{version_kernel}.tar.xz
Source1:        v%{version_upstream}-%{lqxversion}.patch
Source2:        config-x86_64-liquorix

BuildRequires:  bc
BuildRequires:  bindgen-cli
BuildRequires:  bison
BuildRequires:  cpio
BuildRequires:  dwarves
BuildRequires:  elfutils-devel
BuildRequires:  flex
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  kmod
BuildRequires:  make
BuildRequires:  openssl-devel
BuildRequires:  patch
BuildRequires:  perl
BuildRequires:  python3
BuildRequires:  rpm-build
BuildRequires:  rust
BuildRequires:  rust-src
BuildRequires:  xz
BuildRequires:  zstd

Provides:       installonlypkg(kernel)
Provides:       kernel-uname-r = %{kversion}
Requires:       %{name}-modules = %{version}-%{release}
Requires(pre):  coreutils
Requires(pre):  systemd
Requires(pre):  /usr/bin/kernel-install
Requires(pre):  dracut
Requires(preun): systemd
Recommends:     linux-firmware
AutoReq:        no
AutoProv:       yes

%define debug_package %{nil}
%define _binary_payload w3.zstdio

%description
The Liquorix kernel is a desktop-optimized kernel built from the Zen kernel
sources with best-of-class configuration and optimizations for throughput,
latency, and interactivity.

%package devel
Summary:        Development files for Liquorix Kernel %{kversion}
Provides:       installonlypkg(kernel)
Provides:       kernel-devel-uname-r = %{kversion}
Requires:       %{name} = %{version}-%{release}
Requires(pre):  findutils
Requires:       findutils
Requires:       perl-interpreter
Requires:       openssl-devel
Requires:       elfutils-libelf-devel
Requires:       bison
Requires:       flex
Requires:       make
Requires:       gcc
AutoReqProv:    no

%description devel
Kernel headers and build files for compiling out-of-tree modules against
the Liquorix kernel %{kversion}.

%package modules
Summary:        Kernel modules for Liquorix Kernel %{kversion}
Provides:       installonlypkg(kernel-module)
Provides:       kernel-modules-uname-r = %{kversion}
Provides:       kernel-modules-core-uname-r = %{kversion}
Requires:       %{name} = %{version}-%{release}
AutoReq:        no
AutoProv:       yes

%description modules
Loadable kernel modules for the Liquorix kernel %{kversion}.

%prep
%setup -q -n linux-%{version_kernel}
patch -p1 < %{SOURCE1}

# Clear EXTRAVERSION set by the zen patch (-lqxN) since we control the full
# version string via LOCALVERSION to match %%{kversion}
sed -i 's/^EXTRAVERSION = .*/EXTRAVERSION =/' Makefile

cp %{SOURCE2} .config

# Match mainline Fedora module compression: XZ method, but not at build time
# (MODULE_COMPRESS_ALL=n means modules_install won't compress; spec does it post-install)
scripts/config --disable MODULE_COMPRESS_ALL
scripts/config --disable MODULE_COMPRESS_ZSTD
scripts/config --enable MODULE_COMPRESS_XZ

make olddefconfig

%build
make %{?_smp_mflags} LOCALVERSION=.%{lqxversion}-%{version_build} bzImage modules

%install
mkdir -p %{buildroot}/boot
mkdir -p %{buildroot}/lib/modules/%{kversion}
mkdir -p %{buildroot}/usr/src/kernels/%{kversion}
mkdir -p %{buildroot}/usr/share/licenses/%{name}

# Install kernel image to /lib/modules (canonical location for kernel-install)
install -m 755 arch/x86/boot/bzImage %{buildroot}/lib/modules/%{kversion}/vmlinuz

# Install supporting files to /lib/modules
install -m 644 System.map %{buildroot}/lib/modules/%{kversion}/System.map
install -m 644 .config %{buildroot}/lib/modules/%{kversion}/config
install -m 644 modules.builtin %{buildroot}/lib/modules/%{kversion}/modules.builtin
install -m 644 modules.builtin.modinfo %{buildroot}/lib/modules/%{kversion}/modules.builtin.modinfo

# Install compressed symvers (use dict=1MiB for memory-constrained decompression)
xz --check=crc32 --lzma2=dict=1MiB --stdout < Module.symvers > %{buildroot}/lib/modules/%{kversion}/symvers.xz

# Create initramfs placeholder for RPM disk space estimation
dd if=/dev/zero of=%{buildroot}/boot/initramfs-%{kversion}.img bs=1M count=40

# Install license
cp COPYING %{buildroot}/usr/share/licenses/%{name}/COPYING-%{version}-%{release}

# Install modules (mod-fw= suppresses firmware installation)
make INSTALL_MOD_PATH=%{buildroot} modules_install INSTALL_MOD_STRIP=1 \
    KERNELRELEASE=%{kversion} mod-fw=

# Generate module category lists
find %{buildroot}/lib/modules/%{kversion} -name "*.ko" -type f > modnames
grep -F /drivers/ modnames |
xargs --no-run-if-empty nm -upA |
sed -n 's,^.*/\([^/]*\.ko\):  *U \(.*\)$,\1 \2,p' > drivers.undef

collect_modules_list()
{
    sed -r -n -e "s/^([^ ]+) \\.?($2)\$/\\1/p" drivers.undef |
        LC_ALL=C sort -u > %{buildroot}/lib/modules/%{kversion}/modules.$1
    if [ ! -z "$3" ]; then
        sed -r -e "/^($3)\$/d" -i %{buildroot}/lib/modules/%{kversion}/modules.$1
    fi
}

collect_modules_list networking \
    'register_netdev|ieee80211_register_hw|usbnet_probe|phy_driver_register|rt(l_|2x00)(pci|usb)_probe|register_netdevice'
collect_modules_list block \
    'ata_scsi_ioctl|scsi_add_host|scsi_add_host_with_dma|blk_alloc_queue|blk_init_queue|register_mtd_blktrans|scsi_esp_register|scsi_register_device_handler|blk_queue_physical_block_size' 'pktcdvd.ko|dm-mod.ko'
collect_modules_list drm \
    'drm_open|drm_init'
collect_modules_list modesetting \
    'drm_crtc_init'

# Compress modules with xz (matching mainline Fedora)
find %{buildroot}/lib/modules/%{kversion} -type f -name '*.ko' | \
    xargs -n 16 -P${RPM_BUILD_NCPUS} -r xz --check=crc32 --lzma2=dict=1MiB

# Create dirs for additional modules
mkdir -p %{buildroot}/lib/modules/%{kversion}/updates
mkdir -p %{buildroot}/lib/modules/%{kversion}/weak-updates
mkdir -p %{buildroot}/lib/modules/%{kversion}/systemtap

# Remove depmod-generated files (will be regenerated at install time)
pushd %{buildroot}/lib/modules/%{kversion}/
rm -f modules.{alias,alias.bin,builtin.alias.bin,builtin.bin} \
      modules.{dep,dep.bin,devname,softdep,symbols,symbols.bin,weakdep}
popd

# Remove build/source symlinks (will be replaced with devel package paths)
rm -f %{buildroot}/lib/modules/%{kversion}/build
rm -f %{buildroot}/lib/modules/%{kversion}/source

# Install VDSO
make ARCH=x86 INSTALL_MOD_PATH=%{buildroot} vdso_install KERNELRELEASE=%{kversion}
rm -rf %{buildroot}/lib/modules/%{kversion}/vdso/.build-id

# --- devel package: headers and build infrastructure ---

DevelDir=%{buildroot}/usr/src/kernels/%{kversion}

# Copy Makefile/Kconfig files first
cp --parents $(find  -type f -name "Makefile*" -o -name "Kconfig*") $DevelDir
cp .config $DevelDir
cp Module.symvers $DevelDir
cp System.map $DevelDir

# Copy scripts (then clean unnecessary files)
cp -a scripts $DevelDir
rm -rf $DevelDir/scripts/tracing
rm -f $DevelDir/scripts/spdxcheck.py

# Files for 'make scripts' to succeed with kernel-devel
mkdir -p $DevelDir/security/selinux/include
cp -a --parents security/selinux/include/classmap.h $DevelDir
cp -a --parents security/selinux/include/initial_sid_to_string.h $DevelDir
cp --parents security/selinux/include/policycap_names.h $DevelDir
cp --parents security/selinux/include/policycap.h $DevelDir

# Tools include files for 'make prepare' and objtool/BPF tools
mkdir -p $DevelDir/tools/include/tools
cp -a --parents tools/include/tools/be_byteshift.h $DevelDir
cp -a --parents tools/include/tools/le_byteshift.h $DevelDir
cp -a --parents tools/include/linux/compiler* $DevelDir
cp -a --parents tools/include/linux/types.h $DevelDir
cp -a --parents tools/include/asm $DevelDir
cp -a --parents tools/include/asm-generic $DevelDir
cp -a --parents tools/include/linux $DevelDir
cp -a --parents tools/include/uapi/asm $DevelDir
cp -a --parents tools/include/uapi/asm-generic $DevelDir
cp -a --parents tools/include/uapi/linux $DevelDir
cp -a --parents tools/include/vdso $DevelDir

# Tools build infrastructure
cp -a --parents tools/build/Build.include $DevelDir
cp --parents tools/build/fixdep.c $DevelDir
cp --parents tools/scripts/utilities.mak $DevelDir

# Tools objtool
cp --parents tools/objtool/sync-check.sh $DevelDir
cp --parents tools/objtool/*.[ch] $DevelDir
cp --parents tools/objtool/Build $DevelDir
cp --parents tools/objtool/include/objtool/*.h $DevelDir
if [ -f tools/objtool/objtool ]; then
    mkdir -p $DevelDir/tools/objtool
    cp -a tools/objtool/objtool $DevelDir/tools/objtool/ || :
fi
if [ -f tools/objtool/fixdep ]; then
    cp -a tools/objtool/fixdep $DevelDir/tools/objtool/ || :
fi

# Tools BPF and lib
cp -a --parents tools/bpf/resolve_btfids $DevelDir
cp -a --parents tools/lib/subcmd $DevelDir
cp --parents tools/lib/*.c $DevelDir
cp -a --parents tools/lib/bpf $DevelDir
cp --parents tools/lib/bpf/Build $DevelDir

# x86-specific devel files for 'make prepare'
cp -a --parents arch/x86/entry/syscalls/syscall_32.tbl $DevelDir
cp -a --parents arch/x86/entry/syscalls/syscall_64.tbl $DevelDir
cp -a --parents arch/x86/tools/relocs_32.c $DevelDir
cp -a --parents arch/x86/tools/relocs_64.c $DevelDir
cp -a --parents arch/x86/tools/relocs.c $DevelDir
cp -a --parents arch/x86/tools/relocs_common.c $DevelDir
cp -a --parents arch/x86/tools/relocs.h $DevelDir
cp -a --parents arch/x86/purgatory/purgatory.c $DevelDir
cp -a --parents arch/x86/purgatory/stack.S $DevelDir
cp -a --parents arch/x86/purgatory/setup-x86_64.S $DevelDir
cp -a --parents arch/x86/purgatory/entry64.S $DevelDir
cp -a --parents arch/x86/boot/string.h $DevelDir
cp -a --parents arch/x86/boot/string.c $DevelDir
cp -a --parents arch/x86/boot/ctype.h $DevelDir
cp -a --parents scripts/syscalltbl.sh $DevelDir
cp -a --parents scripts/syscallhdr.sh $DevelDir
cp -a --parents tools/arch/x86/include/asm $DevelDir
cp -a --parents tools/arch/x86/include/uapi/asm $DevelDir
cp -a --parents tools/objtool/arch/x86/lib $DevelDir
cp -a --parents tools/arch/x86/lib/ $DevelDir
cp -a --parents tools/arch/x86/tools/gen-insn-attr-x86.awk $DevelDir
cp -a --parents tools/objtool/arch/x86/ $DevelDir

# Arch includes, scripts, and linker scripts
cp -a --parents arch/x86/include $DevelDir
if [ -d arch/x86/scripts ]; then
    cp -a arch/x86/scripts $DevelDir/arch/x86/ || :
fi
if [ -f arch/x86/*lds ]; then
    cp -a arch/x86/*lds $DevelDir/arch/x86/ || :
fi
if [ -f arch/x86/kernel/module.lds ]; then
    cp -a --parents arch/x86/kernel/module.lds $DevelDir
fi
cp -a arch/x86/Makefile $DevelDir/arch/x86/

# Include files
cp -a include $DevelDir

# Cross-reference from include/perf/events/sof.h
mkdir -p $DevelDir/sound/soc/sof
cp -a sound/soc/sof/sof-audio.h $DevelDir/sound/soc/sof

# Clean up intermediate build artifacts from scripts and tools
find $DevelDir/scripts \( -iname "*.o" -o -iname "*.cmd" \) -exec rm -f {} +
find $DevelDir/tools \( -iname "*.o" -o -iname "*.cmd" \) -exec rm -f {} +

# Sync timestamps so external modules can build without timestamp issues
touch -r $DevelDir/Makefile \
    $DevelDir/include/generated/uapi/linux/version.h \
    $DevelDir/include/config/auto.conf

# Create symlinks from modules dir to devel dir
ln -sf /usr/src/kernels/%{kversion} %{buildroot}/lib/modules/%{kversion}/build
ln -sf /usr/src/kernels/%{kversion} %{buildroot}/lib/modules/%{kversion}/source

# --- scriptlets ---

# kernel-liquorix (core) post: mark that core is being installed
%post
mkdir -p %{_localstatedir}/lib/rpm-state/%{name}
touch %{_localstatedir}/lib/rpm-state/%{name}/installing_core_%{kversion}

# kernel-liquorix (core) posttrans: run kernel-install to populate /boot
%posttrans
rm -f %{_localstatedir}/lib/rpm-state/%{name}/installing_core_%{kversion}
/bin/kernel-install add %{kversion} /lib/modules/%{kversion}/vmlinuz || exit $?
if [ ! -e /boot/symvers-%{kversion}.xz ]; then
    cp /lib/modules/%{kversion}/symvers.xz /boot/symvers-%{kversion}.xz
    if command -v restorecon &>/dev/null; then
        restorecon /boot/symvers-%{kversion}.xz
    fi
fi

# kernel-liquorix (core) preun: remove from bootloader
%preun
entry_type=""
/bin/kernel-install --help 2>&1 | grep -q -- '--entry-type=' && \
    entry_type="--entry-type type1"
/bin/kernel-install remove %{kversion} $entry_type || exit $?

# kernel-liquorix-modules post/postun: run depmod, trigger dracut if needed
%post modules
/sbin/depmod -a %{kversion}
if [ -f /lib/modules/%{kversion}/vmlinuz ] && \
   [ -f /boot/initramfs-%{kversion}.img ] && \
   [ ! -f %{_localstatedir}/lib/rpm-state/%{name}/installing_core_%{kversion} ]; then
    mkdir -p %{_localstatedir}/lib/rpm-state/%{name}
    touch %{_localstatedir}/lib/rpm-state/%{name}/need_to_run_dracut_%{kversion}
fi

%postun modules
if [ -d /lib/modules/%{kversion} ]; then
    /sbin/depmod -a %{kversion}
fi

%posttrans modules
if [ -f %{_localstatedir}/lib/rpm-state/%{name}/need_to_run_dracut_%{kversion} ]; then
    rm -f %{_localstatedir}/lib/rpm-state/%{name}/need_to_run_dracut_%{kversion}
    echo "Running: dracut -f --kver %{kversion} /boot/initramfs-%{kversion}.img"
    dracut -f --kver %{kversion} /boot/initramfs-%{kversion}.img || exit $?
fi

# kernel-liquorix-devel post: hardlink across kernel-devel packages to save space
%post devel
if [ -f /etc/sysconfig/kernel ]; then
    . /etc/sysconfig/kernel || exit $?
fi
if [ "$HARDLINK" != "no" ] && [ -x /usr/bin/hardlink ] && [ ! -e /run/ostree-booted ]; then
    (cd /usr/src/kernels/%{kversion} &&
     /usr/bin/find . -type f | while read f; do
       hardlink -c /usr/src/kernels/*%{?dist}.*/$f $f > /dev/null 2>&1
     done
     /usr/bin/find /usr/src/kernels -type f -name '*.hardlink-temporary' -delete
    ) || true
fi

# --- file lists ---

%files
%license /usr/share/licenses/%{name}/COPYING-%{version}-%{release}
/lib/modules/%{kversion}/vmlinuz
/lib/modules/%{kversion}/System.map
/lib/modules/%{kversion}/config
/lib/modules/%{kversion}/symvers.xz
/lib/modules/%{kversion}/modules.builtin*
%dir /lib/modules
%dir /lib/modules/%{kversion}
%ghost %attr(0755, root, root) /boot/vmlinuz-%{kversion}
%ghost %attr(0644, root, root) /boot/System.map-%{kversion}
%ghost %attr(0644, root, root) /boot/config-%{kversion}
%ghost %attr(0644, root, root) /boot/symvers-%{kversion}.xz
%ghost %attr(0600, root, root) /boot/initramfs-%{kversion}.img

%files modules
%dir /lib/modules
%dir /lib/modules/%{kversion}
%dir /lib/modules/%{kversion}/kernel
/lib/modules/%{kversion}/kernel
/lib/modules/%{kversion}/updates
/lib/modules/%{kversion}/weak-updates
/lib/modules/%{kversion}/systemtap
/lib/modules/%{kversion}/vdso
/lib/modules/%{kversion}/modules.order
/lib/modules/%{kversion}/modules.block
/lib/modules/%{kversion}/modules.drm
/lib/modules/%{kversion}/modules.modesetting
/lib/modules/%{kversion}/modules.networking
%ghost %attr(0644, root, root) /lib/modules/%{kversion}/modules.alias
%ghost %attr(0644, root, root) /lib/modules/%{kversion}/modules.alias.bin
%ghost %attr(0644, root, root) /lib/modules/%{kversion}/modules.builtin.alias.bin
%ghost %attr(0644, root, root) /lib/modules/%{kversion}/modules.builtin.bin
%ghost %attr(0644, root, root) /lib/modules/%{kversion}/modules.dep
%ghost %attr(0644, root, root) /lib/modules/%{kversion}/modules.dep.bin
%ghost %attr(0644, root, root) /lib/modules/%{kversion}/modules.devname
%ghost %attr(0644, root, root) /lib/modules/%{kversion}/modules.softdep
%ghost %attr(0644, root, root) /lib/modules/%{kversion}/modules.symbols
%ghost %attr(0644, root, root) /lib/modules/%{kversion}/modules.symbols.bin
%ghost %attr(0644, root, root) /lib/modules/%{kversion}/modules.weakdep
%exclude /lib/modules/%{kversion}/build
%exclude /lib/modules/%{kversion}/source

%files devel
%defverify(not mtime)
/usr/src/kernels/%{kversion}
/lib/modules/%{kversion}/build
/lib/modules/%{kversion}/source
