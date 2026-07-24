# Roadmap

**Open work only.** Shipped work: high-level in the [README version
history](README.md#version-history), full detail in
[CHANGELOG.md](CHANGELOG.md); settled rules and design decisions in
[AGENTS.md](AGENTS.md). This file is only *what's next* — versions are
indicative, not contractual, and everything before 1.0 is beta (internal
TestFlight; see [RELEASING.md](RELEASING.md)).

**v0.5.0 has shipped** (two-player, iCloud sync, Nearby duel, first
TestFlight). Next up is v0.6.0.

---

## v0.6.0 — Puzzle mode & polish

- [ ] Solver-generated puzzles ("find N more moves", "find the only move")
      from recorded/simulated games
- [ ] Interactive tutorial (teach the segment rule and no-free-lines by
      doing)
- [ ] Accessibility pass: VoiceOver on the board, Dynamic Type in chrome,
      keyboard-only play on Mac/iPad
- [ ] Performance/battery sanity pass on the render loop
- [ ] Revisit the replay slider: the analysis chart scrubs too — drop the
      slider near release if it feels redundant (deferred 2026-07-21)
- [ ] Sacrificed-line markers (placements that enabled two lines) — deferred
      from the v0.3 analysis slice
- [ ] Score ladder: local milestones against the known reference points
      (records/bounds table in AGENTS.md) — deferred from v0.2

## Open decisions

- [ ] **Daily variant rotation**: daily currently stays classic-5T (varied
      start per date). Decide whether it rotates variants; record in AGENTS.md.

## v1.0.0 — The store release

- [ ] One ASC record (Universal Purchase), listing text + screenshots,
      privacy questionnaire (nothing collected)
- [ ] Submit to public App Store review, release (spends the 1.0.0 version)

ASC tooling: Donpa's `asc-listing*` + `asc-screenshots*` Makefile targets
(over `Scripts/asc/`: `run.sh`, `listing.py`, `screenshots.py`,
`organize-shots.py`, `listing.json`, `shots/`) are the copy-wholesale
source for this slice — bring them over when store prep starts, adapting
only the per-app listing/shots data. Skip `asc-achievements*` unless
Lattice ever adds Game Center (it has none, and none is planned).

## Backlog (unversioned)

- [ ] Nearby duel follow-ups: rematch / back-to-lobby (Close currently
      tears the match down); record each player's own duel game as a
      GameRecord (a duel currently leaves no history).
- [ ] Reset progress: per-pool and full reset behind destructive
      confirmations — arrives with a Settings surface (shared with the sync
      toggle above)
- [ ] Finnish/Japanese localization (String Catalog makes this
      translation-only)
- [ ] Game-controller support for board navigation
- [ ] Widget: today's daily status / current streak
- [ ] 5T++ as a curiosity ("borrowed dots") — only if variants prove popular

## Deliberately out of scope

Per [AGENTS.md](AGENTS.md): no ads, no IAP, no accounts, no server, no
global leaderboards, no third-party runtime dependencies. No anti-cheat —
scores are local and personal, which is *why* global leaderboards stay out.
watchOS/visionOS/tvOS not targeted; the SwiftUI core keeps doors open.
