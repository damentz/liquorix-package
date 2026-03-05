#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"
# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

function prepare_env {
    log_info "Preparing build directory: $dir_build"
    mkdir -p "$dir_build"
    if [[ -d "$dir_build/$package_name" ]]; then
        log_info "Removing $dir_build/$package_name"
        rm -rf "${dir_build:?}/$package_name"
    fi

    log_info "Creating folder $package_name in $dir_build/"
    mkdir -pv "$dir_build/$package_name"

    log_info "Copying source packages to $dir_build/"
    cp -arv "$dir_artifacts/"*"${version}".* "$dir_build/"

    if [[ ! -L "$dir_build/$package_source" ]]; then
        log_info "Missing symlink: $dir_build/$package_source, creating"
        ln -sf "$dir_base/$package_source" "$dir_build/$package_source"
    fi

    cd "$dir_build" || exit

    log_info "Extracting source package to $dir_build/$package_name-$version_kernel"
    dpkg-source -x "${package_name}_${version}.dsc"
}

declare arch=${1:-}
declare distro=${2:-}
declare release=${3:-}
declare build=${4:-${version_build}}
declare version
version="$(get_release_version "$distro" "$release" "$build")"

declare dir_build="/build"
declare dir_artifacts="$dir_artifacts/$distro/$release"

require_build_args "$arch" "$distro" "$release"

prepare_env

# We need to update our lists to we can install dependencies correctly
apt-get update

cd "$dir_build/$package_name-$version_kernel" || exit
mk-build-deps -ir -t 'apt-get -y'

log_info "Building binary package for $release"
$schedtool dpkg-buildpackage --build=binary

log_info "Copying binary packages to bind mount: $dir_artifacts/"
mkdir -p "$dir_artifacts"

cp -arv "$dir_build/"*"${version}"_"${arch}"* "$dir_artifacts/"