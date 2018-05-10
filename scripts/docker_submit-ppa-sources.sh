#!/bin/bash

set -euo pipefail

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

declare -i processes_default=2
declare -i processes=${1:-"$processes_default"}
declare -a releases=("${releases_ubuntu[@]}")
declare -i build=${2:-${version_build}}
declare -a args=()

declare distro='ubuntu'
for release in "${releases[@]}"; do
    args+=("$distro" "$release" "$build")
done

echo "[DEBUG] $0, args: ${args[@]}"
for item in "${args[@]}"; do
    echo "$item"
done | xargs -n3 -P "$processes" "$dir_base/scripts/docker_build-sources.sh"

for release in "${releases[@]}"; do
    echo "[INFO ] Uploading sources for $distro/$release"
    docker run \
    --rm \
    -v $dir_base:/liquorix-package \
    -t "liquorix_$source_arch/$source_distro/$source_release" \
    /liquorix-package/scripts/container_dput-to-ppa.sh \
        "$distro" \
        "$release" \
        "$build"
done
