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

schedtool -D -n19 -e "$dir_scripts"/docker_bootstrap.sh $procs
schedtool -D -n19 -e "$dir_scripts"/docker_build-source_all.sh $procs $build
schedtool -D -n19 -e "$dir_scripts"/docker_submit-ppa-sources.sh $build
schedtool -D -n19 -e "$dir_scripts"/docker_build-binary_debian.sh $build
