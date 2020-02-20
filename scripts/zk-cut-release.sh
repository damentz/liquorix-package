#!/bin/bash

set -euo pipefail

declare ev=${1:-lqx1}
if [[ ! -f "Makefile" ]]; then
    echo "[ERROR] Makefile for Linux not in current directory!"
    exit 1
fi

sed -r -i "s/^EXTRAVERSION = .*/EXTRAVERSION = -${ev}/" Makefile

declare -i kv=$(grep -E '^VERSION = ' Makefile | sed -r 's/^VERSION = //')
declare -i kpl=$(grep -E '^PATCHLEVEL = ' Makefile | sed -r 's/^PATCHLEVEL = //')
declare -i ksl=$(grep -E '^SUBLEVEL = ' Makefile | sed -r 's/^SUBLEVEL = //')

tag="v$kv.$kpl.$ksl-$ev"

git add Makefile
git commit -m "Cut $tag"
git tag -s "$tag" -m "Cut $tag"
git push origin "$tag"

echo -e "\n"
