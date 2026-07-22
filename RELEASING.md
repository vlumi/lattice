# Releasing

The whole cut is one local command run from a clean, up-to-date base:

```sh
make release                 # all platforms: preflight → publish → tag → distribute
make release PLATFORM=ios    # one platform (build number still bumps every target)
make release-build           # stop after export — no ASC upload
```

Adapted from Donpa's release lane; the scripts are `Scripts/release-*.sh` +
`Scripts/distribute.sh`, chained by the Makefile. The pure steps (preflight,
tag, distribute) re-derive everything from git + `project.yml`, so each runs
standalone; only publish (bump prompts → auto-merging PR → CI wait) is
stateful, and its state lands in the merged commit.

## Branching

- Normal releases cut from **main**.
- A patch on a shipped version after main has moved on cuts from a
  **`release/X.Y.x`** version-line branch. Build numbers stay globally
  monotonic across branches (next build = 1 + max(base, every tag)).
- The publish step's own PR branches are **`release/vX.Y.Z-N`** (v-prefixed,
  so they can't be mistaken for version lines). Never release from one.

## Versioning

Both live in `project.yml`, identical across the two targets (the lane
verifies):

- **`MARKETING_VERSION`** (X.Y.Z) — bumped only on an `all` release, and only
  when you answer the prompt.
- **`CURRENT_PROJECT_VERSION`** (the build number) — bumped on every release,
  shared by both targets so the apps never diverge.

The changelog's `### Unreleased (next build)` entries are promoted to a
`### build N — date` heading at publish time (no-op if empty).

## Tags & GitHub releases

`ios/vX.Y.Z-N` and `mac/vX.Y.Z-N` on the merge commit — the strict scheme is
load-bearing (sorting and previous-tag detection depend on it; no `-beta.N`
suffixes ever). Each gets a GitHub release; iOS carries the repo's "latest"
badge only when it truly is the highest tag.

## One-time setup

1. **ASC API key**: App Store Connect → Users and Access → Integrations →
   App Store Connect API → generate (App Manager role). Put the `.p8` at
   `~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8`.
2. Copy `Scripts/.asc-config.example` → `Scripts/.asc-config` (gitignored)
   and fill in the Key ID + Issuer ID.
3. Signing is automatic (`-allowProvisioningUpdates`); the team is committed
   in `project.yml`. No certs or profiles to install by hand.

## Recovering from a failed release

Every step is re-runnable; `make release` resumes where it left off:

- **CI failed at publish** — the PR is left open; nothing merged, tagged, or
  built. Fix, push to the PR branch (or close it), re-run.
- **Merged but not tagged** (e.g. interrupted) — publish detects the
  bumped-but-untagged base and skips straight to tagging.
- **Tag exists, release/dist failed** — the tag step is idempotent per
  platform; `make release-distribute-retry` re-archives/uploads an
  already-tagged release without touching git.
- **Export succeeded, upload failed** — `make release-upload` sends the
  existing `dist/` package without rebuilding.

## TestFlight notes

- The upload lands in ASC and processes for a few minutes; the build then
  appears under TestFlight for both apps (one Universal Purchase record).
- First-ever upload per platform may require accepting agreements in ASC.
- Export compliance is pre-answered (`ITSAppUsesNonExemptEncryption: false`
  in both Info.plists), so builds go straight to testable.

## Platform deltas

- **iOS** exports an `.ipa`; **macOS** exports a `.pkg` (App Sandbox is
  already entitled; hardened runtime is on).
- macOS App Store validation uses the `…puzzle-games` category UTI and
  `LSMinimumSystemVersion` — both maintained in `project.yml`; keep them in
  step with the deployment floor.
