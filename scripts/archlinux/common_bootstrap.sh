#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

# Always make sure we have the latest version.  Actual file size is 
if [[ -f "$dir_base/$package_source" ]]; then
    rm -fv "$dir_base/$package_source"
fi

wget -O "$dir_base/$package_source" \
    "https://aur.archlinux.org/cgit/aur.git/snapshot/$package_source"
