#!/bin/bash
# Checks scripts/debian/env.sh agrees with scripts/version on the real tree.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
fail=0
expect() { if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: want '$2', got '$3'" >&2; fail=1; fi; }

# shellcheck source=../lib.sh
source ../lib.sh
# shellcheck source=../debian/env.sh
source ../debian/env.sh

# shellcheck disable=SC2154  # assigned in env.sh via eval
expect "version_package" "$(../version get kernel)-$(../version get pkgrev)" "$version_package"
expect "version_kernel"  "$(../version get kernel)" "$version_kernel"
# shellcheck disable=SC2154
expect "version_major"   "$(../version get major)"  "$version_major"
expect "get_release_version debian" "$(../version release debian trixie 3)" "$(get_release_version debian trixie 3)"
expect "get_release_version ubuntu" "$(../version release ubuntu noble 1)"  "$(get_release_version ubuntu noble)"
exit $fail
