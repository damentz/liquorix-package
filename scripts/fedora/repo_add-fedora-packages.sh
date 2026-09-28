#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

declare repo_local_path="${liquorix_repo:-${HOME}/www/fedora}"
declare gpg_key="${liquorix_gpg_key:?set liquorix_gpg_key to the signing key id}"
log_debug "repo_local_path: $repo_local_path"

if [[ ! -d "$repo_local_path" ]]; then
    log_error "Fedora repository path $repo_local_path doesn't exist!  Not publishing."
    exit 1
fi

declare -a gpg_args=(--batch --yes --local-user "$gpg_key")

# createrepo_c runs in a container so the web server needs only docker, the
# layer cache makes rebuilding this image a no-op after the first run
require_docker
declare createrepo_image='liquorix/createrepo'
docker build -q -t "$createrepo_image" - <<< $'FROM fedora:latest\nRUN dnf -y install createrepo_c && dnf clean all'

# Publish every release built in this run, releases that failed keep their previous tree
declare -i published=0
for dir in "$dir_artifacts"/fedora/*/; do
    release="$(basename "$dir")"
    compgen -G "$dir*.rpm" > /dev/null || continue

    target="$repo_local_path/$release/x86_64"
    log_info "Publishing Fedora $release to $target"
    rm -rf "$target.new" "$target.old"
    mkdir -p "$target.new"
    cp -v "$dir"*.rpm "$target.new/"
    docker run --rm --user "$(id -u):$(id -g)" -v "$target.new":/repo "$createrepo_image" createrepo_c /repo
    gpg "${gpg_args[@]}" --detach-sign --armor "$target.new/repodata/repomd.xml"

    # Latest only, like the Debian repo
    # ponytail: two renames leave a sub-millisecond gap, a symlink swap closes it if clients ever notice
    [[ -d "$target" ]] && mv "$target" "$target.old"
    mv "$target.new" "$target"
    rm -rf "$target.old"
    published+=1
done

if [[ $published -eq 0 ]]; then
    log_error "No Fedora RPMs found under $dir_artifacts/fedora"
    exit 1
fi

log_info "Updating repo file and public key in $repo_local_path"
cp -v "$dir_scripts/liquorix.repo" "$repo_local_path/liquorix.repo"
gpg --batch --yes --armor --output "$repo_local_path/RPM-GPG-KEY-liquorix" --export "$gpg_key"
