#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

declare -i build=${1:-${version_build}}
declare repo_local_path="${liquorix_repo:-${HOME}/www/debian/}"
log_debug "build: $build"
log_debug "repo_local_path: $repo_local_path"

if [[ ! -d "$repo_local_path" ]]; then
    log_error "Debian repository path $repo_local_path doesn't exist!  Not including changes."
    exit 1
fi

# shellcheck disable=SC2043
for arch in amd64; do
    distro='debian'
    for release in "${releases_debian[@]}"; do
        cd "$dir_artifacts/$distro/$release" || exit
        changes="${package_name}_${version_package}.${build}~${release}_${arch}.changes"

        log_info "Including $changes to repo at $repo_local_path"
        reprepro -b "$repo_local_path" include "$release" "$changes"
    done
done

declare repo_server_name="${liquorix_server_name:-localhost}"
declare repo_server_path="${liquorix_server_repo:-/var/www/debian/}"
log_debug "repo_server_name: $repo_server_name"
log_debug "repo_server_path: $repo_server_path"

if [[ "$repo_server_name" == "localhost" ]]; then
    log_error "Remote server not configured, not syncing"
    exit 1
fi

log_info "Syncing $repo_local_path to $repo_server_name:$repo_server_path"
rsync --progress -ahvz --delete "$repo_local_path" -e ssh "$repo_server_name":"$repo_server_path"
