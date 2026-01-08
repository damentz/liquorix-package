ARG ARCH
ARG DISTRO
ARG RELEASE

FROM $ARCH/$DISTRO:$RELEASE

ARG DEFAULT
ARG PUBLIC
ARG SECRET

ENV DEBIAN_FRONTEND=noninteractive
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

RUN echo "$PUBLIC" | gpg --import &&\
    echo "$SECRET" | gpg --import --batch --no-tty &&\
    echo "default-key $DEFAULT" > ~/.gnupg/gpg.conf

RUN if command -v sq; then \
        sq pki link add --cert "$DEFAULT" --userid \
            "$(gpg --list-keys --with-colons $DEFAULT | grep ^uid | cut -d: -f10)" &&\
        sq pki link authorize --cert "$DEFAULT" --all --unconstrained; \
    fi
