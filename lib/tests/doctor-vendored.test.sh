#!/usr/bin/env bash
# lib/tests/doctor-vendored.test.sh — lib/doctor-vendored.sh's
# check_vendored_skills(): a fixture repo under mktemp with a fake
# plugins.lock.json (single-path shape, list shape, dict shape with a
# references/ file), a fake link.sh holding a multi-line
# EXTERNAL_SKILLS=(...) array and a fake <claude_home>/skills dir.
# Cases: every file present + linked (ALL_PRESENT), a
# list-shape skill missing its SKILL.md (FILE_MISSING), a dict-shape
# skill missing one of two files — only that file is named
# (DICT_FILES_COMPLETE), a linked name with no symlink
# (SYMLINK_MISSING_ACTIVE) or a symlink to the wrong target
# (SYMLINK_WRONG_TARGET), an unreadable lock file degrading to a
# warn instead of a fail (LOCK_UNREADABLE, rc 0), a lock entry whose
# "skills" is neither null/list/dict degrading the same way with no
# Python traceback leaking (LOCK_MALFORMED_ENTRY, rc 0), the
# item-name allowlist rejecting a
# link.sh entry with a ".." segment — warned and skipped, not failed
# (REJECTS_BAD_NAME), and an "always_on": true lock entry's name with no
# symlink failing like any other (ALWAYS_ON_LINK_CHECKED). Git-tree
# dests in link.sh: an absent one only warns via check_vendored_trees
# (TREE_OWNED_ABSENT_WARN_ONLY), a present one skips the file check
# (TREE_OWNED_FILES_SKIPPED) but has its symlink checked
# (TREE_OWNED_LINK_CHECKED), and a broken lock never trips errexit
# (TREE_NAMES_ERREXIT_BROKEN_LOCK).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/lib/doctor-vendored.sh"
pass=0; fail=0

check_bool() {
  local name="$1" ok="$2"
  if [ "$ok" = 1 ]; then pass=$((pass+1)); echo "PASS $name"
  else fail=$((fail+1)); echo "FAIL $name"; fi
}

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
REPO="$WORK/repo"
CLAUDE_HOME="$WORK/claude_home"
mkdir -p "$REPO/skills-external" "$CLAUDE_HOME/skills"

# ── Lock: "ok-skill" mirrors the emil-design-eng single-file "path"
# shape (the key IS the name); "list-entry" mirrors the agent-skills
# bare-list shape (5 names, each defaults to SKILL.md); "dict-entry"
# mirrors the mengto-skills explicit shape (dict-skill needs SKILL.md +
# references/notes.md, and only the latter is ever missing below).
cat > "$REPO/plugins.lock.json" <<'JSON'
{
  "ok-skill": {
    "path": "skills/ok-skill/SKILL.md",
    "managed_by": "curl"
  },
  "list-entry": {
    "managed_by": "curl",
    "skills": [
      "missing-skill", "active-nolink-skill", "active-wronglink-skill"
    ]
  },
  "dict-entry": {
    "managed_by": "curl",
    "skills": {"dict-skill": ["SKILL.md", "references/notes.md"]}
  },
  "always-on-entry": {
    "managed_by": "curl",
    "always_on": true,
    "skills": ["always-on-skill"]
  }
}
JSON

# ── link.sh: a multi-line EXTERNAL_SKILLS array, tolerance-tested.
cat > "$REPO/link.sh" <<'SH'
#!/usr/bin/env bash
EXTERNAL_SKILLS=(ok-skill missing-skill dict-skill
  active-nolink-skill active-wronglink-skill always-on-skill)
SH

# ── skills-external/ tree: every name's SKILL.md present, except
# missing-skill (nothing at all) and dict-skill's references/notes.md.
# always-on-skill has its SKILL.md too — only its symlink is missing.
for n in ok-skill dict-skill active-nolink-skill active-wronglink-skill \
         always-on-skill; do
  mkdir -p "$REPO/skills-external/$n"
  echo "v1" > "$REPO/skills-external/$n/SKILL.md"
done

# ── claude_home symlinks: ok-skill correct, active-wronglink-skill
# points elsewhere, active-nolink-skill and always-on-skill have none.
ln -sf "$REPO/skills-external/ok-skill" "$CLAUDE_HOME/skills/ok-skill"
mkdir -p "$WORK/elsewhere"
ln -sf "$WORK/elsewhere" "$CLAUDE_HOME/skills/active-wronglink-skill"

# shellcheck source=../doctor-vendored.sh disable=SC1091
source "$LIB"

out1="$(check_vendored_skills "$REPO" "$CLAUDE_HOME" 2>&1)"

check_bool ALL_PRESENT \
  "$(printf '%s' "$out1" | grep -qF 'ok-skill: vendored + linked' \
    && echo 1 || echo 0)"

check_bool FILE_MISSING \
  "$(printf '%s' "$out1" | \
    grep -qF 'missing-skill: skills-external/missing-skill/SKILL.md missing' \
    && echo 1 || echo 0)"

check_bool DICT_FILES_COMPLETE \
  "$(printf '%s' "$out1" | grep -qF \
      'dict-skill: skills-external/dict-skill/references/notes.md missing' \
    && ! printf '%s' "$out1" | grep -qF \
      'dict-skill: skills-external/dict-skill/SKILL.md missing' \
    && echo 1 || echo 0)"

check_bool SYMLINK_MISSING_ACTIVE \
  "$(printf '%s' "$out1" | \
    grep -qF 'active-nolink-skill: symlink missing/wrong' && echo 1 || echo 0)"

check_bool SYMLINK_WRONG_TARGET \
  "$(printf '%s' "$out1" | \
    grep -qF 'active-wronglink-skill: symlink missing/wrong' \
    && echo 1 || echo 0)"

check_bool ALWAYS_ON_LINK_CHECKED \
  "$(printf '%s' "$out1" | \
    grep -qF 'always-on-skill: symlink missing/wrong' && echo 1 || echo 0)"

# ── LOCK_UNREADABLE — a second, minimal fixture with an invalid
# plugins.lock.json: check_vendored_skills degrades to a warn (not a
# fail) and still returns 0.
BROKEN="$WORK/broken"
mkdir -p "$BROKEN/skills-external/solo-skill"
echo "v1" > "$BROKEN/skills-external/solo-skill/SKILL.md"
echo "not valid json" > "$BROKEN/plugins.lock.json"
cat > "$BROKEN/link.sh" <<'SH'
#!/usr/bin/env bash
EXTERNAL_SKILLS=(solo-skill)
SH
out3="$(check_vendored_skills "$BROKEN" "$CLAUDE_HOME" 2>&1)"
rc3=$?
check_bool LOCK_UNREADABLE \
  "$([ "$rc3" -eq 0 ] && printf '%s' "$out3" | \
    grep -qF 'plugins.lock.json unreadable' && echo 1 || echo 0)"

# ── LOCK_MALFORMED_ENTRY — a valid-JSON lock whose "skills" is a bare
# number (neither null, list nor dict): degrades to the same warn as an
# unreadable lock, rc 0, and no Python traceback text anywhere in the
# captured output.
MALFORMED="$WORK/malformed"
mkdir -p "$MALFORMED/skills-external/bad-entry"
echo "v1" > "$MALFORMED/skills-external/bad-entry/SKILL.md"
cat > "$MALFORMED/plugins.lock.json" <<'JSON'
{
  "bad-entry": {
    "managed_by": "curl",
    "skills": 42
  }
}
JSON
cat > "$MALFORMED/link.sh" <<'SH'
#!/usr/bin/env bash
EXTERNAL_SKILLS=(bad-entry)
SH
out4="$(check_vendored_skills "$MALFORMED" "$CLAUDE_HOME" 2>&1)"
rc4=$?
check_bool LOCK_MALFORMED_ENTRY \
  "$([ "$rc4" -eq 0 ] \
    && printf '%s' "$out4" | grep -qF 'plugins.lock.json unreadable' \
    && ! printf '%s' "$out4" | grep -qi 'traceback' \
    && ! printf '%s' "$out4" | grep -q 'Error:' \
    && echo 1 || echo 0)"

# ── REJECTS_BAD_NAME — a link.sh EXTERNAL_SKILLS entry with a ".."
# segment: warned and skipped, never reaches _dv_check_files/
# _dv_check_link (no fail line names it), rc 0.
BADNAME="$WORK/badname"
mkdir -p "$BADNAME/skills-external"
echo '{}' > "$BADNAME/plugins.lock.json"
cat > "$BADNAME/link.sh" <<'SH'
#!/usr/bin/env bash
EXTERNAL_SKILLS=(../evil)
SH
out5="$(check_vendored_skills "$BADNAME" "$CLAUDE_HOME" 2>&1)"
rc5=$?
check_bool REJECTS_BAD_NAME \
  "$([ "$rc5" -eq 0 ] \
    && printf '%s' "$out5" | \
      grep -qF '"../evil" rejected by the item-name allowlist' \
    && ! printf '%s' "$out5" | grep -qF 'skills-external/../evil' \
    && ! printf '%s' "$out5" | grep -qF '../evil: symlink' \
    && echo 1 || echo 0)"

# ── check_vendored_trees: git-tree lock entries; doctor survives errexit ──
TR="$WORK/trees"
mkdir -p "$TR/skills-external/at-pin" "$TR/skills-external/stale"
printf '%s\n' 1111111111111111111111111111111111111111 \
  > "$TR/skills-external/at-pin/.vendored-commit"
printf '%s\n' 2222222222222222222222222222222222222222 \
  > "$TR/skills-external/stale/.vendored-commit"
cat > "$TR/plugins.lock.json" <<'JSON'
{"t": {"managed_by": "git-tree", "commit": "1111111111111111111111111111111111111111",
       "trees": {"at-pin": {"x": "a"}, "stale": {"x": "a"}, "absent": {"x": "a"}}},
 "c": {"managed_by": "curl", "commit": "1111111111111111111111111111111111111111", "skills": ["s"]}}
JSON
printf 'EXTERNAL_SKILLS=(\n  ghost-ext\n)\n' > "$TR/link.sh"
out_t="$(check_vendored_trees "$TR" 2>&1)"
printf '%s\n' "$out_t" | grep -q 't: at-pin at pin 1111111' && R1=1 || R1=0
printf '%s\n' "$out_t" | grep -q 't: skills-external/stale at 2222222, pin 1111111' && R2=1 || R2=0
printf '%s\n' "$out_t" | grep -q 't: skills-external/absent missing' && R3=1 || R3=0
# Positive control first: the three lines above must exist.
[ "$R1$R2$R3" = 111 ] && ! printf '%s\n' "$out_t" | grep -q '✗' \
  && R4=1 || R4=0
# doctor.sh runs under `set -euo pipefail`: a missing tree dest and a
# missing external copy are reported and doctor goes on to its summary.
cat > "$WORK/errexit.sh" <<'SH'
set -euo pipefail; source "$1"
check_vendored_trees "$2"; check_vendored_skills "$2" "$2/home"
echo DOCTOR_GOES_ON
SH
out_e="$(bash "$WORK/errexit.sh" "$LIB" "$TR" 2>&1)"
printf '%s\n' "$out_e" | grep -qx 'DOCTOR_GOES_ON' \
  && printf '%s\n' "$out_e" | grep -q 'ghost-ext: skills-external/ghost-ext/SKILL.md missing' \
  && R5=1 || R5=0
check_bool TREES_AT_PIN "$R1"
check_bool TREES_STALE_WARN "$R2"
check_bool TREES_MISSING_WARN "$R3"
check_bool TREES_NEVER_FAIL "$R4"
check_bool TREES_ERREXIT_SURVIVES "$R5"

# ── git-tree dests named in link.sh: presence is check_vendored_trees' job
OWN="$WORK/owned"
mkdir -p "$OWN/skills-external/own-present" "$WORK/owned_home/skills"
printf '%s\n' 1111111111111111111111111111111111111111 \
  > "$OWN/skills-external/own-present/.vendored-commit"
cat > "$OWN/plugins.lock.json" <<'JSON'
{"g": {"managed_by": "git-tree", "commit": "1111111111111111111111111111111111111111", "trees": {"own-present": {".": "x"}, "own-absent": {".": "x"}}}}
JSON
printf 'EXTERNAL_SKILLS=(own-present own-absent plain-missing)\n' \
  > "$OWN/link.sh"
out_o1="$(check_vendored_skills "$OWN" "$WORK/owned_home" 2>&1)"
out_ot="$(check_vendored_trees "$OWN" 2>&1)"
ln -s "$OWN/skills-external/own-present" "$WORK/owned_home/skills/own-present"
out_o2="$(check_vendored_skills "$OWN" "$WORK/owned_home" 2>&1)"
out_eb="$(bash "$WORK/errexit.sh" "$LIB" "$BROKEN" 2>&1)"
check_bool TREE_OWNED_ABSENT_WARN_ONLY \
  "$(! printf '%s' "$out_o1" | grep -qF 'own-absent' \
    && printf '%s' "$out_ot" | grep -qF \
      'g: skills-external/own-absent missing — run: make plugin' \
    && printf '%s' "$out_o1" | grep -qF \
      'plain-missing: skills-external/plain-missing/SKILL.md missing' \
    && echo 1 || echo 0)"
check_bool TREE_OWNED_FILES_SKIPPED \
  "$(! printf '%s' "$out_o1" | grep -qF \
    'own-present: skills-external/own-present/SKILL.md missing' \
    && echo 1 || echo 0)"
check_bool TREE_OWNED_LINK_CHECKED \
  "$(printf '%s' "$out_o1" | grep -qF 'own-present: symlink missing/wrong' \
    && printf '%s' "$out_o2" | grep -qF 'own-present: vendored + linked' \
    && echo 1 || echo 0)"
check_bool TREE_NAMES_ERREXIT_BROKEN_LOCK \
  "$(printf '%s\n' "$out_eb" | grep -qx 'DOCTOR_GOES_ON' \
    && echo 1 || echo 0)"

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
