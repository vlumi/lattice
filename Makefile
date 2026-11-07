# Lattice Five — command-line build/test/lint, so you never have to open Xcode.
#
# The shared targets — generate, build, test, lint, the release lane, the App
# Store listing and screenshot sync — come from slipway (Scripts/slipway,
# configured by slipway.yml; see its README.md). This Makefile adds Lattice's
# own: running and the demo, screenshot capture, and the generated assets. Run
# `make` (or `make help`) to list them all.

include Scripts/slipway/slipway.mk

##@ Build & test

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

.PHONY: demo-fixture
demo-fixture:  ## Regenerate the committed demo games (~2 min; commit the result)
	@cd Packages/LatticeCore && LATTICE_GEN_DEMO=1 swift test --filter GenerateDemoFixture

##@ Run

.PHONY: run-mac
run-mac: $(SLIPWAY_XCODEPROJ)  ## Build + launch the macOS app
	@Scripts/run.sh

.PHONY: run-iphone
run-iphone: $(SLIPWAY_XCODEPROJ)  ## Build + launch on an iPhone simulator (DEVICE="SE" / "17 Pro" to pick)
	@Scripts/run-ios.sh iphone "$(DEVICE)"

.PHONY: run-ipad
run-ipad: $(SLIPWAY_XCODEPROJ)  ## Build + launch on an iPad simulator (DEVICE="Air" / "13-inch" to pick)
	@Scripts/run-ios.sh ipad "$(DEVICE)"

.PHONY: demo-iphone
demo-iphone:  ## Launch the iPhone simulator in demo mode (seeded data, isolated storage)
	@PLATFORM=iphone Scripts/demo.sh

.PHONY: demo-ipad
demo-ipad:  ## Launch the iPad simulator in demo mode
	@PLATFORM=ipad Scripts/demo.sh

.PHONY: demo-mac
demo-mac:  ## Launch the Mac app in demo mode
	@PLATFORM=mac Scripts/demo.sh

##@ Screenshots
##~ Capture guide, sizes and the shot list: Scripts/asc/SCREENSHOTS.md
##~ Shoot a set: make shots PLATFORM=iphone|ipad|mac → make asc-screenshots → -apply

.PHONY: shots
shots:  ## Guided screenshot capture: PLATFORM=iphone|ipad|mac [OUT=shots] [WITH_NEARBY=1]
	@Scripts/shoot.sh

.PHONY: shots-list
shots-list:  ## Print the shot list and capture order: PLATFORM=iphone|ipad|mac
	@python3 Scripts/asc/organize-shots.py $${PLATFORM:-iphone} --list

.PHONY: shots-organize
shots-organize:  ## Rename raw freehand screenshots by capture order: DIR=<folder> PLATFORM=iphone|ipad|mac
	@python3 Scripts/asc/organize-shots.py $${PLATFORM:-iphone} $(DIR)
