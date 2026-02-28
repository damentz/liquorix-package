#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"
# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

declare arch=${1:-}
declare distro=${2:-}
declare release=${3:-}
declare build=${4:-${version_build}}

require_build_args "$arch" "$distro" "$release"

docker run --net='host' \
    --rm \
    --ulimit nofile=524288:524288 \
    -v "$HOME/.gnupg":/root/.gnupg \
    -v $dir_base:/liquorix-package \
    -t "liquorix_$arch/$distro/$release" \
    /liquorix-package/scripts/debian/container_build-binary.sh \
        $arch \
        $distro \
        $release \
        $build
