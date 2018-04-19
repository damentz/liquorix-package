ARG DISTRO
ARG RELEASE

FROM $DISTRO:$RELEASE

LABEL DISTRO=$DISTRO
LABEL RELEASE=$RELEASE

RUN apt-get update &&\
    apt-get install eatmydata -y &&\
    eatmydata apt-get dist-upgrade -y &&\
    eatmydata apt-get install build-essential devscripts -y &&\
    eatmydata apt-get clean &&\
    eatmydata rm -rfv /var/lib/apt/lists/*
