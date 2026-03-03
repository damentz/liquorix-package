#!/bin/bash

set -euo pipefail

# shellcheck source=lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/lib.sh"

# shellcheck source=debian/env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/debian/env.sh"

# shellcheck source=archlinux/env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/archlinux/env.sh"

# shellcheck source=fedora/env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/fedora/env.sh"

remove_image() {
    if docker image inspect "$1" &>/dev/null; then
        docker rmi -f "$1"
    fi
}

log_info "Removing Liquorix build images"
docker image ls --format '{{.Repository}}:{{.Tag}}\t{{.ID}}' | \
    awk '/^liquorix_/ {print $2}' | \
    xargs -r docker rmi -f

log_info "Removing base images used by Liquorix builds"
for release in "${releases_debian[@]}"; do
    remove_image "debian:$release"
    remove_image "amd64/debian:$release"
done
for release in "${releases_ubuntu[@]}"; do
    remove_image "ubuntu:$release"
    remove_image "amd64/ubuntu:$release"
done
remove_image "archlinux:base-devel"
remove_image "amd64/archlinux:base-devel"
for release in "${releases_fedora[@]}"; do
    remove_image "fedora:$release"
    remove_image "amd64/fedora:$release"
done

log_info "Done"
