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

Feature-complete; what remains is store prep (below).


## v1.0.0 — The store release

- [ ] One ASC record (Universal Purchase), the privacy questionnaire
      (nothing collected), and the screenshots themselves. The *plumbing* is
      in: `Scripts/asc/listing.json` + `make asc-listing[-apply]` for the text,
      `make demo-iphone|demo-ipad|demo-mac` for a seeded demo build, and
      `Scripts/asc/SCREENSHOTS.md` for the shot list and sizes.
- [ ] Submit to public App Store review, release (spends the 1.0.0 version)

ASC tooling: Donpa's `asc-listing*` + `asc-screenshots*` Makefile targets
(over `Scripts/asc/`: `run.sh`, `listing.py`, `screenshots.py`,
`organize-shots.py`, `listing.json`, `shots/`) are the copy-wholesale
source for this slice — bring them over when store prep starts, adapting
only the per-app listing/shots data. Skip `asc-achievements*` unless
Lattice ever adds Game Center (it has none, and none is planned).

## Backlog (unversioned)

- [ ] **Share the daily's board as a code**, so a board you liked can be
      replayed properly. Works in principle — the daily already generates a
      seeded 36-dot start and scores into `5T#`, so it's the same kind of board
      a challenge code carries. Two things to settle first:
      - **Only after the day's attempt is finished.** The daily's one-attempt,
        one-undo-per-move rules are what make the shared board comparable;
        handing over the code up front lets you practise in Free with unlimited
        undo and then take the "one attempt". Nothing gets corrupted (same pool
        either way) but the constraint dissolves. Offering it at the result
        screen keeps it and reads as a reward.
      - **The code would be 13 characters** (e.g. `FCEAEAVWWTN6W`) against 6 for
        a normal challenge: the daily seed is a full 64-bit FNV-1a of the date
        key, while `SeedCode.randomSeed()` stays under 30 bits to keep codes
        short. Either derive the daily's start from a 30-bit seed (changes every
        past daily board — fine before release, not after) or accept long codes
        for daily shares only.

- [ ] **Share the daily's board as a code**, so a board you liked can be
      replayed properly. Works in principle — the daily already generates a
      seeded 36-dot start and scores into `5T#`, so it's the same kind of board
      a challenge code carries. Two things to settle first:
      - **Only after the day's attempt is finished.** The daily's one-attempt,
        one-undo-per-move rules are what make the shared board comparable;
        handing over the code up front lets you practise in Free with unlimited
        undo and then take the "one attempt". Nothing gets corrupted (same pool
        either way) but the constraint dissolves. Offering it at the result
        screen keeps it and reads as a reward.
      - **The code would be 13 characters** (e.g. `FCEAEAVWWTN6W`) against 6 for
        a normal challenge: the daily seed is a full 64-bit FNV-1a of the date
        key, while `SeedCode.randomSeed()` stays under 30 bits to keep codes
        short. Either derive the daily's start from a 30-bit seed (changes every
        past daily board — fine before release, not after) or accept long codes
        for daily shares only.

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
