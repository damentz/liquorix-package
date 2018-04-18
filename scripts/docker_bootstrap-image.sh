#!/bin/bash

set -euo pipefail

declare distro=${1:-}
declare release=${2:-}

declare -i fail=0

if [[ -z "$distro" ]]; then
    echo "[ERROR] No distribution set!"
    fail=1
fi

if [[ -z "$release" ]]; then
    echo "[ERROR] No release set!"
    fail=1
fi

if [[ $fail -eq 1 ]]; then
    echo "[ERROR] Encountered a fatal error, cannot continue!"
    exit 1
fi

declare release_string="liquorix_$distro/$release"
if [[ "$(docker image ls)" == *"$release_string"* ]]; then
    echo "[INFO ] $release_string: Docker image already built, performing update."
    declare container_id=$(
        docker run -d $release_string bash -c \
        'apt-get update && apt-get dist-upgrade && rm -rf /var/cache/apt'
    )

    echo "[INFO ] $release_string: Trailing container - $container_id"
    while true; do
        if [[ -n "$(docker container ls -q -f id=$container_id)" ]]; then
            sleep 1
        else
            break
        fi
    done

    echo "[INFO ] $release_string: Committing updated container to repository"
    docker commit -m "Update system packages" "$container_id" "$release_string" > /dev/null

    echo "[INFO ] $release_string: Removing container - $container_id"
    docker container rm "$container_id" > /dev/null
else
    echo "[INFO ] $release_string: Docker image not found, building with Dockerfile."
    docker build -t "$release_string" \
        --build-arg=DISTRO=$distro \
        --build-arg=RELEASE=$release \
        ./
fi