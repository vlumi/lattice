#!/usr/bin/env python3
"""Rename raw screenshots to the canonical App Store names.

The order is the SCREENSHOTS.md shot list (capture order, which is NOT the
store order — arrange by persuasion at upload). Per platform the count differs
(the Nearby duel needs two devices), so pass the platform.

  # print the order to shoot in (do this first):
  Scripts/asc/organize-shots.py iphone --list

  # after dumping raw shots into <dir> (sorted by filename = capture order):
  Scripts/asc/organize-shots.py iphone <dir>
  Scripts/asc/organize-shots.py ipad   <dir>
  Scripts/asc/organize-shots.py mac    <dir>

Sorted by filename ascending — macOS names shots "Screenshot … at H.MM.SS",
Simulator names them by timestamp too, so lexical sort == capture order. Pass
--by-mtime if your names don't sort chronologically.

`make shots` captures straight to the canonical names and skips this entirely;
this is for shots taken freehand (⌘S, the Simulator's own capture, a device).
"""
import os
import sys

# Canonical shots in capture order (see SCREENSHOTS.md — the recommended STORE
# order differs; arrange at upload). Each: (name, needs_two_devices, what to
# capture). `needs_two_devices` marks shots the demo seed can't stage alone.
# Every shot is reachable in seconds from where the previous one left you —
# the demo stages the state, so these are navigation, never "play a game".
SHOTS = [
    ("mid-game", False,
     "Already on screen: the Free tab opens 34 moves in. Pinch/zoom so the "
     "board fills the frame with a little air around it, then capture. The "
     "shot that has to carry the whole listing."),
    ("choosing-a-line", False,
     "Tap any dot with a faint pinpoint — the candidate lines fan out. "
     "Capture BEFORE committing. The one shot that explains the mechanic. "
     "(Esc / tap away to clear it afterwards.)"),
    ("history", False,
     "Tap History. The chart and the recent-games list are already there — "
     "two rows read 'Daily'. Nothing else in the genre shows a curve like it."),
    ("replay", False,
     "Tap the top row in that list, then drag the scrubber to about halfway. "
     "Board plus openness chart: where did the position peak and die?"),
    ("daily", False,
     "Tap Daily. The day's fresh board, streak in the header — also the 'what "
     "you see on day one' shot."),
    ("new-game", False,
     "Back to Free, then the header's variant button (⌘N on Mac). Shows the "
     "variant row with its explanation line and Random Start."),
    ("mid-game-dark", False,
     "Last, because it needs a system-appearance change: close the modal, "
     "switch to Dark, re-frame as in shot 1, capture, switch back to Light."),
    ("nearby", True,
     "The duel board with live standings. Needs a second device — do it last, "
     "or skip for v1."),
]


def shots_for(platform, include_multi_device=False):
    return [(name, desc) for name, needs_two, desc in SHOTS
            if include_multi_device or not needs_two]


def rename_set(d, raw_files, names, platform, subdir=None):
    """Rename `raw_files` (already in capture order) to canonical names, into
    `d`/`subdir` when a subdir (a language) is given."""
    out = os.path.join(d, subdir) if subdir else d
    os.makedirs(out, exist_ok=True)
    for src, name in zip(raw_files, names):
        dst = f"{name}-{platform}.png"
        os.rename(os.path.join(d, src), os.path.join(out, dst))
        print(f"  {src}  →  {os.path.join(subdir, dst) if subdir else dst}")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    flagset = {f.split("=", 1)[0] for f in flags}
    langs = next(
        (f.split("=", 1)[1].split(",") for f in flags if f.startswith("--langs=")), None)
    if not args or args[0] not in ("iphone", "ipad", "mac"):
        sys.exit(
            "usage: organize-shots.py <iphone|ipad|mac> "
            "[<dir> | --list] [--by-mtime] [--with-nearby] [--langs=en]")
    platform = args[0]
    shots = shots_for(platform, include_multi_device="--with-nearby" in flagset)
    names = [name for name, _ in shots]

    if "--plain" in flagset:  # machine-readable, for Scripts/shoot.sh
        for name, desc in shots:
            print(f"{name}\t{desc}")
        return

    if "--list" in flagset or len(args) < 2:
        print(f"Capture these {len(shots)} shots for {platform}, in this order:\n")
        for i, (name, desc) in enumerate(shots, 1):
            print(f"  {i}. {name}-{platform}.png")
            print(f"     {desc}")
        print("\nEverything is Light except the last shot (mid-game-dark), "
              "which is\ndeliberately last so the appearance is switched once, "
              "at the end.")
        print("\nThe Nearby duel needs a second device and is left out by "
              "default;\npass --with-nearby once you have two to hand.")
        print("\n`make shots PLATFORM=" + platform + "` captures straight to "
              "these names.\nFor freehand shots, drop them in a folder and:\n"
              f"  Scripts/asc/organize-shots.py {platform} <dir>")
        return

    d = args[1]
    raw = [f for f in os.listdir(d)
           if f.lower().endswith((".png", ".jpg", ".jpeg")) and not f.startswith(".")]
    key = (
        (lambda f: os.path.getmtime(os.path.join(d, f)))
        if "--by-mtime" in flagset else str.lower)
    raw.sort(key=key)

    # One flat set, or several equal-size language sets back-to-back.
    groups = langs or [None]
    expected = len(names) * len(groups)
    if len(raw) != expected:
        print(f"⚠ found {len(raw)} images but expected {expected} for {platform}"
              + (f" ({len(names)} shots × {len(groups)} languages)" if langs else "") + ".")
        print("  Files (sorted):", raw)
        sys.exit("Fix the folder (one image per shot, in capture order) and re-run.")

    for i, lang in enumerate(groups):
        chunk = raw[i * len(names):(i + 1) * len(names)]
        rename_set(d, chunk, names, platform, subdir=lang)
    print(f"\nRenamed {expected} shot(s) for {platform}"
          + (f" across {len(groups)} languages." if langs else "."))


if __name__ == "__main__":
    main()
