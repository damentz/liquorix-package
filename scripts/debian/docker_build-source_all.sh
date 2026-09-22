#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

declare -i processes_default=2
declare -i processes=${1:-"$processes_default"}
declare -i build=${2:-${version_build}}
declare -a args=()

# Distros to build sources for, default all
declare -a distros=("${@:3}")
[[ ${#distros[@]} -gt 0 ]] || distros=('ubuntu' 'debian')

for distro in "${distros[@]}"; do
    declare -n releases="releases_$distro"
    for release in "${releases[@]}"; do
        args+=("$distro" "$release" "$build")
    done
    unset -n releases
done

log_debug "$0, args: ${args[*]}"
for item in "${args[@]}"; do
    echo "$item"
done | xargs -n3 -P "$processes" "$dir_scripts/docker_build-source.sh"
