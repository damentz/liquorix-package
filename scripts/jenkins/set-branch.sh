#!/bin/bash
# Point the Jenkins jobs at a branch of this repository, e.g. for a new kernel series:
#   scripts/jenkins/set-branch.sh 7.3/master
# Jobs default to all four.  Needs JENKINS_URL, JENKINS_USERNAME and JENKINS_API_KEY.

set -euo pipefail

branch=${1:?usage: set-branch.sh <branch> [job...]}
shift
[[ $# -gt 0 ]] || set -- BuildDebianUbuntu BuildFedora BuildArchlinux PruneRepositories

for job in "$@"; do
    url="${JENKINS_URL%/}/job/$job/config.xml"
    config=$(curl -fsS -u "$JENKINS_USERNAME:$JENKINS_API_KEY" "$url")
    sed -E "/<hudson.plugins.git.BranchSpec>/,/<\/hudson.plugins.git.BranchSpec>/ s|<name>[^<]*</name>|<name>*/$branch</name>|" <<< "$config" |
        curl -fsS -u "$JENKINS_USERNAME:$JENKINS_API_KEY" -H 'Content-Type: application/xml' --data-binary @- "$url"
    echo "$job -> $branch"
done
