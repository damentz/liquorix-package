#!/bin/bash
# Print supported Fedora releases, one per line, as listed by Bodhi.
#   releases.sh            current (stable) + pending (branched, rawhide)
#   releases.sh current    stable releases only
# BODHI_JSON=<file> reads a saved Bodhi response instead of querying.
# The last good response is cached: reused for a week, and beyond that while Bodhi is down.

set -euo pipefail

declare states=${1:-current pending}
declare url='https://bodhi.fedoraproject.org/releases/?state=current&state=pending&exclude_archived=true&rows_per_page=100'
declare cache="${XDG_CACHE_HOME:-$HOME/.cache}/liquorix-package/bodhi-releases.json"

# Bodhi response on stdin
parse() {
    python3 -c '
import json, sys
states = sys.argv[1].split()
versions = sorted({int(r["version"]) for r in json.load(sys.stdin)["releases"]
                   if r["id_prefix"] == "FEDORA" and r["version"].isdigit() and r["state"] in states})
if not versions:
    sys.exit("No Fedora releases found in Bodhi response")
print(*versions, sep="\n")
' "$states"
}

declare json
if [[ -n "${BODHI_JSON:-}" ]]; then
    parse < "$BODHI_JSON"
elif [[ -n "$(find "$cache" -mtime -7 2>/dev/null)" ]] && parse < "$cache"; then
    : # Releases change a few times a year, a week-old response is as good as a live one
elif json=$(curl -fsS --retry 3 "$url") && parse <<< "$json"; then
    # Only a response that parsed is worth keeping
    mkdir -p "${cache%/*}"
    printf '%s\n' "$json" > "$cache.tmp"
    mv "$cache.tmp" "$cache"
elif [[ -s "$cache" ]]; then
    echo "Bodhi unavailable, using the response cached on $(date -r "$cache" '+%F %R')" >&2
    parse < "$cache"
else
    echo "Bodhi unavailable and no cached response at $cache" >&2
    exit 1
fi
