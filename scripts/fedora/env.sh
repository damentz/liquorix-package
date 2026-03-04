#!/bin/bash

dir_script="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
package_name='kernel-liquorix'
package_maintainer="Steven Barrett <steven@liquorix.net>"

dir_base="${dir_script%/*/*}"
dir_package="$dir_base/linux-liquorix"
dir_build="/build"
dir_scripts="$dir_base/scripts/fedora"
dir_artifacts="$dir_base/artifacts"

# Parse version from debian/changelog and config/defines (single source of truth)
# Changelog has: linux-liquorix (6.18-17) => version_kernel=6.18
# Config defines has: abiname: 15-3 => patch=15, lqx=3
# Combined: version_upstream=6.18.15, version_build=3
version_package="$( head -n1 "$dir_package"/debian/changelog | grep -Po '\d+\.\d+-\d+' )"
version_kernel="$(  echo "$version_package" | grep -Po '\d+\.\d+' )"

declare _abiname
_abiname="$( grep -Po '(?<=^abiname:\s)\S+' "$dir_package"/debian/config/defines )"
version_upstream="${version_kernel}.${_abiname%%-*}"
version_build="${_abiname##*-}"

package_source="linux-liquorix_${version_kernel}.orig.tar.xz"

source_arch='amd64'
source_distro='fedora'

releases_fedora=('42' '43')

build_user="builder"

schedtool='schedtool -D -n19 -e'
