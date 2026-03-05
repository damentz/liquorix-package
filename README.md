# Liquorix Package

[![license](https://img.shields.io/badge/license-GPL--2.0-blue.svg)](LICENSE)

This repository contains the Debian package to build Liquorix for both Debian and Ubuntu, and scripts for Debian, Ubuntu, and Arch Linux.

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

Before any builds can be executed, the prepared Docker images must be bootstrapped.  To bootstrap Debian images:

```shell
make bootstrap-debian
```

For Arch Linux:

```shell
make bootstrap-arch
```

Subsequent runs will update the existing images rather than performing a full build.

### Build Source and Binary Packages

Build all Debian source packages:

```shell
make build-source-all
```

Build all Debian binary packages:

```shell
make build-binary-debian
```

Build the Arch Linux binary package:

```shell
make build-binary-arch
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

### Cleanup

Remove all Liquorix Docker build images:

```shell
make clean
```

## Contributing

PRs accepted.
