ARG ARCH
ARG DISTRO
ARG RELEASE
# Image tag to start from; differs from RELEASE when Docker Hub has no image
# for RELEASE yet (a new Ubuntu development release).
ARG BASE_TAG=$RELEASE

FROM $ARCH/$DISTRO:$BASE_TAG

ARG RELEASE
ENV DEBIAN_FRONTEND=noninteractive

# Move to RELEASE when starting from another release's image.  The base image
# can hold updates newer than RELEASE's archive (a new development release is
# copied from the previous release pocket, not its -updates), so pin RELEASE
# and allow downgrades to match RELEASE's versions exactly.
RUN . /etc/os-release &&\
    if [ "$VERSION_CODENAME" != "$RELEASE" ]; then \
        sed -i "s/\\b$VERSION_CODENAME\\b/$RELEASE/g" \
            $(ls /etc/apt/sources.list /etc/apt/sources.list.d/*.sources 2>/dev/null) &&\
        grep -rqw "$RELEASE" /etc/apt/sources.list /etc/apt/sources.list.d/ &&\
        printf 'Package: *\nPin: release n=%s\nPin-Priority: 1001\n' "$RELEASE" \
            > /etc/apt/preferences.d/zz-liquorix-release &&\
        apt-get update &&\
        apt-get dist-upgrade -y --allow-downgrades &&\
        rm /etc/apt/preferences.d/zz-liquorix-release &&\
        apt-get clean &&\
        rm -rf /var/lib/apt/lists/*; \
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
