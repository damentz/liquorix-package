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

# Validate GPG signing setup: agent running, default key configured, and
# socket available. Call this early (before docker builds) to give clear
# errors instead of cryptic failures inside containers.
require_gpg() {
    local -i fail=0

    # gpgconf is required to locate sockets
    if ! command -v gpgconf > /dev/null; then
        log_error "gpgconf not found. Install gnupg (>= 2.1) to enable package signing."
        exit 1
    fi

    # Ensure the agent is running (gpgconf --launch is idempotent)
    if ! gpgconf --launch gpg-agent 2>/dev/null; then
        log_error "Failed to start gpg-agent."
        log_error "Ensure gnupg and gpg-agent are installed and that \$GNUPGHOME (or ~/.gnupg) is accessible."
        exit 1
    fi

    # Verify a default signing key is configured
    local default_key
    default_key="$(
        cat ~/.gnupg/gpg.conf ~/.gnupg/options 2>/dev/null | \
        grep -E '^\s*default-key' | grep -Po '\S+\s*$' || true
    )"
    if [[ -z "$default_key" ]]; then
        log_error "No default-key found in ~/.gnupg/gpg.conf."
        log_error "Add 'default-key <KEY_ID>' to ~/.gnupg/gpg.conf."
        fail=1
    fi

    # Verify the agent socket exists
    local agent_socket
    agent_socket="$(gpgconf --list-dirs agent-socket 2>/dev/null || true)"
    if [[ -z "$agent_socket" || ! -S "$agent_socket" ]]; then
        log_error "GPG agent socket not found at: ${agent_socket:-<unknown>}"
        log_error "Try: gpgconf --kill gpg-agent && gpgconf --launch gpg-agent"
        fail=1
    fi

    if [[ $fail -eq 1 ]]; then
        exit 1
    fi

    log_info "GPG signing ready (key: ${default_key}, agent: $agent_socket)"
}

# Return docker flags to forward the host GPG agent socket into a container.
# Mounts the host agent socket at the standard path inside the container
# so gpg finds it automatically without starting its own agent.
# Usage: docker run $(gpg_agent_mount_flags /root) ...
gpg_agent_mount_flags() {
    local container_home="${1:-/root}"
    local agent_socket
    agent_socket="$(gpgconf --list-dirs agent-socket 2>/dev/null || true)"
    if [[ -z "$agent_socket" ]]; then
        log_warn "Could not determine GPG agent socket path, signing may fail"
        return 0
    fi
    local container_socket="$container_home/.gnupg/S.gpg-agent"
    echo "-v $agent_socket:$container_socket"
}
