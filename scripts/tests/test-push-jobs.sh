#!/bin/bash
# Checks scripts/jenkins/push-jobs.py fills in a hash that a build can reproduce from the sources, and creates a job
# that Jenkins does not have.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
fail=0
expect() { if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: want '$2', got '$3'" >&2; fail=1; fi; }

for job in BuildDebianUbuntu BuildFedora BuildArchlinux BuildArchlinuxCustom PruneRepositories; do
    script=$(scripts/jenkins/push-jobs.py --print "$job")
    jenkinsfile=$(grep -oP "String SOURCE = '\K[^']+" <<< "$script")
    # The same command as checkCurrent in lqx.groovy
    expect "$job hash matches its sources" \
        "$(cat scripts/jenkins/lqx.groovy "$jenkinsfile" | sha256sum | cut -d' ' -f1)" \
        "$(grep -oP "String SOURCE_HASH = '\K[^']+" <<< "$script")"
done

# Against a Jenkins that has BuildArchlinux but not BuildFedora
python3 -B - <<'EOF' || fail=1
import importlib.util
import os
import sys
import urllib.error

spec = importlib.util.spec_from_file_location("push_jobs", "scripts/jenkins/push-jobs.py")
push_jobs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(push_jobs)
posts = {}


def jenkins(url, data=None):
    if data is not None:
        posts[url] = data.decode()
    elif "/job/BuildFedora/" in url:
        raise urllib.error.HTTPError(url, 404, "Not Found", None, None)
    return "<flow-definition><description>kept</description><definition old>old</definition></flow-definition>"


push_jobs.jenkins = jenkins
os.environ["JENKINS_URL"] = "http://jenkins/"
sys.argv = ["push-jobs.py", "BuildArchlinux", "BuildFedora"]
push_jobs.main()

updated = posts.get("http://jenkins/job/BuildArchlinux/config.xml", "")
created = posts.get("http://jenkins/createItem?name=BuildFedora", "")
checks = {
    "an existing job keeps the rest of its config": "<description>kept</description><definition class=" in updated,
    "an existing job gets its script": "String SOURCE = 'scripts/archlinux/Jenkinsfile'" in updated,
    "a missing job is created as a pipeline": created.startswith("<flow-definition>")
    and created.endswith("</flow-definition>\n"),
    "a missing job gets its script": "String SOURCE = 'scripts/fedora/Jenkinsfile'" in created,
    "nothing else is written": len(posts) == 2,
}
for name, passed in checks.items():
    print(f"ok   {name}" if passed else f"FAIL {name}", file=sys.stdout if passed else sys.stderr)
sys.exit(not all(checks.values()))
EOF

exit "$fail"
