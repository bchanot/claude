#!/usr/bin/env bash
# lib/floor-guard.sh — diff-scoped detector of a quietly weakened quality bar.
#
#   bash ~/.claude/lib/floor-guard.sh <base-ref> [-- <pathspec>...]
#
# rc 0 = clean       no floor finding in the diff
#    2 = <n> finding(s), <m> waived
#    3 = usage error  (missing <base-ref>, or it does not resolve to a commit)
#
# WHY (BDR-100 class): "no weakened check in this diff" is exactly the kind
# of judgment an LLM verifier can miss, or be talked past one line at a time
# — a single added TS-ignore comment, a skipped test, a dropped assertion, a
# coverage threshold shaved by one point. This makes that judgment
# deterministic: grep the diff for the known ways a change quietly lowers
# the bar, same floor doctrine as gates.sh (contract oracles) and
# doctrine-citers.test.sh (citation census) — a mechanism, not a lesson.
#
# Adapted from addyosmani/agent-skills constraint-driven-development's
# "floor guard" to this repo's own gate model: `git diff` instead of a
# staged-diff assumption, wired into agents/verifier.md STEP 3 rather than a
# pre-commit hook.
#
# Scope: `git diff <base-ref>` — working tree included (uncommitted changes
# count) — restricted to <pathspec> when given. Every ADDED line is
# classified into one of six kinds (full pattern tables below):
#   SUPPRESS       a checker-silencing comment added, any file
#   SKIP           a test disabled or isolated, test files only
#   DELETED_TEST   a whole test file removed
#   ASSERT_DROP    a test file's assertion-line count went down
#   STUB           a not-implemented marker added, any file
#   THRESHOLD_DOWN a numeric value lowered on the same key, config files only
#
# Waiver: an added line also carrying `floor-guard: allow <reason>` prints as
# WAIVED and does not count toward the finding total or the rc.
set -uo pipefail

_usage() {
  echo "usage: floor-guard.sh <base-ref> [-- <pathspec>...]" >&2
  exit 3
}

[ $# -ge 1 ] || _usage
BASE_REF="$1"; shift
PATHSPEC=()
if [ $# -gt 0 ]; then
  [ "$1" = "--" ] || _usage
  shift
  PATHSPEC=("$@")
fi
git rev-parse --verify -q "${BASE_REF}^{commit}" >/dev/null 2>&1 || _usage

TMPDIFF="$(mktemp)" || { echo "floor-guard: mktemp failed" >&2; exit 3; }
trap 'rm -f "$TMPDIFF"' EXIT

git diff --unified=0 "$BASE_REF" -- "${PATHSPEC[@]}" > "$TMPDIFF" 2>/dev/null
FLOOR_DELETED_FILES="$(git diff --diff-filter=D --name-only \
  "$BASE_REF" -- "${PATHSPEC[@]}" 2>/dev/null)"
export FLOOR_DELETED_FILES

# "working tree included" means brand-new, still-untracked files too: plain
# `git diff <ref>` never shows them (git only diffs what it already tracks),
# so a file added on this branch and never `git add`-ed would be invisible
# to every kind below. --no-index against /dev/null emits the same unified
# format as the tracked diff above (diff --git / +++ b/path / @@ hunks),
# so the parser needs no separate code path for it.
while IFS= read -r f; do
  [ -n "$f" ] || continue
  git diff --no-index --unified=0 -- /dev/null "$f" >> "$TMPDIFF" 2>/dev/null
done < <(git ls-files --others --exclude-standard -- "${PATHSPEC[@]}" 2>/dev/null)

python3 - "$TMPDIFF" <<'PY'
import fnmatch
import os
import re
import sys

# file classes (CLARIFICATIONS): "path contains test/spec/__tests__" is a
# superset of the explicit globs (*.test.*, *.spec.*, *_test.go, *_test.py,
# test_*.py all contain one of these substrings themselves), so one check
# covers all five.
TEST_SUBSTRINGS = ('test', 'spec', '__tests__')
CONFIG_GLOBS = ('jest.config*', 'vitest.config*', '.nycrc*', 'codecov*',
                 'sonar-project.properties', 'lighthouserc*', 'CONSTRAINTS.md')

# ── pattern tables — the trigger strings themselves, waived on this file's
# own diff so the guard stays clean on itself (also exercises the waiver
# path for real) ────────────────────────────────────────────────────────────
SUPPRESS_SUBSTRINGS = (
    '@ts-ignore',            # floor-guard: allow pattern table
    'eslint-disable',        # floor-guard: allow pattern table
    '# noqa',                # floor-guard: allow pattern table
    '# type: ignore',        # floor-guard: allow pattern table
    'nosemgrep',             # floor-guard: allow pattern table
    'nosec',                 # floor-guard: allow pattern table
    'shellcheck disable',    # floor-guard: allow pattern table
)
TS_EXPECT_ERROR = '@ts-expect-error'   # floor-guard: allow pattern table

SKIP_SUBSTRINGS = (
    '.skip(', '.only(', 'it.todo(', '@pytest.mark.skip', '@unittest.skip',
    't.Skip(',
)
# bare Jasmine/Jest focus-or-skip calls (xit/fit/xdescribe/fdescribe); the
# lookbehind keeps `exit(`, `SystemExit(`, `model.fit(` out (BLK-023).
SKIP_IDENT_RE = re.compile(r'(?<![A-Za-z0-9_.])(?:xit|fit|xdescribe|fdescribe)\(')
# shortcut: `def fit(` / `function xit(` still match (space before), `xit (`
# and `xit.each(` still do not — upgrade path (?<!def )(?<!function ) and
# (?:\.each)?\s*\(.

STUB_SUBSTRINGS = (
    'not implemented',       # floor-guard: allow pattern table
    'NotImplementedError',   # floor-guard: allow pattern table
)
EMPTY_CATCH_RE = re.compile(r'catch\s*\([^)]*\)\s*\{\s*\}')
BARE_EXCEPT_RE = re.compile(r'except\b[^:\n]*:\s*pass\b')

ASSERT_SUBSTRINGS = ('expect(', 'assert', 'should', '.toBe')

KEYVAL_RE = re.compile(r'["\']?([A-Za-z0-9_.\-]+)["\']?\s*[:=]\s*(-?\d+(?:\.\d+)?)')
WAIVER_RE = re.compile(r'floor-guard:\s*allow\s+(\S.*)$')
HUNK_RE = re.compile(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@')


def is_test_file(path):
    return any(s in path for s in TEST_SUBSTRINGS)


def is_config_file(path):
    base = os.path.basename(path)
    return any(fnmatch.fnmatch(base, g) for g in CONFIG_GLOBS)


def is_waived(text):
    return bool(WAIVER_RE.search(text))


def strip_prefix(raw):
    if raw == '/dev/null':
        return raw
    return raw[2:] if raw[:2] in ('a/', 'b/') else raw


def _new_file_entry(files):
    entry = {'old_path': None, 'new_path': None, 'adds': [], 'dels': [],
             'first_new': None}
    files.append(entry)
    return entry


def parse_diff(lines):   # → list of per-file entries (adds/dels + paths)
    files, cur = [], None
    old_no = new_no = 0
    for raw in lines:
        if raw.startswith('diff --git '):
            cur = _new_file_entry(files)
        elif raw.startswith('--- '):
            cur['old_path'] = strip_prefix(raw[4:])
        elif raw.startswith('+++ '):
            cur['new_path'] = strip_prefix(raw[4:])
        elif raw.startswith('@@ '):
            m = HUNK_RE.match(raw)
            if m:
                old_no, new_no = int(m.group(1)), int(m.group(2))
                if cur['first_new'] is None:
                    cur['first_new'] = new_no
        elif raw.startswith('+') and not raw.startswith('+++'):
            cur['adds'].append((new_no, raw[1:])); new_no += 1
        elif raw.startswith('-') and not raw.startswith('---'):
            cur['dels'].append((old_no, raw[1:])); old_no += 1
    return files


def effective_path(entry):
    if entry['new_path'] not in (None, '/dev/null'):
        return entry['new_path']
    return entry['old_path']


def suppress_kind(text):
    if TS_EXPECT_ERROR in text:
        after = text.split(TS_EXPECT_ERROR, 1)[1].strip()
        return None if after else 'SUPPRESS'
    return 'SUPPRESS' if any(p in text for p in SUPPRESS_SUBSTRINGS) else None


def stub_kind(text):
    if any(p in text for p in STUB_SUBSTRINGS):
        return 'STUB'
    if EMPTY_CATCH_RE.search(text) or BARE_EXCEPT_RE.search(text):
        return 'STUB'
    return None


def skip_kind(text):
    if any(p in text for p in SKIP_SUBSTRINGS):
        return 'SKIP'
    return 'SKIP' if SKIP_IDENT_RE.search(text) else None


def line_findings(path, lineno, text, test_file):
    out, waived = [], is_waived(text)
    for kindfn in (suppress_kind, stub_kind):
        kind = kindfn(text)
        if kind:
            out.append((kind, path, lineno, text, waived))
    if test_file:
        kind = skip_kind(text)
        if kind:
            out.append((kind, path, lineno, text, waived))
    return out


def _is_assertion(text):
    return any(p in text for p in ASSERT_SUBSTRINGS)


def assert_drop_finding(path, entry):
    added = sum(1 for _, t in entry['adds'] if _is_assertion(t))
    removed = sum(1 for _, t in entry['dels'] if _is_assertion(t))
    if removed <= added:
        return None
    lineno = entry['adds'][0][0] if entry['adds'] else (entry['first_new'] or 1)
    waived = any(is_waived(t) for _, t in entry['adds'])
    snippet = 'assertion lines %d -> %d' % (removed, added)
    return ('ASSERT_DROP', path, lineno, snippet, waived)


def extract_kv(lines):   # → {key: (lineno, value, raw text)} last-wins
    kv = {}
    for lineno, text in lines:
        m = KEYVAL_RE.search(text)
        if m:
            kv[m.group(1)] = (lineno, float(m.group(2)), text)
    return kv


def threshold_down_findings(path, entry):
    removed_kv = extract_kv(entry['dels'])
    added_kv = extract_kv(entry['adds'])
    out = []
    for key, (lineno, new_val, text) in added_kv.items():
        old = removed_kv.get(key)
        if old and new_val < old[1]:
            out.append(('THRESHOLD_DOWN', path, lineno, text, is_waived(text)))
    return out


def classify_file(entry, deleted_paths):
    path = effective_path(entry)
    if path is None:
        return []   # pure rename/mode-change: no --- / +++ header, no content diff
    test_file = is_test_file(path)
    if path in deleted_paths and test_file:
        return [('DELETED_TEST', path, 1, path, False)]
    findings = []
    for lineno, text in entry['adds']:
        findings += line_findings(path, lineno, text, test_file)
    if test_file:
        dropped = assert_drop_finding(path, entry)
        if dropped:
            findings.append(dropped)
    if is_config_file(path):
        findings += threshold_down_findings(path, entry)
    return findings


def load_deleted_paths():
    raw = os.environ.get('FLOOR_DELETED_FILES', '')
    return {p for p in raw.splitlines() if p}


def snippet_of(text):
    return text.strip()[:100]


def emit(findings):
    ordered = sorted(findings, key=lambda f: (f[1], f[2], f[0]))
    n_found = n_waived = 0
    for kind, path, lineno, text, waived in ordered:
        tag = 'WAIVED' if waived else 'FLOOR'
        print('%s %s %s:%d %s' % (tag, kind, path, lineno, snippet_of(text)))
        n_waived += 1 if waived else 0
        n_found += 0 if waived else 1
    if n_found:
        print('FLOOR GUARD: %d finding(s), %d waived' % (n_found, n_waived))
        return 2
    print('FLOOR GUARD: clean')
    return 0


def main():
    with open(sys.argv[1], 'r', errors='replace') as fh:
        lines = fh.read().split('\n')
    deleted = load_deleted_paths()
    findings = []
    for entry in parse_diff(lines):
        findings += classify_file(entry, deleted)
    return emit(findings)


if __name__ == '__main__':
    sys.exit(main())
PY
rc=$?
exit "$rc"
