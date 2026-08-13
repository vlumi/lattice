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
- [ ] Dynamic Type pass. Structurally already there — every font is a semantic
      text style, no hard-coded `.system(size:)` — so this is testing at
      accessibility sizes and fixing layout. Known suspects: the header's
      `.fixedSize()` (already tight on iPhone SE, has a `ViewThatFits`
      fallback) and History's `.frame(width: 64)` label and fixed-height
      chart.
- [ ] Cursor feedback: a distinct sound + haptic per cursor state while
      roaming with the keyboard — **placeable** / **occupied by a dot** /
      **empty**. Pitch for sound, impact intensity for haptics; a fourth
      `Feedback.cursorMoved(state:)` beside `selectChanged`/`committed`,
      reusing both existing toggles. Ambient feedback, deliberately NOT
      spoken announcements: it has to keep up with held-down arrow keys, and
      it serves the sighted keyboard player as much as anyone.
- [x] Performance/battery sanity pass on the render loop — measured, no
      problem at these board sizes (dead-gap scan 0.05ms at 58 moves, ~420
      canvas fills/frame). Cached `deadGaps`, de-duplicated an `isPlaceable`
      call, and back-stopped Nearby teardown with a `deinit`. Timers,
      observers and the gesture path audited clean. Not traced on device —
      deliberately: with ~3 orders of magnitude of frame-budget headroom
      there's no symptom to chase. Revisit only if one shows up.

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

- [ ] Reset progress: per-pool and full reset behind destructive
      confirmations. The Settings surface it was waiting on now exists.
      **Must clear the cloud blob too, not just local:** the sync merge is
      commutative (max of bests, union of daily days), so a local-only wipe
      is silently undone by the next reconcile — the old bests come back from
      iCloud. Either reset both sides, or state plainly in the UI that it's
      this-device-only.
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
