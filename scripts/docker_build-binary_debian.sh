#!/bin/bash

set -euo pipefail

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

declare -i processes_default=2
declare -i processes=${1:-"$processes_default"}
declare -i build=${2:-${version_build}}
declare -a args=()

declare distro=''

for arch in 'amd64' 'i386'; do
    distro='debian'
    for release in "${releases_debian[@]}"; do
        args+=("$arch" "$distro" "$release" "$build")
    done
done

echo "[DEBUG] $0, args: ${args[@]}"
for item in "${args[@]}"; do
    echo "$item"
done | xargs -n4 -P "$processes" "$dir_base/scripts/docker_build-binary.sh"
