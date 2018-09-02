#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

declare distro=${1:-}
declare release=${2:-}
declare build=${3:-${version_build}}

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

docker run \
    --rm \
	--tmpfs /build:exec \
    -v $dir_base:/liquorix-package \
    -t "liquorix_$source_arch/$source_distro/$source_release" \
    /liquorix-package/scripts/container_build-source.sh \
        $distro \
        $release \
        $build
