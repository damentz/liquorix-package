#!/usr/bin/env python3
"""Write the Jenkinsfiles into their Jenkins jobs.

Each job holds its pipeline script inline.  The script is scripts/jenkins/lqx.groovy followed by
the job's Jenkinsfile, with a hash of both filled in so a build can tell when its job is out of
date.  The Jenkins Sync workflow runs this on every push to the default branch.

    push-jobs.py [job...]        write the jobs (default: all of them)
    push-jobs.py --print job     print the job's script instead

Needs JENKINS_URL, JENKINS_USERNAME and JENKINS_API_KEY.
"""

import base64
import hashlib
import os
import sys
import urllib.request
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[2]
JOBS = {
    "BuildDebianUbuntu": "scripts/debian/Jenkinsfile",
    "BuildFedora": "scripts/fedora/Jenkinsfile",
    "BuildArchlinux": "scripts/archlinux/Jenkinsfile",
    "PruneRepositories": "scripts/prune/Jenkinsfile",
}


def job_script(jenkinsfile):
    """The helpers, then the Jenkinsfile, with its path and the hash of both sources filled in."""
    helpers = (ROOT / "scripts/jenkins/lqx.groovy").read_bytes()
    pipeline = (ROOT / jenkinsfile).read_bytes()
    script = helpers.decode()
    filled = {
        "SOURCE": jenkinsfile,
        "SOURCE_HASH": hashlib.sha256(helpers + pipeline).hexdigest(),
    }
    for name, value in filled.items():
        placeholder = f"String {name} = ''"
        if script.count(placeholder) != 1:
            sys.exit(f"lqx.groovy must contain {placeholder!r} exactly once")
        script = script.replace(placeholder, f"String {name} = '{value}'")
    return script + "\n" + pipeline.decode()


def jenkins(url, data=None):
    """GET the URL, or POST the data to it, as the Jenkins user."""
    login = f"{os.environ['JENKINS_USERNAME']}:{os.environ['JENKINS_API_KEY']}"
    headers = {
        "Authorization": "Basic " + base64.b64encode(login.encode()).decode(),
        "Content-Type": "application/xml",
        "User-Agent": "liquorix-package",
    }
    request = urllib.request.Request(url, data=data, headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read().decode()


def main():
    if sys.argv[1:2] == ["--print"]:
        sys.stdout.write(job_script(JOBS[sys.argv[2]]))
        return
    for job in sys.argv[1:] or JOBS:
        url = f"{os.environ['JENKINS_URL'].rstrip('/')}/job/{job}/config.xml"
        definition = (
            '<definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">\n'
            f"    <script>{escape(job_script(JOBS[job]))}</script>\n"
            "    <sandbox>true</sandbox>\n"
            "  </definition>"
        )
        before, found, rest = jenkins(url).partition("<definition ")
        after = rest.partition("</definition>")[2]
        if not found or not after:
            sys.exit(f"{job}: no <definition> in config.xml")
        jenkins(url, (before + definition + after).encode())
        print(f"{job}: {JOBS[job]}")


if __name__ == "__main__":
    main()
