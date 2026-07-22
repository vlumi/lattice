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
	@xcodegen generate

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
