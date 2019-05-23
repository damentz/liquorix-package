#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"


declare build=${1:-${version_build}}
declare dir_scripts="$dir_base/scripts"

declare -i procs=0
if command -v nproc > /dev/null 2>&1; then
    procs=$(( $(nproc) / 2 ))
fi

if [[ $procs -lt 2 ]]; then
    procs=2
fi

"$dir_scripts"/docker_bootstrap.sh "$procs"
"$dir_scripts"/docker_build-source_all.sh "$procs" "$build"
"$dir_scripts"/docker_submit-ppa-sources.sh "$build"

# We build only one kernel at a time since each build uses all CPU resources
"$dir_scripts"/docker_build-binary_debian.sh 1 "$build"

"$dir_scripts"/repo_add-debian-packages.sh "$build"
