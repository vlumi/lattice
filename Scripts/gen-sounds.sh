#!/usr/bin/env bash
# Regenerate the game's sound effects from the synth script into the LatticeKit
# resource bundle. Deterministic — reruns are byte-stable, so the CAFs are
# committed like the icon assets. See Scripts/make-sounds.swift.
set -euo pipefail
cd "$(dirname "$0")/.."

swift Scripts/make-sounds.swift
