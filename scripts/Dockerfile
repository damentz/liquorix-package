ARG ARCH
ARG DISTRO
ARG RELEASE

FROM $ARCH/$DISTRO:$RELEASE

LABEL ARCH=$ARCH
LABEL DISTRO=$DISTRO
LABEL RELEASE=$RELEASE

RUN apt-get update &&\
    apt-get install eatmydata -y &&\
    eatmydata apt-get dist-upgrade -y &&\
    eatmydata apt-get install -y \
        build-essential \
        devscripts \
        wget \
        gnupg &&\
    eatmydata apt-get clean &&\
    eatmydata rm -rfv /var/lib/apt/lists/*
