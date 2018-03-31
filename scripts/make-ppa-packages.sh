#!/bin/bash

set -e

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"
version_build="1"

if [[ -n "$1" ]]; then
    echo "[INFO ] Build version overridden to: $1"
    version_build="$1"
fi

echo "[DEBUG] package_name:   $package_name"
echo "[DEBUG] package_source: $package_source"
echo "[DEBUG] dir_script:  $dir_script"
echo "[DEBUG] dir_base:    $dir_base"
echo "[DEBUG] dir_package: $dir_package"
echo "[DEBUG] dir_ppa:     $dir_ppa"
echo "[DEBUG] releases_ubuntu: ${releases_ubuntu[@]}"

function prepare_env {
    echo "[INFO ] Preparing PPA directory: $dir_ppa"
    mkdir -p "$dir_ppa"
    if [[ -d "$dir_ppa/$package_name" ]]; then
        echo "[INFO ] Removing $dir_ppa/$package_name"
        rm -rf "$dir_ppa/$package_name"
    fi

    cd "$dir_package"
    echo "[INFO ] Cleaning $package_name"
    fakeroot debian/rules maintainerclean

    echo "[INFO ] Copying $package_name to $dir_ppa/"
    cp -raf "$dir_package/" "$dir_ppa/"

    if [[ ! -f "$dir_base/$package_source" ]]; then
        echo "[WARN ] Missing source file: $dir_base/$package_source, downloading now."
        wget -O "$dir_base/$package_source" "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${version_kernel}.tar.xz"
    fi

    if [[ ! -L "$dir_ppa/$package_source" ]]; then
        echo "[INFO ] Missing symlink: $dir_ppa/$package_source, creating"
        ln -sf "$dir_base/$package_source" "$dir_ppa/$package_source"
    fi

    echo "[INFO ] Unpacking kernel source into package folder."
    tar -xpf "$dir_base/$package_source" --strip-components=1 -C "$dir_ppa/$package_name"
}

function build_source_package {
    local release_name="$1"
    local release_version="$2"

    cd "$dir_ppa/$package_name"

    echo "[INFO ] Updating changelog to: $release_version"
    sed -r -i "1s/[^;]+(;.*)/$package_name ($release_version) $release_name\1/" debian/changelog

    echo "[INFO ] Stripping gcc version (use release native gcc)"
    sed -r -i "s/gcc-[0-9]+/gcc/g" debian/config/defines

    echo "[INFO ] Cleaning package"
    local clean='fakeroot debian/rules clean'
    $clean || $clean

    echo "[INFO ] Making source package"
    debuild --no-lintian -S -sa
}

prepare_env

for release_name in "${releases_ubuntu[@]}"; do
    declare release_version="${version_package}ubuntu${version_build}~${release_name}"

    echo "[INFO ] Building source package for $release"
    build_source_package "$release_name" "$release_version"

    echo "[INFO ] Uploading packages to Launchpad PPA"
    dput 'liquorix' "${dir_ppa}/${package_name}_${release_version}_source.changes" ||
        { echo "[ERROR] dput failed to push package!"; }
done
