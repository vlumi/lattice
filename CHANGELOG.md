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

## [1.0.0]

The store release.

### Unreleased (next build)

- **Light or Dark, set in the app** — Settings ▸ Appearance, or leave it on
  System to follow the device as before.

### build 11 — 2026-08-16

- The New Game screen now says what each variant is — "5T" means nothing on
  its own, so a line under the row explains whichever you've selected: the
  classic game, the relaxed one, the stricter one, or the shorter solved ones.
- The New Game panel looks like it belongs on iPhone: it sits inset from the
  edges on a solid surface instead of stretching corner to corner over a murky
  grey, and the variant buttons read as buttons rather than glowing. The header
  button that opens it now looks pressed while it's open.
- History tells dailies apart from other seeded games: they used to read "5T#",
  the pool they share with random starts, so nothing said which was the day's
  board. They now say **Daily**, with the date beside them as before.
- Keyboard focus outlines only appear once you use the keyboard — on the Mac
  they showed the moment a panel opened, which looked like an unexplained
  highlight if you were using a pointer.

### build 10 — 2026-08-14

- **Export game data** in Settings: writes every finished game — with its full
  move list — plus your bests and daily log to a JSON file you can keep or send
  on. The counterpart to Reset, and the way to hand over the exact game when
  something looks wrong.
- Dead-gap marking is now correct in both directions. It used to flag gaps of
  up to four empty dots as sealed, but a line only needs five dots in a row and
  can start partway along a neighbour — so gaps of three or more are still
  playable, and calling them dead was a false alarm (four of them in one
  85-move game). Meanwhile the tightest case of all went unmarked: two lines
  back-to-back with no dot between them really can never be crossed. Both ends
  fixed, live and in replays.

## [0.5.0]

The TestFlight beta: the full single-player game (solitaire, daily, variants,
seeded challenges, replays with analysis), pass-and-play and Nearby two-player,
iCloud sync, full keyboard control, and the in-app rules.

### build 9 — 2026-08-13

- **Fixed a crash on launch on iPad** (iPadOS 26): the app's menu commands
  collided with the system menu bar and it died before showing anything.
- **How to play**, in the app: an illustrated guide to the rules, mostly
  pictures drawn by the board itself. Open it from the **?** button on the
  board, the Help menu (⌘?) on Mac, or Settings on iPhone and iPad.
- **Keyboard play works on iPad** with a hardware keyboard — arrows or WASD,
  Return to place and commit, Tab to cycle lines, Backspace to undo.
- **Reset progress** in Settings: clears bests, replays, the daily streak and
  any game in progress, behind a confirmation. With iCloud Sync on it erases
  everywhere and says so.
- An **About** screen with the version, build and links; every build now also
  carries the commit it came from.
- A tap where no line could ever reach now says so, with a red ring and a soft
  tap, instead of nothing happening.
- The `?` cheatsheet is Mac-only now — its keys don't apply on a phone, and the
  same list is in How to play.

### build 8 — 2026-08-13

- Choosing a line by dragging works again: after placing a dot, the drag could
  slip into feel-the-board mode partway through.
- The feel-sweep buzzes only where a dot can go, and stays quiet elsewhere —
  easier to read under a moving finger than three different strengths.

### build 7 — 2026-08-13

- **Feel the board with your finger:** slide across it and it ticks at each
  point, so you can hunt for a move without staring. Lift on a playable point
  to place your dot. Zoomed in, hold briefly first — a plain drag still pans.
- Large text sizes work properly: the header no longer pushes its buttons off a
  narrow screen, and the cheatsheet, History, code field and macOS Settings all
  grow with the text.
- A tidier header: the score is just the number, and the challenge chip is the
  QR glyph alone (the code is in the popover).
- Starting a random or coded board is instant — the modal closes on the tap and
  the board generates behind a brief indicator.
- Leaving a Nearby game always shuts the radio down now, including on quit.
- iOS no longer draws a stray box around the first Settings row.

### build 6 — 2026-08-10

- **Play and navigate without a mouse.** Arrows or WASD roam the board,
  Enter/Space places and commits, ←/→/Tab cycle the lines, Backspace undoes,
  Esc cancels; press **?** for a cheatsheet. Every screen is arrow-navigable on
  macOS, and every ⌘-shortcut is in the menu bar.
- **New Game modal** (⌘N): variants, Random Start and a code field in one
  place, fully keyboard-driven. Restart-this-board moves to its own ⌘R button.
- **Restart is safer:** disabled on an unplayed board, and an accidental
  restart or New Game is undoable until your first move on the fresh one.
- **Nearby rematch:** the result screen offers Rematch and Back to Lobby
  without re-connecting. Resign now concedes to the results instead of quitting,
  and a host leaving mid-match no longer strands guests.
- **Nearby races rank by time to reach the target**, not final move count, with
  the host as the one clock — so every device shows the same result. Reaching
  the target now shows your placement while you wait.
- **Your Nearby name is set on the Nearby screen**, not in Settings — so the
  device name doesn't quietly broadcast. A duel stays anonymous and leaves no
  history.
- **macOS Settings is a proper sheet** (⌘,) rather than a tab, and the tabs
  appear in the View menu (⌘1–⌘4). iOS keeps Settings as a tab.
- The challenge chip drops its code text on a narrow screen so the header stops
  wrapping; the code is still in the popover.

### build 5 — 2026-08-08

- **Dead-gap markers:** the board faintly flags gaps you've closed off for good
  — where two of your lines sit close enough that no line can ever span
  between. Live and in replays, which also flag the move that sealed each one.
- Undo and Fit move out of the title bar into floating buttons over the board's
  corner, under your thumb, and the game-type menu reads clearly as a picker.

### build 4 — 2026-08-06

- **Sound & haptics** (subtle, opt-in): a picker-style detent as you scrub
  between lines, a firmer tap when one is placed, and a clear game-over cue.
  Two Settings toggles — sound off by default, haptics on. Sound mixes under
  other audio and follows the ring/silent switch.

### build 3 — 2026-07-23

- **Nearby duel** (same room, iOS ↔ macOS, up to 8 players): host a game over
  the local network and others join — no accounts, no server. Race the same
  board either **lock-step** (commit a move and everyone else gets a 10-second
  clock; run out or dead-end and you're out, last standing wins) or as a
  **race** to a target line count, with live scores throughout. Final standings
  rank by move count.
- Local-network privacy strings and Bonjour declarations for both platforms.

### build 2 — 2026-07-23

- **iCloud sync** (opt-in, off by default): best scores and the daily log
  follow you across devices through your own iCloud. Games and replays stay
  local. New Settings tab with the toggle.

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
