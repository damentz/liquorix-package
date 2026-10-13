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

# A custom build merges zen-kernel branches into the release and renames the package
if [[ -n "${FEATURE_BRANCHES:-}" ]]; then
    "$dir_scripts/merge-branches.sh"
fi

log_info "Building binary package for $release"
export PACKAGER="$package_maintainer"

$schedtool makepkg -s
for pkg in ./*.pkg.tar.zst; do
    gpg --detach-sign --use-agent --no-armor "$pkg" || log_warn "GPG signing failed for ${pkg##*/}, skipping"
done

sudo mkdir -vp "$dir_artifacts"
sudo chown -R "$build_user":"$build_user" "$dir_artifacts"
cp -arv "$dir_build/"*.pkg.tar* "$dir_artifacts/"

cd "$dir_artifacts" || exit
# The job archives the packages of a custom build, they don't go into the repository
if [[ -z "${FEATURE_BRANCHES:-}" ]]; then
    log_info "Creating AUR repository"
    repo-add "$repo_file" ./*.pkg.tar.zst
    tar --remove-files -cf "$repo_name.tar" -- *.pkg.tar* *.db* *.files*
fi

ls -ltrh
