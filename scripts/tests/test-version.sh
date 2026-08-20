#!/bin/bash
# Tests for scripts/version. Run: scripts/tests/test-version.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
version=../version
good=fixtures/good
mismatch=fixtures/mismatch
fail=0

expect() {
    local name="$1" want="$2" got="$3"
    if [[ "$want" == "$got" ]]; then
        echo "ok   $name"
    else
        echo "FAIL $name: want '$want', got '$got'" >&2
        fail=1
    fi
}

expect "get upstream"   "7.1.8"                "$($version -C $good get upstream)"
expect "get kernel"     "7.1"                  "$($version -C $good get kernel)"
expect "get major"      "7"                    "$($version -C $good get major)"
expect "get lqx"        "4"                    "$($version -C $good get lqx)"
expect "get pkgrev"     "13"                   "$($version -C $good get pkgrev)"
expect "get abiname"    "8-4"                  "$($version -C $good get abiname)"
expect "get patch_name" "zen/v7.1.8-lqx4.patch" "$($version -C $good get patch_name)"
expect "get tag"        "v7.1.8-lqx4"          "$($version -C $good get tag)"
expect "get unknown key fails" "1" "$($version -C $good get nope >/dev/null 2>&1; echo $?)"

expect "release debian"  "7.1-13.1~trixie"      "$($version -C $good release debian trixie 1)"
expect "release ubuntu"  "7.1-13ubuntu2~noble"  "$($version -C $good release ubuntu noble 2)"
expect "release default build" "7.1-13.1~trixie" "$($version -C $good release debian trixie)"

expect "changes debian" "linux-liquorix_7.1-13.1~trixie_amd64.changes" "$($version -C $good changes debian trixie 1 amd64)"
expect "changes ubuntu" "linux-liquorix_7.1-13ubuntu1~noble_amd64.changes" "$($version -C $good changes ubuntu noble 1 amd64)"

env_out="$($version -C $good env)"
# shellcheck disable=SC2154  # assigned by eval
expect "env is eval-able" "7.1.8 7.1 4 13 8-4" "$(eval "$env_out"; echo "$version_upstream $version_kernel $version_lqx $version_pkgrev $version_abiname")"

expect "check good passes"      "0" "$($version -C $good check >/dev/null 2>&1; echo $?)"
expect "check mismatch fails"   "1" "$($version -C $mismatch check >/dev/null 2>&1; echo $?)"
mismatch_out="$($version -C $mismatch check 2>&1 || true)"
expect "check mismatch names series" "yes" "$([[ "$mismatch_out" == *series* ]] && echo yes || echo no)"

expect "default -C is real tree" "0" "$($version get kernel >/dev/null 2>&1; echo $?)"

exit $fail
