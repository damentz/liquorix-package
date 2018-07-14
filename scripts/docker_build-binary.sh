#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

declare arch=${1:-}
declare distro=${2:-}
declare release=${3:-}
declare build=${4:-${version_build}}

declare -i fail=0

if [[ -z "$arch" ]]; then
    echo "[ERROR] No architecture set!"
    fail=1
fi

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

docker run \
    --rm \
    -v $dir_base:/liquorix-package \
    -t "liquorix_$arch/$distro/$release" \
    /liquorix-package/scripts/container_build-binary.sh \
        $arch \
        $distro \
        $release \
        $build
