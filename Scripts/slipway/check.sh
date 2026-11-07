#!/usr/bin/env bash
# Verify Scripts/slipway is exactly the slipway version it records: every file
# in MANIFEST unchanged, and nothing added. A fix belongs upstream in slipway,
# then comes back here with `make slipway-update`.
set -euo pipefail
cd "$(dirname "$0")"

die() { echo "error: $*" >&2; exit 1; }

[ -f MANIFEST ] || die "Scripts/slipway has no MANIFEST — reinstall it with \`make slipway-update\`."
changed="$(shasum -a 256 -c MANIFEST 2>/dev/null | grep -v ': OK$' || true)"
listed="$(awk '{ print $2 }' MANIFEST | LC_ALL=C sort)"
# Finder drops .DS_Store into any folder it shows; that's not an edit.
present="$(find . -type f ! -name MANIFEST ! -name .DS_Store | sed 's#^\./##' | LC_ALL=C sort)"
added="$(comm -13 <(echo "$listed") <(echo "$present"))"

if [ -n "$changed" ] || [ -n "$added" ]; then
    echo "error: Scripts/slipway differs from slipway $(cat VERSION 2>/dev/null || echo '?'):" >&2
    [ -z "$changed" ] || echo "$changed" | sed 's/^/  /' >&2
    [ -z "$added" ] || echo "$added" | sed 's/^/  added: /' >&2
    echo "Make the change in slipway and \`make slipway-update\`, rather than editing the copy." >&2
    exit 1
fi
echo "✓ Scripts/slipway is slipway $(cat VERSION), unmodified."
