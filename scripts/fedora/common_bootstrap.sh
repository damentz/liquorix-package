#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"
# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

# Verify kernel source tarball exists
if [[ ! -f "$dir_base/$package_source" ]]; then
    log_error "Kernel source tarball not found: $dir_base/$package_source"
    log_error "Run the Debian bootstrap first to download the kernel source."
    exit 1
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
