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

# Now that we're sure this system is compatible with the bootstrap script, lets
# set all the variables needed to proceed.
build_user="$(whoami)"
build_base=$(grep -E "^${build_user}:" /etc/passwd | cut -f6 -d:)
build_deps="debhelper devscripts fakeroot gcc pbuilder ubuntu-dev-tools unzip"
pbuilder_base="${build_base}/pbuilder"
pbuilder_branch='unstable'
pbuilder_bootstrap_amd64="${pbuilder_branch}-base.tgz"
pbuilder_bootstrap_i386="${pbuilder_branch}-i386-base.tgz"
pbuilder_bootstraps=("$pbuilder_bootstrap_amd64" "$pbuilder_bootstrap_i386")

# The usual debugging, purely here to reference if something goes wrong.
echo "[DEBUG] build_user = $build_user"
echo "[DEBUG] build_base = $build_base"
echo "[DEBUG] build_deps = $build_deps"
echo "[DEBUG] pbuilder_base = $pbuilder_base"
echo "[DEBUG] pbuilder_branch = $pbuilder_branch"
echo "[DEBUG] pbuilder_bootstraps = (${pbuilder_bootstraps[@]})"

# The rest of this script, you can read the "[INFO ]"" messages and deduce what
# it is that we're doing.

echo "[INFO ] Updating apt-get repository lists"
sudo apt-get update ||
    { echo "[ERROR] apt-get failed to run, 'apt-get update'"; exit 1; }

echo "[INFO ] Installing dependencies"
sudo apt-get install $build_deps ||
    { echo "[ERROR] apt-get failed to install dependencies: [${build_deps}]!"; exit 1; }

echo "[INFO ] Checking if directory exists: $pbuilder_base"
if [[ ! -d "$pbuilder_base" ]]; then
    echo "[INFO ] Making directory: $pbuilder_base"
    mkdir -v -m 755 "$pbuilder_base"
fi

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

    if [[ ! -f "${pbuilder_base}/${bootstrap}" ]]; then
        echo "[INFO ] Creating pbuilder base, ${bootstrap}"
        pbuilder-dist $pbuilder_branch $bootstrap_arch create ||
            { echo "[ERROR] Failed to execute 'pbuilder-dist'"; exit 1; }
    else
        echo "[INFO ] Updating pbuilder base, ${bootstrap}"
        pbuilder-dist $pbuilder_branch $bootstrap_arch update ||
            { echo "[ERROR] Failed to execute 'pbuilder-dist'"; exit 1; }
    fi
done

echo "[INFO ] Script completed successfully!"
exit 0
