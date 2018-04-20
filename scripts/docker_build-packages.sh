set -euo pipefail

declare arch=${1:-}
declare distro=${2:-}
declare release=${3:-}

declare -i fail=0

if [[ -z "$arch" ]]; then
    echo "[ERROR] No architecture set!"
    fail=1
fi

if [[ -z "$distro" ]]; then
    echo "[ERROR] No distribution set!"
    fail=1
fi

if [[ -z "$release" ]]; then
    echo "[ERROR] No release set!"
    fail=1
fi

if [[ $fail -eq 1 ]]; then
    echo "[ERROR] Encountered a fatal error, cannot continue!"
    exit 1
fi

declare release_string="liquorix_$arch/$distro/$release"

echo "[ERROR] Not implemented!"
exit 1