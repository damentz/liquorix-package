ARG ARCH
ARG DISTRO
ARG RELEASE

FROM $ARCH/$DISTRO:$RELEASE

ARG DEFAULT
ARG PUBLIC
ARG SECRET
RUN apt-get update &&\
    apt-get install eatmydata -y &&\
    eatmydata apt-get dist-upgrade -y &&\
    eatmydata apt-get install -y \
        build-essential \
        devscripts \
        equivs \
        wget \
        gnupg \
        schedtool &&\
    eatmydata apt-get clean &&\
    eatmydata rm -rfv /var/lib/apt/lists/* &&\
    echo "$PUBLIC" | gpg --import &&\
    echo "$SECRET" | gpg --import &&\
    echo "default-key $DEFAULT" > ~/.gnupg/gpg.conf
