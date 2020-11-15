#!/bin/bash

dir_script="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
package_name='linux-lqx'
package_source="$package_name.tar.gz"
package_maintainer="Steven Barrett <steven@liquorix.net>"

dir_base="${dir_script%/*/*}"
dir_package="$dir_base/$package_name"
dir_build="/build"
dir_scripts="$dir_base/scripts/archlinux"
dir_artifacts="$dir_base/artifacts"

source_arch='amd64'
source_distro='archlinux'
source_release='latest'

repo_name="liquorix"
repo_file="$repo_name.db.tar.zst"

# stable => stretch, testing => buster, unstable => sid
releases=('latest')

# Now that we're sure this system is compatible with the bootstrap script, lets
# set all the variables needed to proceed.
build_user="builder"

schedtool='schedtool -D -n19 -e'
