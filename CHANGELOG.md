# Changelog

All notable changes to Lattice Five are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Grouped by **marketing version** (a roadmap milestone), then by **build
number** within it — the version stays steady while the build climbs each
TestFlight upload. Each version's top section, **Unreleased (next build)**,
collects entries merged to `main` but not yet in a TestFlight build; cutting a
release renames it to that build's heading and opens a fresh empty one. A
user-facing PR writes its own bullet here (see [AGENTS.md](AGENTS.md)).

## [Unreleased]

Pre-code: planning docs only. The first code milestone is **v0.1.0 — the
core, playable** (see [ROADMAP.md](ROADMAP.md)).

### Unreleased (next build)

- Post-game analysis in the replay viewer: the openness curve (legal
  moves per turn) charted under the board, synced to the scrubber — see
  where the position peaked and where it died.
- Replay viewer: open any finished game from History and scrub through
  it — autoplay cascades the whole game (space to play/pause; any manual
  control pauses), plus slider, frame-step and jump-to-end controls
  (arrow keys on Mac), the current move highlighted in accent.
- History tab: finished games as a score-over-time chart (with the
  running best as a step line) and a recent-games list.
- Share card: a finished game exports as an image — the board rendered
  ink-on-paper by the game's own drawing code, plus the score line (and
  the daily's date). Share and Save Image buttons appear beside the
  final score — save writes a PNG wherever you choose.
- Daily challenge: one attempt per local date at the classic 5T cross,
  one undo per move, streak tracking (an unplayed day breaks it, an
  in-progress day doesn't), Free/Daily tabs; the daily attempt and
  results persist alongside the free game.
- Persistence: the game in progress survives quitting (restored on
  launch), every finished game is stored as a full replay record, and
  personal bests are tracked per variant — the best shows in the header.

- Board camera: pinch to zoom (up to 6×, drag to pan, clamped so the
  board can't be lost off-screen), a Fit button (⌘0) to snap back, camera
  reset on new game.
- Playable solitaire: two-stage move input (tap a point → tentative dot +
  dashed candidate lines in the accent colour → tap a line to commit),
  free cancel, unlimited undo, new game, score header, and game-over
  detection. Played lines render monochrome with the last move
  accent-highlighted.
- Board readability: placeable points render as clearly visible pinpoints
  while settled empty points fade out (open-frontier coding, and it
  defuses the scintillating-grid illusion); dots sit on background-colour
  casing rings; collinear candidate lines fan out side by side so
  overlapping options are visually distinct and individually tappable.
- Game engine: move validation for 5T and 5D (segment-reuse and
  disjoint-dot rules, no-free-lines by construction), legal-move
  enumeration, end detection, scoring, and undo — the move stack doubles
  as the replay record.
- Project scaffolding: XcodeGen project (iOS + macOS targets, Universal
  Purchase bundle id), `LatticeCore` package with the grid model (points,
  axes, canonical segments, symmetries, the standard 36-dot cross) and its
  tests, a minimal monochrome board render, pinned lint/format tooling, and
  CI (lint, tests + coverage, both platform builds).
