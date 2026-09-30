#!/usr/bin/env bash
# lib/tests/higgsfield.test.sh — hermetic suite for the Higgsfield pack.
#   sync    lib/higgsfield-skills.sh against a local git repo shaped like
#           upstream (no network)
#   toggle  lib/toggle-external.sh `higgsfield` / `higgsfield-websites`
#           against a fixture tree, fake CLIs first on PATH
#   wiring  static locks on the installers (order, off by default)
# Each named case prints one `PASS <NAME>` or `FAIL <NAME>:<details>` line.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0; errs=""

# expect <label> <got> <want> — record a mismatch for the current case.
expect() { [ "$2" = "$3" ] || errs="$errs $1(got[$2] want[$3])"; }
# expect_has / expect_not <label> <text> <fragment>
expect_has() { case "$2" in *"$3"*) ;; *) errs="$errs $1(lacks[$3])" ;; esac; }
expect_not() { case "$2" in *"$3"*) errs="$errs $1(has[$3])" ;; esac; }
# verdict <NAME> — close the current case: PASS when nothing was recorded.
verdict() {
  if [ -z "$errs" ]; then pass=$((pass + 1)); printf 'PASS %s\n' "$1"
  else fail=$((fail + 1)); printf 'FAIL %s:%s\n' "$1" "$errs"; fi
  errs=""
}
# yn <command...> — "yes" when the command succeeds, else "no".
yn() { if "$@" 2>/dev/null; then echo yes; else echo no; fi; }
entries() { find "$1" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' '; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# git_q <dir> <git args...> — quiet git in a fixture repo: own identity, no
# hooks, so the machine's global git config never leaks in.
git_q() {
  local dir="$1"; shift
  git -C "$dir" -c user.name=fixture -c user.email=fixture@example.invalid \
    -c core.hooksPath=/dev/null -c init.defaultBranch=trunk "$@" \
    >/dev/null 2>&1
}

# mk_upstream <dir> — a git repo shaped like the upstream skills repo: three
# pack skills, one pack-named dir with no SKILL.md, one foreign skill, and
# root machinery that must never be synced.
mk_upstream() {
  local up="$1" s
  mkdir -p "$up/scripts" "$up/higgsfield-empty" "$up/other-skill"
  for s in higgsfield-alpha higgsfield-beta higgsfield-websites; do
    mkdir -p "$up/$s/references"
    printf -- '---\nname: %s\n---\n' "$s" > "$up/$s/SKILL.md"
    echo "ref" > "$up/$s/references/notes.md"
  done
  echo "old" > "$up/higgsfield-alpha/old.md"
  echo "---" > "$up/other-skill/SKILL.md"
  echo "#!/bin/sh" > "$up/setup"
  echo "#!/bin/sh" > "$up/scripts/update-check.sh"
  git_q "$up" init
  git_q "$up" add -A
  git_q "$up" commit -m fixture
}

# sync_into <repo> [url] — run the helper in a subshell; prints "<rc>:<count>".
sync_into() {
  (
    export HIGGSFIELD_SKILLS_URL="${2:-$UP}"
    # shellcheck source=lib/higgsfield-skills.sh disable=SC1091
    source "$ROOT/lib/higgsfield-skills.sh"
    out="$(higgsfield_sync_skills "$1")"
    printf '%s:%s' "$?" "$out"
  )
}

# ── sync ────────────────────────────────────────────────────
UP="$WORK/upstream"; mk_upstream "$UP"
R1="$WORK/r1"; mkdir -p "$R1/skills" "$R1/skills-disabled"
EXT="$R1/skills-external"

expect rc-count "$(sync_into "$R1")" "0:3"
expect alpha    "$(yn test -f "$EXT/higgsfield-alpha/SKILL.md")" yes
expect refs     "$(yn test -f "$EXT/higgsfield-beta/references/notes.md")" yes
expect websites "$(yn test -f "$EXT/higgsfield-websites/SKILL.md")" yes
expect no-empty "$(yn test -e "$EXT/higgsfield-empty")" no
expect no-other "$(yn test -e "$EXT/other-skill")" no
expect no-setup "$(yn test -e "$EXT/setup")" no
expect no-git   "$(find "$EXT" -name .git | wc -l | tr -d ' ')" 0
expect entries  "$(entries "$EXT")" 3
verdict SYNC_MOVES_PACK_ONLY

rm "$UP/higgsfield-alpha/old.md"; echo "new" > "$UP/higgsfield-alpha/new.md"
git_q "$UP" add -A; git_q "$UP" commit -m refresh
expect before    "$(yn test -f "$EXT/higgsfield-alpha/old.md")" yes
expect rc-count  "$(sync_into "$R1")" "0:3"
expect stale-out "$(yn test -e "$EXT/higgsfield-alpha/old.md")" no
expect new-in    "$(yn test -f "$EXT/higgsfield-alpha/new.md")" yes
verdict SYNC_REFRESH_DROPS_STALE

ln -s "$EXT/higgsfield-beta" "$R1/skills-disabled/higgsfield-beta"
ln -s "$EXT/higgsfield-alpha" "$R1/skills/higgsfield-alpha"
expect rc-count     "$(sync_into "$R1")" "0:3"
expect parked-link  "$(yn test -L "$R1/skills-disabled/higgsfield-beta")" yes
expect parked-reads \
  "$(yn test -f "$R1/skills-disabled/higgsfield-beta/SKILL.md")" yes
expect not-enabled  "$(yn test -e "$R1/skills/higgsfield-beta")" no
expect live-reads   "$(yn test -f "$R1/skills/higgsfield-alpha/SKILL.md")" yes
verdict SYNC_KEEPS_PARKED

BARE="$WORK/bare-upstream"; mkdir -p "$BARE"; echo "x" > "$BARE/README.md"
git_q "$BARE" init; git_q "$BARE" add -A; git_q "$BARE" commit -m fixture
expect no-repo   "$(sync_into "$R1" "$WORK/no-such-repo")" "1:0"
expect no-skills "$(sync_into "$R1" "$BARE")" "1:0"
expect copy-kept "$(yn test -f "$EXT/higgsfield-alpha/new.md")" yes
expect entries   "$(entries "$EXT")" 3
verdict SYNC_FAIL_KEEPS_COPY

# ── tally ───────────────────────────────────────────────────
printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
