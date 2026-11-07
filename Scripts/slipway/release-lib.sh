# Shared helpers for the release scripts (sourced, not executed).
#
# The release flow is split by concern — release-preflight.sh, release-publish.sh,
# release-tag.sh, release-distribute.sh — wired in order by slipway.mk. The pure
# steps (preflight, tag, distribute) re-derive their inputs from git + project.yml
# so each runs standalone; only the dirty middle (publish: prompts + PR + CI wait)
# carries in-memory state, all within one script.

# shellcheck shell=bash
# shellcheck source=common.sh
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Make the local tags an exact mirror of origin's. The lane reads its state from
# the tags (resume guard, tag_exists, previous_tag), and origin is the copy that
# counts: a tag deleted there to redo a failed cut must stop counting here too,
# or publish re-bumps and tag refuses to re-tag. Tags are only ever created by
# the lane and pushed at once, so a local-only tag is always stale.
sync_tags() {
    git fetch --quiet --prune origin '+refs/tags/*:refs/tags/*'
}

# The changelog heading for a version, from slipway.yml's template.
version_heading() {
    local h="$SLIPWAY_VERSION_HEADING"
    printf '%s' "${h//\{version\}/$1}"
}

# Stamp the changelog's "Unreleased (next build)" section with a build number,
# so the entries written there as PRs merged become `### build N — <date>` (and
# a fresh empty Unreleased takes its place). The author writes the entries; this
# only does the mechanical promotion. No-op if Unreleased has no list items, so
# a docs/internal-only build gets no empty heading.
#
# Given a version (only when this release cuts a NEW marketing version), it
# writes that version's heading too: a hand-set line in an otherwise automatic
# lane is a step that gets forgotten, and the release's own entries then sit
# under the previous version.
promote_changelog_build() {
    local build="$1" version="${2:-}"
    local heading="### Unreleased (next build)"
    [ -f "$CHANGELOG_FILE" ] || { say "no $CHANGELOG_FILE — skipping changelog stamp."; return 0; }

    # The Unreleased heading is immediately followed by its list items (nothing
    # in between), so "anything to promote" is: a list item before the next heading.
    awk '
        f && /^#/ { exit 1 }
        f && /^[[:space:]]*-[[:space:]]/ { exit 0 }
        $0 == h { f = 1 }
        END { if (!f) exit 1 }
    ' h="$heading" "$CHANGELOG_FILE" || {
        echo "  (Unreleased has no entries — nothing to promote)"
        return 0
    }

    local today tmp new_heading="" prefix
    today="$(date +%Y-%m-%d)"
    tmp="$(mktemp)"
    [ -z "$version" ] || new_heading="$(version_heading "$version")"
    # What every version heading starts with ("## v", "## ["): the template up
    # to {version}. A heading is that prefix followed by a digit.
    prefix="${SLIPWAY_VERSION_HEADING%%\{version\}*}"

    # Same version: rename Unreleased in place — its `## X.Y.Z` section is
    # already open above it.
    #
    # New version: the OLD heading must keep covering the builds it shipped. The
    # old heading line is replaced by the new section — new heading, fresh
    # Unreleased, this build's heading — and the old heading, with any prose
    # blurb under it, is re-opened just above its newest build.
    #
    # A new version whose heading is already there (written by hand) is
    # promoted in place under it, like a same-version build; one with no
    # version heading above Unreleased at all (the first) gets it put there.
    awk -v build="$build" -v today="$today" -v nh="$new_heading" -v prefix="$prefix" -v h="$heading" '
        function is_version_heading(line) {
            return index(line, prefix) == 1 && substr(line, length(prefix) + 1, 1) ~ /[0-9]/
        }
        nh != "" && !done && is_version_heading($0) && ($0 == nh || index($0, nh " ") == 1) { nh = "" }
        nh != "" && !done && is_version_heading($0) {
            old = $0
            print nh "\n"
            print h "\n"
            print "### build " build " — " today "\n"
            done = 1
            buffering = 1
            next
        }
        buffering && $0 == h { buffering = 0; eat_blank = 1; next }
        buffering { blurb = blurb $0 "\n"; next }
        eat_blank && /^$/ { eat_blank = 0; next }
        old != "" && /^### build / {
            print old
            if (blurb != "") printf "%s", blurb
            else print ""
            old = ""
            print
            next
        }
        $0 == h && !done {
            if (nh != "") print nh "\n"
            print h "\n\n### build " build " — " today
            done = 1
            next
        }
        { print }
    ' "$CHANGELOG_FILE" >"$tmp"
    mv "$tmp" "$CHANGELOG_FILE"
    git add "$CHANGELOG_FILE"
    if [ -n "$version" ]; then
        echo "  promoted Unreleased → v${version} build ${build}"
    else
        echo "  promoted Unreleased → build ${build}"
    fi
}

# The branch this release is cut from: main, or a version-line release branch
# (release/X.Y.x — a patch on a shipped version after main has moved on).
# A release/vX.Y.Z-N branch is the lane's own PR branch, left checked out by an
# interrupted publish — never a base.
release_base() {
    local b
    b="$(git rev-parse --abbrev-ref HEAD)"
    case "$b" in
        release/v*) die "on '$b' — the release lane's own PR branch, not a base. Check out main (or the version-line release branch) first." ;;
        main | release/*) printf '%s' "$b" ;;
        *) die "not on a release base (on '$b') — release from main or a version-line release/… branch." ;;
    esac
}

# The sole distinct value of a setting in project.yml (quoted or not), or die
# if it's missing or differs between targets (they're kept in lock-step).
read_unique() {
    local key="$1" vals
    vals="$(grep -oE "${key}: *\"?[^\"[:space:]#]+" "$PROJECT_FILE" | sed -E "s/^${key}: *\"?//" | sort -u)"
    [ -n "$vals" ] || die "no ${key} found in $PROJECT_FILE"
    [ "$(printf '%s\n' "$vals" | wc -l | tr -d ' ')" -eq 1 ] \
        || die "${key} differs between targets in $PROJECT_FILE: $(echo "$vals" | tr '\n' ' ')"
    printf '%s' "$vals"
}

# The highest build number N across every ios/ + mac/ vX.Y.Z-N tag, or 0. Lets
# publish tell "the base is a bumped-but-untagged tip" (already merged) from a
# fresh release, without any state file — the tags are the record.
highest_tagged_build() {
    local n max=0
    while IFS= read -r n; do [ "$n" -gt "$max" ] && max="$n"; done < <(
        git tag --list 'ios/v*' 'mac/v*' | grep -oE -- '-[0-9]+$' | tr -d '-'
    )
    printf '%s' "$max"
}

# The newest release tag across the given platforms, by (version, build).
newest_tag() {
    local p patterns=() t best="" best_key=-1 k
    for p in "$@"; do patterns+=("$(tag_prefix "$p")/v*"); done
    while IFS= read -r t; do
        [ -n "$t" ] || continue
        k="$(tag_sort_key "$t")"
        [ "$k" -gt "$best_key" ] && best="$t" && best_key="$k"
    done < <(git tag --list "${patterns[@]}")
    printf '%s' "$best"
}

tag_name() { printf '%s/v%s-%s' "$(tag_prefix "$1")" "$2" "$3"; }

# True if a git tag exists for this platform at version-build.
tag_exists() { git rev-parse --verify --quiet "$(tag_name "$1" "$2" "$3")" >/dev/null; }

# The previous release tag to diff notes against: the highest tag for this
# platform that is NOT newer than this release (and not itself). So an
# out-of-line release (a 0.1.x patch cut after 0.2.0 shipped) diffs against
# the prior 0.1.x, never against a version ahead of it. Nothing if none.
#
# Tags MUST be `<prefix>/vMAJOR.MINOR.PATCH-BUILD`: a `-beta.N` suffix would
# mis-sort (git reads it as a semver pre-release), so the strict form is
# load-bearing.
previous_tag() {
    local plat="$1" version="$2" build="$3"
    local prefix this this_key t k
    prefix="$(tag_prefix "$plat")"
    this="$(tag_name "$plat" "$version" "$build")"
    this_key="$(tag_sort_key "$this")"
    while IFS= read -r t; do
        [ "$t" = "$this" ] && continue
        k="$(tag_sort_key "$t")"
        if [ "$k" -le "$this_key" ]; then
            printf '%s' "$t"
            return
        fi
    done < <(git tag --list "${prefix}/v*" --sort=-v:refname)
}

# A sortable integer for a `<prefix>/vX.Y.Z-N` tag: X*1e12 + Y*1e8 + Z*1e4 + N.
tag_sort_key() {
    local v="${1#*/v}"
    local ver="${v%-*}" build="${v##*-}"
    local maj="${ver%%.*}"
    local rest="${ver#*.}"
    local min="${rest%%.*}"
    local pat="${rest#*.}"
    printf '%d' "$((maj * 1000000000000 + min * 100000000 + pat * 10000 + build))"
}

# True if a GitHub release exists for the given tag.
gh_release_exists() { gh release view "$1" >/dev/null 2>&1; }
