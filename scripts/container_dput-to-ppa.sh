#!/bin/bash

set -euo pipefail

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

# Redefine prepare_env with only the necessary operations required to save time.
function prepare_env {
    echo "[INFO ] Preparing build directory: $dir_build"
    mkdir -p "$dir_build"
    if [[ -d "$dir_build/$package_name" ]]; then
        echo "[INFO ] Removing $dir_build/$package_name"
        rm -rf "$dir_build/$package_name"
    fi

    if [[ ! -L "$dir_build/$package_source" ]]; then
        echo "[INFO ] Missing symlink: $dir_build/$package_source, creating"
        ln -sf "$dir_base/$package_source" "$dir_build/$package_source"
    fi
}

declare distro=${1:-}
declare release=${2:-}
declare build=${3:-}

declare version="$(get_release_version $distro $release $build)"
declare conf_dput="$dir_base/configs/.dput.cf"
declare dir_build="/build"
declare dir_artifacts="$dir_artifacts/$distro/$release"

prepare_env

cd "$dir_build"
cp -av "$dir_artifacts/${package_name}_${version}"* ./

dput --config "$conf_dput" 'liquorix' "${package_name}_${version}_source.changes"