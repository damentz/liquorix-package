#!/bin/bash

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"
set -euo pipefail

declare distro=${1:-}
declare release=${2:-}
declare version_build=${3:-1}
declare dir_build="/build"
declare dir_sources="$dir_base/$distro/$release"

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

# Ubuntu packages like to have the "ubuntu" name inserted between the package
# version and the build number, while Debian packages don't care.
declare version=''
if [[ "$distro" == "ubuntu" ]]; then
    version="${version_package}ubuntu${version_build}~${release}"
else
    version="${version_package}.${version_build}~${release}"
fi
echo "[INFO ] Building source package for $release"
build_source_package "$release" "$version"

echo "[INFO ] Copying sources to bind mount: $dir_sources/"
mkdir -p "$dir_sources"
cp -arv "$dir_build/"*$version* "$dir_sources/"