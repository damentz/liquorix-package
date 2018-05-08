#!/bin/bash

set -euo pipefail

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

declare -i processes_default=2
declare -i processes=${1:-"$processes_default"}
declare -a releases=("${releases_ubuntu[@]}")
declare -a args=()

for release in "${releases[@]}"; do
    args+=('ubuntu' "$release")
done

echo "[DEBUG] $0, args: ${args[@]}"
for item in "${args[@]}"; do
    echo "$item"
done | xargs -n2 -P "$processes" "$dir_base/scripts/docker_build-sources.sh"