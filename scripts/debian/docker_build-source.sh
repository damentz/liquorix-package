#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"
# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

declare distro=${1:-}
declare release=${2:-}
declare build=${3:-${version_build}}

declare -i fail=0
require_var "distribution" "$distro" || fail=1
require_var "release" "$release" || fail=1
if [[ $fail -eq 1 ]]; then
    exit 1
fi

docker run --net='host' \
    --rm \
    --tmpfs /build:exec \
    --ulimit nofile=524288:524288 \
    -v "$HOME/.gnupg":/root/.gnupg \
    -v $dir_base:/liquorix-package \
    -t "liquorix_$source_arch/$source_distro/$source_release" \
    /liquorix-package/scripts/debian/container_build-source.sh \
        $distro \
        $release \
        $build
