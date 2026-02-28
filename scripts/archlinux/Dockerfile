
ARG ARCH
ARG DISTRO
ARG RELEASE

FROM $ARCH/$DISTRO:base-devel

RUN echo 'Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch' \
      > /etc/pacman.d/mirrorlist &&\
    pacman -Syyu \
        base-devel \
        bc \
        cpio \
        fakeroot \
        git \
        gnupg \
        inetutils \
        kmod \
        libeatmydata \
        libelf \
        openssh \
        pacman-contrib \
        pahole \
        python \
        rust \
        rust-bindgen \
        rust-src \
        schedtool \
        sudo \
        unzip \
        wget \
        zstd \
        --noconfirm \
        --needed &&\
    rm -rf /var/cache/pacman

ENV LD_PRELOAD=/usr/lib/libeatmydata.so

RUN sed -r -i.bak 's/^#?MAKEFLAGS.*/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf &&\
    sed -r -i.bak 's/^PKGEXT.*/PKGEXT=".pkg.tar.zst"/' /etc/makepkg.conf &&\
    sed -r -i.bak 's/^SRCEXT.*/SRCEXT=".src.tar.zst"/' /etc/makepkg.conf &&\
    sed -r -i.bak 's/^BUILDENV.*/BUILDENV=(fakeroot !distcc !color !ccache check !sign)/' /etc/makepkg.conf &&\
    useradd -ms /bin/bash builder && mkdir -p /etc/sudoers.d &&\
    echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/10-builder

USER builder
WORKDIR /home/builder
