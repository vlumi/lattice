#!/usr/bin/env python3
"""Upload the App Store screenshots from the project's capture tree, so the
per-locale uploads never happen by hand in Media Manager.

Reads shots/<platform>/<lang>/<shot>-<platform>.png (or shots/<platform>/<shot>-
<platform>.png for an app in one language, read as en), maps the platform
folder to its ASC screenshot set and the language to its locale, and makes each
set hold those files in the store order of Scripts/asc/shots.json. Only what
changed goes up: a shot whose file matches one already in the set (by MD5, ASC's
sourceFileChecksum) stays as it is, so it is not sent through ASC's processing
again.

Run from the project root, through asc.sh:

  asc.sh screens               # dry run: show the plan
  asc.sh screens --apply       # upload the changed, drop the stale, reorder
  asc.sh screens --all         # replace every shot, changed or not
  asc.sh screens --dir <tree>  # a different capture tree (default: shots)

shots.json needs only `"store": [<shot>, …]`, the carousel order by shot name;
a shot listed under `"shots"` with `"platforms"` is left out of the others.
"""
import argparse
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc_client import ASC  # noqa: E402

LISTING = os.path.join("Scripts", "asc", "listing.json")
SHOTS = os.path.join("Scripts", "asc", "shots.json")

# platform folder → (ASC version platform, screenshot display type)
PLATFORMS = {
    "iphone": ("IOS", "APP_IPHONE_67"),
    "ipad": ("IOS", "APP_IPAD_PRO_3GEN_129"),
    "mac": ("MAC_OS", "APP_DESKTOP"),
    "watch": ("IOS", "APP_WATCH_ULTRA"),
}
# Pixel sizes ASC accepts for each platform folder. A capture at any other size
# uploads fine but fails ASC's processing — a broken tile that BLOCKS
# submission — so refuse it here, loudly, before touching the sets.
EXPECTED_SIZES = {
    "iphone": {(1320, 2868)},
    "ipad": {(2064, 2752)},
    "mac": {(1440, 900), (2880, 1800)},
    "watch": {(410, 502), (422, 514)},
}
# A language folder is its ASC locale, but for English.
LOCALES = {"en": "en-US"}
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
            "METADATA_REJECTED", "PENDING_DEVELOPER_RELEASE"}


def store_order(doc, platform):
    """The shot names that platform carries, in carousel order."""
    shots = doc.get("shots", {})
    return [name for name in doc["store"]
            if platform in shots.get(name, {}).get("platforms", [platform])]


def languages(plat_dir):
    """(language, folder) pairs: a folder per language, or the platform's own."""
    if any(f.endswith(".png") for f in os.listdir(plat_dir)):
        return [("en", plat_dir)]
    return [(lang, os.path.join(plat_dir, lang)) for lang in sorted(os.listdir(plat_dir))
            if os.path.isdir(os.path.join(plat_dir, lang))]


def ordered_files(lang_dir, platform, order):
    """The captured files present, in store order, and the ones it doesn't name."""
    files = [os.path.join(lang_dir, f"{name}-{platform}.png") for name in order]
    files = [f for f in files if os.path.exists(f)]
    unnamed = sorted(f for f in os.listdir(lang_dir)
                     if f.endswith(".png") and os.path.join(lang_dir, f) not in files)
    return files, unnamed


def png_size(path):
    """Width × height from the PNG header (IHDR is always first)."""
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        sys.exit(f"Not a PNG: {path}")
    return (int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big"))


def check_sizes(files, platform):
    """Refuse the whole run on a wrong-sized capture (see EXPECTED_SIZES)."""
    bad = [(p, png_size(p)) for p in files if png_size(p) not in EXPECTED_SIZES[platform]]
    if bad:
        lines = "\n".join(f"  {p}: {w}x{h}" for p, (w, h) in bad)
        want = " or ".join(f"{w}x{h}" for w, h in sorted(EXPECTED_SIZES[platform]))
        sys.exit(f"Wrong-sized {platform} capture(s) — expected {want}:\n{lines}\n"
                 "Recapture them at the store's size.")


def md5_of(path):
    return hashlib.md5(open(path, "rb").read()).hexdigest()


def plan_set(existing, files, everything):
    """Which files go up, which shots stay, which go.

    Returns (slots, stale): slots is one entry per file in store order, the id
    of the existing shot it matches or None when it is uploaded; stale the ids
    of the shots no file matches. A shot whose processing failed never counts
    as a match, and `everything` matches nothing.
    """
    unused = {}
    for shot in existing:
        attrs = shot["attributes"]
        state = (attrs.get("assetDeliveryState") or {}).get("state")
        if everything or state == "FAILED" or not attrs.get("sourceFileChecksum"):
            continue
        unused.setdefault(attrs["sourceFileChecksum"], []).append(shot["id"])
    slots = []
    for path in files:
        same = unused.get(md5_of(path))
        slots.append(same.pop(0) if same else None)
    kept = {i for i in slots if i}
    stale = [shot["id"] for shot in existing if shot["id"] not in kept]
    return slots, stale


def screenshot_set(asc, loc_id, display_type, apply):
    """The localization's set for `display_type`, created when missing."""
    sets = asc.get_all(f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")
    for s in sets:
        if s["attributes"]["screenshotDisplayType"] == display_type:
            return s["id"]
    if not apply:
        return None  # dry run: would create
    created = asc.post("/appScreenshotSets", {
        "data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": display_type},
            "relationships": {
                "appStoreVersionLocalization": {
                    "data": {"type": "appStoreVersionLocalizations", "id": loc_id}}},
        }})
    return created["data"]["id"]


def reorder(asc, set_id, ids):
    asc.patch(f"/appScreenshotSets/{set_id}/relationships/appScreenshots", {
        "data": [{"type": "appScreenshots", "id": i} for i in ids]})


def upload(asc, set_id, path):
    """The 3-step dance: reserve → upload chunk(s) → commit. Returns the new id."""
    data = open(path, "rb").read()
    reserve = asc.post("/appScreenshots", {
        "data": {
            "type": "appScreenshots",
            "attributes": {
                "fileName": os.path.basename(path), "fileSize": len(data)},
            "relationships": {
                "appScreenshotSet": {
                    "data": {"type": "appScreenshotSets", "id": set_id}}},
        }})
    shot_id = reserve["data"]["id"]
    for op in reserve["data"]["attributes"]["uploadOperations"]:
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        _put_bytes(op, chunk, headers)
    # Commit — try the documented checksum form; drop it if ASC rejects the
    # attribute (as it now does for achievement images).
    md5 = hashlib.md5(data).hexdigest()
    for attrs in ({"uploaded": True, "sourceFileChecksum": md5}, {"uploaded": True}):
        try:
            asc.patch(f"/appScreenshots/{shot_id}", {
                "data": {"type": "appScreenshots", "id": shot_id, "attributes": attrs}})
            return shot_id
        except RuntimeError as e:
            if "ATTRIBUTE.UNKNOWN" not in str(e):
                raise


def _put_bytes(op, data, headers):
    import urllib.request
    req = urllib.request.Request(op["url"], data=data, method=op["method"])
    for k, v in headers.items():
        req.add_header(k, v)
    with urllib.request.urlopen(req):
        pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="write (default: dry run)")
    ap.add_argument(
        "--all", action="store_true",
        help="replace every shot, even one ASC already holds unchanged")
    ap.add_argument("--dir", default="shots", help="capture tree (default: shots)")
    args = ap.parse_args()

    if not os.path.exists(SHOTS):
        sys.exit(f"No {SHOTS}: it gives the store order, as {{\"store\": [<shot>, …]}}.")
    shots_doc = json.load(open(SHOTS))
    doc = json.load(open(LISTING))
    asc = ASC()
    apps = asc.get(f"/apps?filter[bundleId]={doc['bundleId']}&limit=1")["data"]
    if not apps:
        sys.exit(f"No app with bundle id {doc['bundleId']} under this key.")
    app_id = apps[0]["id"]

    versions = asc.get(f"/apps/{app_id}/appStoreVersions?limit=20")["data"]
    by_platform = {}
    for ver in versions:
        if ver["attributes"]["appStoreState"] in EDITABLE:
            by_platform.setdefault(ver["attributes"]["platform"], ver)

    print(f"== {'APPLYING' if args.apply else 'DRY RUN (--apply to write)'} ==\n")
    uploaded = 0
    for platform, (ver_platform, display_type) in PLATFORMS.items():
        plat_dir = os.path.join(args.dir, platform)
        if not os.path.isdir(plat_dir):
            continue
        ver = by_platform.get(ver_platform)
        if not ver:
            print(f"({platform}: no editable {ver_platform} version — skipped)")
            continue
        locs = asc.get_all(
            f"/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")
        loc_ids = {l["attributes"]["locale"]: l["id"] for l in locs}
        order = store_order(shots_doc, platform)
        for lang, lang_dir in languages(plat_dir):
            locale = LOCALES.get(lang, lang)
            label = f"{platform} [{locale}]"
            files, unnamed = ordered_files(lang_dir, platform, order)
            if unnamed:
                print(f"({label}: not in the store order, left out: {', '.join(unnamed)})")
            if not files:
                print(f"({label}: no captures — skipped)")
                continue
            check_sizes(files, platform)
            loc_id = loc_ids.get(locale)
            if not loc_id:
                print(f"({label}: locale missing on the version — skipped)")
                continue
            set_id = screenshot_set(asc, loc_id, display_type, args.apply)
            if set_id is None:
                print(f"{label}: would create {display_type} set and upload {len(files)}")
                uploaded += len(files)
                continue
            existing = asc.get_all(f"/appScreenshotSets/{set_id}/appScreenshots")
            slots, stale = plan_set(existing, files, args.all)
            changed = [f for f, slot in zip(files, slots) if slot is None]
            in_order = [s["id"] for s in existing] == slots
            if not changed and not stale and in_order:
                print(f"{label}: up to date ({len(files)})")
                continue
            names = ", ".join(os.path.basename(f) for f in changed) or "none"
            if not args.apply:
                print(f"{label}: would upload {len(changed)} ({names}), keep "
                      f"{len(files) - len(changed)}, drop {len(stale)}, then reorder")
                uploaded += len(changed)
                continue
            # Stale ones first: a set holds ten at most.
            for shot_id in stale:
                asc.delete(f"/appScreenshots/{shot_id}")
            ids = []
            for path, slot in zip(files, slots):
                if slot is None:
                    slot = upload(asc, set_id, path)
                    print(f"  {label} ← {os.path.basename(path)}")
                ids.append(slot)
            reorder(asc, set_id, ids)
            print(f"{label}: uploaded {len(changed)}, kept {len(files) - len(changed)}, "
                  f"dropped {len(stale)}")
            uploaded += len(changed)

    print(f"\n{uploaded} screenshot(s) {'uploaded' if args.apply else 'planned'}.")


if __name__ == "__main__":
    main()
