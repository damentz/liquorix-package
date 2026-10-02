# Liquorix Package

[![license](https://img.shields.io/badge/license-GPL--2.0-blue.svg)](LICENSE)
![Debian and Ubuntu](https://liquorix.net/jenkins/buildStatus/icon?job=BuildDebianUbuntu&subject=Debian%20%2F%20Ubuntu)
![Arch Linux](https://liquorix.net/jenkins/buildStatus/icon?job=BuildArchlinux&subject=Arch%20Linux)
![Fedora](https://liquorix.net/jenkins/buildStatus/icon?job=BuildFedora&subject=Fedora)

This repository contains the Debian package to build Liquorix for both Debian and Ubuntu, and scripts for Debian, Ubuntu, Arch Linux, and Fedora.

## Prerequisites

The following software must be installed.

1. Docker
2. GnuPG (optional — required only for package signing)

## Usage

Run `make` or `make help` to see all available targets and their current variable defaults:

```shell
make
```

Variables can be overridden on the command line:

- `PROCS` — number of parallel jobs (default: `nproc/2`, minimum 2)
- `BUILD` — build number (default: `1`)
- `DISTRO` — distribution name (e.g. `ubuntu`, `debian`) — required for per-release targets
- `RELEASE` — release codename (e.g. `resolute`, `trixie`) — required for per-release targets

### Bootstrap Docker Images

Before any builds can be executed, the prepared Docker images must be bootstrapped.  To bootstrap Debian or Ubuntu images:

```shell
make bootstrap-debian
make bootstrap-ubuntu
```

For Arch Linux:

```shell
make bootstrap-arch
```

For Fedora (one image per supported release):

```shell
make bootstrap-fedora
```

Subsequent runs will update the existing images rather than performing a full build.

Fedora releases are detected from [Bodhi](https://bodhi.fedoraproject.org/releases/): every current, branched, and rawhide release.  Run `make fedora-releases` to see the list, or set `RELEASES_FEDORA="44"` to override it.

### Build Source and Binary Packages

Build all Debian or Ubuntu source packages:

```shell
make build-source-debian
make build-source-ubuntu
```

Build all Debian binary packages:

```shell
make build-binary-debian
```

Build the Arch Linux binary package:

```shell
make build-binary-arch
```

Build Fedora RPM packages:

```shell
make build-binary-fedora
```

To build for a single release, use the per-release targets with `DISTRO` and `RELEASE`:

```shell
make build-source DISTRO=ubuntu RELEASE=resolute
make build-binary DISTRO=ubuntu RELEASE=resolute
```

If the build completes successfully, Debian packages will be found under `artifacts/debian/<release>`.

At this time, only AMD64 is supported and is the only architecture that will build successfully.

### Package Signing

Package signing is optional.  If GnuPG is not installed or no signing key is configured, builds will complete successfully and skip signing with a warning.

To enable signing, configure GnuPG with a default key:

1. Execute `gpg --full-gen-key` and follow prompts
2. Run `gpg --list-secret-keys` to find your key ID
3. Create `~/.gnupg/gpg.conf` and add `default-key EXAMPLE1234...`, where the example is your key from the previous output

When a valid key is configured, packages are signed automatically during the build.  If signing is desired for Debian, make sure to update the changelog with `dch -i --auto-nmu` and set the author to match your signing key.

### Installing on Fedora

Fedora builds are published at `https://liquorix.net/fedora/<release>/x86_64/`, with signed packages and repository metadata:

```shell
sudo curl -fsSL -o /etc/yum.repos.d/liquorix.repo https://liquorix.net/fedora/liquorix.repo
sudo dnf install kernel-liquorix kernel-liquorix-modules kernel-liquorix-devel
```

The Liquorix kernel becomes the default boot entry and stays default when stock Fedora kernels update.  Set `UPDATEDEFAULT=no` in `/etc/sysconfig/kernel` to opt out.  Secure Boot must be disabled.

### Cleanup

Remove all Liquorix Docker build images:

```shell
make clean
```

## Contributing

PRs accepted.
