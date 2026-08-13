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

See `SCREENSHOTS.md` for the capture guide, sizes and the shot list. The demo
mode it relies on is `make demo-iphone` / `demo-ipad` / `demo-mac`.

## Not copied from Donpa

`achievements.json` and the `medals`/`status`/`sync` scripts — Lattice has no
Game Center and none is planned.
