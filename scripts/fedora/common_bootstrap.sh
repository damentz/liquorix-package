#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"
# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

# shellcheck disable=SC2154  # assigned in env.sh via eval
if [[ ! -f "$dir_base/$package_source" ]]; then
    log_warn "Missing source file: $dir_base/$package_source, downloading now."
    curl -fL --retry 3 -o "$dir_base/$package_source" "https://cdn.kernel.org/pub/linux/kernel/v${version_major}.x/linux-${version_kernel}.tar.xz"
fi

# Verify liquorix patch exists
# shellcheck disable=SC2154  # assigned in env.sh via eval
declare patch_file="$dir_package/debian/patches/$version_patch_name"
if [[ ! -f "$patch_file" ]]; then
    log_error "Liquorix patch not found: $patch_file"
    exit 1
fi

log_info "Source verification passed:"
log_info "  Tarball: $dir_base/$package_source"
log_info "  Patch:   $patch_file"
