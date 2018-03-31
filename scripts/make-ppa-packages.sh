#!/bin/bash

set -e

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"
version_build="1"
dir_build="$dir_base/ppa"

if [[ -n "$1" ]]; then
    echo "[INFO ] Build version overridden to: $1"
    version_build="$1"
fi

echo "[DEBUG] package_name:   $package_name"
echo "[DEBUG] package_source: $package_source"
echo "[DEBUG] dir_script:  $dir_script"
echo "[DEBUG] dir_base:    $dir_base"
echo "[DEBUG] dir_package: $dir_package"
echo "[DEBUG] dir_build:     $dir_build"
echo "[DEBUG] releases_ubuntu: ${releases_ubuntu[@]}"

prepare_env

for release_name in "${releases_ubuntu[@]}"; do
    declare release_version="${version_package}ubuntu${version_build}~${release_name}"

    echo "[INFO ] Building source package for $release"
    build_source_package "$release_name" "$release_version"

    echo "[INFO ] Uploading packages to Launchpad PPA"
    dput 'liquorix' "${dir_build}/${package_name}_${release_version}_source.changes" ||
        { echo "[ERROR] dput failed to push package!"; }
done
