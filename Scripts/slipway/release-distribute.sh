#!/usr/bin/env bash
# Release step 4 (pure): regenerate the project from the checked-out tree, then
# archive, export and (unless --no-upload) upload each platform in scope via
# distribute.sh. Builds straight from the checked-out base, which is the tagged
# merge commit after the previous step.
#
# Usage: release-distribute.sh <all|ios|macos> [--no-upload|--upload-only] [--require-tag]
#   --no-upload:   archive/export only, skip the App Store Connect upload
#   --upload-only: upload the package already in dist/ (no regen, no rebuild)
#   --require-tag: refuse unless project.yml's version+build is already tagged
#                  (the standalone retry: only re-distribute a real release)
set -euo pipefail
. "$(dirname "$0")/release-lib.sh"

scope="${1:-}"
plats="$(release_scope "$scope")"
shift || true
mode=full
require_tag=0
while [ $# -gt 0 ]; do
    case "$1" in
        --no-upload) mode=no-upload ;;
        --upload-only) mode=upload-only ;;
        --require-tag) require_tag=1 ;;
        *) die "unknown argument '$1'" ;;
    esac
    shift
done

if [ "$require_tag" -eq 1 ]; then
    sync_tags
    version="$(read_unique MARKETING_VERSION)"
    build="$(read_unique CURRENT_PROJECT_VERSION)"
    for p in $plats; do
        tag_exists "$p" "$version" "$build" \
            || die "no $(tag_name "$p" "$version" "$build") tag — nothing tagged to re-distribute. Run \`make release\` for a fresh cut."
    done
    echo "✓ tag(s) for v${version}-${build} present — re-distributing."
fi

[ "$mode" = upload-only ] || "$SLIPWAY_DIR/generate.sh" >/dev/null

say "Distributing…"
for p in $plats; do
    case "$mode" in
        full) "$SLIPWAY_DIR/distribute.sh" "$p" ;;
        no-upload) "$SLIPWAY_DIR/distribute.sh" "$p" --no-upload ;;
        upload-only) "$SLIPWAY_DIR/distribute.sh" "$p" --upload-only ;;
    esac
done

echo
case "$mode" in
    full) echo "✓ distributed (${scope}) — uploaded to App Store Connect." ;;
    no-upload) echo "✓ built (${scope}) — packages in dist/ (upload skipped)." ;;
    upload-only) echo "✓ uploaded (${scope}) — existing dist/ packages sent to App Store Connect." ;;
esac
