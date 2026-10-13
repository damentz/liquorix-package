#!/bin/bash
# Checks scripts/archlinux/merge-branches.sh against a small local repository, then applies its patch the way the
# PKGBUILD does.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
fail=0
expect() { if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: want '$2', got '$3'" >&2; fail=1; fi; }

script=$PWD/scripts/archlinux/merge-branches.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

g() { git -C "$tmp/repo" -c user.name=test -c user.email=test@localhost "$@"; }
commit() { echo "$2" > "$tmp/repo/$1"; g add "$1"; g commit -qm "$1: $2"; }

# The release tag is 1.2/main plus a Cut commit.  1.2/main has a newer commit, and two branches change the same line.
git init -q "$tmp/repo"
g checkout -qb 1.2/main
commit a base
g branch 1.2/clean
g branch 1.2/clash
g branch 1.3/other
commit m 1
g checkout -qb 1.2/main-liquorix
commit Makefile cut
g tag -am 'Cut v1.2.3-lqx1' v1.2.3-lqx1
g checkout -q 1.2/main
commit m 2
g checkout -q 1.2/clean
commit a clean
g checkout -q 1.2/clash
commit a clash

touch "$tmp/linux-1.2.tar.xz"
cat > "$tmp/PKGBUILD" <<EOF
_major=1.2
pkgbase=linux-lqx
pkgver=1.2.3.lqx1
pkgrel=1
source=("file://$tmp/linux-1.2.tar.xz")
_package() {
  install=linux-lqx.install
}
_package-headers() {
  depends=('linux-lqx' 'pahole')
}
EOF

# Usage: build <branches> [build number].  Prints the exit status, the output goes to $tmp/log
build() {
    rm -rf "$tmp/build" && mkdir "$tmp/build" && cp "$tmp/PKGBUILD" "$tmp/build/"
    (cd "$tmp/build" && ZEN_KERNEL_REPO="file://$tmp/repo" FEATURE_BRANCHES="$1" BUILD_NUMBER="${2:-}" "$script") \
        > "$tmp/log" 2>&1 && echo 0 || echo "$?"
}

# The release tree after prepare() applied every patch beside the PKGBUILD
prepared() {
    rm -rf "$tmp/src" && mkdir "$tmp/src" && g archive v1.2.3-lqx1 | tar -x -C "$tmp/src"
    for patch in "$tmp"/build/*.patch; do
        patch -sNp1 -d "$tmp/src" -i "$patch"
    done
    cat "$tmp/src/$1"
}

expect "a branch merges" "0" "$(build 1.2/clean 7)"
expect "the branch change is in the patch" "clean" "$(prepared a)"
expect "the newer main commit is in the patch" "2" "$(prepared m)"
expect "the Cut commit stays" "cut" "$(prepared Makefile)"
expect "the package is renamed" "linux-lqx-test" "$(grep -Po '^pkgbase=\K.*' "$tmp/build/PKGBUILD")"
expect "the headers depend on the renamed kernel" "  depends=('linux-lqx-test' 'pahole')" "$(grep 'depends=' "$tmp/build/PKGBUILD")"
expect "the install script keeps its name" "  install=linux-lqx.install" "$(grep 'install=' "$tmp/build/PKGBUILD")"
expect "pkgrel is the build number" "7" "$(grep -Po '^pkgrel=\K.*' "$tmp/build/PKGBUILD")"

# What a pacman hook that _package() puts in the package triggers on, and when it runs
packaged() {
    rm -rf "$tmp/pkg"
    # shellcheck disable=SC1091,SC2034  # the PKGBUILD reads them
    (cd "$tmp/build" && pkgdir="$tmp/pkg" startdir="$tmp/build" && source ./PKGBUILD && _package)
    grep -Po '^(Operation|Target|When) = \K.*' "$tmp/pkg/usr/share/libalpm/hooks/$1" | paste -sd' '
}
expect "the GRUB menu gets the kernel after its initramfs is built" \
    "Install Upgrade linux-lqx-test PostTransaction" "$(packaged 95-linux-lqx-test-grub-install.hook)"
expect "the GRUB menu loses the kernel after it left /boot" \
    "Remove linux-lqx-test PreTransaction" "$(packaged 95-linux-lqx-test-grub-remove.hook)"
expect "both hooks write grub.cfg" "2" \
    "$(grep -l 'grub-mkconfig -o /boot/grub/grub.cfg' "$tmp"/pkg/usr/share/libalpm/hooks/*.hook | wc -l)"

expect "main alone merges" "0" "$(build 1.2/main)"
expect "pkgrel stays without a build number" "1" "$(grep -Po '^pkgrel=\K.*' "$tmp/build/PKGBUILD")"

expect "a conflict stops the build" "1" "$(build '1.2/clean 1.2/clash')"
expect "the conflict names the branch and the file" "Conflict merging 1.2/clash: a" "$(grep -A1 'Conflict merging' "$tmp/log" | sed 's/^\[ERROR\] //' | paste -sd' ')"
expect "a conflict leaves no patch" "" "$(find "$tmp/build" -name '*.patch')"

expect "a branch of another series is refused" "1" "$(build 1.3/other)"
expect "a bad branch name is refused" "1" "$(build '1.2/a..b')"

exit "$fail"
