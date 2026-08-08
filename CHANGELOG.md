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

## [0.5.0]

The first TestFlight milestone: the full single-player game (solitaire,
daily, variants, seeded challenges, replays with analysis) plus pass-and-play
two-player. Entries below are promoted to a `### build N` heading when the
release lane cuts the build (see [RELEASING.md](RELEASING.md)).

### Unreleased (next build)

- Dead-gap markers: the board faintly flags gaps you've permanently
  closed off — where two of your lines sit 1–4 dots apart on the same
  axis, so no line can ever span the space between them. Shown live as
  you play and in the replay (which also flags the move that sealed each
  one). A quiet "you burned potential here" review aid.
- Board chrome: Undo and Fit moved out of the crowded title bar into
  subtle floating buttons over the board's bottom corner (Undo always,
  Fit when the view has moved) — the frequent actions now sit under the
  thumb. The fitted board keeps that corner clear so no dot is ever
  hidden behind the buttons (there's no panning at the fit zoom) — it
  reserves whichever axis has room to spare, so the board never shrinks.
  The game-type
  menu reads clearly as a picker (grid icon + variant + chevron) instead
  of a bare code, and the remaining header buttons have more breathing
  room.

### build 4 — 2026-08-06

- Sound & haptics (subtle, opt-in): a picker-style haptic detent as you
  scrub between candidate lines (so choosing between overlapping lines is
  tactile), a firmer tap when a line is placed, and a clear game-over cue
  (a soft settling tone + a neutral notification haptic) — the plain
  game-over was easy to miss. Two Settings toggles at the top of the tab:
  **Sound effects** (off by default) and **Haptics** (on by default,
  iOS). Sound mixes under other audio and follows the ring/silent switch
  (never interrupts music). Adapted from Donpa's sound/haptics slice.

### build 3 — 2026-07-23

- Nearby duel (MultipeerConnectivity, same room, iOS ↔ macOS): host a
  game and others join over the local network — no accounts, no server.
  - **Host-advertises lobby:** one player taps "Host a game", picks a
    mode and variant (and target, for race), and advertises it; others
    browse the nearby games and tap to request; the host accepts or
    declines each, then starts. Up to 8 players.
  - **Lock-step mode:** everyone races the same board with no target —
    when anyone commits a move, everyone who hasn't gets a 10-second
    clock; let yours run out, or dead-end while others can still play,
    and you're out. Last player standing wins. You can't move again
    until everyone has committed the current move.
  - **Race mode:** everyone plays the same board in parallel to a target
    line count; first to reach it wins, the rest keep going for
    placement. Live scores show throughout.
  - Final standings rank everyone by move count; equal counts tie.
  - A Nearby display name (Settings) is the only identity — no records,
    no win/loss history; a match is its own event.
- Local-network privacy strings + Bonjour service declarations for
  Nearby play on both platforms.

### build 2 — 2026-07-23

- iCloud sync (opt-in, off by default): best scores and the daily log
  sync across your devices via a single shared iCloud key-value blob —
  commutative merge (max bests, union daily days), self-healing, no
  device IDs. Games and replays stay local. New Settings tab with the
  toggle.

### build 1 — 2026-07-22

Grouped by area (newest first within each group):

- **Modes & rules**
  - Two-player (Versus): pass-and-play on one device — players alternate,
    the last able to move wins; one undo before the opponent replies; its
    own resumable slot, outside records and bests. Each player owns a
    colour-vision-safe colour (lines, accent, and a filled turn chip).
  - Variants: 5T (classic), 5D, the solved 4T/4D (smaller cross), and 5T+
    (relaxed "MS2" rules — dot and line decoupled, free lines legal, shown
    as standing offers). Switchable from the free game; bests, ghosts, and
    records tracked per pool.
  - Daily: one attempt per local date, one undo per move, streaks (an
    unplayed day doesn't break it), Free/Daily tabs. Each date generates
    its own symmetric 36-dot start — same board for everyone.
  - Solitaire: the base game — unlimited undo, new game, game-over
    detection.
- **Sharing**
  - Challenge codes: Random Start (5T#) deals a fresh seeded board with a
    six-character code; Enter Code / Scan Code play a friend's. Seeded
    games score in their own "5T#" pool so a lucky start never touches the
    classic bests. No server — the code is the whole challenge.
  - Links & QR: the header code opens a panel with a scannable QR and a
    `lattice.misaki.fi/c/CODE` link; opening one launches straight into
    the board, and the site shows the code for manual entry without the app.
  - Share card: a finished game exports as an ink-on-paper image (the board
    in the game's own drawing style + score/date); Share and Save Image
    beside the final score.
- **Review & history**
  - Replay viewer: open any finished game from History and scrub or
    autoplay through it (space to play/pause; slider, frame-step, jump;
    arrow keys on Mac), the current move accent-highlighted.
  - Post-game analysis: the openness curve (legal moves per turn) charted
    under the replay, scrubbable — see where the position peaked and died.
  - Personal-best ghost: a live game races its openness against your best
    game's curve.
  - History tab: all pools on one score-over-time chart (fixed
    colour + symbol per pool, colour-vision-safe), running-best lines, and
    a recent-games list; filter to one pool.
- **Board & input**
  - Two-stage input: tap a point → tentative dot + candidate ghosts → tap
    a line to commit; free cancel. Hover previews on Mac/iPad; touch-drag
    scrubs across targets and selects on lift.
  - Readability: placeable points show as clear pinpoints while settled
    ones fade (defuses the scintillating-grid illusion); dots wear
    background casing rings; collinear candidates fan out to stay tappable.
  - Camera: pinch-zoom (to 6×) and pan, clamped so the board can't be lost;
    Fit (⌘0) snaps back.
  - App icon: a legal 5T-style line field with a "5" erased from it
    (negative space) — light/dark/tinted, all from the game's drawing code
    (`make icon`).
- **Foundation**
  - Engine: 5T/5D/4T/4D/5T+ move validation (segment-reuse, no-free-lines
    by construction where it applies), legal-move enumeration, end
    detection, scoring, undo — the move stack doubles as the replay record.
  - Persistence: in-progress games survive quitting; every finished game is
    stored as a full replay; per-pool bests.
  - Project: XcodeGen iOS + macOS (Universal Purchase), `LatticeCore`
    package (grid model + tests), String Catalog, pinned lint/format, CI
    (lint, tests + coverage, both builds), and the release lane (`make
    release`: bump PR with CI gate → per-platform tags + GitHub releases →
    archive/export/upload to App Store Connect).
