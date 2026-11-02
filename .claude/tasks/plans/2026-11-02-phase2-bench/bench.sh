#!/usr/bin/env bash
# bench.sh [id…] — one isolated headless run per cases.tsv row (all rows, or
# the ids given), auto mode, rule present; one control per ASKED/DENIED row
# with the same command and no rule. Appends to results.tsv, never
# truncates: the last row per id wins. Harmless commands, fresh temp dir.
set -u
B="$(cd "$(dirname "$0")" && pwd)"
W="$(mktemp -d)"; mkdir -p "$W/sub" && git -C "$W" init -q
printf 'X=1\n' > "$W/.env"; printf 'X=1\n' > "$W/sub/.env"
settings() { # settings <kind|none> <rule> <file>
  jq -n --arg k "$1" --arg r "$2" '{permissions: ({allow: ["Bash(*)"],
    defaultMode: "auto"} + (if $k == "none" then {} else {($k): [$r]} end)),
    skipAutoPermissionPrompt: true}' > "$3"
}
wanted() { [ "$#" -eq 1 ] && return 0; local x; for x in "${@:2}"; do
  [ "$x" = "$1" ] && return 0; done; return 1; }
while IFS=$'\t' read -r id kind rule cmd want; do
  [ -n "$id" ] || continue
  wanted "$id" "$@" || continue
  printf '%b' "$cmd" > "$W/cmd.txt"
  settings "$kind" "$rule" "$W/s.json"
  printf '%s\t' "$want" >> "$B/results.tsv"
  bash "$B/run.sh" "$id" "$W/cmd.txt" "$W/s.json" "$W" </dev/null \
    >> "$B/results.tsv"
  case "$want" in ASKED|DENIED) ;; *) continue ;; esac
  settings none "" "$W/n.json"
  printf 'control\t' >> "$B/results.tsv"
  bash "$B/run.sh" "$id-ctl" "$W/cmd.txt" "$W/n.json" "$W" </dev/null \
    >> "$B/results.tsv"
done < "$B/cases.tsv"
echo "bench dir kept: $W"
