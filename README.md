# Liquorix Package

[![license](https://img.shields.io/github/license/damentz/liquorix-package.svg)](LICENSE)

This repository contains the Debian package to build Liquorix for both Debian and Ubuntu, and scripts for Debian, Ubuntu, and Arch Linux.

## Prerequisites

The following software must be installed.

1. Docker
2. GnuPG

GnuPG must be configured with a `default-key` line defined in `~/.gnupg/gpg.conf`.  Consult the GnuPG manual for more information if you're unsure what to put here.

## Usage

### Bootstrap Docker Images

Before any builds can be executed, the prepared docker images must be bootstrapped.  To bootstrap all supported images, execute:

```shell
./scripts/debian/docker_bootstrap.sh
```

Subsequent executions of `docker_bootstrap.sh` will update the existing images rather than performing a full build.

### Build Source and Binary Packages

The `debian/docker_build-source.sh` script require two operands, the distribution and release.  For example, to build for Ubuntu Focal, you would execute below:

```shell
./scripts/debian/docker_build-source.sh ubuntu focal
```

Once complete, you need to build the binary:

```shell
./scripts/debian/docker_build-binary.sh amd64 ubuntu focal
```

If the build completes successfully, the build for Ubuntu Focal will be found under `artifacts/ubuntu/focal`.

At this time, only AMD64 is supported and is the only architecture that will build successfully.

### Package Signing

If you run into trouble with errors for signing or don't desire signed packages, look for instances in the scripts folder of `dpkg-buildpackage` and add the `--no-sign` flag to all lines.

For example, from the root of this project, execute the following script to find all instances and edit each file as necessary:

```shell
find scripts/ -type f | xargs grep -H 'dpkg-buildpackage'
```

If signing is desired, make sure to update the changelog with `dch -i --auto-nmu` and set the author to match your signing key you set up with GnuPG.

## Contributing

PRs accepted.
