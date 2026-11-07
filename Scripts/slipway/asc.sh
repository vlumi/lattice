#!/usr/bin/env bash
# The App Store Connect sync, from the project root: the listing text from
# Scripts/asc/listing.json, the screenshots from the shots/ capture tree in the
# store order Scripts/asc/shots.json gives. Dry runs unless --apply.
#
# Usage: asc.sh listing [--apply]
#        asc.sh screens [--apply] [--all] [--dir <tree>]
#
# The Python runs in a venv of its own, shared by every project (Homebrew's
# Python is externally managed), made on first use and reinstalled when
# asc-requirements.txt changes.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
venv="${SLIPWAY_ASC_VENV:-$HOME/.venvs/slipway-asc}"
py="$venv/bin/python"

if [ ! -x "$py" ]; then
    echo "▶︎ Creating the App Store Connect venv at $venv …"
    python3 -m venv "$venv"
fi
if ! cmp -s "$here/asc-requirements.txt" "$venv/.slipway-requirements"; then
    echo "▶︎ Installing its dependencies …"
    "$venv/bin/pip" install --quiet --upgrade pip
    "$venv/bin/pip" install --quiet -r "$here/asc-requirements.txt"
    cp "$here/asc-requirements.txt" "$venv/.slipway-requirements"
fi

# No __pycache__ in the copy: check.sh would count it as an edit.
export PYTHONDONTWRITEBYTECODE=1
cmd="${1:-}"
shift || true
case "$cmd" in
    listing) exec "$py" "$here/asc_listing.py" "$@" ;;
    screens) exec "$py" "$here/asc_screenshots.py" "$@" ;;
    *) echo "usage: asc.sh {listing|screens} [--apply] …" >&2; exit 2 ;;
esac
