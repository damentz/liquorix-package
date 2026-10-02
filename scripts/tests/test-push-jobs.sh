#!/bin/bash
# Checks scripts/jenkins/push-jobs.py fills in a hash that a build can reproduce from the sources.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
fail=0
expect() { if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: want '$2', got '$3'" >&2; fail=1; fi; }

for job in BuildDebianUbuntu BuildFedora BuildArchlinux PruneRepositories; do
    script=$(scripts/jenkins/push-jobs.py --print "$job")
    jenkinsfile=$(grep -oP "String SOURCE = '\K[^']+" <<< "$script")
    # The same command as checkCurrent in lqx.groovy
    expect "$job hash matches its sources" \
        "$(cat scripts/jenkins/lqx.groovy "$jenkinsfile" | sha256sum | cut -d' ' -f1)" \
        "$(grep -oP "String SOURCE_HASH = '\K[^']+" <<< "$script")"
done

exit "$fail"
