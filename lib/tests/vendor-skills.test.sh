#!/usr/bin/env bash
# lib/tests/vendor-skills.test.sh — lib/vendor-skills.sh's vendor_pinned_skills():
# list-shape and dict-shape lock entries, a file:// VENDOR_BASE_URL fixture
# tree (VENDOR_SKILLS_REPO_OVERRIDE points skills-external/ + the lock at a
# throwaway repo), tmp+mv semantics (a missing upstream file leaves no dest
# and no tmp), skip-when-present, refresh overwriting a stale copy, a
# non-file:// VENDOR_BASE_URL override being ignored (warn, default URL),
# a "../evil" lock file being rejected before any fetch, a lock value
# ending in a newline being rejected (the re.fullmatch fix), and a bad
# commit/source/path on the lock entry itself being rejected before the
# raw URL is ever built.
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
# key is rejected before either one is fetched. "newline-key" names a
# file whose value ends in a newline, to prove the SAFE-class check uses
# re.fullmatch (a plain re.match "$" would let it through). "bad-commit-
# key", "bad-source-key" and "bad-path-key" carry an otherwise-valid entry
# with exactly one malformed field, to prove each is checked before the
# raw URL is built. Every commit below is a real 40-hex sha1 (of the key's
# own name) — only the three "bad-*-key" entries break that on purpose.
cat > "$FIXTURE_REPO/plugins.lock.json" <<'JSON'
{
  "list-key": {
    "source": "https://github.com/acme/list-repo",
    "commit": "0b29f58330afad53522f9045ef48ba153bb5ab81",
    "skills": ["skill-list-a"]
  },
  "dict-key": {
    "source": "https://github.com/acme/dict-repo",
    "commit": "68ca98404892988c1cbe928dc12ef3ed144c8d70",
    "path": "somewhere/nested",
    "skills": {"skill-dict-a": ["SKILL.md", "references/notes.md"]}
  },
  "fail-key": {
    "source": "https://github.com/acme/fail-repo",
    "commit": "898733695eac132c05aac536e7f86cdd89bdfe09",
    "skills": ["skill-fail-a"]
  },
  "missing-key": {
    "source": "https://github.com/acme/missing-repo",
    "commit": "2e7a1c5865d4f2c9dc2e3354658f0e257f6110d8",
    "skills": ["skill-missing-a"]
  },
  "traversal-key": {
    "source": "https://github.com/acme/traversal-repo",
    "commit": "9704a3bf7b366acd318b0d12dacc78774ff2ade1",
    "skills": {"skill-trav-a": ["SKILL.md", "../evil"]}
  },
  "newline-key": {
    "source": "https://github.com/acme/newline-repo",
    "commit": "12f27ef33f4cd777b9471b989a8e022e35c0ab74",
    "skills": {"skill-nl-a": ["SKILL.md\n"]}
  },
  "bad-commit-key": {
    "source": "https://github.com/acme/badcommit-repo",
    "commit": "main",
    "skills": ["skill-badcommit-a"]
  },
  "bad-source-key": {
    "source": "https://evil.example.com/x/y",
    "commit": "eeb5c78b15a6b1ffa3fb5d46d8c794bcd0446bdc",
    "skills": ["skill-badsource-a"]
  },
  "bad-path-key": {
    "source": "https://github.com/acme/badpath-repo",
    "commit": "e341601ba6f6255378268e9aaec304de93a13d50",
    "path": "../x",
    "skills": {"skill-badpath-a": ["SKILL.md"]}
  }
}
JSON

LIST_SHA="0b29f58330afad53522f9045ef48ba153bb5ab81"
DICT_SHA="68ca98404892988c1cbe928dc12ef3ed144c8d70"
mkdir -p "$UPSTREAM/$LIST_SHA/skills/skill-list-a"
echo v1 > "$UPSTREAM/$LIST_SHA/skills/skill-list-a/SKILL.md"
mkdir -p "$UPSTREAM/$DICT_SHA/somewhere/nested/skill-dict-a/references"
echo "dict skill" > "$UPSTREAM/$DICT_SHA/somewhere/nested/skill-dict-a/SKILL.md"
echo "dict notes" \
  > "$UPSTREAM/$DICT_SHA/somewhere/nested/skill-dict-a/references/notes.md"
# fail-key: .../skills/skill-fail-a/SKILL.md deliberately absent.
# missing-key: no $UPSTREAM tree at all — refresh must skip it on the
# missing skills-external/ dir alone, before ever reaching curl.
# traversal-key, newline-key, bad-commit-key, bad-source-key and
# bad-path-key: no $UPSTREAM tree either — every one of them must be
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
echo v2-upstream-changed > "$UPSTREAM/$LIST_SHA/skills/skill-list-a/SKILL.md"
vendor_pinned_skills list-key >/dev/null 2>&1
check_bool SKIP_PRESENT "$([ "$(cat "$dest")" = v1 ] && echo 1 || echo 0)"

# ── REFRESH_OVERWRITES — same changed upstream, refresh picks it up ─────
vendor_pinned_skills list-key refresh >/dev/null 2>&1
check_bool REFRESH_OVERWRITES \
  "$([ "$(cat "$dest")" = v2-upstream-changed ] && echo 1 || echo 0)"

# ── REFRESH_SKIPS_MISSING — refresh never installs a skill that has no
# skills-external/<name> dir yet; it prints the standard "not installed"
# skip line and never touches curl (missing-key's sha has no $UPSTREAM
# tree at all).
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
# used everywhere else in this suite (asserted by the eleven other cases)
# keeps working.
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

# ── REJECTS_TRAILING_NEWLINE — a lock file value ending in a newline
# ("SKILL.md\n") is rejected by the SAFE-class check (re.fullmatch, not
# re.match): nothing is fetched for the key, and the err line names the
# lock key.
out="$(vendor_pinned_skills newline-key 2>&1)"
rc=$?
nldir="$FIXTURE_REPO/skills-external/skill-nl-a"
check_bool REJECTS_TRAILING_NEWLINE "$([ "$rc" -ne 0 ] && [ ! -e "$nldir" ] \
  && printf '%s' "$out" | grep -q 'newline-key' && echo 1 || echo 0)"

# ── REJECTS_BAD_COMMIT — a lock entry whose "commit" is not 40 lowercase
# hex chars ("main") is rejected before any URL is built.
out="$(vendor_pinned_skills bad-commit-key 2>&1)"
rc=$?
bcdir="$FIXTURE_REPO/skills-external/skill-badcommit-a"
check_bool REJECTS_BAD_COMMIT "$([ "$rc" -ne 0 ] && [ ! -e "$bcdir" ] \
  && printf '%s' "$out" | grep -qF "rejected commit='main'" \
  && echo 1 || echo 0)"

# ── REJECTS_BAD_SOURCE — a lock entry whose "source" is not a
# "https://github.com/<owner>/<repo>" URL is rejected before any URL is
# built.
out="$(vendor_pinned_skills bad-source-key 2>&1)"
rc=$?
bsdir="$FIXTURE_REPO/skills-external/skill-badsource-a"
check_bool REJECTS_BAD_SOURCE "$([ "$rc" -ne 0 ] && [ ! -e "$bsdir" ] \
  && printf '%s' "$out" \
    | grep -qF "rejected source='https://evil.example.com/x/y'" \
  && echo 1 || echo 0)"

# ── REJECTS_BAD_PATH — a lock entry whose "path" walks outside the repo
# ("../x") is rejected before any URL is built.
out="$(vendor_pinned_skills bad-path-key 2>&1)"
rc=$?
bpdir="$FIXTURE_REPO/skills-external/skill-badpath-a"
check_bool REJECTS_BAD_PATH "$([ "$rc" -ne 0 ] && [ ! -e "$bpdir" ] \
  && printf '%s' "$out" | grep -qF "rejected path='../x'" && echo 1 || echo 0)"

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
