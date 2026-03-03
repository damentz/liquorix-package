%{!?version_upstream: %global version_upstream 6.18.15}
%{!?version_build:      %global version_build      3}
%{!?fedora_release:   %global fedora_release   rawhide}

%global lqxversion       lqx1
%global kversion         %{version_upstream}-%{lqxversion}-%{version_build}

Name:           kernel-liquorix
Version:        %{version_upstream}
Release:        %{version_build}.fc.%{fedora_release}%{?dist}
Summary:        Liquorix Kernel - Zen-based desktop optimized kernel
License:        GPL-2.0-only
URL:            https://liquorix.net
ExclusiveArch:  x86_64

Source0:        linux-%{lua:print(rpm.expand("%{version_upstream}"):match("(%d+%.%d+)"))}%{nil}.tar.xz
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

%define debug_package %{nil}
%define _binary_payload w3.zstdio

%description
The Liquorix kernel is a desktop-optimized kernel built from the Zen kernel
sources with best-of-class configuration and optimizations for throughput,
latency, and interactivity.

%package devel
Summary:        Development files for Liquorix Kernel %{kversion}
Requires:       %{name} = %{version}-%{release}
AutoReqProv:    no

%description devel
Kernel headers and build files for compiling out-of-tree modules against
the Liquorix kernel %{kversion}.

%package modules
Summary:        Kernel modules for Liquorix Kernel %{kversion}
Requires:       %{name} = %{version}-%{release}

%description modules
Loadable kernel modules for the Liquorix kernel %{kversion}.

%prep
%setup -q -n linux-%{lua:print(rpm.expand("%{version_upstream}"):match("(%d+%.%d+)"))}%{nil}
patch -p1 < %{SOURCE1}
cp %{SOURCE2} .config
make olddefconfig

%build
make %{?_smp_mflags} LOCALVERSION=-%{version_build} bzImage modules

%install
mkdir -p %{buildroot}/boot
mkdir -p %{buildroot}/lib/modules/%{kversion}
mkdir -p %{buildroot}/usr/src/kernels/%{kversion}

# Install kernel image
install -m 644 arch/x86/boot/bzImage %{buildroot}/boot/vmlinuz-%{kversion}
install -m 644 System.map %{buildroot}/boot/System.map-%{kversion}
install -m 644 .config %{buildroot}/boot/config-%{kversion}

# Install modules
make INSTALL_MOD_PATH=%{buildroot} modules_install INSTALL_MOD_STRIP=1 LOCALVERSION=-%{version_build}

# Remove build/source symlinks (will be replaced with devel package paths)
rm -f %{buildroot}/lib/modules/%{kversion}/build
rm -f %{buildroot}/lib/modules/%{kversion}/source

# Install devel headers
# Copy required files for building external modules
cp .config %{buildroot}/usr/src/kernels/%{kversion}/
cp Module.symvers %{buildroot}/usr/src/kernels/%{kversion}/
cp Makefile %{buildroot}/usr/src/kernels/%{kversion}/

# Copy arch-specific files
mkdir -p %{buildroot}/usr/src/kernels/%{kversion}/arch/x86
cp -a arch/x86/Makefile %{buildroot}/usr/src/kernels/%{kversion}/arch/x86/
cp -a arch/x86/include %{buildroot}/usr/src/kernels/%{kversion}/arch/x86/

# Copy scripts
cp -a scripts %{buildroot}/usr/src/kernels/%{kversion}/

# Copy include files
cp -a include %{buildroot}/usr/src/kernels/%{kversion}/

# Copy Kconfig files
find . -name 'Kconfig*' -exec install -D -m 644 {} %{buildroot}/usr/src/kernels/%{kversion}/{} \;

# Copy generated files needed for module builds
if [ -d tools/objtool ]; then
    mkdir -p %{buildroot}/usr/src/kernels/%{kversion}/tools/objtool
    cp -a tools/objtool/objtool %{buildroot}/usr/src/kernels/%{kversion}/tools/objtool/ 2>/dev/null || true
fi

# Create symlinks from modules dir to devel dir
ln -sf /usr/src/kernels/%{kversion} %{buildroot}/lib/modules/%{kversion}/build
ln -sf /usr/src/kernels/%{kversion} %{buildroot}/lib/modules/%{kversion}/source

%post
if command -v kernel-install >/dev/null 2>&1; then
    kernel-install add %{kversion} /boot/vmlinuz-%{kversion}
elif command -v dracut >/dev/null 2>&1; then
    dracut --force /boot/initramfs-%{kversion}.img %{kversion}
fi
if command -v depmod >/dev/null 2>&1; then
    depmod %{kversion}
fi

%postun
if command -v kernel-install >/dev/null 2>&1; then
    kernel-install remove %{kversion}
fi

%files
/boot/vmlinuz-%{kversion}
/boot/System.map-%{kversion}
/boot/config-%{kversion}

%files modules
/lib/modules/%{kversion}
%exclude /lib/modules/%{kversion}/build
%exclude /lib/modules/%{kversion}/source

%files devel
/usr/src/kernels/%{kversion}
/lib/modules/%{kversion}/build
/lib/modules/%{kversion}/source
