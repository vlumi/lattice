# App Store Connect data

The listing text and the screenshots go to App Store Connect from this repo,
never typed into the ASC web UI. The sync itself is slipway's
(`Scripts/slipway/`, see its README.md); this folder holds what it reads, plus
Lattice's screenshot capture.

- `listing.json` — the listing text: name, subtitle, description, keywords,
  what's new, URLs.
- `shots.json` — the App Store carousel order.
- `SCREENSHOTS.md` — the shot list, how to stage each shot, and the sizes.
- `organize-shots.py` — the shot list in capture order, for `make shots` and
  for renaming freehand captures.
- `window-id.swift` — finds the Mac app's window for `make shots` to capture.
- `REVIEW-NOTES.md` — what App Review gets told.

```sh
make asc-listing               # dry run: what the listing text would change
make asc-listing-apply         # write it

make shots PLATFORM=iphone     # guided capture into shots/iphone/ (ipad / mac too)
make asc-screenshots           # dry run: which shots would upload
make asc-screenshots-apply     # upload the changed ones, in shots.json's order
```

Credentials come from the release lane's `Scripts/.asc-config`, so there's
nothing extra to set up if `make release` already works. Sizes are checked
before any upload: ASC accepts a wrong-sized image and then fails to process
it, which blocks submission.

`make shots-organize DIR=<folder>` renames freehand captures by capture order,
and `make shots-list` prints that order without launching anything.

The app is English-only, so the captures live flat in `shots/<platform>/`; a
`<platform>/<lang>/` folder per language is all a second language needs.
