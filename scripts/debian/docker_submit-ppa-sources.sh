#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

require_gpg

declare -i build=${1:-${version_build}}
declare distro='ubuntu'

for release in "${releases_ubuntu[@]}"; do
    log_info "Uploading sources for $distro/$release"
    docker run --net='host' \
    --rm \
    --env LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libeatmydata.so \
    -v "$HOME/.gnupg":/root/.gnupg \
    $(gpg_agent_mount_flags /root) \
    -v "$dir_base":/liquorix-package \
    -t "liquorix_$source_arch/$source_distro/$source_release" \
    /liquorix-package/scripts/debian/container_dput-to-ppa.sh \
        "$distro" \
        "$release" \
        "$build"
done
