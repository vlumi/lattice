# slipway

The shared build, test and release plumbing for my Apple-platform apps — iOS,
macOS and watchOS, in any combination. One copy of the release lane and the
make targets, instead of a near-identical copy drifting in every project.

A project carries slipway as a **pinned copy** in `Scripts/slipway/`, with the
version it came from. Nothing changes in a project until it's updated on
purpose, so a project that hasn't been touched in months still releases with
exactly the scripts it last shipped with.

## What a project looks like

slipway works by convention, for a project laid out like this:

- `project.yml` for XcodeGen, with app targets named `<name>-iOS`,
  `<name>-macOS`, `<name>-watchOS` (the schemes take the same names; a watch app
  is embedded in the iOS app). `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`
  are quoted and kept equal across targets; `DEVELOPMENT_TEAM` is set.
- The logic in a Swift package at `Packages/<core>/`, the apps in `Sources/`.
- `.swift-format` and `.swiftlint.yml` at the root.
- `CHANGELOG.md` with an `### Unreleased (next build)` heading, its list items
  directly under it, inside the current version's section.
- `main` protected with required CI checks (so the release PR can auto-merge).

## Adopting it

1. From a slipway checkout: `./install.sh ~/src/vlumi/myapp` (or, in a project
   that has it, `make slipway-update V=vX.Y.Z`).
2. Add `slipway.yml` at the project root (below).
3. `include Scripts/slipway/slipway.mk` in the `Makefile`, and delete the
   targets slipway now provides.
4. Point the commit-SHA build phase at the copy:
   `script: "\"$SRCROOT/Scripts/slipway/embed-commit-sha.sh\""`.
5. Gitignore `dist/`, `*.xcodeproj` and `Scripts/.asc-config`; put the App Store
   Connect API Key ID and Issuer ID in that last one (see `distribute.sh`).
6. Have CI run `Scripts/slipway/check.sh`, so an edited copy can't merge.

## slipway.yml

Flat `key: value` and `key: [a, b]` lines, `#` comments. Quote a value that
contains `#`.

| Key | Default | |
| --- | --- | --- |
| `name` | required | `<name>.xcodeproj`, `<name>-iOS`, … |
| `display_name` | `name` | tag messages and GitHub release titles |
| `core_package` | `<name>Core` | `Packages/<core>/`, for tests and formatting |
| `platforms` | `[ios]` | what the project builds: `ios`, `macos`, `watchos` |
| `release_platforms` | `platforms` minus `watchos` | what ships to App Store Connect |
| `changelog_version_heading` | `"## [{version}]"` | e.g. `"## v{version}"` |
| `app_icon` | none | the 1024 icon; preflight refuses one with an alpha channel |
| `pre_generate` | none | a command run before every `xcodegen generate` |

```yaml
name: Yomidori
platforms: [ios, macos]
changelog_version_heading: "## v{version}"
app_icon: Sources/Shared/Assets.xcassets/AppIcon.appiconset/icon-1024.png
pre_generate: Scripts/ensure-dictionary.sh
```

## Make targets

`make` lists them, with the project's own targets merged in by section.
Targets for a platform the project doesn't build don't exist, and aren't listed.

- **Build & test:** `generate`, `build-ios`, `build-mac`, `build-watch`, `test`,
  `lint`, `format`, `clean`
- **Release:** `release`, `release-build`, the four steps
  (`release-preflight`, `-publish`, `-tag`, `-distribute`),
  `release-distribute-retry`, `release-upload`
- **App Store:** `asc-listing`, `asc-screenshots` (dry runs), and each with
  `-apply` to write
- **slipway:** `slipway-check`, `slipway-update`

### Hooking in

The project's Makefile keeps everything project-specific (run, demo,
screenshots, App Store listing, generated assets). To extend a slipway target,
**add a prerequisite** — make merges them — rather than redefining it, which
make only warns about before silently using the second recipe:

```make
lint: lint-markdown                     # runs before SwiftLint + swift-format
$(SLIPWAY_XCODEPROJ): $(DICTIONARY)     # regenerate when it changes
```

In the help, a description starting with `[ios]`, `[macos]` or `[watchos]` is
listed only when the project builds that platform, and a `##@ Section` heading
that matches one of slipway's adds to it.

## The release lane

`make release` (from a clean `main` matching origin) runs four steps:

1. **preflight** — clean tree, on `main` or a `release/X.Y.x` version line,
   matching origin; `gh` and `xcodegen` present; the app icon opaque.
2. **publish** — asks for the version (blank keeps it, `p` patch, `m` minor,
   or `X.Y.Z`), bumps the build past every tag, stamps the changelog, and opens
   a PR that auto-merges when CI passes. It waits for the merge.
3. **tag** — tags the merge commit `ios/vX.Y.Z-N` / `mac/vX.Y.Z-N` and
   publishes a GitHub release per platform, with the commit subjects since the
   previous one. The first release platform carries the "latest" badge.
4. **distribute** — regenerates the project, archives, exports and uploads
   each platform.

`PLATFORM=ios` (or `macos`) releases one platform; the build number still
moves on every target. `UPLOAD=0` stops after export.

Every step re-derives its state from git, so a failed run is resumed by
running it again: a merged but untagged build skips straight to tagging, a
platform that is already tagged and released is skipped, and
`make release-distribute-retry` / `make release-upload` repeat only the
building or only the upload.

**The changelog.** Publish renames `### Unreleased (next build)` to
`### build N — <date>` and opens a fresh one above it. When the version
changes it also writes the new version's heading, keeping the old heading (and
any text under it) over the builds it shipped. If Unreleased is empty but code
changed since the last tag, it asks before releasing without notes.

## App Store Connect

The listing text and the screenshots go to App Store Connect from the repo,
never by hand in the ASC UI. The project keeps the data; slipway the code:

- `Scripts/asc/listing.json`: `bundleId`, then `appInfo` (name, subtitle,
  privacy URL) and `version` (description, keywords, promotional text, what's
  new, URLs), each keyed by ASC locale.
- `Scripts/asc/shots.json`: `"store": [<shot>, …]`, the carousel order. A shot
  under `"shots"` with `"platforms": [...]` is left out of the others; any other
  fields are the project's own (its capture script's, say).
- `shots/<platform>/<lang>/<shot>-<platform>.png`, the captures, with platform
  `iphone`, `ipad`, `mac` or `watch` at the store's sizes. An app in one
  language can leave out `<lang>/`; that reads as English.

`make asc-listing` and `make asc-screenshots` show what would change, and
`-apply` writes it to every editable version. A screenshot set gets only the
shots whose file differs from what it holds (by MD5), loses the ones no file
matches and is put in store order, so one retaken screen doesn't send the rest
through ASC's processing again; `ALL=1` replaces every shot. A capture at the
wrong size stops the run before anything is touched, since ASC would accept it
and then fail to process it.

The credentials are the release lane's (`Scripts/.asc-config`). The Python runs
in a venv shared by every project, `~/.venvs/slipway-asc`, made on first use.

## Updating and checking

```sh
make slipway-update V=v0.2.0                   # a slipway release from GitHub
make slipway-update SLIPWAY_SRC=../slipway     # a local checkout, as it stands
make slipway-check                             # is the copy unmodified?
```

`VERSION` records where the copy came from and `MANIFEST` a checksum of every
file. A fix belongs here in slipway: change it, release it, and update the
projects that need it — never edit a project's copy.

## Developing slipway

```sh
tests/run.sh             # all tests; tests/run.sh <filter> for some
shellcheck -S warning install.sh lib/*.sh scripts/*.sh tests/*.sh tests/stubs/*
```

The tests build small projects (iOS, iOS + macOS, iOS + macOS + watchOS) with a
local bare repo as origin and fake `gh`, `xcodebuild`, `xcrun` and `xcodegen`,
and run the real targets — the whole release lane included — against them.

The scripts run on macOS's own bash 3.2: no associative arrays, `mapfile` or
`${x,,}`.

### Releasing slipway

A change to `lib/` — what the projects run — writes its entry under
`## [Unreleased]` in `CHANGELOG.md`. The rest (`scripts/`, `tests/`, CI, a
docs-only README change) gets no entry and no release of its own; the README
reaches the projects with the next release that has one.

```sh
scripts/release.sh 0.2.0
```

It files Unreleased under `## [0.2.0] — <date>` in a release PR, waits for it
to merge, tags that merge commit `v0.2.0` — so the tagged changelog has the
heading — and publishes a GitHub release with that section as its notes. If it
stops partway, run it again: it picks up at the step that's missing.
