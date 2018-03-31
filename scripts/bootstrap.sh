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

dir_script="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
dir_base="${dir_script%/*}"
dir_pbuilder="${dir_script%/*}/pbuilder"

# Now that we're sure this system is compatible with the bootstrap script, lets
# set all the variables needed to proceed.
build_user="$(whoami)"
build_base=$(grep -E "^${build_user}:" /etc/passwd | cut -f6 -d:)
build_deps="debhelper devscripts fakeroot gcc pbuilder unzip"
pbuilder_base="$dir_base/pbuilder"
pbuilder_branch='unstable'
pbuilder_bootstraps=("$pbuilder_branch-amd64-base.tgz" "$pbuilder_branch-i386-base.tgz")
pbuilder_mirror="http://ftp.us.debian.org/debian"
pbuilder_chroots="/var/cache/pbuilder"
pbuilder_results="$pbuilder_base/results"
pbuilder_cache="$pbuilder_base/cache"


# The usual debugging, purely here to reference if something goes wrong.
echo "[DEBUG] build_user = $build_user"
echo "[DEBUG] build_base = $build_base"
echo "[DEBUG] build_deps = $build_deps"
echo "[DEBUG] pbuilder_base = $pbuilder_base"
echo "[DEBUG] pbuilder_branch = $pbuilder_branch"
echo "[DEBUG] pbuilder_bootstraps = (${pbuilder_bootstraps[@]})"
echo "[DEBUG] pbuilder_mirror = $pbuilder_mirror"
echo "[DEBUG] pbuilder_chroots = $pbuilder_chroots"
echo "[DEBUG] pbuilder_results = $pbuilder_results"
echo "[DEBUG] pbuilder_cache = $pbuilder_cache"

# The rest of this script, you can read the "[INFO ]"" messages and deduce what
# it is that we're doing.

echo "[INFO ] Updating apt-get repository lists"
sudo apt-get update ||
    { echo "[ERROR] apt-get failed to run, 'apt-get update'"; exit 1; }

echo "[INFO ] Installing dependencies"
sudo apt-get install $build_deps ||
    { echo "[ERROR] apt-get failed to install dependencies: [${build_deps}]!"; exit 1; }

for dir in "$pbuilder_chroots" "$pbuilder_results" "$pbuilder_cache"; do
    echo "[INFO ] Checking if directory exists: $dir"
    if [[ ! -d "$dir" ]]; then
        echo "[INFO ] Making directory: $dir"
        mkdir -v -m 755 "$dir"
    fi
done

declare opts_base=""
opts_base="$opts_base --distribution $pbuilder_branch"
opts_base="$opts_base --mirror $pbuilder_mirror"

echo "[INFO ] Checking pbuilder bootstraps"
for bootstrap in "${pbuilder_bootstraps[@]}"; do

    # pbuilder likes to store native architectures without the arch in the
    # file name.  Due to the requirements of this script, 32-bit bootstraps
    # will contain "i386" while 64-bit bootstraps will not have arch in filename.
    bootstrap_arch=''
    if [[ "$bootstrap" =~ i386 ]]; then
        bootstrap_arch='i386'
    else
        bootstrap_arch='amd64'
    fi
    echo "[DEBUG] bootstrap_arch = $bootstrap_arch"

    declare opts_arch="--architecture $bootstrap_arch"
    declare opts_chroot="--basetgz $pbuilder_chroots/$bootstrap"
    declare opts_final="$opts_base $opts_arch $opts_chroot"

    echo "[DEBUG] opts_final = $opts_final"

    if [[ ! -f "$pbuilder_chroots/$bootstrap" ]]; then
        echo "[INFO ] Creating pbuilder base, ${bootstrap}"
        sudo pbuilder create $opts_final ||
            { echo "[ERROR] Failed to execute 'pbuilder'"; exit 1; }
    else
        echo "[INFO ] Updating pbuilder base, ${bootstrap}"
        sudo pbuilder update $opts_final ||
            { echo "[ERROR] Failed to execute 'pbuilder'"; exit 1; }
    fi
done

echo "[INFO ] Script completed successfully!"
exit 0
