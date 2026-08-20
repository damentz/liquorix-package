# Liquorix Build System - Task Runner
#
# Usage:
#   make              # show available targets
#   make help         # show available targets
#   make PROCS=4 bootstrap-debian
#
# Variables:
#   PROCS   - number of parallel jobs (default: nproc/2, min 2)
#   BUILD   - build number (default: 1)
#   DISTRO  - distribution name (e.g. ubuntu, debian) — required for per-release targets
#   RELEASE - release codename (e.g. resolute, trixie) — required for per-release targets

NPROC := $(shell nproc 2>/dev/null || echo 4)
PROCS := $(shell echo $$(( $(NPROC) / 2 > 2 ? $(NPROC) / 2 : 2 )))
BUILD := 1

DISTRO  :=
RELEASE :=
SCRIPTS := scripts

require-release = \
  $(if $(DISTRO),,$(error DISTRO is required, e.g. make $@ DISTRO=ubuntu RELEASE=resolute)) \
  $(if $(RELEASE),,$(error RELEASE is required, e.g. make $@ DISTRO=ubuntu RELEASE=resolute))

.PHONY: help release-debian release-fedora \
        bootstrap-debian bootstrap-arch bootstrap-fedora bootstrap-image \
        build-source-all build-source build-binary-debian build-binary-arch build-binary-fedora build-binary \
        upload-ppa repo-add-debian \
        clean-ppa clean check-version test

help: ## Show available targets
	@echo "Liquorix Build System"
	@echo ""
	@echo "Usage: make [target] [PROCS=N] [BUILD=N] [DISTRO=name] [RELEASE=name]"
	@echo ""
	@echo "Variables:"
	@echo "  PROCS=$(PROCS)  parallel jobs (nproc/2, min 2)"
	@echo "  BUILD=$(BUILD)      build number"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-z][-a-z]+:.*##' $(MAKEFILE_LIST) | \
		awk -F ':.*## ' '{ printf "  %-22s %s\n", $$1, $$2 }'

release-debian: ## Full Debian release pipeline
	$(MAKE) bootstrap-debian
	$(MAKE) build-source-all
	$(MAKE) clean-ppa
	$(MAKE) upload-ppa
	$(MAKE) PROCS=1 build-binary-debian
	$(MAKE) repo-add-debian

release-fedora: ## Full Fedora release pipeline
	$(MAKE) bootstrap-fedora
	$(MAKE) build-binary-fedora

bootstrap-debian: ## Bootstrap Debian Docker build images
	$(SCRIPTS)/debian/docker_bootstrap.sh $(PROCS)

bootstrap-image: ## Bootstrap a single Docker image (needs DISTRO, RELEASE)
	$(require-release)
	$(SCRIPTS)/$(DISTRO)/docker_bootstrap-image.sh amd64 $(DISTRO) $(RELEASE)

bootstrap-arch: ## Bootstrap Arch Linux Docker build image
	$(SCRIPTS)/archlinux/docker_bootstrap.sh $(PROCS)

bootstrap-fedora: ## Bootstrap Fedora Docker build image
	$(SCRIPTS)/fedora/docker_bootstrap.sh $(PROCS)

build-source-all: ## Build Debian source packages for all releases
	$(SCRIPTS)/debian/docker_build-source_all.sh $(PROCS) $(BUILD)

build-binary-debian: ## Build Debian binary packages for all releases
	$(SCRIPTS)/debian/docker_build-binary_debian.sh $(PROCS) $(BUILD)

build-source: ## Build source package for a single release (needs DISTRO, RELEASE)
	$(require-release)
	$(SCRIPTS)/$(DISTRO)/docker_build-source.sh $(DISTRO) $(RELEASE) $(BUILD)

build-binary-arch: ## Build Arch Linux binary package
	$(SCRIPTS)/archlinux/docker_build-binary_archlinux.sh $(PROCS)

build-binary-fedora: ## Build Fedora RPM packages
	$(SCRIPTS)/fedora/docker_build-binary_fedora.sh $(PROCS) $(BUILD)

build-binary: ## Build binary package for a single release (needs DISTRO, RELEASE)
	$(require-release)
	$(SCRIPTS)/$(DISTRO)/docker_build-binary.sh amd64 $(DISTRO) $(RELEASE) $(BUILD)

upload-ppa: ## Upload source packages to PPA
	$(SCRIPTS)/debian/docker_submit-ppa-sources.sh $(BUILD)

repo-add-debian: ## Add built packages to Debian repository
	$(SCRIPTS)/debian/repo_add-debian-packages.sh $(BUILD)

clean-ppa: ## Delete PPA packages
	$(SCRIPTS)/debian/delete_ppa_packages.py

clean: ## Remove Liquorix Docker build images
	$(SCRIPTS)/docker-clean.sh

check-version: ## Verify changelog, defines and patches/series agree on the release version
	$(SCRIPTS)/version check

test: ## Run script tests
	$(SCRIPTS)/tests/test-version.sh
	$(SCRIPTS)/tests/test-debian-env.sh
	$(SCRIPTS)/tests/test-fedora-env.sh
