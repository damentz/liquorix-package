#!/bin/bash

set -euo pipefail

# shellcheck source=debian/env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/debian/env.sh"

# shellcheck source=archlinux/env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/archlinux/env.sh"

echo "[INFO ] Removing Liquorix build images"
docker image ls --format '{{.Repository}}:{{.Tag}}\t{{.ID}}' | \
    awk '/^liquorix_/ {print $2}' | \
    xargs -r docker rmi -f

echo "[INFO ] Removing base images used by Liquorix builds"
for release in "${releases_debian[@]}"; do
    docker rmi -f "debian:$release" 2>/dev/null || true
    docker rmi -f "amd64/debian:$release" 2>/dev/null || true
done
for release in "${releases_ubuntu[@]}"; do
    docker rmi -f "ubuntu:$release" 2>/dev/null || true
    docker rmi -f "amd64/ubuntu:$release" 2>/dev/null || true
done
docker rmi -f "archlinux:base-devel" 2>/dev/null || true
docker rmi -f "amd64/archlinux:base-devel" 2>/dev/null || true

echo "[INFO ] Done"
