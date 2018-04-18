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
if docker image ls | grep "$release_string" -q; then
    echo "[INFO ] Docker image '$release_string' already built, performing update."
    echo "[INFO ] STUB -- update not implemented yet."
else
    echo "[INFO ] Docker image '$release_string' not found, building with Dockerfile."
    docker build -t "$release_string" \
        --build-arg=DISTRO=$distro \
        --build-arg=RELEASE=$release \
        ./
fi