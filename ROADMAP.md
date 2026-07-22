# Roadmap

**Open work only.** Shipped milestones live in [CHANGELOG.md](CHANGELOG.md);
settled rules and design decisions in [AGENTS.md](AGENTS.md). This file is
only *what's next* — versions are indicative, not contractual, and everything
before 1.0 is beta (internal TestFlight; see [RELEASING.md](RELEASING.md)).

**Shipped so far** (detail in the changelog): v0.1 core engine + playable
solitaire · v0.2 persistence, daily, share card, history · v0.3 replay
viewer, analysis, PB ghost · v0.4 variants (5T/5D/4T/4D/5T+), seeded starts,
challenge codes/links/QR · v0.5 pass-and-play, app icon, release lane.

---

## v0.5.0 — Two-player + first TestFlight

Suggested build sequence: **build 1** cuts as-is to validate the release
pipeline (signing, ASC record, TestFlight processing) with the smallest
surface — no sync. Then the slices below land in later 0.5.0 builds.

- [ ] **Nearby** (MultipeerConnectivity, iOS ↔ macOS): mutual-consent
      handshake, one small message per move, consent-based undo
- [ ] **Same-seed duel**: both play the same start solo, higher score wins —
      pass-and-play and Nearby
- [ ] Local network privacy strings + Bonjour service declarations
- [ ] **iCloud KVS sync** — pulled into 0.5.0 (was backlog) so the cloud blob
      schema lands before any user data exists, while it's cheap to shape.
      NOT in build 1 — it's the one feature needing two real devices to
      verify, so it ships as its own build after the pipeline is proven.
      - Payload: `BestScores` + the full `DailyLog` (bests + day-set —
        ~tens of KB, decades from the 1 MB per-app cap; replays stay local).
      - Shape: one Codable blob per key (not key-per-record — dodges the
        1024-key limit). Merge = union the day-sets + max the bests;
        streak/longest fall out (see AGENTS.md "Daily variety").
      - Seam: copy-adapt Donpa's `Ubiquitous*Store` — protocol + fake for
        tests, opt-in toggle (off by default), needs a Settings surface.

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

## Backlog (unversioned)

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
