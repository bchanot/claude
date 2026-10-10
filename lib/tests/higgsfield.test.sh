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
trap 'rm -rf "${WORK:?}"' EXIT

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
# The repo path carries a space on purpose: every expansion must be quoted.
R1="$WORK/r 1"; mkdir -p "$R1/skills" "$R1/skills-disabled"
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
# macOS spelling: only `gtimeout` exists. A wrapper, not a symlink: a
# multi-call coreutils binary dispatches on the name it is invoked under.
GT="$WORK/gtbin"; mkdir -p "$GT"
printf '#!/bin/sh\nexec %s "$@"\n' "$(command -v timeout)" > "$GT/gtimeout"
chmod +x "$GT/gtimeout"
expect gtimeout    "$(probe "$BIN:$GT:$CLEAN" higgsfield_signed_in)" "rc=0"
verdict PROBES_SILENT

# ── toggle ──────────────────────────────────────────────────
# mk_toggle_fx <dir> [skill...] — fixture repo: the toggle script plus one
# skills-external source per named skill (none → installed-nothing tree).
mk_toggle_fx() {
  local fx="$1" s; shift
  mkdir -p "$fx/lib" "$fx/skills"
  cp "$ROOT/lib/toggle-external.sh" "$ROOT/lib/gstack-removed.sh" "$fx/lib/"
  for s in "$@"; do
    mkdir -p "$fx/skills-external/$s"
    echo "---" > "$fx/skills-external/$s/SKILL.md"
  done
}
PACK=(higgsfield-generate higgsfield-soul-id higgsfield-websites)

# tog <fixture> <args...> — run the fixture's toggle script, fake CLIs first.
tog() {
  local fx="$1"; shift
  TOGGLE_EXTERNAL_REPO_OVERRIDE="$fx" PATH="$BIN:$PATH" \
    bash "$fx/lib/toggle-external.sh" "$@" 2>&1
}
# list_row <fixture> <tool> — the status column of `list` for one tool.
list_row() { tog "$1" list | awk -v t="$2" '$1 == t { print $2 }'; }

F0="$WORK/f0"; mk_toggle_fx "$F0"
F1="$WORK/f1"; mk_toggle_fx "$F1" "${PACK[@]}"
expect pack-missing  "$(tog "$F0" status higgsfield)" missing
expect web-missing   "$(tog "$F0" status higgsfield-websites)" missing
expect pack-disabled "$(tog "$F1" status higgsfield)" disabled
expect web-disabled  "$(tog "$F1" status higgsfield-websites)" disabled
ln -s "$F1/skills-external/higgsfield-generate" "$F1/skills/higgsfield-generate"
expect pack-partial  "$(tog "$F1" status higgsfield)" enabled
expect web-apart     "$(tog "$F1" status higgsfield-websites)" disabled
expect list-pack     "$(list_row "$F1" higgsfield)" enabled
expect list-web      "$(list_row "$F1" higgsfield-websites)" disabled
verdict STATUS_STATES

F2="$WORK/f2"; mk_toggle_fx "$F2" "${PACK[@]}"
out="$(tog "$F2" enable higgsfield)"; rc=$?
expect rc "$rc" 0
expect generate "$(readlink "$F2/skills/higgsfield-generate")" \
  "$F2/skills-external/higgsfield-generate"
expect soul-id "$(readlink "$F2/skills/higgsfield-soul-id")" \
  "$F2/skills-external/higgsfield-soul-id"
expect no-websites "$(yn test -e "$F2/skills/higgsfield-websites")" no
expect_has count "$out" "higgsfield enabled (2 skills: 0 restored, 2 linked)"
out="$(tog "$F2" enable higgsfield)"; rc=$?
expect again-rc "$rc" 0
expect_has again "$out" "higgsfield already enabled"
verdict ENABLE_PACK_EXCLUDES_WEBSITES

# The media pack is an allowlist: a synced skill nobody listed is reported,
# never linked; neither is a listed name whose directory holds no SKILL.md.
F8="$WORK/f 8"; mk_toggle_fx "$F8" "${PACK[@]}" higgsfield-newcomer
mkdir -p "$F8/skills-external/higgsfield-brandkit" \
  "$F8/skills-external/higgsfield-noskill"
out="$(tog "$F8" enable higgsfield)"; rc=$?
expect rc "$rc" 0
expect_has count "$out" "higgsfield enabled (2 skills: 0 restored, 2 linked)"
expect newcomer-off "$(yn test -e "$F8/skills/higgsfield-newcomer")" no
expect brandkit-off "$(yn test -e "$F8/skills/higgsfield-brandkit")" no
expect_has reported "$out" "higgsfield-newcomer"
expect_not noskill-quiet "$out" "higgsfield-noskill"
expect links "$(entries "$F8/skills")" 2
# Enabled is the steady state: a re-run must still name the drift.
out="$(tog "$F8" enable higgsfield)"; rc=$?
expect again-rc "$rc" 0
expect_has again-state "$out" "higgsfield already enabled"
expect_has again-reported "$out" "higgsfield-newcomer"
verdict UNLISTED_NOT_LINKED

F3="$WORK/f3"; mk_toggle_fx "$F3" "${PACK[@]}"
out="$(tog "$F3" enable higgsfield-websites)"; rc=$?
expect rc "$rc" 0
expect link "$(readlink "$F3/skills/higgsfield-websites")" \
  "$F3/skills-external/higgsfield-websites"
expect no-generate "$(yn test -e "$F3/skills/higgsfield-generate")" no
expect pack-status "$(tog "$F3" status higgsfield)" disabled
expect web-status  "$(tog "$F3" status higgsfield-websites)" enabled
tog "$F3" disable higgsfield-websites >/dev/null
out="$(FAKE_HF_SESSION=out tog "$F3" enable higgsfield-websites)"; rc=$?
expect hint-rc "$rc" 0
expect_has web-hint "$out" "higgsfield auth login"
verdict ENABLE_WEBSITES_ALONE

# Continues on F2: the pack is enabled, websites is not.
tog "$F2" enable higgsfield-websites >/dev/null
out="$(tog "$F2" disable higgsfield)"; rc=$?
expect rc "$rc" 0
expect_has msg "$out" "higgsfield disabled (2 skills parked)"
expect parked "$(yn test -L "$F2/skills-disabled/higgsfield-generate")" yes
expect unlinked      "$(yn test -e "$F2/skills/higgsfield-generate")" no
expect web-untouched "$(yn test -e "$F2/skills/higgsfield-websites")" yes
out="$(tog "$F2" enable higgsfield)"
expect_has restored "$out" "2 restored, 0 linked"
tog "$F2" disable higgsfield-websites >/dev/null
expect web-parked "$(yn test -L "$F2/skills-disabled/higgsfield-websites")" yes
expect pack-on    "$(tog "$F2" status higgsfield)" enabled
verdict DISABLE_PARKS

F4="$WORK/f4"; mk_toggle_fx "$F4" "${PACK[@]}"
out="$(FAKE_HF_SESSION=out tog "$F4" enable higgsfield)"; rc=$?
expect out-rc "$rc" 0
expect out-linked "$(yn test -e "$F4/skills/higgsfield-generate")" yes
expect_has out-hint "$out" "higgsfield auth login"
F5="$WORK/f5"; mk_toggle_fx "$F5" "${PACK[@]}"
out="$(FAKE_HF_SESSION=in tog "$F5" enable higgsfield)"
expect_not in-quiet "$out" "auth login"
expect_not in-no-token "$out" "fixture-token"
F6="$WORK/f6"; mk_toggle_fx "$F6" "${PACK[@]}"
out="$(TOGGLE_EXTERNAL_REPO_OVERRIDE="$F6" PATH="$CLEAN" \
  bash "$F6/lib/toggle-external.sh" enable higgsfield 2>&1)"; rc=$?
expect absent-rc "$rc" 0
expect absent-linked "$(yn test -e "$F6/skills/higgsfield-generate")" yes
expect_has absent-hint "$out" "not on PATH"
F9="$WORK/f9"; mk_toggle_fx "$F9" "${PACK[@]}"
out="$(FAKE_HF_BINARY=missing tog "$F9" enable higgsfield)"; rc=$?
expect shim-rc "$rc" 0
expect_has shim-hint "$out" "does not answer"
expect_not shim-not-login "$out" "auth login"
verdict SIGNED_OUT_WARNS

out="$(tog "$F0" enable higgsfield)"; rc=$?
expect pack-rc "$rc" 1
expect_has pack-path "$out" "$F0/skills-external"
out="$(tog "$F0" enable higgsfield-websites)"; rc=$?
expect web-rc "$rc" 1
expect_has web-path "$out" "$F0/skills-external/higgsfield-websites"
verdict ENABLE_MISSING_ERRS

# The pack arms are shared with 21st: its behaviour must not move.
F7="$WORK/f7"; mk_toggle_fx "$F7" 21st-one 21st-two
expect off "$(tog "$F7" status 21st)" disabled
out="$(tog "$F7" enable 21st)"
expect_has on "$out" "21st enabled (2 skills: 0 restored, 2 linked)"
expect_not quiet "$out" "21st login"
expect hf-apart "$(tog "$F7" status higgsfield)" missing
out="$(tog "$F7" disable 21st)"
expect_has parked "$out" "21st disabled (2 skills parked)"
verdict PACK_21ST_UNCHANGED

# ── wiring ──────────────────────────────────────────────────
# count <file> <fixed string> — matching lines (0 when none).
count() { grep -cF -- "$2" "$ROOT/$1"; }

# Positive control first: the pattern does bite on a line that carries it.
expect control    "$(echo 'higgsfield-x external' | grep -cF higgsfield)" 1
expect link-sh    "$(count link.sh higgsfield)" 0
expect profile-sh "$(count lib/profile.sh higgsfield)" 0
expect profiles \
  "$(cat "$ROOT"/lib/profiles/*.profile | grep -cF higgsfield)" 0
verdict OFF_BY_DEFAULT_WIRING

# ln_first / ln_last <file> <fixed string> — line number of a match.
ln_first() { grep -nF -- "$2" "$ROOT/$1" | head -1 | cut -d: -f1; }
ln_last()  { grep -nF -- "$2" "$ROOT/$1" | tail -1 | cut -d: -f1; }

# install-plugins.sh: the sync sits in Step 8.6; the CLI is proven by a
# probe, not by its shim; every login offer tests stdin alone (stdout is
# the tee pipe).
sync_ln="$(ln_last install-plugins.sh 'higgsfield_sync_skills')"
expect after-8.5 "$(yn test "$sync_ln" -gt \
  "$(ln_first install-plugins.sh 'Step 8.5: External skills')")" yes
expect before-8.7 "$(yn test "$sync_ln" -lt \
  "$(ln_first install-plugins.sh 'Step 8.7: 21st.dev')")" yes
expect probe-gates \
  "$(yn test "$(count install-plugins.sh 'if higgsfield_cli_ok')" -ge 3)" yes
expect control "$(echo 'if [ -t 0 ] && [ -t 1 ]; then' | grep -cF -- '-t 1')" 1
expect no-stdout-test "$(count install-plugins.sh '-t 1')" 0
expect stdin-tests \
  "$(yn test "$(count install-plugins.sh '[ -t 0 ]')" -ge 3)" yes
verdict INSTALL_WIRING

# update-all.sh: refresh before the 21st block, and the updated CLI is
# proven by the probe, after the npm call.
NPM_UP="npm install -g \"\$HF_PKG\""
sync_ln="$(ln_last update-all.sh 'higgsfield_sync_skills')"
expect before-21st "$(yn test "$sync_ln" -lt \
  "$(ln_first update-all.sh '7.4. Update the 21st.dev')")" yes
expect probe-after-npm "$(yn test \
  "$(ln_first update-all.sh 'higgsfield_cli_ok')" -gt \
  "$(ln_last update-all.sh "$NPM_UP")")" yes
verdict UPDATE_WIRING

# ── tally ───────────────────────────────────────────────────
printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
