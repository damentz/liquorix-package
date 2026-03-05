#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

# Redefine prepare_env with only the necessary operations required to save time.
function prepare_env {
    log_info "Preparing build directory: $dir_build"
    mkdir -p "$dir_build"
    if [[ -d "$dir_build/$package_name" ]]; then
        log_info "Removing $dir_build/$package_name"
        rm -rf "${dir_build:?}/$package_name"
    fi

    if [[ ! -L "$dir_build/$package_source" ]]; then
        log_info "Missing symlink: $dir_build/$package_source, creating"
        ln -sf "$dir_base/$package_source" "$dir_build/$package_source"
    fi
}

declare distro=${1:-}
declare release=${2:-}
declare build=${3:-}

declare version
version="$(get_release_version "$distro" "$release" "$build")"
declare conf_dput="$dir_base/configs/.dput.cf"
declare dir_build="/build"
declare dir_artifacts="$dir_artifacts/$distro/$release"

prepare_env

cd "$dir_build" || exit
cp -av "$dir_artifacts/${package_name}_${version}"* ./

dput --config "$conf_dput" 'liquorix' "${package_name}_${version}_source.changes"
