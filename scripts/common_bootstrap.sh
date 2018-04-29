#!/bin/bash

set -euo pipefail

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

if [[ ! -f "$dir_base/$package_source" ]]; then
    echo "[WARN ] Missing source file: $dir_base/$package_source, downloading now."
    wget -O "$dir_base/$package_source" "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${version_kernel}.tar.xz"
fi

declare gnupg_archive="$dir_base/docker_gnupg.tar.gz"
if [[ ! -f "$gnupg_archive" ]]; then
    echo "[WARN ] Missing gnupg archive file: $dir_base/$gnupg_archive, creating now."
    
    cd ~/
    tar -czvpf "$gnupg_archive" .gnupg/ || {
        echo "[ERROR] No gnupg configuration found, docker images will not build and package signing will fail!"
    }
fi
