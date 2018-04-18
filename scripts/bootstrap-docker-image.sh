#!/bin/bash

declare distro="$1"
declare release="$2"

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