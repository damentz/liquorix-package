#!/bin/bash

# Merge zen-kernel branches on top of the main branch of the series that the PKGBUILD in the current directory
# builds.  The difference from the release that the PKGBUILD builds is left as a patch beside it, which applies it in
# prepare(), and the package is renamed so that it installs beside the released one.  The package also gets pacman
# hooks that keep the GRUB menu current.
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
declare name="$package_name-test"

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

# Not on top of the release tag: its Cut commit sets EXTRAVERSION, and conflicts with each stable release on main
declare result tree
result=$(git rev-parse "$main")
log_info "Starting from $main at $(git rev-parse --short "$main")"
for branch in "${branches[@]}"; do
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

sed -i "s/^pkgbase=.*/pkgbase=$name/; s/'$package_name'/'$name'/" PKGBUILD
if [[ "${BUILD_NUMBER:-}" =~ ^[0-9]+$ ]]; then
    sed -i "s/^pkgrel=.*/pkgrel=$BUILD_NUMBER/" PKGBUILD
fi

# Nothing writes the GRUB menu when pacman installs a kernel, and a kernel with a new name is not in it.  An install
# script runs too early for that: mkinitcpio puts the kernel and the initramfs in /boot from a PostTransaction hook,
# and takes them out from a PreTransaction hook.  These hooks sort after both.
# Usage: grub_hook <install|remove> <operations> <when>
grub_hook() {
    cat > "95-$name-grub-$1.hook" <<EOF
[Trigger]
Type = Package
$2
Target = $name

[Action]
Description = Updating the GRUB menu...
When = $3
Exec = /bin/sh -c '[ ! -f /boot/grub/grub.cfg ] || grub-mkconfig -o /boot/grub/grub.cfg'
EOF
}
grub_hook install $'Operation = Install\nOperation = Upgrade' PostTransaction
grub_hook remove 'Operation = Remove' PreTransaction
# shellcheck disable=SC2016  # expanded by makepkg
sed -i '/^_package() {$/a\  install -Dm644 -t "$pkgdir/usr/share/libalpm/hooks" "$startdir"/*.hook' PKGBUILD
if ! grep -q 'libalpm/hooks' PKGBUILD; then
    log_error "No _package() in the PKGBUILD to install the GRUB hooks from"
    exit 1
fi

log_info "Prepared $name from $tag: $(git diff --shortstat "$tag" "$result")"
