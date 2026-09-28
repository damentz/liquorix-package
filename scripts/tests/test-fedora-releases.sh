#!/bin/bash
# Checks scripts/fedora/releases.sh parses Bodhi and RELEASES_FEDORA overrides it.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
fail=0
expect() { if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: want '$2', got '$3'" >&2; fail=1; fi; }

export BODHI_JSON="$PWD/fixtures/bodhi-releases.json"
expect "all releases"     "43 44 45 46" "$(../fedora/releases.sh | xargs)"
expect "current releases" "43 44"       "$(../fedora/releases.sh current | xargs)"
expect "no match fails"   "failed"      "$(../fedora/releases.sh archived 2>/dev/null || echo failed)"

# shellcheck source=../lib.sh
source ../lib.sh
# shellcheck source=../fedora/env.sh
source ../fedora/env.sh
expect "fedora_releases detects" "43 44 45 46" "$(fedora_releases | xargs)"
expect "RELEASES_FEDORA overrides" "44" "$(RELEASES_FEDORA=44 fedora_releases | xargs)"
exit $fail
