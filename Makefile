# Lattice Five — command-line build/test/lint, so you never have to open Xcode.
# Run `make` (or `make help`) to list targets.

.DEFAULT_GOAL := help

.PHONY: help
help:  ## List the available commands
	@echo "Lattice Five — available make targets:"
	@awk 'BEGIN {FS = ":.*## "} \
		/^##@ / {printf "\n\033[1m%s\033[0m\n", substr($$0, 5); next} \
		/^##~ / {printf "  \033[2m%s\033[0m\n", substr($$0, 5); next} \
		/^[a-zA-Z0-9_-]+:.*## / {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

##@ Dev — build, run, test

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

.PHONY: icon-svg
icon-svg:  ## Emit the icon as SVG for the website (OUT=dir, default ../lattice-site/static)
	@out="$$(cd "$${OUT:-../lattice-site/static}" && pwd)"; \
	LATTICE_ICON_SVG="$$out/icon.svg" LATTICE_ICON_SVG_SMALL="$$out/favicon.svg" \
		swift test --package-path Packages/LatticeCore \
		--filter "IconRender/testRenderIconSVG" 2>&1 | grep -E "wrote " || true

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

##@ Release lane
##~ make release runs preflight → publish → tag → distribute; each step also runs alone

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

##@ Demo & App Store screenshots
##~ Capture guide, sizes and the shot list: Scripts/asc/SCREENSHOTS.md
##~ Shoot a set: make shots PLATFORM=iphone|ipad|mac → make asc-screenshots → -apply

.PHONY: shots
shots:  ## Guided screenshot capture: PLATFORM=iphone|ipad|mac [OUT=shots] [WITH_NEARBY=1]
	@Scripts/shoot.sh

.PHONY: shots-list
shots-list:  ## Print the shot list and capture order: PLATFORM=iphone|ipad|mac
	@Scripts/asc/run.sh organize $${PLATFORM:-iphone} --list

.PHONY: shots-organize
shots-organize:  ## Rename raw freehand screenshots by capture order: DIR=<folder> PLATFORM=iphone|ipad|mac
	@Scripts/asc/run.sh organize $${PLATFORM:-iphone} $(DIR)

.PHONY: demo-iphone
demo-iphone:  ## Launch the iPhone simulator in demo mode (seeded data, isolated storage)
	@PLATFORM=iphone Scripts/demo.sh

.PHONY: demo-ipad
demo-ipad:  ## Launch the iPad simulator in demo mode
	@PLATFORM=ipad Scripts/demo.sh

.PHONY: demo-mac
demo-mac:  ## Launch the Mac app in demo mode
	@PLATFORM=mac Scripts/demo.sh

.PHONY: demo-fixture
demo-fixture:  ## Regenerate the committed demo games (~2 min; commit the result)
	@cd Packages/LatticeCore && LATTICE_GEN_DEMO=1 swift test --filter GenerateDemoFixture

##@ App Store Connect (dry-run by default; -apply writes)
##~ Listing text: edit Scripts/asc/listing.json → make asc-listing → make asc-listing-apply

.PHONY: asc-listing
asc-listing:  ## Show what differs between listing.json and ASC (dry run)
	@Scripts/asc/run.sh listing

.PHONY: asc-listing-apply
asc-listing-apply:  ## Push listing.json text to App Store Connect
	@Scripts/asc/run.sh listing --apply

.PHONY: asc-screenshots
asc-screenshots:  ## Show what the shots/ tree would upload to the ASC listings (dry run)
	@Scripts/asc/run.sh screens $(ARGS)

.PHONY: asc-screenshots-apply
asc-screenshots-apply:  ## Replace + upload the shots/ tree to the ASC listings
	@Scripts/asc/run.sh screens --apply $(ARGS)
