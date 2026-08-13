# App Store screenshots — capture guide

The carousel's job: make someone who has scrolled past a hundred puzzle games
stop and think *"I haven't seen that before."* Lattice's hook is visual — a
sparse field of dots and drawn lines that looks like nothing else on the store —
so lead with the board and let the depth follow.

**Gameplay and functional UI only.** Show the game, not packaging.

## Workflow

```sh
make demo-iphone      # or demo-ipad / demo-mac
```

The demo launches with seeded data, staged so each tab shows what it should:

- **Free** opens on a board **34 moves in** — lines drawn, dots placed, the
  frontier still open. This is the lead shot, and it has to look like the game
  rather than an empty grid.
- **Daily** is deliberately **unplayed today**, so it shows the day's fresh
  board — the initial state a newcomer meets — while the header still reads a
  live streak (an unplayed today doesn't break one).
- **History** charts eight finished games over five weeks, with bests in several
  pools.

Dates are **fixed**, not wall-clock, so the chart and the recent-games list read
identically whether you capture today or next week. Identical on every device —
switch screens, capture, move to the next device, get the same content.

Then capture per the list below:

- **Simulators:** `xcrun simctl io <udid> screenshot shots/<name>.png`
  (the launcher prints the exact command with the udid filled in).
- **Mac:** ⇧⌘4 then Space to grab the window, or `screencapture -o -w out.png`.

Save into `shots/<platform>/<name>.png`. Nothing renames or uploads yet — this
is the handoff for the ASC upload.

### Demo isolation

`-demo-clean` routes every store to a temp directory and forces sync off;
`-demo-seed` fills it. A demo run **cannot** touch real player data — which
matters because the debug build shares the shipped app's bundle id and
container. (The dev Mac's real history was wiped once before this gate existed.)

To change what the demo shows, edit the fixtures in `DemoSeed.games` and
regenerate the committed games:

```sh
LATTICE_GEN_DEMO=1 swift test --filter GenerateDemoFixture   # ~2 min
```

The result is committed as `LatticeKit/Resources/demo-games.json` because
playing the games live costs two minutes; a demo launch just replays the moves.

## Sizes

Apple requires one set per display class:

| class | device | portrait |
|---|---|---|
| iPhone 6.9" | iPhone 16 Pro Max / 16 Plus | 1320×2868 |
| iPad 13" | iPad Pro 13" | 2064×2752 |
| Mac | any | 2880×1800 (16:10) |

## The shots

Capture in this order — it's the order the demo makes easiest, not the order
they go in the store (see below).

1. **mid-game board** — the Free tab as the demo opens it (34 moves in). The
   core loop, and the shot that has to carry the whole listing: dots, drawn
   lines, the faint pinpoints showing where a move is still possible. Zoom so
   the board fills the frame with a little air around it.
2. **choosing a line** — tap a placeable point so the candidate ghosts fan out,
   and capture before committing. This is the one shot that explains the
   *mechanic* — a placement offering several lines — which no static board can.
3. **game over with the score** — play to the end (or resume a finished replay)
   so the final panel with the score and Share is visible. Shows there's an
   outcome to chase.
4. **History** — the History tab: the score-over-time chart across pools with
   the running-best lines, and the recent-games list beneath. The "this tracks
   you properly" shot; nothing else in the genre shows a curve like it.
5. **replay with the openness curve** — open a finished game from History and
   scrub to mid-game, so the board and the openness chart are both visible.
   The analysis hook: *where did the position peak and die?*
6. **the daily** — the Daily tab: the day's fresh board with the streak in the
   header. Doubles as the "what you see on day one" shot. "One shared board a
   day, a reason to come back."
7. **New Game modal** — ⌘N (or the header button) showing the variant row and
   Random Start. Proves breadth: 5T/5D/4T/4D/5T+ plus seeded challenges.
8. **How to play** — the illustrated rules, showing the segment-rule diagram.
   Reassures a newcomer that the one hard rule is explained.
9. **Nearby duel** *(needs two devices — do last, or skip for v1)* — the duel
   board with live standings. Local multiplayer with no accounts is a genuine
   differentiator, but it can't be staged from the demo seed alone.

**Store order ≠ capture order.** In ASC, arrange by persuasion — the first three
carry it:

> **mid-game board · choosing a line · History**

then game-over, daily, replay, new-game, how-to-play, nearby.

Don't lead with How to play or the New Game modal: a picker doesn't sell a game.

## Dark mode

Capture the **mid-game board** a second time in Dark (system appearance), as
`mid-game-dark`. One dark taster is enough to show the app isn't light-only;
spending an early slot on the dark twin of slot 1 wastes it.

## Captions (optional, added in ASC)

One concrete idea each, no marketing voice:

- "Place a dot. Draw a line through five."
- "One placement, several lines — choose."
- "Every game charted."
- "A new board every day."
