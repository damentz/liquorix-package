#!/bin/bash

set -e

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

echo "[DEBUG] package_name:   $package_name"
echo "[DEBUG] package_source: $package_source"
echo "[DEBUG] dir_script:  $dir_script"
echo "[DEBUG] dir_base:    $dir_base"
echo "[DEBUG] dir_package: $dir_package"
echo "[DEBUG] releases:    ${releases[@]}"

function prepare_env {

    echo "[INFO ] Preparing package directory: $dir_package"

    cd "$dir_package"
    echo "[INFO ] Cleaning $package_name"
    fakeroot debian/rules maintainerclean

    if [[ ! -f "$dir_base/$package_source" ]]; then
        echo "[WARN ] Missing source file: $dir_base/$package_source, downloading now."
        wget -O "$dir_base/$package_source" "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${version_kernel}.tar.xz"
    fi

    echo "[INFO ] Unpacking kernel source into package folder."
    tar -xpf "$dir_base/$package_source" --strip-components=1 -C "$dir_package/"
}

function build_source_package {
    cd "$dir_package"

    echo "[INFO ] Cleaning package"
    local clean='fakeroot debian/rules clean'
    $clean || $clean

    echo "[INFO ] Making source package"
    debuild --no-lintian -S -sa
}

prepare_env
build_source_package