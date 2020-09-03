
ARG ARCH
ARG DISTRO
ARG RELEASE

FROM $ARCH/$DISTRO:$RELEASE

RUN pacman -Syu --noconfirm &&\
	pacman -S gnupg pacman-contrib zstd schedtool sudo \
              kmod inetutils bc libelf cpio fakeroot base-devel \
              --noconfirm &&\
    rm -rf /var/cache/pacman &&\
    rm -rf /var/lib/pacman/sync &&\
    sed -r -i.bak 's/^#?MAKEFLAGS.*/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf &&\
    sed -r -i.bak 's/^PKGEXT.*/PKGEXT=".pkg.tar.zst"/' /etc/makepkg.conf &&\
    sed -r -i.bak 's/^SRCEXT.*/SRCEXT=".src.tar.zst"/' /etc/makepkg.conf &&\
    sed -r -i.bak 's/^BUILDENV.*/BUILDENV=(fakeroot !distcc !color !ccache check !sign)/' /etc/makepkg.conf &&\
    useradd -ms /bin/bash builder && mkdir -p /etc/sudoers.d &&\
    echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/10-builder

USER builder
WORKDIR /home/builder
ARG DEFAULT
ARG PUBLIC
ARG SECRET
RUN gpg --keyserver na.pool.sks-keyservers.net --recv-keys \
		79BE3E4300411886  9AE4078033F8024D  38DBBDC86092693E &&\
    echo "$PUBLIC" | gpg --import &&\
    echo "$SECRET" | gpg --import &&\
    echo "default-key $DEFAULT" >> ~/.gnupg/gpg.conf
