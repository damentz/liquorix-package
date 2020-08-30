#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

declare -i processes_default=2
declare -i processes=${1:-${processes_default}}
declare -a args=()

declare distro=''

for arch in 'amd64'; do
    distro='archlinux'
    for release in "${releases[@]}"; do
        args+=("$arch" "$distro" "$release")
    done
done

echo "[DEBUG] $0, args: ${args[@]}"
for item in "${args[@]}"; do
    echo "$item"
done | xargs -n3 -P "$processes" "$dir_scripts/docker_build-binary.sh"
