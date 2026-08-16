# App Store screenshots — capture guide

The carousel's job: make someone who has scrolled past a hundred puzzle games
stop and think *"I haven't seen that before."* Lattice's hook is visual — a
sparse field of dots and drawn lines that looks like nothing else on the store —
so lead with the board and let the depth follow.

**Gameplay and functional UI only.** Show the game, not packaging.

## Workflow

```sh
make shots PLATFORM=iphone     # or ipad / mac — guided capture
make asc-screenshots           # dry run: what would upload
make asc-screenshots-apply     # replace + upload
```

`make shots` launches the demo, then walks the list below one shot at a time:
it prints what to stage, waits for ⏎, and captures for you — canonically named
into `shots/<platform>/`, ready to upload. `r` retakes, `s` skips, `q` stops.

The Nearby duel needs a second device and is left out by default; add it with
`WITH_NEARBY=1` once you have two to hand.

To stage a board by hand instead, `make demo-iphone` (or `demo-ipad` /
`demo-mac`) just launches the demo; capture freehand and then rename by capture
order with `make shots-organize DIR=<folder> PLATFORM=iphone`.

The demo launches with seeded data, staged so each tab shows what it should:

- **Free** opens on a board **34 moves in** — lines drawn, dots placed, the
  frontier still open. This is the lead shot, and it has to look like the game
  rather than an empty grid.
- **Daily** is deliberately **unplayed today**, so it shows the day's fresh
  board — the initial state a newcomer meets — while the header still reads a
  live streak (an unplayed today doesn't break one).
- **History** charts ten finished games over five weeks, with bests in several
  pools. Two are dailies, so the "Daily" row label shows beside the variant keys.

Dates are **fixed**, not wall-clock, so the chart and the recent-games list read
identically whether you capture today or next week. Identical on every device —
switch screens, capture, move to the next device, get the same content.

Capturing by hand instead of with `make shots`:

- **Simulators:** `xcrun simctl io <udid> screenshot shots/<name>.png`
  (the launcher prints the exact command with the udid filled in).
- **Mac:** ⇧⌘4 then Space to grab the window, or `screencapture -o -w out.png`.

Save into `shots/<platform>/<name>-<platform>.png` — that's the name
`asc-screenshots` looks for. Wrong-sized captures are refused before anything
is uploaded, since ASC accepts them and then fails processing, which blocks
submission.

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
| iPhone 6.9" | iPhone 16/17 **Pro Max** | 1320×2868 |
| iPad 13" | iPad Pro 13" | 2064×2752 |
| Mac | any | 2880×1800 (16:10) |

`make shots` pins all of this: it boots those exact simulators (not the smaller,
faster ones `make demo-iphone` uses), and in demo mode the Mac app fixes its
window to 1440×900 — which captures at 2880×1800 on a Retina display. Each shot
is size-checked as it's taken, so a wrong one is caught immediately rather than
at upload with the whole set to redo.

Capturing on the wrong device is the easy mistake, and "close enough" models are
the trap — a 16 **Plus** is 6.7", not 6.9", and gives 1290×2796. An SE gives
1170×2532 and an iPad Air 1640×2360. ASC refuses all of them.

## The shots

The list lives in `organize-shots.py`, so one table drives this guide, the
`make shots` prompts and the upload order:

```sh
make shots-list PLATFORM=iphone
```

Seven shots (eight with Nearby). Capture order is chosen so **each is a couple
of seconds from the last** — the demo stages the state, so every step is
navigation, never "play a game to the end". The dark twin is last, so the
appearance is changed once, at the end — in **Settings ▸ Appearance**, not the
system settings, so it's the same two taps on every platform.

Two screens are deliberately left out. **Game over** only appears on a live
finished board, so it would mean playing a game out, and the final score is
already in History and the replay. **How to play** is documentation — nobody
downloads a game because its rules are explained well, and the segment rule
reads as homework in a carousel.

**Store order ≠ capture order.** In ASC, arrange by persuasion — the first three
carry it:

> **mid-game board · choosing a line · History**

then daily, replay, new-game, nearby, and the dark twin last.
`make asc-screenshots` uploads in that order automatically.

Don't lead with the New Game modal: a picker doesn't sell a game.

## Captions (optional, added in ASC)

One concrete idea each, no marketing voice:

- "Place a dot. Draw a line through five."
- "One placement, several lines — choose."
- "Every game charted."
- "A new board every day."
