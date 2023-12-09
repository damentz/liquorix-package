#!/bin/bash

dir_script="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
package_name='linux-liquorix'

dir_base="${dir_script%/*/*}"
dir_package="$dir_base/$package_name"
dir_build="$dir_base/build"
dir_scripts="$dir_base/scripts/debian"
dir_artifacts="$dir_base/artifacts"

version_package="$( head -n1 "$dir_package"/debian/changelog | grep -Po '\d+\.\d+-\d+' )"
version_kernel="$(  echo $version_package                    | grep -Po '\d+\.\d+' )"
version_major="$(   echo $version_kernel                     | sed -r 's/\..*//' )"
version_build="1"

package_source="${package_name}_${version_kernel}.orig.tar.xz"

# Distribution and release to build source packages with.  Normally defaulted
# to Debian Sid since it normally tracks the latest upstream.
source_arch='amd64'
source_distro='debian'
source_release='bookworm'

# stable => bookworm, testing => trixie, unstable => sid
releases_debian=('bookworm' 'trixie' 'sid')
releases_ubuntu=('jammy' 'lunar' 'mantic' 'noble')
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
    'gzip'
    'pigz'
    'xz-utils'
    'schedtool'
)

schedtool='schedtool -D -n19 -e'

# Common routine to get correct release version for Debian / Ubuntu
function get_release_version {
    local distro="${1:-}"
    local release="${2:-}"
    local build="${3:-${version_build}}"

    declare version=''
    if [[ "$distro" == "ubuntu" ]]; then
        version="${version_package}ubuntu${build}~${release}"
    else
        version="${version_package}.${build}~${release}"
    fi

    echo "$version"
}

function prepare_env {
    echo "[INFO ] Preparing build directory: $dir_build"
    mkdir -p "$dir_build"
    if [[ -d "$dir_build/$package_name" ]]; then
        echo "[INFO ] Removing $dir_build/$package_name"
        rm -rf "$dir_build/$package_name"
    fi

    echo "[INFO ] Creating folder $package_name in $dir_build/"
    mkdir -pv "$dir_build/$package_name"

    echo "[INFO ] Copying $package_name/debian to $dir_build/$package_name/"
    cp -raf "$dir_package/debian" "$dir_build/$package_name/"

    # Fakeroot has a 15% chance of failing for a semop error in docker
    local maintainerclean='fakeroot debian/rules maintainerclean'
    if [[ "$(id -u)" == 0 ]]; then
        maintainerclean='debian/rules maintainerclean'
    fi
    cd "$dir_build/$package_name"

    echo "[INFO ] Running '$maintainerclean'"
    $maintainerclean

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

    # Fakeroot has a 15% chance of failing for a semop error in docker
    if [[ "$(id -u)" == 0 ]]; then
        clean='debian/rules clean'
    fi

    $clean || $clean

    mk-build-deps -ir -t 'apt-get -y'

    EDITOR="cat" \
    DPKG_SOURCE_COMMIT_MESSAGE="Automated changes through CI" \
    DPKG_SOURCE_COMMIT_OPTIONS="--include-removal" \
        dpkg-source --commit . ci.patch

    echo "[INFO ] Making source package"
    $schedtool dpkg-buildpackage --build=source
}
