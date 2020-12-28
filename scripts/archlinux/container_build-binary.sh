#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

declare arch=${1:-}
declare distro=${2:-}
declare release=${3:-}

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

# We need to update our lists to we can install dependencies correctly
sudo pacman -Sy

echo "[INFO ] Preparing build directory: $dir_build"
sudo mkdir -vp "$dir_build"
sudo chown -R "$build_user":"$build_user" "$dir_build"
cd "$dir_build"

tar -xpvf "$dir_base/$package_source" --strip-components=1

echo "[INFO ] Building binary package for $release"
export PACKAGER="$package_maintainer"
$schedtool makepkg --sign -s

echo "[INFO ] Copying binary packages to bind mount: $dir_artifacts/"
if [[ -d "$dir_artifacts" ]]; then
    echo "[INFO ] Removing existing artifacts first"
    sudo rm -fv "$dir_artifacts"/*
fi

sudo mkdir -vp "$dir_artifacts"
sudo chown -R "$build_user":"$build_user" "$dir_artifacts"
cp -arv "$dir_build/"*.pkg.tar* "$dir_artifacts/"

echo "[INFO ] Creating AUR repository"
cd "$dir_artifacts"
repo-add $repo_file *.pkg.tar.zst
tar --remove-files -cf "$repo_name.tar" -- *.pkg.tar* *.db* *.files*

ls -ltrh
