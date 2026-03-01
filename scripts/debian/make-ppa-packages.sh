#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

version_build="1"
dir_build="$dir_base/ppa"

if [[ -n "$1" ]]; then
    log_info "Build version overridden to: $1"
    version_build="$1"
fi

log_debug "package_name:   $package_name"
log_debug "package_source: $package_source"
log_debug "dir_script:  $dir_script"
log_debug "dir_base:    $dir_base"
log_debug "dir_package: $dir_package"
log_debug "dir_build:     $dir_build"
log_debug "releases_ubuntu: ${releases_ubuntu[*]}"

prepare_env

for release_name in "${releases_ubuntu[@]}"; do
    declare release_version="$(get_release_version ubuntu $release_name $version_build)"

    log_info "Building source package for $release"
    build_source_package "$release_name" "$release_version"

    log_info "Uploading packages to Launchpad PPA"
    dput 'liquorix' "${dir_build}/${package_name}_${release_version}_source.changes" ||
        { log_error "dput failed to push package!"; exit 1; }
done
