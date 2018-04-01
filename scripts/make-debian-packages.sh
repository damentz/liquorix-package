#!/bin/bash

set -e

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

if [[ -n "$1" ]]; then
    echo "[INFO ] Build version overridden to: $1"
    version_build="$1"
fi

package_source="${package_name}_${version_kernel}.orig.tar.xz"

releases=(
    sid
)

echo "[DEBUG] package_name:   $package_name"
echo "[DEBUG] package_source: $package_source"
echo "[DEBUG] dir_script:  $dir_script"
echo "[DEBUG] dir_base:    $dir_base"
echo "[DEBUG] dir_package: $dir_package"
echo "[DEBUG] dir_build:   $dir_build"
echo "[DEBUG] releases_debian: ${releases_debian[@]}"

function build_binary_package {
    local release_name="$1"
    local release_version="$2"
    local release_file="${dir_build}/${package_name}_${release_version}.dsc"

    for arch in "${pbuilder_arches[@]}"; do
        declare bootstrap="$pbuilder_chroots/$release_name-$arch-base.tgz"
        declare opts_release="--distribution $release_name"
        declare opts_arch="--architecture $arch"
        declare opts_chroot="--basetgz $bootstrap"
        declare opts_results="--buildresult $pbuilder_results"
        declare opts_final="$opts_mirror $opts_release $opts_arch $opts_chroot"

        echo "[DEBUG] opts_final = $opts_final"

        schedtool -D -n19 -e sudo pbuilder build $opts_final $release_file ||
            { echo "[ERROR] Failed to execute 'pbuilder'"; }
    done
}

prepare_env

for release_name in "${releases_debian[@]}"; do
    release_version="${version_package}.${version_build}~${release_name}"

    echo "[INFO ] Building source package for $release_name"
    build_source_package "$release_name" "$release_version"

    echo "[INFO ] Building binary package for $release_name"
    build_binary_package "$release_name" "$release_version"
done
