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

# shellcheck source=Scripts/simulator.sh
. Scripts/simulator.sh

# $1 = name pattern. The newest runtime first, and only DEMO_RUNTIME's (a
# prefix like iOS-26) when that is set.
candidate_udids() {
    xcrun simctl list devices available -j | PATTERN="$1" RUNTIME="${DEMO_RUNTIME:-}" python3 -c '
import json, os, re, sys
pattern, runtime_prefix = re.compile(os.environ["PATTERN"]), os.environ["RUNTIME"]
found = []
for runtime, devices in json.load(sys.stdin)["devices"].items():
    name = runtime.split(".")[-1]  # iOS-26-5
    version = re.search(r"-(\d+)-(\d+)$", name)
    if not version or not name.startswith(runtime_prefix):
        continue
    for device in devices:
        if pattern.search(device["name"]):
            found.append(((int(version[1]), int(version[2])), device["udid"]))
for _, udid in sorted(found, reverse=True):
    print(udid)
'
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
        # Small, fast simulators by default — a dev demo doesn't need a 13" iPad.
        # DEVICE_PATTERN overrides it; Scripts/shoot.sh pins the store sizes,
        # which these deliberately are NOT (see Scripts/asc/SCREENSHOTS.md).
        pattern='iPhone 16e|iPhone SE'
        [ "$PLATFORM" = ipad ] && pattern='iPad Pro|iPad Air'
        [ -n "${DEVICE_PATTERN:-}" ] && pattern="$DEVICE_PATTERN"
        candidates="$(candidate_udids "$pattern")"
        [ -n "$candidates" ] || { echo "No $PLATFORM simulator found." >&2; exit 1; }
        make build-ios
        # shellcheck disable=SC2086  # one udid per word
        udid="$(boot_first_simulator $candidates)" || { echo "No $PLATFORM simulator would boot." >&2; exit 1; }
        # Shown where there is a Simulator.app to show it in; Xcode 27 has none
        # (its devices live in DeviceHub), and the demo runs headless just as well.
        open -g -a Simulator --args -CurrentDeviceUDID "$udid" 2>/dev/null || true
        app="$(find .build-xcode/Build/Products/Debug-iphonesimulator \
            -maxdepth 1 -name 'Lattice Five.app' | head -1)"
        [ -n "$app" ] || { echo "Build missing." >&2; exit 1; }
        xcrun simctl install "$udid" "$app"
        xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
        xcrun simctl launch "$udid" "$BUNDLE" "${ARGS[@]}"
        # So a caller (Scripts/shoot.sh) can capture from THIS device rather
        # than `booted`, which picks arbitrarily with several sims open.
        [ -n "${LATTICE_UDID_FILE:-}" ] && echo "$udid" > "$LATTICE_UDID_FILE"
        echo "Screenshot with: xcrun simctl io $udid screenshot shot.png"
        ;;
    *)
        echo "PLATFORM must be iphone | ipad | mac (got '$PLATFORM')" >&2
        exit 2
        ;;
esac
