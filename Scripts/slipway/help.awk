# `make help`: lists the `target: ## text` lines of the given makefiles, grouped
# by their `##@ Section` headings, with `##~ text` lines as dim hints.
#
# Sections merge by name across files, in first-seen order (slipway.mk is read
# first, so its order holds), and print only when something in them shows. A
# `##@> Section` heading is listed after all the others — slipway's release
# sections, so the project's own day-to-day sections come before them. A
# text starting with `[platform] ` shows only if that platform is in `plats`
# (space-padded: " ios macos ") — awk reads the text, not the `ifneq`s that
# leave the target undefined.
BEGIN { FS = ":.*## " }
function keep(s,   p) {
    if (s !~ /^\[[a-z]+\] /) return 1
    p = substr(s, 2, index(s, "]") - 2)
    return index(plats, " " p " ") > 0
}
function strip(s) { sub(/^\[[a-z]+\] /, "", s); return s }
function add(line) {
    if (!(sec in body)) order[++n] = sec
    body[sec] = body[sec] line "\n"
}
FNR == 1 { sec = "General" }
/^##@ / { sec = substr($0, 5); next }
/^##@> / { sec = substr($0, 6); last[sec] = 1; next }
/^##~ / { s = substr($0, 5); if (keep(s)) add(sprintf("  \033[2m%s\033[0m", strip(s))); next }
/^[a-zA-Z0-9_-]+:.*## / { if (keep($2)) add(sprintf("  \033[36m%-30s\033[0m %s", $1, strip($2))) }
function show(s) { printf "\n\033[1m%s\033[0m\n%s", s, body[s] }
END {
    for (i = 1; i <= n; i++) if (!(order[i] in last)) show(order[i])
    for (i = 1; i <= n; i++) if (order[i] in last) show(order[i])
}
