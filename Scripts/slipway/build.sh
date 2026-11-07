#!/usr/bin/env bash
# Build one platform's app unsigned: iOS and watchOS for the simulator, macOS
# natively. Assumes the project is generated (slipway.mk sees to that).
#
# Usage: build.sh <ios|macos|watchos>
set -euo pipefail
. "$(dirname "$0")/common.sh"

platform="${1:-}"
case " $SLIPWAY_PLATFORMS " in
    *" ${platform:-none} "*) ;;
    *) die "usage: build.sh <$(echo "$SLIPWAY_PLATFORMS" | tr ' ' '|')>" ;;
esac
case "$platform" in
    ios) destination="generic/platform=iOS Simulator" ;;
    macos) destination="generic/platform=macOS" ;;
    watchos) destination="generic/platform=watchOS Simulator" ;;
esac
scheme="$(plat_scheme "$platform")"

build() {
    xcodebuild -project "$SLIPWAY_XCODEPROJ" -scheme "$scheme" \
        -destination "$destination" -derivedDataPath .build-xcode \
        CODE_SIGNING_ALLOWED=NO build
}

say "Building ${scheme}…"
if command -v xcbeautify >/dev/null; then
    build | xcbeautify
else
    build
fi
