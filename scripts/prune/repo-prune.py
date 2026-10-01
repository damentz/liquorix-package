#!/usr/bin/env python3
"""Remove old kernel builds from the package repositories.

Keeps the newest KEEP complete builds of every kernel series (7.2, 7.1, ...) in every
release and removes everything older.  A build is complete when both its kernel and its
headers package are present.  Nothing newer than the oldest kept build is touched.

    repo-prune.py [--keep 3] [--dry-run] reprepro:/var/www/debian arch:/var/www/archlinux/liquorix/x86_64
"""

import argparse
import os
import re
import subprocess
import sys
from collections import defaultdict


def natural(version):
    """Sort key that orders 7.2-9.1 before 7.2-10.1."""
    return [int(part) if part.isdigit() else part for part in re.split(r"(\d+)", version)]


def stale(builds, keep):
    """Versions to remove, given {version: package kinds} for one series of one release."""
    complete = sorted((v for v, kinds in builds.items() if {"kernel", "headers"} <= kinds), key=natural)
    if len(complete) <= keep:
        return []
    cutoff = natural(complete[-keep])
    return sorted((v for v in builds if natural(v) < cutoff), key=natural)


def report(where, series, builds, remove, dry_run):
    kept = sorted(set(builds) - set(remove), key=natural)
    print(f"{where} {series}: keeping {' '.join(kept)}; {'would remove' if dry_run else 'removing'} {' '.join(remove)}")


def prune_reprepro(repo, keep, dry_run):
    """Debian and Ubuntu: one build is the versioned image and headers packages of a release."""
    with open(os.path.join(repo, "conf", "distributions")) as conf:
        codenames = re.findall(r"^Codename:\s*(\S+)", conf.read(), re.M)
    freed = 0
    for codename in codenames:
        listing = subprocess.run(["reprepro", "-b", repo, "list", codename],
                                 check=True, capture_output=True, text=True).stdout
        series = defaultdict(lambda: defaultdict(set))
        packages = defaultdict(list)
        for line in listing.splitlines():
            match = re.match(r"[^:]+: (linux-(image|headers)-\d\S*) (\S+)$", line)
            if not match:
                continue
            name, kind, version = match.groups()
            series[version.split("-")[0]][version].add("kernel" if kind == "image" else kind)
            packages[version].append(name)
        for name, builds in sorted(series.items(), key=lambda item: natural(item[0])):
            remove = stale(builds, keep)
            if not remove:
                continue
            report(f"{repo} {codename}", name, builds, remove, dry_run)
            names = [package for version in remove for package in packages[version]]
            for version in remove:
                for package in packages[version]:
                    deb = os.path.join(repo, "pool", "main", "l", "linux-liquorix", f"{package}_{version}_amd64.deb")
                    freed += os.path.getsize(deb) if os.path.exists(deb) else 0
            if not dry_run:
                # reprepro deletes the pool files once nothing references them
                subprocess.run(["reprepro", "-b", repo, "remove", codename, *names], check=True)
    return freed


ARCH_PACKAGE = re.compile(r"^linux-lqx(-headers|-docs)?-(\d[^-]*-\d+)-x86_64\.pkg\.tar\.zst(\.sig)?$")


def prune_arch(repo, keep, dry_run):
    """Arch: one build is the linux-lqx, headers and docs packages of one pkgver-pkgrel."""
    # The database only lists the current build; never delete what it points at
    database = subprocess.run(["tar", "-tf", os.path.join(repo, "liquorix.db")],
                              check=True, capture_output=True, text=True).stdout
    current = set(re.findall(r"^linux-lqx(?:-headers|-docs)?-(\d[^/]*)/$", database, re.M))
    series = defaultdict(lambda: defaultdict(set))
    files = defaultdict(list)
    for filename in os.listdir(repo):
        match = ARCH_PACKAGE.match(filename)
        if not match:
            continue
        kind, version, _ = match.groups()
        series[".".join(version.split(".")[:2])][version].add(kind.lstrip("-") if kind else "kernel")
        files[version].append(os.path.join(repo, filename))
    freed = 0
    for name, builds in sorted(series.items(), key=lambda item: natural(item[0])):
        remove = [version for version in stale(builds, keep) if version not in current]
        if not remove:
            continue
        report(repo, name, builds, remove, dry_run)
        for version in remove:
            for path in files[version]:
                freed += os.path.getsize(path)
                if not dry_run:
                    os.remove(path)
    return freed


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--keep", type=int, default=3, help="builds to keep per series (default 3)")
    parser.add_argument("--dry-run", action="store_true", help="only list what would be removed")
    parser.add_argument("repos", nargs="+", metavar="KIND:PATH", help="reprepro:<path> or arch:<path>")
    args = parser.parse_args()
    if args.keep < 1:
        parser.error("--keep must be at least 1")
    prune = {"reprepro": prune_reprepro, "arch": prune_arch}
    freed = 0
    for repo in args.repos:
        kind, _, path = repo.partition(":")
        if kind not in prune or not os.path.isdir(path):
            parser.error(f"not a repository: {repo}")
        freed += prune[kind](path, args.keep, args.dry_run)
    print(f"{'Would free' if args.dry_run else 'Freed'} {freed / 1e9:.1f} GB")


if __name__ == "__main__":
    sys.exit(main())
