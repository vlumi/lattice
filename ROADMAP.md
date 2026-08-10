# Roadmap

**Open work only.** Shipped work: high-level in the [README version
history](README.md#version-history), full detail in
[CHANGELOG.md](CHANGELOG.md); settled rules and design decisions in
[AGENTS.md](AGENTS.md). This file is only *what's next* — versions are
indicative, not contractual, and everything before 1.0 is beta (internal
TestFlight; see [RELEASING.md](RELEASING.md)).

**v0.5.0 is in flight** on internal TestFlight. The work below lands as
further 0.5.0 builds before the version bump.

---

## v0.5.0 — remaining

- [ ] Interactive tutorial (teach the segment rule and no-free-lines by
      doing)
- [ ] Accessibility pass: VoiceOver on the board, Dynamic Type in chrome,
      keyboard-only play on Mac/iPad
- [ ] Keyboard-control gaps: much chrome is still mouse-only. Settings
      toggles/field aren't keyboard-operable; audit every screen (History
      list/replay transport, Nearby lobby, game-over actions) for
      keyboard reachability — the New Game modal's arrow-nav is the pattern.
- [ ] Performance/battery sanity pass on the render loop
- [ ] Score ladder: local milestones against the known reference points
      (records/bounds table in AGENTS.md)
- [ ] Solver-generated puzzles ("find N more moves", "find the only move")
      from recorded/simulated games

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
- [ ] Race-mode reach feedback: when you reach the target the board goes
      silently unresponsive (you've placed, others play on). Show a "You
      reached N — waiting for the others" state with live standings so you
      can watch the rest finish. (Board swaps to a "reached" overlay when
      `players[local].status == .placed`; `standingsBar` already has the
      live scores.) Possible mode tweak: everyone races to N, ranked by
      time taken. Needs a real 2-device test to verify the end-condition.
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
