ARG DISTRO
ARG RELEASE

FROM $DISTRO:$RELEASE

LABEL DISTRO=$DISTRO
LABEL RELEASE=$RELEASE

RUN apt-get update &&\
    apt-get dist-upgrade -y &&\
    apt-get install build-essential devscripts -y &&\
    rm -rfv /var/cache/apt &&\
    rm -rfv /var/lib/apt/lists/*

