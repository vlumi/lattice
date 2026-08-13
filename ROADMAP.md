# Roadmap

**Open work only.** Shipped work: high-level in the [README version
history](README.md#version-history), full detail in
[CHANGELOG.md](CHANGELOG.md); settled rules and design decisions in
[AGENTS.md](AGENTS.md). This file is only *what's next* — versions are
indicative, not contractual, and everything before 1.0 is beta (internal
TestFlight; see [RELEASING.md](RELEASING.md)).

**v0.5.0 is in flight** on internal TestFlight. Everything still open lands as
further 0.5.0 builds; after that it's store prep, so 0.5.0 is effectively the
last feature milestone before 1.0.

---

## v0.5.0 — remaining

- [ ] In-the-moment teaching: the rejected-placement feedback already flagged
      as a TODO in `BoardView.handleTap` ("Rejected in place; a shake/haptic is
      later polish") — a shake plus a one-line reason teaches at the exact
      moment of confusion, which beats any up-front page.

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
