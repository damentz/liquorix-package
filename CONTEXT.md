# Liquorix Packaging

Builds and publishes the Liquorix kernel for Debian, Ubuntu, Arch Linux and Fedora from a single upstream release.

## Language

### Release Version

**Release Version**:
The complete identity of one published build: Upstream Version, Lqx Revision, Package Revision and Build Number, rendered per distro.
_Avoid_: version string, release_version, abiname (as a whole)

**Upstream Version**:
The stable kernel the release is based on, e.g. `7.1.8`.
_Avoid_: version_upstream, kernel version

**Kernel Series**:
The major.minor line of the Upstream Version, e.g. `7.1`. Names the branch and the orig tarball.
_Avoid_: version_kernel, branch_major

**Lqx Revision**:
The Liquorix patch iteration on top of an Upstream Version, e.g. `4` in `v7.1.8-lqx4`. Names the zen-kernel tag and the patch file.
_Avoid_: lqxversion, EXTRAVERSION, ev

**Package Revision**:
The Debian packaging iteration for a Kernel Series, e.g. `13` in `7.1-13`. Increments on every packaging change, including Lqx Revision bumps.
_Avoid_: version_package, changelog version

**Build Number**:
A rebuild of the same source for one distro release without any source change. Defaults to 1.
_Avoid_: version_build, build
