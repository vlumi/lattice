#!/usr/bin/env bash
# Guided App Store screenshot capture. Walks the shot list: launches the demo,
# tells you what to stage, and CAPTURES for you — no ⌘S, no renaming, no file
# shuffling. Output lands canonically named at
#   <OUT>/<platform>/<shot>-<platform>.png
# ready for the ASC upload (make asc-screenshots).
#   PLATFORM=iphone|ipad|mac   (default iphone)
#   OUT=shots                  (default ./shots)
#   WITH_NEARBY=1              include the two-device Nearby shot
# Mac note: window capture needs Screen Recording permission for your terminal
# (System Settings ▸ Privacy) — macOS prompts on first use.
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORM="${PLATFORM:-iphone}"
OUT="${OUT:-shots}"
BUNDLE="fi.misaki.lattice"
APP_NAME="Lattice Five"
LIST_FLAGS=(--plain)
[ -n "${WITH_NEARBY:-}" ] && LIST_FLAGS+=(--with-nearby)

# The devices ASC wants, NOT demo.sh's small fast defaults: a 6.9" iPhone and a
# 13" iPad. Capturing on an SE or an Air yields images ASC refuses, which is
# only discovered at upload — so pin them here and check every shot below.
case "$PLATFORM" in
    iphone) export DEVICE_PATTERN='iPhone 16 Pro Max|iPhone 16 Plus'; EXPECT="1320x2868" ;;
    ipad) export DEVICE_PATTERN='iPad Pro 13-inch'; EXPECT="2064x2752" ;;
    mac) EXPECT="2880x1800|1440x900" ;;
esac

png_size() {  # $1 = file → "WxH"
    python3 -c "
import struct, sys
d = open(sys.argv[1], 'rb').read(33)
w, h = struct.unpack('>II', d[16:24])
print(f'{w}x{h}')" "$1"
}

case "$PLATFORM" in
    mac) make build-mac >/dev/null ;;
    iphone | ipad) make build-ios >/dev/null ;;
    *) echo "PLATFORM must be iphone | ipad | mac" >&2; exit 2 ;;
esac

capture() {  # $1 = output file
    mkdir -p "$(dirname "$1")"
    if [ "$PLATFORM" = mac ]; then
        screencapture -o -x -l"$WINDOW_ID" "$1"
    else
        # By UDID — `booted` grabs an arbitrary device with several sims open.
        # --display=internal silences the "No display specified" note.
        xcrun simctl io "${SIM_UDID:-booted}" screenshot --display=internal "$1" >/dev/null
    fi
}

# Find the app's window by PID, for a clean click-free `screencapture -l`.
mac_window_id() {
    for _ in $(seq 1 15); do
        local pid
        pid=$(pgrep -x "$APP_NAME" | head -1)
        if [ -n "$pid" ]; then
            if id=$(swift Scripts/asc/window-id.swift "$pid" 2>/dev/null); then
                echo "$id"; return 0
            fi
        fi
        sleep 1
    done
    return 1
}

# Quit and WAIT until the process is really gone — an open modal can stall the
# polite quit, and relaunching while the old instance lives makes `open` just
# activate it, silently keeping the previous run's launch args.
quit_app() {
    if [ "$PLATFORM" = mac ]; then
        pgrep -xq "$APP_NAME" || return 0
        osascript -e "tell application id \"$BUNDLE\" to quit" >/dev/null 2>&1 || true
        for _ in $(seq 1 8); do
            pgrep -xq "$APP_NAME" || return 0
            sleep 1
        done
        echo "  (app didn't quit politely — terminating it)"
        killall "$APP_NAME" >/dev/null 2>&1 || true
        sleep 1
        pgrep -xq "$APP_NAME" && { killall -9 "$APP_NAME" || true; sleep 1; }
    else
        xcrun simctl terminate "${SIM_UDID:-booted}" "$BUNDLE" >/dev/null 2>&1 || true
    fi
    return 0
}

total=$(python3 Scripts/asc/organize-shots.py "$PLATFORM" "${LIST_FLAGS[@]}" | wc -l | tr -d ' ')

echo "━━━ $PLATFORM — launching demo ━━━"
quit_app  # a lingering instance would swallow the new launch args
udid_file=$(mktemp)
PLATFORM="$PLATFORM" LATTICE_UDID_FILE="$udid_file" Scripts/demo.sh >/dev/null
if [ "$PLATFORM" = mac ]; then
    WINDOW_ID=$(mac_window_id) || { echo "App window never appeared." >&2; exit 1; }
    sleep 1  # the app pins 1440x900 in demo mode; let that settle
else
    SIM_UDID=$(cat "$udid_file" 2>/dev/null || true)
    sleep 3  # let the launch settle before the first stage prompt
fi
rm -f "$udid_file"

i=0
while IFS=$'\t' read -r name desc; do
    i=$((i + 1))
    file="$OUT/$PLATFORM/${name}-${PLATFORM}.png"
    echo ""
    echo "[$i/$total] $name"
    echo "  $desc"
    printf "  ⏎ capture · s skip · q quit: "
    read -r reply </dev/tty
    [ "$reply" = q ] && { quit_app; exit 0; }
    [ "$reply" = s ] && continue
    while :; do
        capture "$file"
        size=$(png_size "$file")
        if echo "$size" | grep -qE "^($EXPECT)$"; then
            printf "  saved %s (%s) — ⏎ next · r retake: " "$file" "$size"
        else
            # Loudly, and on the FIRST shot: ASC accepts a wrong-sized image and
            # then fails processing, so this would otherwise surface at upload
            # with the whole set to redo.
            printf "  ⚠ %s is %s, expected %s — the upload will refuse it.\n" \
                "$file" "$size" "$EXPECT"
            printf "    ⏎ next anyway · r retake: "
        fi
        read -r again </dev/tty
        [ "$again" = r ] || break
    done
done < <(python3 Scripts/asc/organize-shots.py "$PLATFORM" "${LIST_FLAGS[@]}")

quit_app

echo ""
echo "Done. Set under $OUT/$PLATFORM/ — upload with: make asc-screenshots"
