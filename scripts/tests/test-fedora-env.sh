#!/bin/bash
# Checks scripts/fedora/env.sh and the Fedora build inputs agree with scripts/version.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
fail=0
expect() { if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: want '$2', got '$3'" >&2; fail=1; fi; }

# shellcheck source=../lib.sh
source ../lib.sh
# shellcheck source=../fedora/env.sh
source ../fedora/env.sh

# shellcheck disable=SC2154  # assigned in env.sh via eval
expect "version_upstream"   "$(../version get upstream)"   "$version_upstream"
# shellcheck disable=SC2154
expect "version_lqx"        "$(../version get lqx)"        "$version_lqx"
# shellcheck disable=SC2154
expect "version_patch_name" "$(../version get patch_name)" "$version_patch_name"
expect "version_build is Build Number default" "1" "$version_build"
expect "patch file exists" "yes" "$([[ -f "$dir_package/debian/patches/$version_patch_name" ]] && echo yes || echo no)"
expect "no hardcoded lqx1 in fedora scripts/spec" "" "$(grep -ln 'lqx1' ../fedora/*.sh ../fedora/*.spec || true)"
exit $fail
