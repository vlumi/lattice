#!/usr/bin/env bash
# Run the App Store Connect tooling in a self-managed venv, so the
# Makefile targets are one step. Bootstraps the venv on first use and refreshes
# it only when requirements.txt changes (a stamp file guards the reinstall).
#
# Usage: run.sh status
#        run.sh sync [-- <extra args passed to sync.py, e.g. --apply --images>]
set -euo pipefail
cd "$(dirname "$0")"

VENV="${LATTICE_ASC_VENV:-$HOME/.venvs/lattice-asc}"
PY="$VENV/bin/python"
STAMP="$VENV/.requirements-stamp"

# Homebrew's Python is externally-managed; a venv is the correct install target.
if [ ! -x "$PY" ]; then
    echo "▶︎ Creating venv at $VENV …"
    python3 -m venv "$VENV"
fi
# (Re)install deps when requirements.txt is newer than the last install.
if [ ! -f "$STAMP" ] || [ requirements.txt -nt "$STAMP" ]; then
    echo "▶︎ Installing dependencies …"
    "$VENV/bin/pip" install --quiet --upgrade pip
    "$VENV/bin/pip" install --quiet -r requirements.txt
    touch "$STAMP"
fi

cmd="${1:-listing}"
shift || true
case "$cmd" in
    listing) exec "$PY" listing.py "$@" ;;
    # Donpa's achievement/screenshot-upload scripts aren't copied: Lattice has no
    # Game Center, and screenshots are captured by hand per SCREENSHOTS.md.
    *) echo "usage: run.sh listing [args]" >&2; exit 2 ;;
esac
