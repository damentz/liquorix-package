#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

function prepare_env {
    echo "[INFO ] Preparing build directory: $dir_build"
    mkdir -p "$dir_build"
    if [[ -d "$dir_build/$package_name" ]]; then
        echo "[INFO ] Removing $dir_build/$package_name"
        rm -rf "$dir_build/$package_name"
    fi

    echo "[INFO ] Creating folder $package_name in $dir_build/"
    mkdir -pv "$dir_build/$package_name"

    echo "[INFO ] Copying source packages to $dir_build/"
    cp -arv "$dir_artifacts/"*${version}.* "$dir_build/"

    if [[ ! -f "$dir_base/$package_source" ]]; then
        echo "[WARN ] Missing source file: $dir_base/$package_source, downloading now."
        wget -O "$dir_base/$package_source" "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${version_kernel}.tar.xz"
    fi

    if [[ ! -L "$dir_build/$package_source" ]]; then
        echo "[INFO ] Missing symlink: $dir_build/$package_source, creating"
        ln -sf "$dir_base/$package_source" "$dir_build/$package_source"
    fi

    cd "$dir_build"

    echo "[INFO ] Extracting source package to $dir_build/$package_name-$version_kernel"
    dpkg-source -x "${package_name}_${version}.dsc"
}

declare arch=${1:-}
declare distro=${2:-}
declare release=${3:-}
declare build=${4:-${version_build}}
declare version="$(get_release_version $distro $release $build)"

declare dir_build="/build"
declare dir_artifacts="$dir_artifacts/$distro/$release"

declare -i fail=0

if [[ -z "$arch" ]]; then
    echo "[ERROR] No architecture set!"
    fail=1
fi

if [[ -z "$distro" ]]; then
    echo "[ERROR] No distribution set!"
    fail=1
fi

if [[ -z "$release" ]]; then
    echo "[ERROR] No release set!"
    fail=1
fi

if [[ $fail -eq 1 ]]; then
    echo "[ERROR] Encountered a fatal error, cannot continue!"
    exit 1
fi

prepare_env

# We need to update our lists to we can install dependencies correctly
apt-get update

cd "$dir_build/$package_name-$version_kernel"
mk-build-deps -ir -t 'apt-get -y'

echo "[INFO ] Building binary package for $release"
dpkg-buildpackage --build=binary

echo "[INFO ] Copying binary packages to bind mount: $dir_artifacts/"
mkdir -p "$dir_artifacts"

cp -arv "$dir_build/"*${version}_${arch}* "$dir_artifacts/"