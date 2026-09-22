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

    # Upload straight from the host when it has dput, no build image needed
    if command -v dput > /dev/null; then
        changes="$dir_artifacts/$distro/$release/${package_name}_$(get_release_version "$distro" "$release" "$build")_source.changes"

        # The orig tarball is only part of the upload for a new upstream version
        if grep -q "$package_source" "$changes"; then
            "$dir_scripts"/common_bootstrap.sh
            ln -sf "$dir_base/$package_source" "${changes%/*}/"
        fi

        dput --config "$dir_base/configs/.dput.cf" 'liquorix' "$changes"
        continue
    fi

    # shellcheck disable=SC2046
    docker run --net='host' \
    --rm \
    --tmpfs /build:exec \
    --env LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libeatmydata.so \
    $(gpg_docker_flags /root) \
    -v "$dir_base":/liquorix-package \
    -t "liquorix_$source_arch/$source_distro/$source_release" \
    /liquorix-package/scripts/debian/container_dput-to-ppa.sh \
        "$distro" \
        "$release" \
        "$build"
done
