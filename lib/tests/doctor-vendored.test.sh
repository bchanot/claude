#!/usr/bin/env bash
# lib/tests/doctor-vendored.test.sh — lib/doctor-vendored.sh's
# check_vendored_skills(): a fixture repo under mktemp with a fake
# plugins.lock.json (single-path shape, list shape, dict shape with a
# references/ file), a fake link.sh holding a multi-line
# EXTERNAL_SKILLS=(...) array, a fake <claude_home>/skills dir and a fake
# profile file. Cases: every file present + linked (ALL_PRESENT), a
# list-shape skill missing its SKILL.md (FILE_MISSING), a dict-shape
# skill missing one of two files — only that file is named
# (DICT_FILES_COMPLETE), a profile-listed name with no symlink
# (SYMLINK_MISSING_ACTIVE) or a symlink to the wrong target
# (SYMLINK_WRONG_TARGET), a name absent from the profile reported parked
# rather than failed (SYMLINK_PARKED), the same name treated as
# expected-linked (fail, not parked) when no profile file is passed at
# all (NO_PROFILE_EXPECTS_LINK), an unreadable lock file degrading to a
# warn instead of a fail (LOCK_UNREADABLE, rc 0), a lock entry whose
# "skills" is neither null/list/dict degrading the same way with no
# Python traceback leaking (LOCK_MALFORMED_ENTRY, rc 0), the
# profile-name allowlist rejecting a path-traversal value
# (REJECTS_BAD_PROFILE_NAME), the item-name allowlist rejecting a
# link.sh entry with a ".." segment — warned and skipped, not failed
# (REJECTS_BAD_NAME), and an "always_on": true lock entry's name, absent
# from the profile and with no symlink, checked (and failed) instead of
# reported parked (ALWAYS_ON_LINK_CHECKED).
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
      "missing-skill", "active-nolink-skill", "active-wronglink-skill",
      "parked-skill", "noprofile-skill"
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
  active-nolink-skill active-wronglink-skill
  parked-skill noprofile-skill always-on-skill)
SH

# ── skills-external/ tree: every name's SKILL.md present, except
# missing-skill (nothing at all) and dict-skill's references/notes.md.
# always-on-skill has its SKILL.md too — only its symlink is missing.
for n in ok-skill dict-skill active-nolink-skill active-wronglink-skill \
         parked-skill noprofile-skill always-on-skill; do
  mkdir -p "$REPO/skills-external/$n"
  echo "v1" > "$REPO/skills-external/$n/SKILL.md"
done

# ── claude_home symlinks: ok-skill correct, active-wronglink-skill
# points elsewhere, active-nolink-skill, noprofile-skill and
# always-on-skill have none.
ln -sf "$REPO/skills-external/ok-skill" "$CLAUDE_HOME/skills/ok-skill"
mkdir -p "$WORK/elsewhere"
ln -sf "$WORK/elsewhere" "$CLAUDE_HOME/skills/active-wronglink-skill"

# ── active.profile: lists everything EXCEPT parked-skill,
# noprofile-skill and always-on-skill (all three proven absent from it).
cat > "$REPO/active.profile" <<'PROF'
# DESC: fixture profile
ok-skill                external
missing-skill            external
dict-skill               external
active-nolink-skill      external
active-wronglink-skill   external
PROF

# shellcheck source=../doctor-vendored.sh disable=SC1091
source "$LIB"

# ── With the active profile passed ──────────────────────────────────
out1="$(check_vendored_skills "$REPO" "$CLAUDE_HOME" \
  "$REPO/active.profile" 2>&1)"

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

check_bool SYMLINK_PARKED \
  "$(printf '%s' "$out1" | grep -qF 'parked-skill: parked by profile active' \
    && ! printf '%s' "$out1" | \
      grep -qF 'parked-skill: symlink missing/wrong' \
    && echo 1 || echo 0)"

# ── always-on-skill: absent from active.profile (same as parked-skill)
# but its lock entry is "always_on": true — checked (and failed, no
# symlink) instead of reported parked.
check_bool ALWAYS_ON_LINK_CHECKED \
  "$(printf '%s' "$out1" | \
    grep -qF 'always-on-skill: symlink missing/wrong' \
    && ! printf '%s' "$out1" | \
      grep -qF 'always-on-skill: parked by profile' \
    && echo 1 || echo 0)"

# ── No profile file passed at all: noprofile-skill (absent from
# active.profile, parked above) must now be treated as expected-linked.
out2="$(check_vendored_skills "$REPO" "$CLAUDE_HOME" 2>&1)"
check_bool NO_PROFILE_EXPECTS_LINK \
  "$(printf '%s' "$out2" | \
    grep -qF 'noprofile-skill: symlink missing/wrong' && echo 1 || echo 0)"

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

# ── REJECTS_BAD_PROFILE_NAME — the profile-name allowlist helper
# rejects a path-traversal value and accepts a plain one.
check_bool REJECTS_BAD_PROFILE_NAME \
  "$( { _dv_valid_profile_name "full" \
      && ! _dv_valid_profile_name "../x" \
      && ! _dv_valid_profile_name "a/b" \
      && ! _dv_valid_profile_name "a.b"; } && echo 1 || echo 0)"

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

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
