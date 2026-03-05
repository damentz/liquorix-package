#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"
# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

declare distro=${1:-}
declare release=${2:-}
declare build=${3:-${version_build}}
declare dir_build="/build"
declare dir_artifacts="$dir_artifacts/$distro/$release"

declare -i fail=0
require_var "distribution" "$distro" || fail=1
require_var "release" "$release" || fail=1
if [[ $fail -eq 1 ]]; then
    exit 1
fi

prepare_env

# We need to update our lists to we can install dependencies correctly
apt-get update

version="$(get_release_version "$distro" "$release" "$build")"

log_info "Building source package for $release"
build_source_package "$release" "$version"

log_info "Copying sources to bind mount: $dir_artifacts/"
mkdir -p "$dir_artifacts"
cp -arv "$dir_build/"*"$version"* "$dir_artifacts/"