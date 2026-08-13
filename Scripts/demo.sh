#!/usr/bin/env bash
# Launch Lattice in DEMO mode for App Store screenshots: seeded history, bests
# and a live daily streak, in isolated storage.
#
#   -demo-clean routes persistence to a temp dir and forces sync OFF, so a demo
#   run can never touch the real player's data. The debug build shares the
#   shipped app's bundle id — and container — so this is not optional.
#   -demo-seed fills that clean store from the committed fixture.
#
#   PLATFORM=iphone|ipad|mac   which target   (default iphone)
#
# Screenshot sizes and the shot list live in Scripts/asc/SCREENSHOTS.md.
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORM="${PLATFORM:-iphone}"
BUNDLE="fi.misaki.lattice"
ARGS=(-demo-clean -demo-seed)

pick_udid() {  # $1 = name pattern
    xcrun simctl list devices available | grep -E "$1" \
        | grep -oE "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}" | tail -1
}

case "$PLATFORM" in
    mac)
        make build-mac
        app=".build-xcode/Build/Products/Debug/Lattice Five.app"
        [ -d "$app" ] || { echo "Build missing: $app" >&2; exit 1; }
        # `open --args` doesn't reach a running instance; make sure it's not.
        osascript -e 'quit app "Lattice Five"' 2>/dev/null || true
        open -n "$app" --args "${ARGS[@]}"
        ;;
    iphone | ipad)
        pattern='iPhone 16e|iPhone SE'
        [ "$PLATFORM" = ipad ] && pattern='iPad Pro|iPad Air'
        udid="$(pick_udid "$pattern")"
        [ -n "$udid" ] || { echo "No $PLATFORM simulator found." >&2; exit 1; }
        make build-ios
        xcrun simctl boot "$udid" 2>/dev/null || true
        open -a Simulator --args -CurrentDeviceUDID "$udid"
        app="$(find .build-xcode/Build/Products/Debug-iphonesimulator \
            -maxdepth 1 -name 'Lattice Five.app' | head -1)"
        [ -n "$app" ] || { echo "Build missing." >&2; exit 1; }
        xcrun simctl install "$udid" "$app"
        xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
        xcrun simctl launch "$udid" "$BUNDLE" "${ARGS[@]}"
        echo "Screenshot with: xcrun simctl io $udid screenshot shot.png"
        ;;
    *)
        echo "PLATFORM must be iphone | ipad | mac (got '$PLATFORM')" >&2
        exit 2
        ;;
esac
