# Sourced by every slipway script: moves to the project root, loads and checks
# slipway.yml, and defines the logging, retry and per-platform helpers.

# shellcheck shell=bash
# shellcheck disable=SC2034  # the settings are read by the scripts that source this

SLIPWAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SLIPWAY_DIR/../.." || exit 1

# shellcheck source=config.sh
. "$SLIPWAY_DIR/config.sh"

say() { printf '\033[36m▶︎ %s\033[0m\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }

slipway_validate
SLIPWAY_NAME="$(slipway_get name)"
SLIPWAY_DISPLAY_NAME="$(slipway_get display_name)"
SLIPWAY_CORE="$(slipway_get core_package)"
SLIPWAY_PLATFORMS="$(slipway_get platforms)"
SLIPWAY_RELEASE_PLATFORMS="$(slipway_get release_platforms)"
SLIPWAY_VERSION_HEADING="$(slipway_get changelog_version_heading)"
SLIPWAY_APP_ICON="$(slipway_get app_icon)"
SLIPWAY_PRE_GENERATE="$(slipway_get pre_generate)"
SLIPWAY_XCODEPROJ="${SLIPWAY_NAME}.xcodeproj"
PROJECT_FILE="project.yml"
CHANGELOG_FILE="CHANGELOG.md"

# Run a command, retrying on failure a few times with backoff — for GitHub API
# calls, where a transient 502/timeout must not abort a release mid-flight.
# Returns the LAST attempt's exit code, so a caller that cares about a specific
# code (`gh pr checks` exit 8 = pending) still sees it.
gh_retry() {
    local tries=0 max=5 rc=0
    while :; do
        "$@" && return 0
        rc=$?
        tries=$((tries + 1))
        [ "$tries" -ge "$max" ] && return "$rc"
        echo "  (GitHub call failed, rc=$rc — retry $tries/$((max - 1)) in $((tries * 2))s)" >&2
        sleep $((tries * 2))
    done
}

# Per-platform names. The schemes follow XcodeGen's `<target>` naming, with the
# targets called <name>-iOS / -macOS / -watchOS.
plat_label() {
    case "$1" in ios) echo iOS ;; macos) echo macOS ;; watchos) echo watchOS ;; *) die "unknown platform '$1'" ;; esac
}
plat_scheme() { echo "${SLIPWAY_NAME}-$(plat_label "$1")"; }
tag_prefix() {
    case "$1" in ios) echo ios ;; macos) echo mac ;; *) die "no release tags for platform '$1'" ;; esac
}

# A release scope argument (all, or one release platform) as the list of
# platforms it covers.
release_scope() {
    case "${1:-}" in
        all) echo "$SLIPWAY_RELEASE_PLATFORMS" ;;
        *)
            case " $SLIPWAY_RELEASE_PLATFORMS " in
                *" ${1:-} "*) [ -n "${1:-}" ] && echo "$1" && return ;;
            esac
            die "platform must be all or one of: $SLIPWAY_RELEASE_PLATFORMS (got '${1:-}')"
            ;;
    esac
}
