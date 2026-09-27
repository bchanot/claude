#!/usr/bin/env bash
# lib/tests/vendor-skills.test.sh — lib/vendor-skills.sh's vendor_pinned_skills():
# list-shape and dict-shape lock entries, a file:// VENDOR_BASE_URL fixture
# tree (VENDOR_SKILLS_REPO_OVERRIDE points skills-external/ + the lock at a
# throwaway repo), tmp+mv semantics (a missing upstream file leaves no dest
# and no tmp), skip-when-present, refresh overwriting a stale copy, a
# non-file:// VENDOR_BASE_URL override being ignored (warn, default URL),
# and a "../evil" lock file being rejected before any fetch.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/lib/vendor-skills.sh"
pass=0; fail=0

check_bool() {
  local name="$1" ok="$2"
  if [ "$ok" = 1 ]; then pass=$((pass+1)); echo "PASS $name"
  else fail=$((fail+1)); echo "FAIL $name"; fi
}

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
FIXTURE_REPO="$WORK/repo"
UPSTREAM="$WORK/upstream"
mkdir -p "$FIXTURE_REPO/skills-external"

# Lock: "list-key" mirrors the agent-skills bare-list shape (file defaults
# to SKILL.md, path defaults to "skills"). "dict-key" mirrors the
# mengto-skills explicit shape (a references/ file, an explicit path).
# "fail-key" names a file that is never placed in $UPSTREAM. "missing-key"
# names a skill never installed locally (no skills-external/ dir), to
# prove refresh skips it instead of installing it. "traversal-key" names
# a well-behaved SKILL.md alongside a "../evil" file, to prove the whole
# key is rejected before either one is fetched.
cat > "$FIXTURE_REPO/plugins.lock.json" <<'JSON'
{
  "list-key": {
    "source": "https://github.com/acme/list-repo",
    "commit": "abc123",
    "skills": ["skill-list-a"]
  },
  "dict-key": {
    "source": "https://github.com/acme/dict-repo",
    "commit": "def456",
    "path": "somewhere/nested",
    "skills": {"skill-dict-a": ["SKILL.md", "references/notes.md"]}
  },
  "fail-key": {
    "source": "https://github.com/acme/fail-repo",
    "commit": "789fail",
    "skills": ["skill-fail-a"]
  },
  "missing-key": {
    "source": "https://github.com/acme/missing-repo",
    "commit": "111missing",
    "skills": ["skill-missing-a"]
  },
  "traversal-key": {
    "source": "https://github.com/acme/traversal-repo",
    "commit": "222trav",
    "skills": {"skill-trav-a": ["SKILL.md", "../evil"]}
  }
}
JSON

mkdir -p "$UPSTREAM/abc123/skills/skill-list-a"
echo v1 > "$UPSTREAM/abc123/skills/skill-list-a/SKILL.md"
mkdir -p "$UPSTREAM/def456/somewhere/nested/skill-dict-a/references"
echo "dict skill" > "$UPSTREAM/def456/somewhere/nested/skill-dict-a/SKILL.md"
echo "dict notes" > "$UPSTREAM/def456/somewhere/nested/skill-dict-a/references/notes.md"
# fail-key: 789fail/skills/skill-fail-a/SKILL.md deliberately absent.
# missing-key: no $UPSTREAM tree at all — refresh must skip it on the
# missing skills-external/ dir alone, before ever reaching curl.
# traversal-key: no $UPSTREAM tree either — the "../evil" file must be
# rejected by the lock reader itself, before any URL is built.

export VENDOR_SKILLS_REPO_OVERRIDE="$FIXTURE_REPO"
export VENDOR_BASE_URL="file://$UPSTREAM"
# shellcheck source=../vendor-skills.sh disable=SC1091
source "$LIB"

# ── LIST_SHAPE ────────────────────────────────────────────────────────────
vendor_pinned_skills list-key >/dev/null 2>&1
dest="$FIXTURE_REPO/skills-external/skill-list-a/SKILL.md"
check_bool LIST_SHAPE \
  "$([ -f "$dest" ] && [ "$(cat "$dest")" = v1 ] && echo 1 || echo 0)"

# ── DICT_SHAPE ────────────────────────────────────────────────────────────
vendor_pinned_skills dict-key >/dev/null 2>&1
d1="$FIXTURE_REPO/skills-external/skill-dict-a/SKILL.md"
d2="$FIXTURE_REPO/skills-external/skill-dict-a/references/notes.md"
check_bool DICT_SHAPE \
  "$([ -f "$d1" ] && [ "$(cat "$d2")" = "dict notes" ] && echo 1 || echo 0)"

# ── FAIL_LEAVES_NOTHING ───────────────────────────────────────────────────
out="$(vendor_pinned_skills fail-key 2>&1)"
fdest="$FIXTURE_REPO/skills-external/skill-fail-a/SKILL.md"
check_bool FAIL_LEAVES_NOTHING "$([ ! -e "$fdest" ] && [ ! -e "$fdest.tmp" ] \
  && printf '%s' "$out" | grep -q 'not all files landed' && echo 1 || echo 0)"

# ── SKIP_PRESENT — upstream changes, a plain re-run keeps the old copy ───
echo v2-upstream-changed > "$UPSTREAM/abc123/skills/skill-list-a/SKILL.md"
vendor_pinned_skills list-key >/dev/null 2>&1
check_bool SKIP_PRESENT "$([ "$(cat "$dest")" = v1 ] && echo 1 || echo 0)"

# ── REFRESH_OVERWRITES — same changed upstream, refresh picks it up ─────
vendor_pinned_skills list-key refresh >/dev/null 2>&1
check_bool REFRESH_OVERWRITES \
  "$([ "$(cat "$dest")" = v2-upstream-changed ] && echo 1 || echo 0)"

# ── REFRESH_SKIPS_MISSING — refresh never installs a skill that has no
# skills-external/<name> dir yet; it prints the standard "not installed"
# skip line and never touches curl (no $UPSTREAM/111missing/ exists).
mdest="$FIXTURE_REPO/skills-external/skill-missing-a"
out="$(vendor_pinned_skills missing-key refresh 2>&1)"
check_bool REFRESH_SKIPS_MISSING "$([ ! -e "$mdest" ] \
  && printf '%s' "$out" | \
    grep -qF 'skill-missing-a not installed — skipping (run: make plugin)' \
  && echo 1 || echo 0)"

# ── OVERRIDE_NON_FILE_IGNORED — a non-file:// VENDOR_BASE_URL is ignored:
# a warn names the variable and the default raw.githubusercontent.com
# prefix is used instead. list-key's SKILL.md is already vendored (v2,
# from REFRESH_OVERWRITES above), so this probe never touches curl
# either way — the assertion is the warn line, and that the file:// mode
# used everywhere else in this suite (asserted by the six cases above
# and below) keeps working.
out="$(VENDOR_BASE_URL="https://evil.example.com" \
  vendor_pinned_skills list-key 2>&1)"
check_bool OVERRIDE_NON_FILE_IGNORED \
  "$(printf '%s' "$out" | grep -q 'VENDOR_BASE_URL ignored' \
    && echo 1 || echo 0)"

# ── REJECTS_TRAVERSAL — a lock entry naming a "../evil" file is rejected
# whole by the lock reader: nothing is fetched for the key, so not even
# its well-behaved SKILL.md lands, and nothing lands outside the skill's
# own directory either.
out="$(vendor_pinned_skills traversal-key 2>&1)"
rc=$?
tdir="$FIXTURE_REPO/skills-external/skill-trav-a"
outside="$FIXTURE_REPO/skills-external/evil"
check_bool REJECTS_TRAVERSAL "$([ "$rc" -ne 0 ] && [ ! -e "$tdir" ] \
  && [ ! -e "$outside" ] && echo 1 || echo 0)"

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
