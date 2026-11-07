#!/usr/bin/env bash
# Run the core package's logic tests — no Xcode project needed.
set -euo pipefail
. "$(dirname "$0")/common.sh"

say "Running ${SLIPWAY_CORE} tests…"
swift test --package-path "Packages/${SLIPWAY_CORE}"
