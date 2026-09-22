#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"
# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

# Bootstrap common prerequisites
"$dir_scripts"/common_bootstrap.sh

cd "$dir_scripts"

require_docker

declare -i processes_default=2
declare -i processes=${1:-"$processes_default"}

if [[ $processes -eq $processes_default ]]; then
    log_info "Using default process count, $processes"
else
    log_info "Using override process count, $processes"
fi

# Distros to bootstrap release images for, default all
declare -a distros=("${@:2}")
[[ ${#distros[@]} -gt 0 ]] || distros=('debian' 'ubuntu')

# Build arguments to bootstrap images in parallel.  Source packages for every
# distro are built in the source image, so always include it.
declare -a architectures=('amd64')
declare -a args=("$source_arch" "$source_distro" "$source_release")
for arch in "${architectures[@]}"; do
    for distro in "${distros[@]}"; do
        declare -a releases=()
        if [[ "$distro" == 'debian' ]]; then
            releases=("${releases_debian[@]}")
        elif [[ "$distro" == 'ubuntu' ]]; then
            releases=("${releases_ubuntu[@]}")
        fi

        for release  in "${releases[@]}"; do
            [[ "$arch/$distro/$release" == "$source_arch/$source_distro/$source_release" ]] && continue
            args+=("$arch" "$distro" "$release")
        done
    done
done

# Then pass them into docker_bootstrap-image.sh with xargs
for item in "${args[@]}"; do
    echo "$item"
done | xargs -n3 -P "$processes" "$dir_scripts/docker_bootstrap-image.sh"
