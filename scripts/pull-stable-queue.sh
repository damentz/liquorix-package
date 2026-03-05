#!/bin/bash

set -euo pipefail

# shellcheck source=lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/lib.sh"

function usage() { echo "Usage: $0 [directory] <remote>"; }

if [[ -z "$1" ]] || [[ ! -d "$1" ]]; then
    log_error "'$1' is an invalid directory."
    usage
    exit 1
fi

remote='linux-stable'
if [[ -z "$2" ]]; then
    log_warn "'$2' is an invalid remote, defaulting to '$remote'"
else
    log_info "Setting remote to '$2'"
    remote="$2"
fi

if [[ ! -d ".git" ]]; then
    log_error "Not in a git repository!"
    exit 1
fi

branch="$(git branch | grep -E '^\* [0-9]+\.[0-9]+/upstream-updates-next')"
version="$(echo "$branch" | grep -Eo '[0-9]+\.[0-9]+')"
queue="$1/queue-$version"

if [[ "$branch" =~ upstream-updates-next ]]; then
    log_info "branch is valid"
else
    log_error "branch, $branch, is invalid"
    exit 1
fi

if [[ "$version" =~ [0-9]+\.[0-9]+ ]]; then
    log_info "version is valid"
else
    log_error "version, $version, is invalid"
    exit 1
fi

log_info "fetching latest changes"
git fetch "$remote"

log_info "resetting repository"
git reset --hard "$remote/linux-$version.y"

log_info "cleaning repository"
git clean -xdf

log_info "checking if, $queue, exists"
if ! stat "$queue" &> /dev/null; then
    log_error "folder, $queue, does not exist"
    exit 1
fi

log_info "merging from stable queue"
while IFS= read -r file; do
    git am -3 "$queue/$file"
done < "$queue/series"

exit 0
