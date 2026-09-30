#!/usr/bin/env bash
# lib/tests/higgsfield.test.sh — hermetic suite for the Higgsfield pack.
#   sync    lib/higgsfield-skills.sh against a local git repo shaped like
#           upstream (no network), and its CLI probes against a fake CLI
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
# entries <dir> — how many entries the directory holds, hidden ones included.
entries() { find "$1" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' '; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Fake CLIs, first on PATH in every case that needs one. `higgsfield`
# answers per $FAKE_HF_BINARY (ok | missing: the npm shim without its
# binary) and $FAKE_HF_SESSION (in | out).
BIN="$WORK/bin"; mkdir -p "$BIN"
cat > "$BIN/higgsfield" <<'EOF'
#!/usr/bin/env bash
if [ "${FAKE_HF_BINARY:-ok}" = missing ]; then
  echo "@higgsfield/cli: binary not found" >&2; exit 1
fi
case "${1:-} ${2:-}" in
  "version ") echo "higgsfield 0.0.0 (fixture) built never"; exit 0 ;;
  "auth token")
    if [ "${FAKE_HF_SESSION:-in}" = in ]; then echo "fixture-token"; exit 0; fi
    echo "Error: Not authenticated." >&2; exit 2 ;;
esac
exit 64
EOF
cat > "$BIN/21st" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = whoami ] && echo "Logged in as fixture (saved in fixture)."
EOF
chmod +x "$BIN/higgsfield" "$BIN/21st"

# A PATH that holds the tools the scripts under test need and nothing else:
# no `higgsfield`, no `timeout`, whatever this machine has installed.
CLEAN="$WORK/cleanbin"; mkdir -p "$CLEAN"
for t in bash dirname basename mkdir mv rm ln sed; do
  ln -s "$(command -v "$t")" "$CLEAN/$t"
done

# git_q <dir> <git args...> — quiet git in a fixture repo: own identity, no
# hooks, so the machine's global git config never leaks in.
git_q() {
  local dir="$1"; shift
  git -C "$dir" -c user.name=fixture -c user.email=fixture@example.invalid \
    -c core.hooksPath=/dev/null -c init.defaultBranch=trunk "$@" \
    >/dev/null 2>&1
}

# mk_upstream <dir> — a git repo shaped like the upstream skills repo: three
# pack skills, a pack-named dir with no SKILL.md, a pack-named symlink to
# a foreign skill, and root machinery that must never be synced.
mk_upstream() {
  local up="$1" s
  mkdir -p "$up/scripts" "$up/higgsfield-noskill" "$up/other-skill"
  for s in higgsfield-generate higgsfield-soul-id higgsfield-websites; do
    mkdir -p "$up/$s/references"
    printf -- '---\nname: %s\n---\n' "$s" > "$up/$s/SKILL.md"
    echo "ref" > "$up/$s/references/notes.md"
  done
  echo "old" > "$up/higgsfield-generate/old.md"
  echo "no skill here" > "$up/higgsfield-noskill/README.md"
  ln -s other-skill "$up/higgsfield-linked"
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

# probe <path> <function> — run one CLI probe of the helper on the given
# PATH; prints everything it wrote, then "rc=<status>".
probe() {
  PATH="$1" bash -c 'source "$1/lib/higgsfield-skills.sh"; "$2"; echo "rc=$?"' \
    _ "$ROOT" "$2" 2>&1
}

# ── sync ────────────────────────────────────────────────────
UP="$WORK/upstream"; mk_upstream "$UP"
R1="$WORK/r1"; mkdir -p "$R1/skills" "$R1/skills-disabled"
EXT="$R1/skills-external"

expect fixture  "$(yn test -f "$UP/.git/HEAD")" yes
expect rc-count "$(sync_into "$R1")" "0:3"
expect generate "$(yn test -f "$EXT/higgsfield-generate/SKILL.md")" yes
expect refs \
  "$(yn test -f "$EXT/higgsfield-soul-id/references/notes.md")" yes
expect websites "$(yn test -f "$EXT/higgsfield-websites/SKILL.md")" yes
expect noskill  "$(yn test -e "$EXT/higgsfield-noskill")" no
expect symlink  "$(yn test -L "$EXT/higgsfield-linked")" no
expect no-other "$(yn test -e "$EXT/other-skill")" no
expect no-setup "$(yn test -e "$EXT/setup")" no
expect no-git   "$(find "$EXT" -name .git | wc -l | tr -d ' ')" 0
expect entries  "$(entries "$EXT")" 3
verdict SYNC_MOVES_PACK_ONLY

rm "$UP/higgsfield-generate/old.md"
echo "new" > "$UP/higgsfield-generate/new.md"
git_q "$UP" add -A; git_q "$UP" commit -m refresh
expect before    "$(yn test -f "$EXT/higgsfield-generate/old.md")" yes
expect rc-count  "$(sync_into "$R1")" "0:3"
expect stale-out "$(yn test -e "$EXT/higgsfield-generate/old.md")" no
expect new-in    "$(yn test -f "$EXT/higgsfield-generate/new.md")" yes
verdict SYNC_REFRESH_DROPS_STALE

ln -s "$EXT/higgsfield-soul-id" "$R1/skills-disabled/higgsfield-soul-id"
ln -s "$EXT/higgsfield-generate" "$R1/skills/higgsfield-generate"
expect rc-count    "$(sync_into "$R1")" "0:3"
expect parked-link "$(yn test -L "$R1/skills-disabled/higgsfield-soul-id")" yes
expect parked-reads \
  "$(yn test -f "$R1/skills-disabled/higgsfield-soul-id/SKILL.md")" yes
expect not-enabled "$(yn test -e "$R1/skills/higgsfield-soul-id")" no
expect live-reads  "$(yn test -f "$R1/skills/higgsfield-generate/SKILL.md")" yes
verdict SYNC_KEEPS_PARKED

BARE="$WORK/bare-upstream"; mkdir -p "$BARE"; echo "x" > "$BARE/README.md"
git_q "$BARE" init; git_q "$BARE" add -A; git_q "$BARE" commit -m fixture
expect no-repo   "$(sync_into "$R1" "$WORK/no-such-repo")" "1:0"
expect no-skills "$(sync_into "$R1" "$BARE")" "1:0"
expect copy-kept "$(yn test -f "$EXT/higgsfield-generate/new.md")" yes
expect entries   "$(entries "$EXT")" 3
verdict SYNC_FAIL_KEEPS_COPY

expect cli-ok      "$(probe "$BIN:$PATH" higgsfield_cli_ok)" "rc=0"
expect signed-in   "$(probe "$BIN:$PATH" higgsfield_signed_in)" "rc=0"
expect signed-out  \
  "$(FAKE_HF_SESSION=out probe "$BIN:$PATH" higgsfield_signed_in)" "rc=2"
expect shim-only   \
  "$(FAKE_HF_BINARY=missing probe "$BIN:$PATH" higgsfield_cli_ok)" "rc=1"
expect no-cli      "$(probe "$CLEAN" higgsfield_cli_ok)" "rc=127"
expect no-timeout  "$(probe "$BIN:$CLEAN" higgsfield_cli_ok)" "rc=0"
verdict PROBES_SILENT

# ── tally ───────────────────────────────────────────────────
printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
