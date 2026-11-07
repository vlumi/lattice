#!/usr/bin/env bash
# Replace Scripts/slipway with another slipway version: a release tag fetched
# from GitHub, or a local checkout as it stands (for trying a slipway change in
# a project before releasing it).
#
# Usage: update.sh <vX.Y.Z> | update.sh "" <slipway-checkout>
set -euo pipefail
cd "$(dirname "$0")/../.."

die() { echo "error: $*" >&2; exit 1; }

version="${1:-}"
src="${2:-}"
repo="${SLIPWAY_REPO:-https://github.com/vlumi/slipway.git}"

if [ -n "$src" ]; then
    [ -x "$src/install.sh" ] || die "$src is not a slipway checkout (no install.sh)."
    "$src/install.sh" "$(pwd)"
    exit 0
fi

[ -n "$version" ] || die "say which version: make slipway-update V=vX.Y.Z (or SLIPWAY_SRC=<checkout>)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# A shallow clone of a tag talks even with --quiet (detached HEAD, "not a
# commit" for an annotated tag); keep that for when it actually failed.
if ! out="$(git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$version" "$repo" "$tmp/slipway" 2>&1)"; then
    echo "$out" >&2
    die "couldn't fetch slipway $version from $repo"
fi
"$tmp/slipway/install.sh" "$(pwd)" "$version"
