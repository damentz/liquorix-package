#!/bin/bash

set -euo pipefail

# shellcheck source=env.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh"
# shellcheck source=../lib.sh
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../lib.sh"

declare arch=${1:-}
declare distro=${2:-}
declare release=${3:-}
declare build=${4:-${version_build}}

version_build="$build"

declare dir_artifacts="$dir_artifacts/$distro/$release"

require_build_args "$arch" "$distro" "$release"

declare rpmbuild_dir="$HOME/rpmbuild"
declare spec_name="kernel-liquorix.spec"

# Copy kernel source tarball to SOURCES
log_info "Copying kernel source tarball to rpmbuild SOURCES"
cp -v "$dir_base/$package_source" \
    "$rpmbuild_dir/SOURCES/linux-${version_kernel}.tar.xz"

# Copy liquorix patch to SOURCES
log_info "Copying liquorix patch to rpmbuild SOURCES"
cp -v "$dir_package/debian/patches/zen/v${version_upstream}-lqx1.patch" \
    "$rpmbuild_dir/SOURCES/"

# Copy kernel config to SOURCES
log_info "Copying kernel config to rpmbuild SOURCES"
cp -v "$dir_package/debian/config/kernelarch-x86/config-arch-64" \
    "$rpmbuild_dir/SOURCES/config-x86_64-liquorix"

# Copy spec file to SPECS
log_info "Copying spec file to rpmbuild SPECS"
cp -v "$dir_scripts/$spec_name" "$rpmbuild_dir/SPECS/"

# Build RPMs
log_info "Building RPM packages for $release"
$schedtool rpmbuild -bb \
    --define "version_upstream $version_upstream" \
    --define "version_build $version_build" \
    --define "fedora_release $release" \
    "$rpmbuild_dir/SPECS/$spec_name"

# Sign RPMs
log_info "Signing RPM packages"
declare gpg_key
gpg_key="$(
    cat ~/.gnupg/gpg.conf ~/.gnupg/options 2>/dev/null | \
    grep -E '^\s*default-key' | grep -Po '\S+\s*$' | tr -d '[:space:]' || true
)"
if [[ -n "$gpg_key" ]]; then
    echo "%_gpg_name $gpg_key" >> ~/.rpmmacros
    rpm --addsign "$rpmbuild_dir/RPMS/x86_64/"*.rpm
else
    log_warn "No GPG default-key found, skipping RPM signing"
fi

# Copy artifacts to bind-mounted directory
log_info "Copying RPM packages to bind mount: $dir_artifacts/"
if [[ -d "$dir_artifacts" ]]; then
    log_info "Removing existing artifacts first"
    sudo rm -fv "$dir_artifacts"/*
fi

sudo mkdir -vp "$dir_artifacts"
sudo chown -R "$build_user":"$build_user" "$dir_artifacts"
cp -arv "$rpmbuild_dir/RPMS/x86_64/"*.rpm "$dir_artifacts/"

# Create repository metadata
log_info "Creating RPM repository"
cd "$dir_artifacts"
createrepo_c .

ls -ltrh
