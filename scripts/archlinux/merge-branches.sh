#!/bin/bash

# Merge zen-kernel branches on top of the release that the PKGBUILD in the current directory builds.  The result is
# left as a patch beside the PKGBUILD, which applies it in prepare(), and the package is renamed so that it installs
# beside the released one.
#
#     FEATURE_BRANCHES='7.2/foo 7.2/bar' merge-branches.sh

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"
# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

declare repo=${ZEN_KERNEL_REPO:-https://github.com/zen-kernel/zen-kernel}
declare -a branches=()
read -ra branches <<< "${FEATURE_BRANCHES//,/ }"

declare major='' pkgver='' tarball=''
# shellcheck disable=SC1091,SC2154  # assigned by the PKGBUILD
read -r major pkgver tarball < <(set +eu; source ./PKGBUILD > /dev/null; echo "$_major $pkgver ${source[0]}") || true
if [[ -z "$tarball" ]]; then
    log_error "No PKGBUILD with _major, pkgver and source in $PWD"
    exit 1
fi

declare tag="v${pkgver/.lqx/-lqx}"
declare main="$major/main"

for branch in "${branches[@]}"; do
    if [[ "$branch" != "$major"/* ]] || ! git check-ref-format --branch "$branch" > /dev/null 2>&1; then
        log_error "'$branch' is not a $major branch"
        exit 1
    fi
done

# The merges need no history from before the base release.  The remote has no tag for it, so the clone is cut at
# a date instead: a week before the tarball of the base release was published.
declare modified since
modified=$(curl -fsI --retry 3 "$tarball" | grep -iPo '^last-modified: \K[^\r]+') || {
    log_error "No date for $tarball"
    exit 1
}
since=$(date -ud "@$(( $(date -d "$modified" +%s) - 7 * 86400 ))" +%F)

GIT_DIR=$(mktemp -d)
export GIT_DIR
trap 'rm -rf "$GIT_DIR"' EXIT
git init -q --bare

# One fetch for everything, a second fetch into a shallow clone is very slow
declare -a refs=("refs/tags/$tag:refs/tags/$tag")
for branch in "$main" "${branches[@]}"; do
    refs+=("refs/heads/$branch:refs/heads/$branch")
done
log_info "Fetching $tag, $main and ${branches[*]} from $repo, history since $since"
git fetch --no-tags --shallow-since="$since" "$repo" "${refs[@]}"

declare result tree
result=$(git rev-parse "$tag^{commit}")
for branch in "$main" "${branches[@]}"; do
    if ! tree=$(git merge-tree --write-tree --name-only --no-messages "$result" "$branch"); then
        log_error "Conflict merging $branch:"
        tail -n +2 <<< "$tree" >&2
        exit 1
    fi
    result=$(git -c user.name="$package_name" -c user.email="$package_name@localhost" \
        commit-tree -p "$result" -p "$branch" -m "Merge $branch" "$tree")
    log_info "Merged $branch at $(git rev-parse --short "$branch")"
done

git diff "$tag" "$result" > feature-branches.patch

sed -i "s/^pkgbase=.*/pkgbase=$package_name-test/; s/'$package_name'/'$package_name-test'/" PKGBUILD
if [[ "${BUILD_NUMBER:-}" =~ ^[0-9]+$ ]]; then
    sed -i "s/^pkgrel=.*/pkgrel=$BUILD_NUMBER/" PKGBUILD
fi
log_info "Prepared $package_name-test from $tag: $(git diff --shortstat "$tag" "$result")"
