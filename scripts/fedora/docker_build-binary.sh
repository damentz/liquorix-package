#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"
# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

require_gpg

declare arch=${1:-}
declare distro=${2:-}
declare release=${3:-}
declare build=${4:-${version_build}}

require_build_args "$arch" "$distro" "$release"

log_debug "dir_base: $dir_base"
docker run --net='host' \
    --rm \
    --ulimit nofile=524288:524288 \
    -v "$HOME/.gnupg":/home/builder/.gnupg \
    $(gpg_agent_mount_flags /home/builder) \
    -v "$dir_base":/liquorix-package \
    -t "liquorix_$arch/$distro/$release" \
    /liquorix-package/scripts/fedora/container_build-binary.sh \
        "$arch" \
        "$distro" \
        "$release" \
        "$build"
