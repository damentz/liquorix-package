#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

if [[ ! -f "$dir_base/$package_source" ]]; then
    echo "[WARN ] Missing source file: $dir_base/$package_source, downloading now."
    wget --quiet -O "$dir_base/$package_source" "https://cdn.kernel.org/pub/linux/kernel/v${version_major}.x/linux-${version_kernel}.tar.xz"
fi
