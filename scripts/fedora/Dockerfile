
ARG ARCH
ARG DISTRO
ARG RELEASE

FROM $DISTRO:$RELEASE

RUN dnf -y update &&\
    dnf -y install \
        bc \
        bindgen-cli \
        bison \
        cpio \
        dwarves \
        elfutils-devel \
        flex \
        gcc \
        gcc-c++ \
        gnupg2 \
        kmod \
        make \
        openssl-devel \
        patch \
        perl \
        python3 \
        rpm-build \
        rpm-sign \
        rpmdevtools \
        rust \
        rust-src \
        createrepo_c \
        schedtool \
        sudo \
        wget \
        xz \
        zstd &&\
    dnf clean all &&\
    rm -rf /var/cache/dnf

RUN useradd -ms /bin/bash builder && mkdir -p /etc/sudoers.d &&\
    echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/10-builder

USER builder
WORKDIR /home/builder

RUN rpmdev-setuptree
