#!/bin/bash
# Print supported Fedora releases, one per line, as listed by Bodhi.
#   releases.sh            current (stable) + pending (branched, rawhide)
#   releases.sh current    stable releases only
# BODHI_JSON=<file> reads a saved Bodhi response instead of querying.

set -euo pipefail

declare states=${1:-current pending}
declare url='https://bodhi.fedoraproject.org/releases/?state=current&state=pending&exclude_archived=true&rows_per_page=100'

{
    if [[ -n "${BODHI_JSON:-}" ]]; then
        cat "$BODHI_JSON"
    else
        curl -fsS --retry 3 "$url"
    fi
} | python3 -c '
import json, sys
states = sys.argv[1].split()
versions = sorted({int(r["version"]) for r in json.load(sys.stdin)["releases"]
                   if r["id_prefix"] == "FEDORA" and r["version"].isdigit() and r["state"] in states})
if not versions:
    sys.exit("No Fedora releases found in Bodhi response")
print(*versions, sep="\n")
' "$states"
