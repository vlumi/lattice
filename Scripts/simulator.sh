#!/usr/bin/env bash
# Booting a simulator under Xcode 27: there is no Simulator.app to do it, and a
# device whose runtime is listed but not mounted fails with "runtime path not
# found" while `simctl list devices available` still offers it. So the callers
# hand over every candidate, best first, and the first one that comes up is used.
#   boot_first_simulator <udid>...   prints the udid booted; fails when none boots

boot_first_simulator() {
    local udid err
    for udid in "$@"; do
        # Exit 149 is "already booted", which is fine; the state check below is what counts.
        err=$(xcrun simctl boot "$udid" 2>&1 >/dev/null) || true
        # Not grep -q: it quits at the first match, and under pipefail the long list then dies of SIGPIPE.
        if xcrun simctl list devices booted | grep "$udid" >/dev/null; then
            xcrun simctl bootstatus "$udid" >/dev/null 2>&1 || true
            echo "$udid"
            return 0
        fi
        echo "Could not boot $udid: ${err:-not booted}" >&2
    done
    return 1
}
