#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"
# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

declare arch=${1:-}
declare distro=${2:-}
declare release=${3:-}

declare dir_artifacts="$dir_artifacts/$distro/$release"

require_build_args "$arch" "$distro" "$release"

log_info "Preparing build directory: $dir_build"
sudo mkdir -vp "$dir_build"
sudo chown -R "$build_user":"$build_user" "$dir_build"
cd "$dir_build" || exit

unzip -j "$dir_base/$package_source"

log_info "Building binary package for $release"
export PACKAGER="$package_maintainer"

declare -a makepkg_flags=(-s)
if gpg_available; then
    makepkg_flags+=(--sign)
else
    log_warn "No GPG signing key available, skipping package signing"
fi

$schedtool makepkg "${makepkg_flags[@]}"

sudo mkdir -vp "$dir_artifacts"
sudo chown -R "$build_user":"$build_user" "$dir_artifacts"
cp -arv "$dir_build/"*.pkg.tar* "$dir_artifacts/"

log_info "Creating AUR repository"
cd "$dir_artifacts" || exit
repo-add "$repo_file" ./*.pkg.tar.zst
tar --remove-files -cf "$repo_name.tar" -- *.pkg.tar* *.db* *.files*

ls -ltrh
