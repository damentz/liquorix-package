#!/bin/bash

set -e

package_name='linux-liquorix'
dir_script="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
dir_base="${dir_script%/*}"
dir_package="$dir_base/$package_name"
dir_ppa="$dir_base/ppa"

version_package="$( head -n1 $dir_package/debian/changelog | grep -Po '\d+\.\d+-\d+' )"
version_kernel="$(  head -n1 $dir_package/debian/changelog | grep -Po '\d+\.\d+' )"

package_source="${package_name}_${version_kernel}.orig.tar.xz"

releases=(
    yakkety
	artful
	bionic
)

echo "[DEBUG] package_name:   $package_name"
echo "[DEBUG] package_source: $package_source"
echo "[DEBUG] dir_script:  $dir_script"
echo "[DEBUG] dir_base:    $dir_base"
echo "[DEBUG] dir_package: $dir_package"
echo "[DEBUG] dir_ppa:     $dir_ppa"
echo "[DEBUG] releases:    ${releases[@]}"

function prepare_env {
	echo "[INFO ] Preparing PPA directory: $dir_ppa"
	mkdir -p "$dir_ppa"
	if [[ -d "$dir_ppa/$package_name" ]]; then
		echo "[INFO ] Removing $dir_ppa/$package_name"
		rm -rf "$dir_ppa/$package_name"
	fi

	cd "$dir_package"
	echo "[INFO ] Cleaning package"
	fakeroot debian/rules maintainerclean

	echo "[INFO ] Copying over $package_name package"
	cp -raf "$dir_package/" "$dir_ppa/"

	if [[ ! -f "$dir_base/$package_source" ]]; then
		echo "[WARN ] Missing source file: $dir_base/$package_source, downloading now."
		wget -O "$dir_base/$package_source" "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-$version_package.tar.xz"
	fi

	echo "[INFO ] Unpacking kernel source into package folder."
	tar -xf "$dir_base/$package_source" --strip-components=1 -C "$dir_ppa/$package_name"
}

prepare_env