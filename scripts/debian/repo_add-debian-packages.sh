#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

declare -i build=${1:-${version_build}}
declare distro=${2:-debian}
declare -n releases="releases_$distro"
declare repo_local_path="${liquorix_repo:-${HOME}/www/$distro/}"
log_debug "build: $build"
log_debug "distro: $distro"
log_debug "repo_local_path: $repo_local_path"

if [[ ! -d "$repo_local_path" ]]; then
    log_error "Repository path $repo_local_path doesn't exist!  Not including changes."
    exit 1
fi

# Publish every release built in this run, releases that weren't built are skipped
declare -i published=0
# shellcheck disable=SC2043
for arch in amd64; do
    for release in "${releases[@]}"; do
        changes="$dir_artifacts/$distro/$release/$("$dir_base/scripts/version" -C "$dir_package" changes "$distro" "$release" "$build" "$arch")"
        if [[ ! -f "$changes" ]]; then
            log_warn "No $distro $release packages for build $build, skipping"
            continue
        fi

        log_info "Including $changes to repo at $repo_local_path"
        reprepro -b "$repo_local_path" include "$release" "$changes"
        published+=1
    done
done

if [[ $published -eq 0 ]]; then
    log_error "No $distro packages found under $dir_artifacts/$distro"
    exit 1
fi

declare repo_server_name="${liquorix_server_name:-localhost}"
declare repo_server_path="${liquorix_server_repo:-/var/www/$distro/}"
log_debug "repo_server_name: $repo_server_name"
log_debug "repo_server_path: $repo_server_path"

# On the server itself the repo is published in place, nothing to sync
if [[ "$repo_server_name" == "localhost" ]]; then
    log_info "Remote server not configured, not syncing"
    exit 0
fi

log_info "Syncing $repo_local_path to $repo_server_name:$repo_server_path"
rsync --progress -ahvz --delete "$repo_local_path" "$repo_server_name":"$repo_server_path"
