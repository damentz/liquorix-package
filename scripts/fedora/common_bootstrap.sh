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
declare patch_file="$dir_package/debian/patches/zen/v${version_upstream}-lqx1.patch"
if [[ ! -f "$patch_file" ]]; then
    log_error "Liquorix patch not found: $patch_file"
    exit 1
fi

log_info "Source verification passed:"
log_info "  Tarball: $dir_base/$package_source"
log_info "  Patch:   $patch_file"
