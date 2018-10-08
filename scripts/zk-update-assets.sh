#!/bin/bash

set -euo pipefail

declare ev=${1:-lqx1}
if [[ ! -f "Makefile" ]]; then
    echo "[ERROR] Makefile for Linux not in current directory!"
    exit 1
fi

if [[ -z "${GH_ASSET_TOKEN:-}" ]]; then
    echo "[ERROR] No GitHub API token found under GH_ASSET_TOKEN!"
    exit 1
fi

declare -i kv=$(grep -E '^VERSION = ' Makefile | sed -r 's/^VERSION = //')
declare -i kpl=$(grep -E '^PATCHLEVEL = ' Makefile | sed -r 's/^PATCHLEVEL = //')
declare -i ksl=$(grep -E '^SUBLEVEL = ' Makefile | sed -r 's/^SUBLEVEL = //')

tag="v$kv.$kpl.$ksl-$ev"
tag_commit="$(git rev-list -n1 "$tag")"
tag_patch_file="${tag}.patch.xz"
tag_patch_dir="../"

# zen-kernel repo is under an organization, not user, so it must be specified
# by its unique ID
declare -i repository_id=2465166
release_data='{"tag_name": "'"$tag"'", "tag_commitish": "'"$tag_commit"'"}'

git diff "v$kv.$kpl" "$tag" | xz -9 > "$tag_patch_dir/$tag_patch_file"
gpg --output "$tag_patch_dir/$tag_patch_file.sig" \
    --detach-sign "$tag_patch_dir/$tag_patch_file"

echo "[INFO ] Making release and getting release ID"
release_id=$(
    curl -X POST -H "Authorization: token ${GH_ASSET_TOKEN:-}" \
        --data "$release_data" "https://api.github.com/repositories/$repository_id/releases" |\
        python -c "import sys, json; print(json.load(sys.stdin)['id']);"
)

echo ""
echo ""
echo "[DEBUG] release_id: $release_id"
echo "[INFO ] Uploading $tag_patch_file"
curl -X POST -H "Content-Type:application/x-xz" \
    -H "Authorization: token ${GH_ASSET_TOKEN:-}" \
    --data-binary @"${tag_patch_dir}/${tag_patch_file}" \
    "https://uploads.github.com/repositories/$repository_id/releases/$release_id/assets?name=$tag_patch_file"

echo ""
echo ""
echo "[INFO ] Uploading $tag_patch_file.sig"
curl -X POST -H "Content-Type:application/octet-stream" \
    -H "Authorization: token ${GH_ASSET_TOKEN:-}" \
    --data-binary @"${tag_patch_dir}/${tag_patch_file}.sig" \
    "https://uploads.github.com/repositories/$repository_id/releases/$release_id/assets?name=$tag_patch_file.sig"
