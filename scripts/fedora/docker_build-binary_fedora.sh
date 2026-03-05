#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

declare -i processes_default=2
declare -i processes=${1:-${processes_default}}
declare -i build=${2:-${version_build}}
declare -a args=()

declare distro=''

for arch in 'amd64'; do
    distro='fedora'
    for release in "${releases_fedora[@]}"; do
        args+=("$arch" "$distro" "$release" "$build")
    done
done

log_debug "$0, args: ${args[*]}"
for item in "${args[@]}"; do
    echo "$item"
done | xargs -n4 -P "$processes" "$dir_scripts/docker_build-binary.sh"
