#!/bin/bash

set -euo pipefail

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

cd "$dir_base/scripts"

if ! which docker; then
    echo "[ERROR] Docker is not installed, cannot continue!"
    exit 1
fi

declare -a distros=('debian' 'ubuntu')

for distro in "${distros[@]}"; do

    declare -a releases=()
    if [[ "$distro" == 'debian' ]]; then
        releases=(${releases_debian[@]})
    elif [[ "$distro" == 'ubuntu' ]]; then
        releases=(${releases_ubuntu[@]})
    fi

    for release  in "${releases[@]}"; do
        declare release_string="liquorix_$distro/$release"
        if docker image ls | grep "$release_string"; then
            echo "[INFO ] Docker image '$release_string' already built, performing update."
            echo "[INFO ] STUB -- update not implemented yet."
        else
            echo "[INFO ] Docker image '$release_string' not found, building with Dockerfile."
            docker build -t "$release_string" \
                --build-arg=DISTRO=$distro \
                --build-arg=RELEASE=$release \
                ./
        fi
    done
done