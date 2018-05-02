#!/bin/bash

dir_script="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
package_name='linux-liquorix'

dir_base="${dir_script%/*}"
dir_package="$dir_base/$package_name"
dir_build="$dir_base/build"


version_package="$( head -n1 "$dir_package"/debian/changelog | grep -Po '\d+\.\d+-\d+' )"
version_kernel="$(  head -n1 "$dir_package"/debian/changelog | grep -Po '\d+\.\d+' )"
version_build="1"

package_source="${package_name}_${version_kernel}.orig.tar.xz"

releases_debian=('sid')
releases_ubuntu=('xenial' 'artful' 'bionic' 'cosmic')
mirror_debian='http://deb.debian.org/debian'
mirror_ubuntu='http://archive.ubuntu.com/ubuntu'

# Now that we're sure this system is compatible with the bootstrap script, lets
# set all the variables needed to proceed.
build_user="$(whoami)"
build_base=$(grep -E "^${build_user}:" /etc/passwd | cut -f6 -d:)
build_deps=(
    'debhelper'
    'devscripts'
    'fakeroot'
    'gcc'
    'pbuilder'
    'gzip'
    'pigz'
    'xz-utils'
    'schedtool'
)

pbuilder_releases=("${releases_debian[@]}")
pbuilder_arches=('amd64' 'i386')
pbuilder_mirror="$mirror_debian"
pbuilder_chroots="/var/cache/pbuilder"
pbuilder_results="$dir_base/debs"

function prepare_env {
    echo "[INFO ] Preparing build directory: $dir_build"
    mkdir -p "$dir_build"
    if [[ -d "$dir_build/$package_name" ]]; then
        echo "[INFO ] Removing $dir_build/$package_name"
        rm -rf "$dir_build/$package_name"
    fi

    cd "$dir_package"
    echo "[INFO ] Cleaning $package_name"
    fakeroot debian/rules maintainerclean

    echo "[INFO ] Copying $package_name to $dir_build/"
    cp -raf "$dir_package/" "$dir_build/"

    if [[ ! -f "$dir_base/$package_source" ]]; then
        echo "[WARN ] Missing source file: $dir_base/$package_source, downloading now."
        wget -O "$dir_base/$package_source" "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${version_kernel}.tar.xz"
    fi

    if [[ ! -L "$dir_build/$package_source" ]]; then
        echo "[INFO ] Missing symlink: $dir_build/$package_source, creating"
        ln -sf "$dir_base/$package_source" "$dir_build/$package_source"
    fi

    echo "[INFO ] Unpacking kernel source into package folder."
    tar -xpf "$dir_base/$package_source" --strip-components=1 -C "$dir_build/$package_name"
}

function build_source_package {
    local release_name="$1"
    local release_version="$2"

    cd "$dir_build/$package_name"

    echo "[INFO ] Updating changelog to: $release_version"
    sed -r -i "1s/[^;]+(;.*)/$package_name ($release_version) $release_name\1/" debian/changelog

    echo "[INFO ] Cleaning package"
    local clean='fakeroot debian/rules clean'
    $clean || $clean

    echo "[INFO ] Making source package"
    debuild --no-lintian -S -sa
}
