#!/usr/bin/env bash
# Release step 1 (pure): refuse to start unless we're on a clean release base
# (main, or a release/X.Y.x version line — see release_base) matching origin,
# with the tools the lane needs — so the commit we tag and build is exactly what
# reviewers saw. Mutates nothing but the local tag mirror; safe to run anytime.
set -euo pipefail
. "$(dirname "$0")/release-lib.sh"

command -v gh >/dev/null || die "gh CLI not found (needed to open + auto-merge the PR)."
command -v xcodegen >/dev/null || die "xcodegen not found (brew install xcodegen)."
[ -z "$(git status --porcelain)" ] || die "working tree not clean — commit or stash first."

# App Store Connect silently drops an icon with an alpha channel (it just never
# shows up), so guard the release against a transparent one.
if [ -n "$SLIPWAY_APP_ICON" ]; then
    [ -f "$SLIPWAY_APP_ICON" ] || die "app icon not found at $SLIPWAY_APP_ICON (slipway.yml app_icon)."
    if sips -g hasAlpha "$SLIPWAY_APP_ICON" 2>/dev/null | grep -q "hasAlpha: yes"; then
        die "app icon has an alpha channel — App Store Connect will reject it: $SLIPWAY_APP_ICON"
    fi
fi

base="$(release_base)"
say "Fetching origin…"
git fetch --quiet origin "$base"
sync_tags
[ "$(git rev-parse HEAD)" = "$(git rev-parse "origin/$base")" ] \
    || die "local ${base} differs from origin/${base} — pull/push to sync first."
echo "✓ preflight: on a clean ${base} matching origin."
