#!/bin/bash

set -euo pipefail

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

declare distro=${1:-}
declare release=${2:-}

declare -i fail=0

if [[ -z "$distro" ]]; then
    echo "[ERROR] No distribution set!"
    fail=1
fi

if [[ -z "$release" ]]; then
    echo "[ERROR] No release set!"
    fail=1
fi

if [[ $fail -eq 1 ]]; then
    echo "[ERROR] Encountered a fatal error, cannot continue!"
    exit 1
fi

# Prefer amd64 if possible when making source files
declare -a architectures=('amd64' 'i386')
declare arch=''
declare release_string=''
for i in "${architectures[@]}"; do
    arch=$i
    release_string="liquorix_$arch/$source_distro/$source_release"
    if [[ "$(docker image ls)" == *"$release_string"* ]]; then
        break
    fi
done

if [[ -z "$release_string" ]]; then
    echo "[ERROR] Unable to set release string!"
    exit 1
fi

docker run \
    --rm \
    -v $dir_base:/liquorix-package \
    -it $release_string \
    /liquorix-package/scripts/container_build-sources.sh \
        $distro \
        $release
