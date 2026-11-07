#!/usr/bin/env bash
# Read the project's slipway.yml. Sourced by common.sh for the functions; run
# directly (`config.sh <key>`) it prints one resolved setting, which is how
# slipway.mk reads them.
#
# slipway.yml is deliberately flat — `key: value` and `key: [a, b]` lines,
# `#` comments — so plain shell can read it without a YAML parser:
#
#   name: Yomidori                    # required: <name>.xcodeproj, <name>-iOS, …
#   display_name: Yomidori            # tags + GitHub release titles (default: name)
#   core_package: YomidoriCore        # Packages/<core>/ (default: <name>Core)
#   platforms: [ios, macos]           # what the project builds (default: [ios])
#   release_platforms: [ios, macos]   # what ships (default: platforms minus watchos)
#   changelog_version_heading: "## v{version}"   # default: "## [{version}]"
#   app_icon: Sources/…/icon-1024.png # optional: preflight refuses an alpha channel
#   pre_generate: Scripts/x.sh        # optional: run before every xcodegen
#
# Quote a value that contains `#` (the heading does), or it reads as a comment.

# shellcheck shell=bash

SLIPWAY_KEYS="name display_name core_package platforms release_platforms changelog_version_heading app_icon pre_generate"

slipway_config_die() { echo "error: $*" >&2; exit 1; }

# The raw value of a key, or nothing (exit 1) if the key isn't set.
slipway_config_raw() {
    local file="${SLIPWAY_CONFIG:-slipway.yml}"
    [ -f "$file" ] || slipway_config_die "no $file in $(pwd) — see Scripts/slipway/README.md"
    awk -v k="$1" '
        index($0, k ":") == 1 {
            v = substr($0, length(k) + 2)
            sub(/^[[:space:]]+/, "", v)
            if (v ~ /^"/)      { v = substr(v, 2); sub(/".*$/, "", v) }
            else if (v ~ /^'\''/) { v = substr(v, 2); sub(/'\''.*$/, "", v) }
            else               { sub(/[[:space:]]+#.*$/, "", v); sub(/[[:space:]]+$/, "", v) }
            print v; found = 1; exit
        }
        END { exit !found }
    ' "$file"
}

# A `[a, b]` list as "a b".
slipway_config_list() {
    local v
    v="$(slipway_config_raw "$1")" || return 1
    printf '%s' "$v" | tr -d '[]' | tr ',' ' ' | xargs
}

# A setting with its default applied.
slipway_get() {
    local v
    case "$1" in
        name)
            slipway_config_raw name || slipway_config_die "slipway.yml: 'name' is required" ;;
        display_name)
            slipway_config_raw display_name || slipway_get name ;;
        core_package)
            slipway_config_raw core_package || printf '%sCore' "$(slipway_get name)" ;;
        platforms)
            slipway_config_list platforms || printf 'ios' ;;
        release_platforms)
            slipway_config_list release_platforms || {
                v="$(slipway_get platforms)"
                printf '%s' "$v" | tr ' ' '\n' | grep -vx watchos | xargs
            } ;;
        changelog_version_heading)
            slipway_config_raw changelog_version_heading || printf '## [{version}]' ;;
        app_icon | pre_generate)
            slipway_config_raw "$1" || true ;;
        *) slipway_config_die "unknown slipway.yml key '$1'" ;;
    esac
}

# Refuse a config that would only fail later: unknown keys (typos), unknown
# platforms, a release platform that isn't built, a watch app with no iOS app
# to carry it.
slipway_validate() {
    local file="${SLIPWAY_CONFIG:-slipway.yml}" key p plats rels
    for key in $(sed -nE 's/^([a-z_]+):.*/\1/p' "$file"); do
        case " $SLIPWAY_KEYS " in *" $key "*) ;; *) slipway_config_die "slipway.yml: unknown key '$key'" ;; esac
    done
    slipway_get name >/dev/null
    plats="$(slipway_get platforms)"
    rels="$(slipway_get release_platforms)"
    [ -n "$plats" ] || slipway_config_die "slipway.yml: 'platforms' is empty"
    [ -n "$rels" ] || slipway_config_die "slipway.yml: 'release_platforms' is empty"
    for p in $plats; do
        case "$p" in ios | macos | watchos) ;; *) slipway_config_die "slipway.yml: unknown platform '$p' (ios|macos|watchos)" ;; esac
    done
    for p in $rels; do
        case "$p" in
            ios | macos) ;;
            watchos) slipway_config_die "slipway.yml: watchos can't be a release platform — the watch app ships inside the iOS app" ;;
            *) slipway_config_die "slipway.yml: unknown release platform '$p' (ios|macos)" ;;
        esac
        case " $plats " in *" $p "*) ;; *) slipway_config_die "slipway.yml: release platform '$p' isn't in platforms" ;; esac
    done
    case " $plats " in
        *" watchos "*) case " $plats " in *" ios "*) ;; *) slipway_config_die "slipway.yml: watchos needs ios (the watch app is embedded in it)" ;; esac ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -euo pipefail
    cd "$(dirname "$0")/../.."
    [ $# -eq 1 ] || slipway_config_die "usage: config.sh <key>"
    slipway_validate
    printf '%s\n' "$(slipway_get "$1")"
fi
