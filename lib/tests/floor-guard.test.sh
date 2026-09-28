#!/usr/bin/env bash
# lib/tests/floor-guard.test.sh — flip-tests for lib/floor-guard.sh: one RED
# fixture per KIND, one WAIVED fixture, one CLEAN fixture, plus boundary
# cases for SKIP. Each fixture is a fresh throwaway repo under $WORK
# (`make test` exports
# GIT_CONFIG_GLOBAL=/dev/null; core.hooksPath is also pinned per-repo so a
# machine-wide hook never fires here). This file itself carries the trigger
# strings for every kind — the self-run criterion excludes it by pathspec.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/lib/floor-guard.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0

# check_kind <KIND> <rc> <want_rc> <out> <want_substr>
check_kind() {
  local kind="$1" rc="$2" want_rc="$3" out="$4" want_sub="$5"
  if [ "$rc" = "$want_rc" ] && printf '%s\n' "$out" | grep -qF -- "$want_sub"; then
    pass=$((pass+1)); echo "PASS $kind"
  else
    fail=$((fail+1))
    printf 'FAIL %s: rc=%s (want %s), out:\n%s\n' \
      "$kind" "$rc" "$want_rc" "$(printf '%s\n' "$out" | tail -5)"
  fi
}

# mk_repo <name> → path to a fresh throwaway repo: one test file (3
# assertions), one vitest.config.ts (coverage.lines: 80), one source file.
mk_repo() {
  local d="$WORK/$1"
  mkdir -p "$d/src"
  git init -q "$d"
  git -C "$d" config user.email t@t
  git -C "$d" config user.name t
  git -C "$d" config core.hooksPath /dev/null
  printf 'expect(1).toBe(1);\nexpect(2).toBe(2);\nexpect(3).toBe(3);\n' \
    > "$d/sample.test.js"
  printf 'export default {\n  coverage: {\n    lines: 80,\n  },\n};\n' \
    > "$d/vitest.config.ts"
  printf 'function add(a, b) {\n  return a + b;\n}\n' > "$d/src/index.js"
  git -C "$d" add -A
  git -C "$d" commit -q -m base
  echo "$d"
}

# ── SUPPRESS ──────────────────────────────────────────────────────────────
d=$(mk_repo suppress); base=$(git -C "$d" rev-parse HEAD)
echo '// eslint-disable-next-line no-console' >> "$d/src/index.js"
out=$(cd "$d" && bash "$LIB" "$base" 2>&1); rc=$?
check_kind SUPPRESS "$rc" 2 "$out" 'FLOOR SUPPRESS'

# ── SKIP ──────────────────────────────────────────────────────────────────
d=$(mk_repo skip); base=$(git -C "$d" rev-parse HEAD)
echo "it.skip('later', () => {});" >> "$d/sample.test.js"
out=$(cd "$d" && bash "$LIB" "$base" 2>&1); rc=$?
check_kind SKIP "$rc" 2 "$out" 'FLOOR SKIP'

# ── SKIP_EXIT_CLEAN ───────────────────────────────────────────────────────
d=$(mk_repo skipexit); base=$(git -C "$d" rev-parse HEAD)
{
  echo 'process.exit(1); // sys.exit(1)' # floor-guard: allow flip-test fixture
  echo 'model.fit(x);' # floor-guard: allow flip-test fixture
  echo 'const p = profit(1);' # floor-guard: allow flip-test fixture
} >> "$d/sample.test.js"
out=$(cd "$d" && bash "$LIB" "$base" 2>&1); rc=$?
check_kind SKIP_EXIT_CLEAN "$rc" 0 "$out" 'FLOOR GUARD: clean'

# ── SKIP_XIT_FLAGS / SKIP_FIT_FLAGS / SKIP_FDESCRIBE_FLAGS ────────────────
d=$(mk_repo skipxit); base=$(git -C "$d" rev-parse HEAD)
echo "  xit('skipped', () => {});" >> "$d/sample.test.js" # floor-guard: allow flip-test fixture
out=$(cd "$d" && bash "$LIB" "$base" 2>&1); rc=$?
check_kind SKIP_XIT_FLAGS "$rc" 2 "$out" 'FLOOR SKIP'

d=$(mk_repo skipfit); base=$(git -C "$d" rev-parse HEAD)
echo "fit('focused', () => {});" >> "$d/sample.test.js" # floor-guard: allow flip-test fixture
out=$(cd "$d" && bash "$LIB" "$base" 2>&1); rc=$?
check_kind SKIP_FIT_FLAGS "$rc" 2 "$out" 'FLOOR SKIP'

d=$(mk_repo skipfdescribe); base=$(git -C "$d" rev-parse HEAD)
echo "fdescribe('focused', () => {});" >> "$d/sample.test.js" # floor-guard: allow flip-test fixture
out=$(cd "$d" && bash "$LIB" "$base" 2>&1); rc=$?
check_kind SKIP_FDESCRIBE_FLAGS "$rc" 2 "$out" 'FLOOR SKIP'

# ── DELETED_TEST ──────────────────────────────────────────────────────────
d=$(mk_repo deleted); base=$(git -C "$d" rev-parse HEAD)
rm "$d/sample.test.js"
out=$(cd "$d" && bash "$LIB" "$base" 2>&1); rc=$?
check_kind DELETED_TEST "$rc" 2 "$out" 'FLOOR DELETED_TEST'

# ── ASSERT_DROP ───────────────────────────────────────────────────────────
d=$(mk_repo assertdrop); base=$(git -C "$d" rev-parse HEAD)
printf 'expect(1).toBe(1);\n' > "$d/sample.test.js"
out=$(cd "$d" && bash "$LIB" "$base" 2>&1); rc=$?
check_kind ASSERT_DROP "$rc" 2 "$out" 'FLOOR ASSERT_DROP'

# ── STUB ──────────────────────────────────────────────────────────────────
d=$(mk_repo stub); base=$(git -C "$d" rev-parse HEAD)
echo "function todo() { throw new Error('not implemented'); }" >> "$d/src/index.js"
out=$(cd "$d" && bash "$LIB" "$base" 2>&1); rc=$?
check_kind STUB "$rc" 2 "$out" 'FLOOR STUB'

# ── THRESHOLD_DOWN ────────────────────────────────────────────────────────
d=$(mk_repo threshold); base=$(git -C "$d" rev-parse HEAD)
sed -i 's/lines: 80/lines: 60/' "$d/vitest.config.ts"
out=$(cd "$d" && bash "$LIB" "$base" 2>&1); rc=$?
check_kind THRESHOLD_DOWN "$rc" 2 "$out" 'FLOOR THRESHOLD_DOWN'

# ── WAIVED ────────────────────────────────────────────────────────────────
d=$(mk_repo waived); base=$(git -C "$d" rev-parse HEAD)
echo '// eslint-disable-next-line no-console -- floor-guard: allow legacy shim' \
  >> "$d/src/index.js"
out=$(cd "$d" && bash "$LIB" "$base" 2>&1); rc=$?
check_kind WAIVED "$rc" 0 "$out" 'WAIVED'

# ── CLEAN ─────────────────────────────────────────────────────────────────
d=$(mk_repo clean); base=$(git -C "$d" rev-parse HEAD)
echo '// helper' >> "$d/src/index.js"
out=$(cd "$d" && bash "$LIB" "$base" 2>&1); rc=$?
check_kind CLEAN "$rc" 0 "$out" 'FLOOR GUARD: clean'

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
