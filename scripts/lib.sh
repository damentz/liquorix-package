#!/bin/bash
# Shared library for Liquorix build scripts

# Logging
log_info()  { echo "[INFO ] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

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
