#!/usr/bin/env bash

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Check prerequisites first.
if [[ "$(id -u)" -eq 0 ]]; then
    echo "[ERROR] Cannot run as root.  Actions that require root will use sudo."
    exit 1
fi

if [[ "$(uname -m)" != 'x86_64' ]]; then
    echo "[ERROR] Please run this script on a 64-bit operating system."
    exit 1
fi

grep -q 'Debian' /etc/issue ||
    { echo "[ERROR] Please run this script on a Debian machine."; exit 1; }

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"

# The usual debugging, purely here to reference if something goes wrong.
echo "[DEBUG] build_user = $build_user"
echo "[DEBUG] build_base = $build_base"
echo "[DEBUG] build_deps = $build_deps"
echo "[DEBUG] pbuilder_releases = ${pbuilder_releases[@]}"
echo "[DEBUG] pbuilder_arches = ${pbuilder_arches[@]}"
echo "[DEBUG] pbuilder_mirror = $pbuilder_mirror"
echo "[DEBUG] pbuilder_chroots = $pbuilder_chroots"
echo "[DEBUG] pbuilder_results = $pbuilder_results"

# The rest of this script, you can read the "[INFO ]"" messages and deduce what
# it is that we're doing.

echo "[INFO ] Updating apt-get repository lists"
sudo apt-get update ||
    { echo "[ERROR] apt-get failed to run, 'apt-get update'"; exit 1; }

echo "[INFO ] Installing dependencies"
echo "${build_deps[@]}" | xargs sudo apt-get install -y ||
    { echo "[ERROR] apt-get failed to install dependencies: [${build_deps[@]}]!"; exit 1; }

for dir in "$pbuilder_chroots" "$pbuilder_results"; do
    echo "[INFO ] Checking if directory exists: $dir"
    if [[ ! -d "$dir" ]]; then
        echo "[INFO ] Making directory: $dir"
        mkdir -v -m 755 "$dir"
    fi
done

declare opts_mirror="--mirror $pbuilder_mirror"

echo "[INFO ] Checking pbuilder bootstraps"

for release in "${pbuilder_releases[@]}"; do
    for arch in "${pbuilder_arches[@]}"; do
        echo "[DEBUG] arch = $arch"

        declare bootstrap="$pbuilder_chroots/$release-$arch-base.tgz"
        declare opts_final="--distribution $release"
        opts_final="$opts_final --architecture $arch"
        opts_final="$opts_final --basetgz $bootstrap"
        opts_final="$opts_final --compressprog pigz"

        echo "[DEBUG] opts_final = $opts_final"

        if [[ ! -f "$bootstrap" ]]; then
            echo "[INFO ] Creating pbuilder base, $bootstrap"
            sudo pbuilder create $opts_final ||
                { echo "[ERROR] Failed to execute 'pbuilder'"; exit 1; }
        else
            echo "[INFO ] Updating pbuilder base, $bootstrap"
            sudo pbuilder update $opts_final ||
                { echo "[ERROR] Failed to execute 'pbuilder'"; exit 1; }
        fi
    done
done

echo "[INFO ] Script completed successfully!"
exit 0
