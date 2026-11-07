#!/usr/bin/env bash
# Regenerate <name>.xcodeproj from project.yml, after slipway.yml's
# pre_generate (for anything the project must find on disk, like a built
# resource). Every path to a project — make and the release lane — comes
# through here.
#
# Refuses only if this project is open in Xcode: regenerating it under Xcode's
# in-memory model causes a save conflict that can clobber the new file.
set -euo pipefail
. "$(dirname "$0")/common.sh"

if pgrep -x Xcode >/dev/null; then
    open_docs="$(osascript -e 'tell application "Xcode" to get name of documents' 2>/dev/null || true)"
    if printf '%s' "$open_docs" | grep -qF "$SLIPWAY_XCODEPROJ"; then
        die "$SLIPWAY_XCODEPROJ is open in Xcode. Close it before regenerating."
    fi
fi
command -v xcodegen >/dev/null || die "xcodegen not found (brew install xcodegen)."

if [ -n "$SLIPWAY_PRE_GENERATE" ]; then
    bash -c "$SLIPWAY_PRE_GENERATE"
fi
xcodegen generate
echo "Generated $SLIPWAY_XCODEPROJ"
