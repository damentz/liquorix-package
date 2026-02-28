#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

declare arch=${1:-}
declare distro=${2:-}
declare release=${3:-}

declare -i fail=0

if [[ -z "$arch" ]]; then
    echo "[ERROR] No architecture set!"
    fail=1
fi

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

declare release_string="liquorix_$arch/$distro/$release"
if [[ "$(docker image ls --format table)" == *"$release_string"* ]]; then
    echo "[INFO ] $release_string: Docker image already built, performing update."
    declare container_id=$(
        docker run --net='host' -d $release_string bash -c \
        'apt-get update && \
         apt-get dist-upgrade && \
         apt-get clean && \
         rm -rf /var/lib/apt/lists'
    )

    echo "[INFO ] $release_string: Waiting for container - $container_id"
    docker wait "$container_id" > /dev/null

    echo "[INFO ] $release_string: Committing updated container to repository"
    docker commit -m "Update system packages" "$container_id" "$release_string" > /dev/null

    echo "[INFO ] $release_string: Removing container - $container_id"
    docker container rm "$container_id" > /dev/null
else
    echo "[INFO ] $release_string: Docker image not found, building with Dockerfile."
    docker buildx build \
        --network="host" \
        --no-cache \
        --progress=quiet \
        -f "$dir_scripts/Dockerfile" \
        -t "$release_string" \
        --pull=true \
        --build-arg ARCH="$arch" \
        --build-arg DISTRO="$distro" \
        --build-arg RELEASE="$release" \
        $dir_base/
fi
