#!/bin/bash

# Variables defined here are used by scripts that source this file
# shellcheck disable=SC2034

dir_script="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
package_name='kernel-liquorix'
package_maintainer="Steven Barrett <steven@liquorix.net>"

dir_base="${dir_script%/*/*}"
dir_package="$dir_base/linux-liquorix"
dir_build="/build"
dir_scripts="$dir_base/scripts/fedora"
dir_artifacts="$dir_base/artifacts"

# Release Version strings come from the version module (see CONTEXT.md).
eval "$("$dir_base/scripts/version" -C "$dir_package" env)"
# shellcheck disable=SC2154  # assigned by eval above
version_package="${version_kernel}-${version_pkgrev}"
# Build Number: rebuild of the same source, overridable by the BUILD argument.
version_build="1"

package_source="linux-liquorix_${version_kernel}.orig.tar.xz"

source_arch='amd64'
source_distro='fedora'

releases_fedora=('42' '43')

build_user="builder"

schedtool='schedtool -D -n19 -e'
