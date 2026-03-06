#!/bin/bash
# Shared library for Liquorix build scripts

# Logging
log_info()  { echo "[INFO ] $*"; }
log_warn()  { echo "[WARN ] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
log_debug() { echo "[DEBUG] $*"; }

# Validate that a required variable is set, exit with error if not.
# Usage: require_var "architecture" "$arch"
require_var() {
    local name="$1" value="$2"
    if [[ -z "$value" ]]; then
        log_error "No $name set!"
        return 1
    fi
}

# Validate arch/distro/release and exit on failure.
# Usage: require_build_args "$arch" "$distro" "$release"
require_build_args() {
    local arch="${1:-}" distro="${2:-}" release="${3:-}"
    local -i fail=0

    require_var "architecture" "$arch" || fail=1
    require_var "distribution" "$distro" || fail=1
    require_var "release" "$release" || fail=1

    if [[ $fail -eq 1 ]]; then
        log_error "Encountered a fatal error, cannot continue!"
        exit 1
    fi
}

# Construct the Docker image name for a given arch/distro/release.
# Usage: image_name amd64 debian bookworm
image_name() {
    echo "liquorix_${1}/${2}/${3}"
}

# Verify Docker is installed.
require_docker() {
    if ! command -v docker > /dev/null; then
        log_error "Docker is not installed, cannot continue!"
        exit 1
    fi
}

# Check if GPG signing is available. Returns 0 if ready, 1 if not.
# Does NOT exit — callers decide how to handle the result.
gpg_available() {
    command -v gpgconf > /dev/null || return 1
    gpgconf --launch gpg-agent 2>/dev/null || return 1

    local default_key
    default_key="$(
        cat ~/.gnupg/gpg.conf ~/.gnupg/options 2>/dev/null | \
        grep -E '^\s*default-key' | grep -Po '\S+\s*$' || true
    )"
    [[ -n "$default_key" ]] || return 1

    gpg-connect-agent /bye 2>/dev/null || return 1

    return 0
}

# Require GPG signing to be available, exit with error if not.
require_gpg() {
    if ! gpg_available; then
        log_error "GPG signing is not available. See README.md for setup instructions."
        exit 1
    fi
    log_info "GPG signing ready"
}

# Return all docker flags needed for GPG signing, or empty if GPG is unavailable.
# Usage: docker run $(gpg_docker_flags /home/builder) ...
gpg_docker_flags() {
    gpg_available || return 0

    local container_home="${1:-/root}"
    local flags="-v $HOME/.gnupg:${container_home}/.gnupg"

    local agent_socket
    agent_socket="$(gpgconf --list-dirs agent-socket 2>/dev/null || true)"
    if [[ -n "$agent_socket" ]]; then
        flags+=" -v $agent_socket:${container_home}/.gnupg/S.gpg-agent"
    fi

    echo "$flags"
}
