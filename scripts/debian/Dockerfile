ARG ARCH
ARG DISTRO
ARG RELEASE
# Image tag to start from; differs from RELEASE when Docker Hub has no image
# for RELEASE yet (a new Ubuntu development release).
ARG BASE_TAG=$RELEASE

FROM $ARCH/$DISTRO:$BASE_TAG

ARG RELEASE
ENV DEBIAN_FRONTEND=noninteractive

# Point apt at RELEASE when starting from another release's image; the
# dist-upgrade below then upgrades the image to it.
RUN . /etc/os-release &&\
    if [ "$VERSION_CODENAME" != "$RELEASE" ]; then \
        sed -i "s/\\b$VERSION_CODENAME\\b/$RELEASE/g" \
            $(ls /etc/apt/sources.list /etc/apt/sources.list.d/*.sources 2>/dev/null) &&\
        grep -rqw "$RELEASE" /etc/apt/sources.list /etc/apt/sources.list.d/; \
    fi
RUN apt-get update &&\
    apt-get install eatmydata -y &&\
    apt-get clean &&\
    rm -rfv /var/lib/apt/lists/*

ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libeatmydata.so
RUN apt-get update &&\
    apt-get dist-upgrade -y &&\
    apt-get install -y \
        build-essential \
        devscripts \
        equivs \
        wget \
        gnupg \
        schedtool &&\
    apt-get clean &&\
    rm -rfv /var/lib/apt/lists/*
