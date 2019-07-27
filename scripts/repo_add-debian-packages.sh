#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

declare -i build=${1:-${version_build}}
declare repo_local_path="${liquorix_repo:-${HOME}/www/debian/}"
echo "[DEBUG] build: $build"
echo "[DEBUG] repo_local_path: $repo_local_path"

if [[ ! -d "$repo_local_path" ]]; then
    "[ERROR] Debian repository path $repo_local_path doesn't exist!  Not including changes."
    exit 1
fi

for arch in 'amd64'; do
    distro='debian'
    for release in "${releases_debian[@]}"; do
        cd "$dir_artifacts/$distro/$release"
        changes="${package_name}_${version_package}.${build}~${release}_${arch}.changes"

        echo "[INFO ] Including $changes to repo at $repo_local_path"
        reprepro -b "$repo_local_path" include "$release" "$changes"
    done
done

declare repo_server_name="${liquorix_server_name:-localhost}"
declare repo_server_path="${liquorix_server_repo:-/var/www/debian/}"
echo "[DEBUG] repo_server_name: $repo_server_name"
echo "[DEBUG] repo_server_path: $repo_server_path"

if [[ "$repo_server_name" == "localhost" ]]; then
    echo "[ERROR] Remote server not configured, not syncing"
    exit 1
fi

echo "[INFO ] Syncing $repo_local_path to $repo_server_name:$repo_server_path"
rsync --progress -ahvz --delete "$repo_local_path" -e ssh "$repo_server_name":"$repo_server_path"
