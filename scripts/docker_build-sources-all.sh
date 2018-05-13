#!/bin/bash

set -euo pipefail

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

declare -i processes_default=2
declare -i processes=${1:-"$processes_default"}
declare -i build=${2:-${version_build}}
declare -a args=()

declare distro=''

distro='ubuntu'
for release in "${releases_ubuntu[@]}"; do
    args+=("$distro" "$release" "$build")
done

distro='debian'
for release in "${releases_debian[@]}"; do
    args+=("$distro" "$release" "$build")
done

echo "[DEBUG] $0, args: ${args[@]}"
for item in "${args[@]}"; do
    echo "$item"
done | xargs -n3 -P "$processes" "$dir_base/scripts/docker_build-source.sh"
