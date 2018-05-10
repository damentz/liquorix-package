#!/bin/bash

set -euo pipefail

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

declare distro=${1:-}
declare release=${2:-}
declare build=${3:-${version_build}}
declare dir_build="/build"
declare dir_artifacts="$dir_artifacts/$distro/$release"

declare -i fail=0

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

version="$(get_release_version $distro $release $build)"

echo "[INFO ] Building source package for $release"
build_source_package "$release" "$version"

echo "[INFO ] Copying sources to bind mount: $dir_artifacts/"
mkdir -p "$dir_artifacts"
cp -arv "$dir_build/"*$version* "$dir_artifacts/"