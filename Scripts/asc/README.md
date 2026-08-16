# App Store Connect tooling

Listing text lives in `listing.json` and is pushed with one command, so the
shipped copy is in git rather than typed into the ASC web UI.

```sh
make asc-listing         # dry run: show what would change
make asc-listing-apply   # write it
```

Credentials come from the release lane's `Scripts/.asc-config` (Key ID + Issuer
ID; the `.p8` is auto-discovered from `~/.appstoreconnect/private_keys/`), so
there's nothing extra to set up if `make release` already works.

First run creates a venv at `~/.venvs/lattice-asc` and installs
`requirements.txt` — Homebrew's Python is externally-managed, so a bare
`pip install` is refused.

## Screenshots

```sh
make shots PLATFORM=iphone     # guided capture (ipad / mac too)
make asc-screenshots           # dry run: what would upload
make asc-screenshots-apply     # replace + upload
```

`make shots` walks the shot list, stages each one with a prompt and captures it
canonically named into `shots/<platform>/`. See `SCREENSHOTS.md` for the list,
the sizes and the store order. `make shots-organize DIR=<folder>` renames
freehand captures by capture order instead, and `make shots-list` prints the
order without launching anything.

Sizes are checked before any upload: ASC accepts a wrong-sized image and then
fails processing, which blocks submission.

## Not copied from Donpa

`achievements.json` and the `medals`/`status`/`sync` scripts — Lattice has no
Game Center and none is planned.

The screenshot tooling is ported but single-language: `LOCALES` in
`screenshots.py` is just `en-US`, and captures live flat in `shots/<platform>/`.
A `<platform>/<lang>/` subdir is still preferred when present, so adding a
language needs no change to the upload path.
