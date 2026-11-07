# slipway — the shared build, test and release targets, included from the
# project's Makefile:
#
#     include Scripts/slipway/slipway.mk
#
# Settings come from slipway.yml. The project keeps its own targets beside
# these; to hook one of these, give it an extra prerequisite in the project's
# Makefile (`lint: lint-markdown`) — never redefine it, which make only warns
# about. See README.md.

SLIPWAY_DIR := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
SLIPWAY_NAME := $(shell $(SLIPWAY_DIR)/config.sh name)
ifeq ($(SLIPWAY_NAME),)
$(error slipway: couldn't read slipway.yml — see the error above)
endif
SLIPWAY_TITLE := $(shell $(SLIPWAY_DIR)/config.sh display_name)
SLIPWAY_CORE := $(shell $(SLIPWAY_DIR)/config.sh core_package)
SLIPWAY_PLATFORMS := $(shell $(SLIPWAY_DIR)/config.sh platforms)
SLIPWAY_XCODEPROJ := $(SLIPWAY_NAME).xcodeproj
SLIPWAY_FORMAT_PATHS := $(wildcard Packages/$(SLIPWAY_CORE)/Sources Packages/$(SLIPWAY_CORE)/Tests Sources)

.DEFAULT_GOAL := help

.PHONY: help
help:  ## List the available commands
	@echo "$(SLIPWAY_TITLE) — available make targets:"
	@awk -v plats=" $(SLIPWAY_PLATFORMS) " -f $(SLIPWAY_DIR)/help.awk \
		$(SLIPWAY_DIR)/slipway.mk $(filter-out $(SLIPWAY_DIR)/%,$(MAKEFILE_LIST))

##@ Build & test

# The generated project depends on what XcodeGen reads, so it's regenerated
# only when one of them changed. A project adds its own inputs as extra
# prerequisites: `$(SLIPWAY_XCODEPROJ): Resources/data.sqlite`.
SLIPWAY_PROJECT_INPUTS := project.yml slipway.yml \
	$(wildcard Sources/*/Info.plist) \
	$(wildcard Sources/*/*.entitlements) \
	$(wildcard Sources/*/*.xcstrings)

$(SLIPWAY_XCODEPROJ): $(SLIPWAY_PROJECT_INPUTS)
	@$(SLIPWAY_DIR)/generate.sh

.PHONY: generate
generate: $(SLIPWAY_XCODEPROJ)  ## Regenerate the Xcode project from project.yml (if stale)

ifneq ($(filter ios,$(SLIPWAY_PLATFORMS)),)
.PHONY: build-ios
build-ios: $(SLIPWAY_XCODEPROJ)  ## [ios] Build the iOS app (simulator, unsigned)
	@$(SLIPWAY_DIR)/build.sh ios
endif

ifneq ($(filter macos,$(SLIPWAY_PLATFORMS)),)
.PHONY: build-mac
build-mac: $(SLIPWAY_XCODEPROJ)  ## [macos] Build the macOS app (unsigned)
	@$(SLIPWAY_DIR)/build.sh macos
endif

ifneq ($(filter watchos,$(SLIPWAY_PLATFORMS)),)
.PHONY: build-watch
build-watch: $(SLIPWAY_XCODEPROJ)  ## [watchos] Build the watchOS app (simulator, unsigned)
	@$(SLIPWAY_DIR)/build.sh watchos
endif

.PHONY: test
test:  ## Run the core package's logic tests (no Xcode project needed)
	@$(SLIPWAY_DIR)/test.sh

.PHONY: lint
lint:  ## SwiftLint + swift-format, both strict (as CI runs them)
	@swiftlint lint --strict
	@swift format lint --strict --recursive --configuration .swift-format $(SLIPWAY_FORMAT_PATHS)

.PHONY: format
format:  ## Rewrite sources with swift-format
	@swift format --in-place --recursive --configuration .swift-format $(SLIPWAY_FORMAT_PATHS)

.PHONY: clean
clean:  ## Remove the generated project and local build output
	@rm -rf $(SLIPWAY_XCODEPROJ) .build-xcode Packages/$(SLIPWAY_CORE)/.build dist
	@echo "removed $(SLIPWAY_XCODEPROJ), .build-xcode, Packages/$(SLIPWAY_CORE)/.build, dist"

##@> Release
##~ Cut a build: make release — preflight → publish → tag → distribute
##~ [macos] PLATFORM=all (default) or one platform; UPLOAD=0 stops after export

# One script per step, chained in order. The pure ends (preflight, tag,
# distribute) re-derive their inputs from git + project.yml, so each also runs
# standalone; the dirty middle (publish: prompts, PR, CI wait) is the one
# stateful script, and state crosses to the later steps via the merged commit,
# not through make. A linear chain, so the order holds under `make -j` too.
PLATFORM ?= all
UPLOAD ?= 1
SLIPWAY_DIST_FLAGS := $(if $(filter 0,$(UPLOAD)),--no-upload,)

.PHONY: release
release: release-distribute  ## Cut a release (UPLOAD=0 to skip the App Store Connect upload)
	@echo "✓ release complete (PLATFORM=$(PLATFORM))."

.PHONY: release-build
release-build:  ## Like `release` but stop after export (no upload)
	@$(MAKE) --no-print-directory release UPLOAD=0

.PHONY: release-preflight
release-preflight:  ## Release step 1: verify a clean, up-to-date base (main or release/X.Y.x)
	@$(SLIPWAY_DIR)/release-preflight.sh

.PHONY: release-publish
release-publish: release-preflight  ## Release step 2: bump, open the auto-merging PR, wait for CI
	@$(SLIPWAY_DIR)/release-publish.sh $(PLATFORM)

.PHONY: release-tag
release-tag: release-publish  ## Release step 3: tag the merge commit + publish GitHub releases
	@$(SLIPWAY_DIR)/release-tag.sh $(PLATFORM)

.PHONY: release-distribute
release-distribute: release-tag  ## Release step 4: archive/export (+ upload unless UPLOAD=0)
	@$(SLIPWAY_DIR)/release-distribute.sh $(PLATFORM) $(SLIPWAY_DIST_FLAGS)

# Distribute is the likeliest step to fail and is safe to repeat: these re-run
# it alone for a release that is already tagged.
.PHONY: release-distribute-retry
release-distribute-retry:  ## Re-distribute an already-tagged release (no PR/tag steps)
	@$(SLIPWAY_DIR)/release-distribute.sh $(PLATFORM) $(SLIPWAY_DIST_FLAGS) --require-tag

.PHONY: release-upload
release-upload:  ## Upload the already-built dist/ package (no rebuild)
	@$(SLIPWAY_DIR)/release-distribute.sh $(PLATFORM) --upload-only

##@> App Store
##~ Text from Scripts/asc/listing.json, screenshots from shots/ in Scripts/asc/shots.json's store order
# The bare targets are dry runs; -apply writes. Every editable version is
# written (Prepare for Submission, rejected); one in review or live is skipped.
SLIPWAY_ASC_ALL := $(if $(filter 1,$(ALL)),--all,)

.PHONY: asc-listing
asc-listing:  ## Show what the listing text would change in App Store Connect
	@$(SLIPWAY_DIR)/asc.sh listing

.PHONY: asc-listing-apply
asc-listing-apply:  ## Write the listing text to App Store Connect
	@$(SLIPWAY_DIR)/asc.sh listing --apply

.PHONY: asc-screenshots
asc-screenshots:  ## Show the screenshot upload plan: only the shots that changed (ALL=1: every shot)
	@$(SLIPWAY_DIR)/asc.sh screens $(SLIPWAY_ASC_ALL)

.PHONY: asc-screenshots-apply
asc-screenshots-apply:  ## Upload the changed screenshots, drop the stale, reorder (ALL=1 replaces every shot)
	@$(SLIPWAY_DIR)/asc.sh screens --apply $(SLIPWAY_ASC_ALL)

##@> slipway
.PHONY: slipway-check
slipway-check:  ## Verify Scripts/slipway is an unmodified copy of its recorded version
	@$(SLIPWAY_DIR)/check.sh

.PHONY: slipway-update
slipway-update:  ## Update Scripts/slipway: V=vX.Y.Z, or SLIPWAY_SRC=<checkout> for a local one
	@$(SLIPWAY_DIR)/update.sh "$(V)" "$(SLIPWAY_SRC)"
