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

# Live path with curl stubbed: Bodhi is only asked when the cache is missing or over a week old
cache_home=$(mktemp -d)
trap 'rm -rf "$cache_home"' EXIT
live() { env -u BODHI_JSON XDG_CACHE_HOME="$1" ../fedora/releases.sh current 2>/dev/null; }
asked() { if [[ -e "$called" ]]; then rm "$called"; echo yes; else echo no; fi; }
export fixture="$BODHI_JSON" called="$cache_home/called"
# shellcheck disable=SC2317,SC2329  # called by releases.sh through export -f
curl() { : > "$called"; [[ -n "$fixture" ]] && cat "$fixture"; }
export -f curl
expect "live response"           "43 44"  "$(live "$cache_home" | xargs)"
expect "no cache asks Bodhi"     "yes"    "$(asked)"
fixture=''
expect "fresh cache"             "43 44"  "$(live "$cache_home" | xargs)"
expect "fresh cache skips Bodhi" "no"     "$(asked)"
touch -d '8 days ago' "$cache_home/liquorix-package/bodhi-releases.json"
expect "stale cache when down"   "43 44"  "$(live "$cache_home" | xargs)"
expect "stale cache asks Bodhi"  "yes"    "$(asked)"
expect "down, no cache"          "failed" "$(live "$cache_home/empty" || echo failed)"
unset -f curl

# shellcheck source=../lib.sh
source ../lib.sh
# shellcheck source=../fedora/env.sh
source ../fedora/env.sh
expect "fedora_releases detects" "43 44 45 46" "$(fedora_releases | xargs)"
expect "RELEASES_FEDORA overrides" "44" "$(RELEASES_FEDORA=44 fedora_releases | xargs)"
exit $fail
