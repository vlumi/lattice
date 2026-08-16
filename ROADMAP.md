# Roadmap

**Open work only.** Shipped work: high-level in the [README version
history](README.md#version-history), full detail in
[CHANGELOG.md](CHANGELOG.md); settled rules and design decisions in
[AGENTS.md](AGENTS.md). This file is only *what's next* — versions are
indicative, not contractual, and everything before 1.0 is beta (internal
TestFlight; see [RELEASING.md](RELEASING.md)).

**v1.0.0 is submitted for review.** The game is feature-complete and store prep
is done; what's left is Apple's verdict.

---

## v1.0.0 — The store release

- [ ] Await App Store review, then release (spends the 1.0.0 version).
      Build 12 is selected for both platforms, with the listing, privacy
      questionnaire, category (**Games → Puzzle**, second subcategory
      **Board**), 21 screenshots and the review notes all in place. A build can
      still be added while the version is in review — the version is only spent
      once it's approved and released.

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
