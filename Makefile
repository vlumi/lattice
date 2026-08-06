# Lattice Five — command-line build/test/lint, so you never have to open Xcode.
# Run `make` (or `make help`) to list targets.

.DEFAULT_GOAL := help

.PHONY: help
help:  ## List the available commands
	@echo "Lattice Five — available make targets:"
	@awk 'BEGIN {FS = ":.*## "} \
		/^[a-zA-Z0-9_-]+:.*## / {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Inputs xcodegen reads — regenerate the project when any of these change.
PROJECT_INPUTS := project.yml \
	$(wildcard Sources/*/Info.plist) \
	$(wildcard Sources/*/*.xcstrings)

Lattice.xcodeproj: $(PROJECT_INPUTS)
	@Scripts/generate.sh

.PHONY: generate
generate: Lattice.xcodeproj  ## Regenerate Lattice.xcodeproj from project.yml (if stale)

.PHONY: run-mac
run-mac: Lattice.xcodeproj  ## Build + launch the macOS app
	@Scripts/run.sh

.PHONY: run-iphone
run-iphone: Lattice.xcodeproj  ## Build + launch on an iPhone simulator (DEVICE="SE" / "17 Pro" to pick)
	@Scripts/run-ios.sh iphone "$(DEVICE)"

.PHONY: run-ipad
run-ipad: Lattice.xcodeproj  ## Build + launch on an iPad simulator (DEVICE="Air" / "13-inch" to pick)
	@Scripts/run-ios.sh ipad "$(DEVICE)"

.PHONY: build-mac
build-mac: Lattice.xcodeproj  ## Build the macOS app (unsigned)
	@xcodebuild build -project Lattice.xcodeproj -scheme Lattice-macOS \
		-destination 'platform=macOS' -derivedDataPath .build-xcode \
		CODE_SIGNING_ALLOWED=NO -quiet

.PHONY: build-ios
build-ios: Lattice.xcodeproj  ## Build the iOS app (simulator, unsigned)
	@xcodebuild build -project Lattice.xcodeproj -scheme Lattice-iOS \
		-destination 'generic/platform=iOS Simulator' -derivedDataPath .build-xcode \
		CODE_SIGNING_ALLOWED=NO -quiet

.PHONY: icon
icon:  ## Regenerate the app icon assets from IconArt (deterministic)
	@Scripts/gen-icon.sh

.PHONY: sounds
sounds:  ## Regenerate the sound effects from make-sounds.swift (deterministic)
	@Scripts/gen-sounds.sh

.PHONY: test
test:  ## Run the package logic tests (no Xcode project needed)
	@swift test --package-path Packages/LatticeCore

.PHONY: lint
lint:  ## SwiftLint + swift-format, both strict (as CI runs them)
	@swiftlint lint --strict
	@swift format lint --strict --recursive --configuration .swift-format \
		Packages/LatticeCore/Sources Packages/LatticeCore/Tests Sources

.PHONY: format
format:  ## Rewrite sources with swift-format
	@swift format --in-place --recursive --configuration .swift-format \
		Packages/LatticeCore/Sources Packages/LatticeCore/Tests Sources

.PHONY: clean
clean:  ## Remove the generated project + local build output
	@rm -rf Lattice.xcodeproj .build-xcode Packages/LatticeCore/.build
	@echo "removed Lattice.xcodeproj, .build-xcode, package .build"

# ── Release lane ─────────────────────────────────────────────────────────────
# The cut is split by concern, one script each, chained here in order:
#   preflight → publish → tag → distribute
# The pure ends (preflight, tag, distribute) re-derive their inputs from git +
# project.yml, so each runs standalone. The dirty middle (publish: version-bump
# prompts + auto-merging PR + CI-wait) is the one stateful script; state crosses
# to the later steps via the merged commit on the base, not through Make.
# PLATFORM selects scope (default all); UPLOAD=0 stops after export.
PLATFORM ?= all
UPLOAD ?= 1
DIST_FLAGS := $(if $(filter 0,$(UPLOAD)),--no-upload,)

.PHONY: release
release: release-distribute  ## Cut a release (PLATFORM=all|ios|macos, UPLOAD=0 to skip ASC)
	@echo "✓ release complete (PLATFORM=$(PLATFORM))."

.PHONY: release-build
release-build:  ## Like `release` but stop after export (no upload)
	@$(MAKE) release UPLOAD=0

.PHONY: release-preflight
release-preflight:  ## Release step 1: verify a clean, up-to-date base (main or release/X.Y.x)
	@Scripts/release-preflight.sh

.PHONY: release-publish
release-publish: release-preflight  ## Release step 2: bump, open auto-merging PR, wait for CI
	@Scripts/release-publish.sh $(PLATFORM)

.PHONY: release-tag
release-tag: release-publish  ## Release step 3: tag the merge commit + publish GitHub releases
	@Scripts/release-tag.sh $(PLATFORM)

.PHONY: release-distribute
release-distribute: release-tag  ## Release step 4: archive/export (+ upload unless UPLOAD=0)
	@Scripts/release-distribute.sh $(PLATFORM) $(DIST_FLAGS)

# Distribute is the likeliest step to fail (archive/export/ASC upload) and is
# safe to repeat. This standalone retry has NO prereqs — it re-distributes an
# already-tagged release without touching git/PR/tags, after verifying the tag
# for the current version+build exists.
.PHONY: release-distribute-retry
release-distribute-retry:  ## Re-distribute an already-tagged release (no PR/tag steps)
	@Scripts/release-distribute.sh $(PLATFORM) $(DIST_FLAGS) --require-tag

# Upload the package already in dist/ (from a prior `release-build`) without
# rebuilding — for when export succeeded but only the ASC upload failed.
.PHONY: release-upload
release-upload:  ## Upload the already-built dist/ package (no rebuild)
	@Scripts/release-distribute.sh $(PLATFORM) --upload-only
