
ARG ARCH
ARG DISTRO
ARG RELEASE

FROM $DISTRO:$RELEASE

# eatmydata first, so every later step skips fsync
RUN dnf -y install libeatmydata &&\
    dnf clean all

ENV LD_PRELOAD=/usr/lib64/libeatmydata.so
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
        openssl \
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
