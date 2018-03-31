#!/bin/bash

dir_script="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
package_name='linux-liquorix'

dir_base="${dir_script%/*}"
dir_package="$dir_base/$package_name"
dir_build="$dir_base/build"
dir_pbuilder="${dir_script%/*}/pbuilder"


version_package="$( head -n1 "$dir_package"/debian/changelog | grep -Po '\d+\.\d+-\d+' )"
version_kernel="$(  head -n1 "$dir_package"/debian/changelog | grep -Po '\d+\.\d+' )"
version_build="1"

package_source="${package_name}_${version_kernel}.orig.tar.xz"

releases_debian=('unstable')
releases_ubuntu=('xenial' 'artful' 'bionic')
mirror_debian='http://ftp.us.debian.org/debian'
mirror_ubuntu='http://us.archive.ubuntu.com/ubuntu'

# Now that we're sure this system is compatible with the bootstrap script, lets
# set all the variables needed to proceed.
build_user="$(whoami)"
build_base=$(grep -E "^${build_user}:" /etc/passwd | cut -f6 -d:)
build_deps="debhelper devscripts fakeroot gcc pbuilder unzip"
pbuilder_releases=("${releases_debian[@]}")
pbuilder_arches=('amd64' 'i386')
pbuilder_mirror="$mirror_debian"
pbuilder_chroots="/var/cache/pbuilder"
pbuilder_results="$dir_base/debs"

function prepare_env {
    local dir_build="$1"
}