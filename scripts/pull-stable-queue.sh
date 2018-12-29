#!/bin/bash

set -e

function usage() { echo "Usage: $0 [directory] <remote>"; }

if [[ -z "$1" ]] || [[ ! -d "$1" ]]; then
    echo "[ERROR] '$1' is an invalid directory."
    usage
    exit 1
fi

remote='linux-stable'
if [[ -z "$2" ]]; then
    echo "[WARN ] '$2' is an invalid remote, defaulting to '$remote'"
else
    echo "[INFO ] Setting remote to '$2'"
    remote="$2"
fi

if [[ ! -d ".git" ]]; then
    echo "[ERROR] Not in a git repository!"
    exit 1
fi

branch="$(git branch | grep -E '^\* [0-9]+\.[0-9]+/upstream-updates-next')"
version="$(echo "$branch" | grep -Eo '[0-9]+\.[0-9]+')"
queue="$1/queue-$version"

if [[ "$branch" =~ upstream-updates-next ]]; then
    echo "[INFO ] branch is valid"
else
    echo "[ERROR] branch, $branch, is invalid"
    exit 1
fi

if [[ "$version" =~ [0-9]+\.[0-9]+ ]]; then
    echo "[INFO ] version is valid"
else
    "[ERROR] version, $version, is invalid"
    exit 1
fi

echo "[INFO ] fetching latest changes"
git fetch "$remote"

echo "[INFO ] resetting repository"
git reset --hard "$remote/linux-$version.y"

echo "[INFO ] cleaning repository"
git clean -xdf

echo "[INFO ] checking if, $queue, exists"
stat "$queue" &> /dev/null
if [[ "$?" -ne 0 ]]; then
    echo "[ERROR] folder, $queue, does not exist"
    exit 1
fi

echo "[INFO ] merging from stable queue"
for file in $(cat "$queue/series"); do
    git am -3 "$queue/$file"
done

exit 0
