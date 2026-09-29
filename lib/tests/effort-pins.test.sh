#!/usr/bin/env bash
# lib/tests/effort-pins.test.sh — lib/effort-pins.sh's apply_effort_pins():
# insert after `name:`, keep an equal level untouched, replace a different
# level inside the frontmatter only (a prose `effort:` in the body stays),
# skip a skill not vendored, insert before the closing `---` when the
# frontmatter has no name line, run idempotently, reject a bad level, a
# traversal name and a three-field line before writing anything, and
# parse the real map without error; hardening: last map line without a
# newline, unterminated frontmatter, CRLF file and read-only directory. All on a throwaway fixture repo.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/lib/effort-pins.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "PASS $1"
  else fail=$((fail+1)); echo "FAIL $1: got[$2] want[$3]"; fi; }
fm_effort() { awk 'NR==1&&/^---$/{p=1;next} p&&/^---$/{exit} p' "$1" \
  | sed -n 's/^effort: //p' | head -1; }

WORK="$(mktemp -d)" || exit 1; trap 'rm -rf "$WORK"' EXIT
REPO="$WORK/repo"; EXT="$REPO/skills-external"
mkdir -p "$REPO/lib" "$EXT/alpha" "$EXT/beta" "$EXT/gamma" "$EXT/noname"
printf -- '---\nname: alpha\ndescription: a\n---\nbody\n' > "$EXT/alpha/SKILL.md"
printf -- '---\nname: beta\neffort: low\n---\nprose says effort: max here\n' > "$EXT/beta/SKILL.md"
printf -- '---\nname: gamma\neffort: low\n---\nbody\n' > "$EXT/gamma/SKILL.md"
printf -- '---\ndescription: no name line\n---\nbody\n' > "$EXT/noname/SKILL.md"
printf '# map\nalpha high\nbeta medium\ngamma low\nghost xhigh\nnoname low\n' > "$REPO/lib/effort-pins.txt"
gamma_before="$(cat "$EXT/gamma/SKILL.md")"

bash "$LIB" "$REPO" >/dev/null 2>&1; check T1-rc-clean "$?" 0
check T2-insert-after-name "$(sed -n '3p' "$EXT/alpha/SKILL.md")" "effort: high"
check T3-replace-in-frontmatter "$(fm_effort "$EXT/beta/SKILL.md")" "medium"
check T3b-body-prose-untouched "$(grep -c 'effort: max' "$EXT/beta/SKILL.md")" 1
check T3c-single-effort-line "$(grep -c '^effort:' "$EXT/beta/SKILL.md")" 1
check T4-equal-level-untouched "$(cat "$EXT/gamma/SKILL.md")" "$gamma_before"
check T5-missing-skill-skipped "$([ -e "$EXT/ghost" ] && echo created || echo absent)" absent
check T6-no-name-inserts-before-closing "$(sed -n '3p' "$EXT/noname/SKILL.md")" "effort: low"
check T6b-no-name-still-frontmatter "$(fm_effort "$EXT/noname/SKILL.md")" "low"
snap="$(cat "$EXT"/*/SKILL.md)"
bash "$LIB" "$REPO" >/dev/null 2>&1
check T7-idempotent "$(cat "$EXT"/*/SKILL.md)" "$snap"
check T7b-no-tmp-left "$(find "$EXT" -name '*.tmp' | wc -l)" 0

# rejections: nothing written, rc 1
for bad in 'alpha turbo' '../evil high' 'alpha high extra'; do
  printf '%s\n' "$bad" > "$REPO/lib/effort-pins.txt"
  out="$(bash "$LIB" "$REPO" 2>&1)"; rc=$?
  check "T8-rejected[$bad]-rc" "$rc" 1
  check "T8-rejected[$bad]-named" "$(printf '%s' "$out" | grep -c 'rejected map line')" 1
done
check T8b-tree-unchanged-after-rejections "$(cat "$EXT"/*/SKILL.md)" "$snap"
check T8c-no-evil-dir "$([ -e "$WORK/evil" ] && echo created || echo absent)" absent

# the real map parses: fixture repo with the real map and no vendored skill
mkdir -p "$WORK/real/lib" "$WORK/real/skills-external"
cp "$ROOT/lib/effort-pins.txt" "$WORK/real/lib/"
out="$(bash "$LIB" "$WORK/real" 2>&1)"; check T9-real-map-parses "$?" 0
check T9b-real-map-nothing-applied "$(printf '%s' "$out" | grep -c '0 applied, 0 already')" 1
check T10-missing-map-rc "$(bash "$LIB" "$WORK/nowhere" >/dev/null 2>&1; echo $?)" 1

# hardening: each case in its own fixture repo
mkrepo() { R="$WORK/$1"; mkdir -p "$R/lib" "$R/skills-external/$2"; }
mkrepo h11 alpha; mkdir "$WORK/h11/skills-external/beta"
printf -- '---\nname: alpha\n---\nb\n' > "$WORK/h11/skills-external/alpha/SKILL.md"
printf -- '---\nname: beta\n---\nb\n' > "$WORK/h11/skills-external/beta/SKILL.md"
printf 'alpha high\nbeta low' > "$WORK/h11/lib/effort-pins.txt"
bash "$LIB" "$WORK/h11" >/dev/null 2>&1
check T11-last-line-no-newline "$(fm_effort "$WORK/h11/skills-external/beta/SKILL.md")" low

mkrepo h12 open; f12="$WORK/h12/skills-external/open/SKILL.md"
printf -- '---\nname: open\nbody effort: max\n' > "$f12"; b12="$(cat "$f12")"
printf 'open high\n' > "$WORK/h12/lib/effort-pins.txt"
out="$(bash "$LIB" "$WORK/h12" 2>&1)"; rc=$?
check T12-unterminated-frontmatter-skipped \
  "$rc|$(cat "$f12" | cmp -s - <(printf '%s\n' "$b12") && echo same)|$(printf '%s' "$out" | grep -c "ERR .*$f12")" "1|same|1"

mkrepo h13 crlf
printf -- '---\r\nname: crlf\r\n---\r\nbody\r\n' > "$WORK/h13/skills-external/crlf/SKILL.md"
printf 'crlf high\n' > "$WORK/h13/lib/effort-pins.txt"
out="$(bash "$LIB" "$WORK/h13" 2>&1)"; rc=$?
check T13-crlf-file-rejected \
  "$rc|$(printf '%s' "$out" | grep -c 'ERR ')|$(printf '%s' "$out" | grep -c ' 0 applied, ')" "1|1|1"

# T13b: the post-write re-read branch, reached with a no-op write stub
mkrepo h13b nowrite; f13b="$WORK/h13b/skills-external/nowrite/SKILL.md"
printf -- '---\nname: nowrite\n---\nb\n' > "$f13b"
out="$(bash -c 'source "$1"; _effort_pin_write() { return 0; }
  _effort_pin_apply_one "$2" nowrite high' _ "$LIB" "$f13b" 2>&1)"; rc=$?
check T13b-reread-mismatch-fails \
  "$rc|$(printf '%s' "$out" | grep -c 'level not applied after write')" "1|1"

if [ "${EFFORT_PINS_TEST_FAKE_ROOT:-0}" = 1 ] || [ "$(id -u)" -eq 0 ]; then
  echo "SKIP T14-write-failure-no-temp: chmod bits ignored as root"
else
  mkrepo h14 ro; d14="$WORK/h14/skills-external/ro"
  printf -- '---\nname: ro\n---\nb\n' > "$d14/SKILL.md"
  printf 'ro high\n' > "$WORK/h14/lib/effort-pins.txt"
  chmod 555 "$d14"; out="$(bash "$LIB" "$WORK/h14" 2>&1)"; rc=$?; chmod 755 "$d14"
  check T14-write-failure-no-temp \
    "$rc|$(printf '%s' "$out" | grep -c 'ERR ')|$(find "$d14" -name 'SKILL.md.*' | wc -l)" "1|1|0"
fi

# T15: SIGINT during the awk write removes the temp sibling, exit 130
mkrepo h15 sig; d15="$WORK/h15/skills-external/sig"
printf -- '---\nname: sig\n---\nb\n' > "$d15/SKILL.md"
bash -c 'source "$1"; awk() { kill -INT $$; sleep 2; }
  _effort_pin_write "$2" sig high' _ "$LIB" "$d15/SKILL.md" >/dev/null 2>&1
rc=$?
check T15-sigint-removes-temp \
  "$rc|$(find "$d15" -name 'SKILL.md.*' | wc -l)" "130|0"

# T15b: previous INT trap restored on a normal return, no EXIT trap set
mkrepo h15b tr; d15b="$WORK/h15b/skills-external/tr"
printf -- '---\nname: tr\n---\nb\n' > "$d15b/SKILL.md"
out="$(bash -c 'source "$1"; trap "echo prev" INT
  _effort_pin_write "$2" tr high
  printf "INT:%s\n" "$(trap -p INT)"; printf "EXIT:%s\n" "$(trap -p EXIT)"' \
  _ "$LIB" "$d15b/SKILL.md" 2>&1)"
check T15b-traps-restored \
  "$(printf '%s' "$out" | grep -c "^INT:trap -- 'echo prev' SIGINT")|$(printf '%s' "$out" | grep -c '^EXIT:$')" "1|1"

# T16: a literal backslash-t in a map line is printed shell-quoted
mkrepo h16 q
printf 'bad\\tname high\n' > "$WORK/h16/lib/effort-pins.txt"
out="$(bash "$LIB" "$WORK/h16" 2>&1)"; rc=$?
check T16-rejected-line-quoted \
  "$rc|$(printf '%s' "$out" | grep -cF 'bad\\tname')" "1|1"

echo "effort-pins: $pass pass, $fail fail"
[ "$fail" -eq 0 ]
