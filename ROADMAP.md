# Roadmap

The implementation plan, in milestone order. Versions are indicative, not
contractual; everything before 1.0 is beta by definition (TestFlight from
v0.1). As milestones ship, their detail moves to `CHANGELOG.md` and this file
keeps only open work. Settled rules, conventions, and design decisions live
in [AGENTS.md](AGENTS.md); this file is only *when*, not *why*.

Guiding order: **the engine is the game** — the rules core and its tests come
first and stay ahead of every feature that consumes them. The daily puzzle is
the retention core, so it lands right after the game is playable. Replays are
recorded from the first playable build even though the viewer comes later —
that data cannot be retrofitted.

---

## v0.1.0 — The core, playable

The pure engine, correct and fully tested, plus the minimum UI that makes it
a game on both platforms.

**Scaffolding:**

- [ ] XcodeGen `project.yml`: `LatticeCore` package +
      `Sources/{iOS,macOS,Shared}`, two thin app targets, shared bundle id
      `fi.misaki.lattice` (Universal Purchase), the gotcha list from
      AGENTS.md applied (orientations, `-games` category, scheme block, …)
- [ ] CI: pinned SwiftLint + swift-format (both `--strict`), `swift test`
      with coverage (view layer coverage-ignored), both platform builds
- [ ] String Catalog in place; every user-facing string localized from the
      first commit (English-only content)

**`LatticeCore` (where nearly all v0.1 work and tests live):**

- [ ] `Point`/`Axis`, canonical segment keys, sparse board, the
      `[-5, 4]²` cross, eight symmetries + invariance tests
- [ ] Move validation for **5T and 5D** (default 5T; the variant flag exists
      from day one even if the UI exposes it later) — exhaustive rule tests:
      consecutive-five, new-dot-in-line, no-free-lines, collinear
      touch/disjoint cases
- [ ] Legal-move enumeration → end detection, scoring, the
      lines-drawn == dots-placed invariant
- [ ] Undo (full move stack) and **replay recording** as the same structure
- [ ] Content bounding box, maintained incrementally

**UI (both platforms):**

- [ ] Canvas board render: monochrome + single accent, light/dark
- [ ] Two-stage input (tentative dot → candidate ghosts → commit), free
      cancel; the input matrix from AGENTS.md (touch, hover, Esc, ⌘Z)
- [ ] Clamped pan/zoom camera + auto-fit
- [ ] Free solitaire with unlimited undo; game-over → score + new game

**Exit criteria:** a complete 5T game playable start-to-finish on iPhone,
iPad, and Mac; core coverage high; CI green; on TestFlight.

## v0.2.0 — Daily + persistence

- [ ] Versioned persistence envelope (tolerant decode, migration seam) for:
      personal bests, full game replays, settings
- [ ] **Daily puzzle**: deterministic local-date seed, one attempt rule
      (one undo per move), streaks + results calendar
- [ ] **Share card**: score + small procedural board render, exported as an
      image; same drawing code as the game
- [ ] **Score ladder**: local milestones against the known reference points
      (records/bounds table in AGENTS.md)
- [ ] Personal-best history (list + simple graph)

## v0.3.0 — Replay & analysis

- [x] Replay viewer (step/scrub/autoplay through any stored game)
- [x] Personal-best **ghost** — implemented as a pace race: the PB game's
      openness curve dimmed under the live game's (a board overlay of a
      second game's dots would fight the visual identity)
- [x] Post-game analysis: legal-move count per turn ("where the position
      died"), charted in the replay viewer and scrubbable
- [ ] Sacrificed-line markers (placements that enabled two lines) —
      deferred from the analysis slice

## v0.4.0 — Variants & seeded starts

- [ ] Variant picker: **5D**, **4T/4D** (smaller cross; "find the perfect
      62/35" completion goals), **5T+** casual ruleset
- [ ] **Seeded random symmetric starts** (the 5T#/5D# form): generator +
      solver-validated playability, seed code as shareable challenge
      (URL/QR — encode variant + start; no server)
- [ ] Per-variant bests and daily-eligible variant rotation (decide: daily
      stays classic-5T-only, or rotates — record the decision in AGENTS.md)

## v0.5.0 — Two-player

- [ ] **Pass-and-play**: alternate moves, last player able to move wins
- [ ] **Nearby** (MultipeerConnectivity, iOS ↔ macOS): mutual-consent
      handshake, one small message per move, consent-based undo
- [ ] **Same-seed duel**: both play the same start solo, higher score wins —
      pass-and-play and Nearby
- [ ] Local network privacy strings + Bonjour service declarations

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

## v1.0.0 — The store release

- [ ] App icon generated from game renders — lines whose negative space
      forms a "5" — light/dark/tinted variants
- [ ] One ASC record (Universal Purchase), listing text + screenshots,
      privacy questionnaire (nothing collected)
- [ ] Release lane (versioning lock-step, archive + upload both platforms)
      and `RELEASING.md`
- [ ] Submit, await review, release

## Backlog (unversioned)

- [ ] Cross-device sync of bests/streaks via the user's iCloud KVS
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
