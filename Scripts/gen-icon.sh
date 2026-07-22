#!/usr/bin/env bash
# Regenerate the app icon from the game's own drawing code (IconArt) into
# the shared asset catalog. Deterministic — reruns are byte-stable.
set -euo pipefail
cd "$(dirname "$0")/.."

out="$(mktemp -d)"
LATTICE_ICON_OUT="$out" swift test --package-path Packages/LatticeCore \
    --filter IconRender/testRenderIconAssets >/dev/null

dest="Sources/Shared/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$dest"
rm -f "$dest"/*.png
cp "$out"/icon-light.png "$out"/icon-dark.png "$out"/icon-tinted.png "$dest/"
# macOS slots want distinct filenames per entry.
cp "$out/mac-16.png"   "$dest/mac-16.png"
cp "$out/mac-32.png"   "$dest/mac-16@2x.png"
cp "$out/mac-32.png"   "$dest/mac-32.png"
cp "$out/mac-64.png"   "$dest/mac-32@2x.png"
cp "$out/mac-128.png"  "$dest/mac-128.png"
cp "$out/mac-256.png"  "$dest/mac-128@2x.png"
cp "$out/mac-256.png"  "$dest/mac-256.png"
cp "$out/mac-512.png"  "$dest/mac-256@2x.png"
cp "$out/mac-512.png"  "$dest/mac-512.png"
cp "$out/mac-1024.png" "$dest/mac-512@2x.png"
rm -rf "$out"
echo "Icon assets regenerated into $dest"
