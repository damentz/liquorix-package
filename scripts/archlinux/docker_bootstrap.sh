#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

# Bootstrap common prerequisites
"$dir_scripts"/common_bootstrap.sh

cd "$dir_scripts"

if ! command -v docker > /dev/null; then
    echo "[ERROR] Docker is not installed, cannot continue!"
    exit 1
fi

declare -i processes_default=2
declare -i processes=${1:-"$processes_default"}

if [[ $processes -eq $processes_default ]]; then
    echo "[INFO ] Using default process count, $processes"
else
    echo "[INFO ] Using override process count, $processes"
fi

# Build arguments to bootstrap images in parallel
declare -a architectures=('amd64')
declare -a distros=('archlinux')
declare -a releases=('latest')
declare -a args=()
for arch in "${architectures[@]}"; do
    for distro in "${distros[@]}"; do
        for release  in "${releases[@]}"; do
            args+=("$arch" "$distro" "$release")
        done
    done
done

# Then pass them into docker_bootstrap-image.sh with xargs
for item in "${args[@]}"; do
    echo "$item"
done | xargs -n3 -P "$processes" "$dir_scripts/docker_bootstrap-image.sh"
