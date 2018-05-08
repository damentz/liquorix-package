#!/bin/bash

set -euo pipefail

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

declare default_key="$(
    cat ~/.gnupg/gpg.conf ~/.gnupg/options 2>/dev/null | \
    grep -E '^\s*default-key' | grep -Po '\S+\s*$'
)"

if [[ -z "$default_key" ]]; then
    echo "[ERROR] No default key found in ~/.gnupg/gpg.conf or ~/.gnupg.options!  Cannot proceed with building bootstrap images."
    exit 1
fi

declare public="$(gpg --armor --export -a "$default_key")"
declare secret="$(gpg --armor --export-secret-keys -a "$default_key")"

declare release_string="liquorix_$arch/$distro/$release"
if [[ "$(docker image ls)" == *"$release_string"* ]]; then
    echo "[INFO ] $release_string: Docker image already built, performing update."
    declare container_id=$(
        docker run -d $release_string bash -c \
        'eatmydata apt-get update && \
         eatmydata apt-get dist-upgrade && \
         eatmydata apt-get clean && \
         eatmydata rm -rf /var/lib/apt/lists'
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
    docker build \
        -f "$dir_base/scripts/Dockerfile" \
        -t "$release_string" \
        --pull=true \
        --build-arg ARCH="$arch" \
        --build-arg DISTRO="$distro" \
        --build-arg RELEASE="$release" \
        --build-arg DEFAULT="$default_key" \
        --build-arg PUBLIC="$public" \
        --build-arg SECRET="$secret" \
        $dir_base/
fi