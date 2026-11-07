#!/usr/bin/env bash
# Release step 2 (the dirty middle): the interactive, stateful core. Bumps the
# version/build (with prompts), stamps the changelog, opens an auto-merging PR,
# and blocks until CI passes and it merges. The pure steps after it (tag,
# distribute) read the result back from the merged commit — nothing is passed
# between scripts.
#
# Versioning (project.yml, shared by every app target):
#   • MARKETING_VERSION — asked on every release; blank keeps it. Shared by all
#     targets, so a version cut on a single-platform release is the project's
#     version: a milestone that ships to one platform still moved the project on.
#   • CURRENT_PROJECT_VERSION — the build number, bumped on every target, every
#     release, and kept one past every tag on every branch.
#
# Usage: release-publish.sh <all|ios|macos>
# On CI failure it stops with the PR left open: no merge, tag, build or upload.
set -euo pipefail
. "$(dirname "$0")/release-lib.sh"

scope="${1:-}"
plats="$(release_scope "$scope")"
base="$(release_base)"

# Releasing everything is the common path — just confirm it when it's more than one.
if [ "$scope" = all ] && [ "$(echo "$plats" | wc -w | tr -d ' ')" -gt 1 ]; then
    labels="$(for p in $plats; do plat_label "$p"; done | paste -sd+ - | sed 's/+/ + /g')"
    printf 'Release ALL platforms (%s)? [Y/n] ' "$labels"
    read -r ans || ans=""
    case "$ans" in [nN]*) die "aborted." ;; esac
fi

# ── Decide the next version + build ───────────────────────────────────────────
cur_version="$(read_unique MARKETING_VERSION)"
cur_build="$(read_unique CURRENT_PROJECT_VERSION)"
echo "current: version ${cur_version}, build ${cur_build}"

# Resume guard: the base's build is ahead of every tag, so a previous run's bump
# merged but wasn't tagged — publishing is done; the chain flows on to tagging.
if [ "$cur_build" -gt "$(highest_tagged_build)" ]; then
    echo "✓ build ${cur_build} already merged to ${base} but untagged — publish already done, skipping to tag."
    exit 0
fi

IFS='.' read -r MA MI PA <<EOF
${cur_version}
EOF
suggested="${MA}.${MI}.$((${PA:-0} + 1))"
minor_suggested="${MA}.$((${MI:-0} + 1)).0"
printf 'Bump marketing version? current %s — blank = keep, "p" = %s, "m" = %s, or X.Y.Z: ' \
    "$cur_version" "$suggested" "$minor_suggested"
read -r answer || answer=""
case "$answer" in
    "") new_version="$cur_version" ;;
    p | P) new_version="$suggested" ;;
    m | M) new_version="$minor_suggested" ;;
    *)
        [[ "$answer" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must be X.Y.Z (got '$answer')"
        new_version="$answer"
        ;;
esac
# One past BOTH the base's build and every tag: a version-line branch lags the
# builds main has cut (and vice versa), and build numbers stay globally
# monotonic so the trains never collide.
highest="$(highest_tagged_build)"
new_build=$(((cur_build > highest ? cur_build : highest) + 1))
echo "release: version ${new_version}, build ${new_build} (build applies to every target)"

# ── Apply the bump to project.yml ─────────────────────────────────────────────
if [ "$new_version" != "$cur_version" ]; then
    sed -i '' -E "s/(MARKETING_VERSION: *)\"[^\"]+\"/\1\"${new_version}\"/" "$PROJECT_FILE"
fi
sed -i '' -E "s/(CURRENT_PROJECT_VERSION: *)\"[0-9]+\"/\1\"${new_build}\"/" "$PROJECT_FILE"
[ "$(read_unique MARKETING_VERSION)" = "$new_version" ] || die "version not applied to all targets (is it quoted in $PROJECT_FILE?)."
[ "$(read_unique CURRENT_PROJECT_VERSION)" = "$new_build" ] || die "build not applied to all targets (is it quoted in $PROJECT_FILE?)."

# ── Stamp the changelog: Unreleased → build N (stages it if it had entries) ──
say "Stamping the changelog…"
# The version only when it changed: a new version heading belongs above the
# first build of that version, and nowhere else.
if [ "$new_version" != "$cur_version" ]; then
    promote_changelog_build "$new_build" "$new_version"
else
    promote_changelog_build "$new_build"
fi

# An empty Unreleased is right for a docs/internal-only build, but it also
# happens when notes were written into an already-shipped section by mistake.
# With code commits since the last release and nothing promoted, make the
# author confirm rather than ship without notes in silence.
if git diff --cached --quiet -- "$CHANGELOG_FILE" 2>/dev/null; then
    # shellcheck disable=SC2086  # the platform list is meant to split
    last_tag="$(newest_tag $plats)"
    if [ -n "$last_tag" ]; then
        n_commits="$(git log --oneline --no-merges "${last_tag}..HEAD" -- \
            ':(exclude)*.md' ':(exclude)Scripts' | wc -l | tr -d ' ')"
        if [ "$n_commits" != "0" ]; then
            printf '  !! %s code commits since %s but no Unreleased notes.\n' "$n_commits" "$last_tag"
            printf '     Continue anyway? [y/N] '
            read -r reply || reply=""
            case "$reply" in [yY]*) ;; *) die "aborted — write the notes first." ;; esac
        fi
    fi
fi

# ── Branch, commit, push, PR with auto-merge ──────────────────────────────────
rel_branch="release/v${new_version}-${new_build}"
git rev-parse --verify --quiet "$rel_branch" >/dev/null && die "branch '$rel_branch' already exists."
git checkout -q -b "$rel_branch"
git add "$PROJECT_FILE"
[ -f "$CHANGELOG_FILE" ] && git add "$CHANGELOG_FILE"
git commit --quiet -m "$(
    cat <<EOF
Release v${new_version} build ${new_build} (${scope})

Marketing version ${new_version}, shared build number ${new_build} (bumped
on every target). The changelog Unreleased section is stamped as build
${new_build}. Opened by the release lane (Scripts/slipway), which tags this
merge commit and distributes ${scope} once CI passes.
EOF
)"
git push --quiet -u origin "$rel_branch"

say "Opening PR (into ${base})…"
gh_retry gh pr create \
    --title "Release v${new_version} build ${new_build} (${scope})" \
    --body "Version **${new_version}**, build **${new_build}** (build bumped on every target; release scope: **${scope}**). Opened by the release lane (\`Scripts/slipway\`); set to auto-merge once CI passes. The resulting merge commit on ${base} is tagged and distributed." \
    --base "$base" --head "$rel_branch" >/dev/null

say "Enabling auto-merge (merge commit) — will merge when CI passes…"
# Auto-merge needs branch protection with required checks — main has it, a
# release/X.Y.x base typically doesn't (GitHub then refuses because the PR is
# already mergeable). Fall back to merging directly after the CI wait.
automerge=1
if ! gh pr merge "$rel_branch" --auto --merge 2>/dev/null; then
    automerge=0
    echo "  (auto-merge unavailable on ${base} — will merge directly once CI passes)"
fi

# ── Wait for CI; stop (PR left open) before anything irreversible if it fails ──
# Right after `pr create`, gh may report "no checks" before the workflow
# appears. Poll (exit 8 = pending) until a check exists, then watch.
say "Waiting for CI to register…"
tries=0
while true; do
    gh pr checks "$rel_branch" >/dev/null 2>&1 && break
    rc=$?
    [ "$rc" -eq 8 ] && break
    tries=$((tries + 1))
    [ "$tries" -ge 12 ] && die "no CI checks registered after ~60s — PR left open at $rel_branch."
    sleep 5
done
say "Waiting for CI to finish (auto-merge completes on green)…"
# `--watch` is a long-lived stream: a transient GitHub blip drops it with a
# non-zero exit that looks just like "CI failed". So re-derive the truth from a
# plain `gh pr checks` (pass / fail / exit 8 = pending), and re-watch while
# anything is pending. Only a check that really reports failure is fatal.
while ! gh pr checks "$rel_branch" --watch --fail-fast; do
    gh_retry gh pr checks "$rel_branch" >/dev/null 2>&1 && break
    rc=$?
    [ "$rc" -eq 8 ] && { say "watch dropped mid-run — re-watching…"; continue; }
    die "CI failed — PR left open at $rel_branch. No merge, tag, build, or upload was done."
done

say "Confirming merge…"
[ "$automerge" -eq 1 ] || gh_retry gh pr merge "$rel_branch" --merge >/dev/null

# Auto-merge is async: GitHub merges a few seconds AFTER the checks go green.
# Poll until MERGED; a timeout is recoverable — re-running `make release`
# detects the merged-but-untagged build and resumes at the tag step.
state=""
for _ in $(seq 1 20); do
    state="$(gh_retry gh pr view "$rel_branch" --json state --jq .state)"
    [ "$state" = "MERGED" ] && break
    sleep 3
done
[ "$state" = "MERGED" ] || die "PR is '$state' after waiting, not MERGED (a required review may be blocking auto-merge). Once it merges, re-run \`make release\` — it resumes at the tag step."

# Leave the tree on the merged base tip (also what release-tag expects).
git checkout -q "$base"
git pull --quiet --ff-only origin "$base"

echo "✓ published: v${new_version} build ${new_build} merged to ${base}."
