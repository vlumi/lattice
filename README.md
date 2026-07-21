# Lattice Five

A procedural, turn-based puzzle game for Apple platforms — a digital
**Morpion Solitaire** (a.k.a. *Join Five*).

> **Status: planning.** No code yet. This repo currently holds only the
> planning docs. See [AGENTS.md](AGENTS.md) for the intended architecture and
> conventions, and [ROADMAP.md](ROADMAP.md) for the implementation plan.

## The game

You start from a fixed cross-shaped outline of dots. On each move you place one
new dot, then draw a straight line through **five dots in a row** (four
segments) — horizontal, vertical, or diagonal. A line may share an endpoint dot
with earlier lines, but **no segment may be reused in the same direction**.
Play continues until no legal line remains; your score is the number of lines
drawn. It's a game of stretching one placement into the most future moves.

Planned modes (single-player is the main focus):

- **Solitaire** — the classic single-player maximization puzzle, with
  unlimited undo and full game replays.
- **Daily puzzle** — everyone plays the same deterministic start each day;
  streaks and a shareable score card rendered from your finished board.
- **Two-player** (ad-hoc) — either **pass-and-play** on one device or
  **Nearby** (device-to-device, no server). Two flavours planned: alternating
  turns where the last player able to move wins, and a **same-seed duel**
  where both play the same start solo for the higher score.

## Platforms & principles

- iOS and macOS, one app under **Universal Purchase** (buy once, both
  platforms) — free, no monetization.
- **All graphics procedural** — dots and line segments drawn in code; no image
  assets. (Carried over from the sibling project's approach.)
- **Mostly monochrome, full light/dark support** — ink-on-paper light mode,
  chalk-on-slate dark mode, one accent colour for interactive state only. The
  app icon (with light/dark variants) is generated from the game's own
  drawing code — lines drawn within a game.
- **English-only for now**, but built on a String Catalog from day one, so
  more languages are drop-in translation later, never a refactor.
- No server, no accounts, no tracking. Nearby play is peer-to-peer on the local
  network.

## Related

Shares lineage (and several reusable engine ideas) with
[Donpa Squad](https://github.com/vlumi/donpa) — a manga-styled Minesweeper by
the same author — but is a **separate codebase**: reusable seams were copied
and adapted, not shared as a package.

## License

MIT. See [LICENSE](LICENSE).
