#!/bin/bash

set -euo pipefail

# shellcheck source=lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/lib.sh"

declare ev=${1:-lqx1}
if [[ ! -f "Makefile" ]]; then
    log_error "Makefile for Linux not in current directory!"
    exit 1
fi

declare -i kv=$(grep -E '^VERSION = ' Makefile | sed -r 's/^VERSION = //')
declare -i kpl=$(grep -E '^PATCHLEVEL = ' Makefile | sed -r 's/^PATCHLEVEL = //')
declare -i ksl=$(grep -E '^SUBLEVEL = ' Makefile | sed -r 's/^SUBLEVEL = //')

tag="v$kv.$kpl.$ksl-$ev"
tag_commit="$(git rev-list -n1 "$tag")"
tag_patch_file="${tag}.patch.xz"
tag_patch_dir="../"

cleanup() {
    rm -f "$tag_patch_dir/$tag_patch_file" "$tag_patch_dir/$tag_patch_file.sig"
}
trap cleanup EXIT

git diff "v$kv.$kpl" "$tag" | xz -9 > "$tag_patch_dir/$tag_patch_file"
gpg --output "$tag_patch_dir/$tag_patch_file.sig" \
    --detach-sign "$tag_patch_dir/$tag_patch_file"

log_info "Creating release and uploading assets for $tag"
gh release create "$tag" \
    "$tag_patch_dir/$tag_patch_file" \
    "$tag_patch_dir/$tag_patch_file.sig" \
    --repo zen-kernel/zen-kernel \
    --target "$tag_commit" \
    --title "$tag" \
    --notes "" \
    --latest=false
