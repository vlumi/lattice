# Lattice Five — agent & contributor guide

A turn-based **Morpion Solitaire** (*Join Five*) puzzle game for Apple
platforms. This file is the canonical guidance for both humans and AI coding
agents. **The repo is at the planning stage — no code exists yet**; this
document describes the intended shape so the first implementation follows it.

Lattice Five is a **separate project** from its sibling
[Donpa Squad](https://github.com/vlumi/donpa) (a Minesweeper game by the same
author). Donpa is the proving ground for most conventions below; where Lattice
reuses an idea it does so by **copying and adapting**, never by sharing a
package (see "Relationship to Donpa").

## The rules (the engine's whole job)

- The board is an integer dot-grid. Play begins from a **fixed starting
  pattern**: a hollow cross (Greek-cross "+") outline of dots, three dots wide.
- A **move** = place one new dot, then draw a straight **line of five dots**
  (four unit segments) along one of the four axes (horizontal, vertical, two
  diagonals). The new dot must be one of the five.
- **Segment-reuse rule** — the defining constraint: no unit segment may be used
  twice *in the same direction*. Two standard variants differ on collinear
  overlap: **5T** (touching allowed — lines may share an endpoint but not a
  segment) vs **5D** (disjoint — collinear lines may not even touch). Pick one
  as the default, offer the other as an option; get this rule and its tests
  exactly right — it *is* the game.
- Play ends when **no legal move remains**; score = lines drawn. A solver that
  can detect "no moves left" (and ideally hint legal moves) is core.

Everything else — deterministic daily puzzle, best-score tracking, two-player
turns — sits on top of this pure, headless-testable core.

## Architecture (intended)

Mirror Donpa's split, scaled down:

- **A pure logic core** (Swift package, e.g. `LatticeCore`) — the board model,
  move validation, the segment-reuse bookkeeping, end detection, scoring.
  **No SwiftUI, no SpriteKit, no I/O** — unit-tested headlessly. This is where
  the real work and nearly all the tests live.
- **A UI layer** (SwiftUI + procedural drawing) — the board rendered with
  Canvas or SpriteKit `SKShapeNode`s (dots + line segments; **no image
  assets**), input handling, the two-player and Nearby flows.
- **Two thin app targets** (iOS, macOS) over a generated `.xcodeproj`.

### Reusable seams to copy-adapt from Donpa

Lift these patterns (copy the *approach*, rewrite for this game — don't
depend on Donpa):

- **Grid / topology** — Donpa's `Topology`/`CellLayout` seam that separates
  neighbour logic from pixel geometry. Lattice's grid is simpler (a sparse dot
  set on an unbounded integer lattice) but the same separation applies.
- **Versioned persistence + best-score tracking** — Donpa's `ScoreRecord` /
  versioned-envelope store with tolerant decode and a migration seam.
- **Deterministic daily seed** — a daily puzzle is natural here (everyone plays
  the same start + rule variant for the day); copy Donpa's stable-hash /
  local-date-key daily pattern.
- **Nearby (MultipeerConnectivity)** — Donpa's two-way swap stack. Turn-based
  play makes this *easier* to reuse: a move is one small message, no realtime
  sync. Reuse the mutual-consent handshake shape.

## Platforms & project facts

- **Platforms:** iOS and macOS (Apple-silicon Macs). Pick concrete floors when
  scaffolding — Donpa uses iOS 16 / macOS 14; match unless a needed API forces
  higher.
- **Toolchain:** Xcode + Swift 6, **XcodeGen** (the `.xcodeproj` is a generated
  artifact — gitignored, never edited or committed; signing/team live only in
  that local file, never in `project.yml`).
- **Bundle id:** `fi.misaki.lattice` (planned). **Name reserved in ASC:**
  "Lattice Five". **SKU:** `lattice`. **Universal Purchase from the start** —
  ONE App Store record spanning both platforms (do NOT create separate
  per-platform records; that was a corrected mistake on Donpa). **License:**
  MIT. No monetization.

## Localization

**English-only for now** — but build the String Catalog infrastructure from
day one: every user-facing string goes through `Text(_, bundle:)` /
`String(localized:)`, never a hardcoded literal. Ship with only the `en`
localization populated. Adding Finnish/Japanese later is then pure translation,
not a refactor. Conventions carried from Donpa: **Xcode's serialized
`.xcstrings` form is canonical** (normalize after any scripted edit so opening
the project produces no churn); localize the **concept**, not the word, when
translations do arrive.

## Conventions (carried from Donpa)

- **Comments minimal** — explain only what isn't obvious from the code; no
  roadmap/history narration in source (that goes in commit messages).
- **Determinism for tests** — inject any randomness (`RandomNumberGenerator`)
  so puzzle generation and solver behaviour are reproducible headlessly.
- **swift-format is the authority on whitespace/punctuation**; where SwiftLint
  conflicts, disable the SwiftLint rule rather than fight it. Run both
  `--strict` before committing. **Pin the SwiftLint version** in CI (an
  unpinned install follows latest and can redden CI on untouched code);
  swift-format ships with the pinned Xcode toolchain.
- **`.vscode/` is gitignored** and must not be pushed.

## Pull requests & CI (carried from Donpa)

- Branch off `main`, one focused change per PR.
- **Commit trailer:** end commit messages with
  `Co-Authored-By: <model> <noreply@anthropic.com>`.
- **A user-facing PR writes its own CHANGELOG bullet** under an `## [Unreleased]`
  → `### Unreleased (next build)` section; the release process stamps the build
  number, it doesn't write entries.
- **CI must stay green** — SwiftLint + swift-format (both `--strict`), the logic
  tests (with coverage), and both platform builds. **Wait for coverage
  (Codecov) before merging** if it's reported but not a required check.
- **Coverage-ignore the untestable view layer** (the SwiftUI/procedural-drawing
  target) and the device-only cloud wrappers; keep testable logic in the pure
  core so it's tracked.

## Deliberately out of scope

No ads, no microtransactions, no accounts, no server, no global leaderboards.
No third-party runtime dependencies. Nearby play is peer-to-peer on the local
network only. Cross-device sync (if added) rides the user's own iCloud KVS,
mirroring Donpa.
