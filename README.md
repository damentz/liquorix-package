# Liquorix Package

[![license](https://img.shields.io/github/license/damentz/liquorix-package.svg)](LICENSE)

This repository contains the Debian package to build Liquorix for both Debian and Ubuntu, and scripts for Debian, Ubuntu, and Arch Linux.

## Prerequisites

The following software must be installed.

1. Docker
2. GnuPG

GnuPG must be configured with a `default-key` line defined in `~/.gnupg/gpg.conf`.  Consult the GnuPG manual for more information if you're unsure what to put here.  But if you're creating a temporary signing key for the purposes of building, follow these steps:

1. Execute `gpg --full-gen-key` and follow prompts
2. Run `gpg --list-secret-keys` to produce a list of keys you own the secrets to
3. Create `~/.gnupg/gpg.conf` and add `default-key EXAMPLE1234...`, where the example is your key from the previous output

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

If you run into trouble with errors for signing or don't desire signed packages, look for instances in the scripts folder of `dpkg-buildpackage` and add the `--no-sign` flag to all lines.

If signing is desired, make sure to update the changelog with `dch -i --auto-nmu` and set the author to match your signing key you set up with GnuPG.

### Cleanup

Remove all Liquorix Docker build images:

```shell
make clean
```

## Contributing

PRs accepted.
