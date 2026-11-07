#!/usr/bin/env bash
# Release step 3 (pure): tag the released commit and publish a GitHub release,
# per platform. Re-derives everything from durable state — the version/build
# from the merged project.yml, the commit from the base's tip — so it needs
# nothing passed in and is safe to re-run (it never clobbers an existing tag).
#
# Tags are ios/vX.Y.Z-N and mac/vX.Y.Z-N (no beta/rc). The first release
# platform in slipway.yml carries the repo's "latest" badge (GitHub allows one).
#
# Usage: release-tag.sh <all|ios|macos>   (run after release-publish.sh merges)
set -euo pipefail
. "$(dirname "$0")/release-lib.sh"

scope="${1:-}"
plats="$(release_scope "$scope")"
latest_plat="${SLIPWAY_RELEASE_PLATFORMS%% *}"

base="$(release_base)"
say "Refreshing ${base}…"
git pull --quiet --ff-only origin "$base"
sync_tags
version="$(read_unique MARKETING_VERSION)"
build="$(read_unique CURRENT_PROJECT_VERSION)"
merge_sha="$(git rev-parse HEAD)"
git log -1 --pretty=%s | grep -q "Merge pull request" \
    || echo "  note: ${base} tip isn't a merge commit (subject: $(git log -1 --pretty=%s)) — tagging it anyway."
echo "tagging v${version} build ${build} at ${merge_sha:0:7}"

release_one() {
    local plat="$1" prefix label tag
    prefix="$(tag_prefix "$plat")"
    label="$(plat_label "$plat")"
    tag="$(tag_name "$plat" "$version" "$build")"

    # Idempotent per platform, so a partial re-run finishes only what's missing:
    # tag + release exist → skip; tag only → create the release; neither → both.
    if tag_exists "$plat" "$version" "$build" && gh_release_exists "$tag"; then
        echo "  $tag already tagged + released — skipping."
        return
    fi
    if tag_exists "$plat" "$version" "$build"; then
        echo "  $tag already tagged; creating its GitHub release."
    else
        git tag -a "$tag" "$merge_sha" -m "${SLIPWAY_DISPLAY_NAME} ${label} v${version} (build ${build})"
        git push --quiet origin "$tag"
        echo "  tagged $tag → ${merge_sha:0:7}"
    fi

    # Notes: commit subjects since this platform's previous release.
    local prev notes_changes since notes
    prev="$(previous_tag "$plat" "$version" "$build")"
    if [ -n "$prev" ]; then
        notes_changes="$(git log --no-merges --pretty='- %s' "${prev}..${merge_sha}")"
        since=" since ${prev#"$prefix"/}"
    else
        notes_changes="- Initial ${label} release."
        since=""
    fi
    notes="$(
        cat <<EOF
${label} release for ${version} build ${build}.

| | |
|---|---|
| Marketing version | ${version} |
| Apple build number | ${version} (${build}) |
| Commit | ${merge_sha:0:7} |

**Changes${since}**
${notes_changes}
EOF
    )"
    # The "latest" badge goes to the main platform's release — but only when this
    # tag really is its highest, so a patch on an old version line doesn't steal
    # it from a newer main release.
    local latest=false
    if [ "$plat" = "$latest_plat" ] && [ "$(newest_tag "$plat")" = "$tag" ]; then
        latest=true
    fi
    gh_retry gh release create "$tag" --verify-tag \
        --title "${label} v${version} (build ${build}) — ${SLIPWAY_DISPLAY_NAME}" \
        --notes "$notes" --latest="$latest" >/dev/null
    echo "  published GitHub release for $tag (latest=$latest)"
}

say "Tagging + publishing GitHub releases…"
for p in $plats; do release_one "$p"; done
echo "✓ tagged + released (${scope})."
