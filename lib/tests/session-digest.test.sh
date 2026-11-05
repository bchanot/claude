#!/usr/bin/env bash
# lib/tests/session-digest.test.sh — memory digest at the end of the
# session-start banner (phase 4c, Task 7). Fixture projects under mktemp -d.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SS="$ROOT/hooks/session-start.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export SESSION_START_OFFLINE=1
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

# mkproj <name> -> path with an empty memory dir
mkproj() {
  mkdir -p "$WORK/$1/.claude/memory" "$WORK/$1/.claude/tasks"
  echo "$WORK/$1"
}
# blk <proj> <n> <status> <title>: append a BLK entry
blk() {
  printf '\n## BLK-%03d — %s [%s]\n\n- **Date**: 2026-11-0%d\n' \
    "$2" "$4" "$3" "$(( $2 % 9 + 1 ))" >> "$1/.claude/memory/blockers.md"
}
# run <proj> <stdin-file|-> [script]: the banner
run() {
  local in=${2:--}
  if [ "$in" = - ]; then
    (cd "$1" && bash "${3:-$SS}" </dev/null 2>/dev/null)
  else
    (cd "$1" && bash "${3:-$SS}" <"$in" 2>/dev/null)
  fi
}
digest() { sed -n '/^memory digest:/,$p' | sed '$d'; }
printf '{"source":"startup"}' > "$WORK/startup.json"
printf '{"source":"resume"}' > "$WORK/resume.json"
printf '{"source":"clear"}' > "$WORK/clear.json"
printf '{"source":"compact"}' > "$WORK/compact.json"

# SD1: 1 open + 2 upstream, 4 todo items, a journal
p=$(mkproj sd1)
blk "$p" 1 open "Bing API unusable"
blk "$p" 2 upstream "Up one"; blk "$p" 3 upstream "Up two"
printf '### Actionable\n- [ ] one\n- [x] done\n- [ ] two\n- [ ] three\n- [ ] four\n\n### Later\n- [ ] nope\n' \
  > "$p/.claude/tasks/TODO.md"
printf '## 2026-11-04\n- first line\n- 2026-11-04: last line\n' > "$p/.claude/memory/journal.md"
want='memory digest:
- open: BLK-001 Bing API unusable
- open: +2 upstream
- todo: one
- todo: two
- todo: three
- journal: 2026-11-04: last line'
check SD1-startup "$(run "$p" "$WORK/startup.json" | digest)" "$want"
check SD1b-clear "$(run "$p" "$WORK/clear.json" | digest)" "$want"
check SD1c-compact "$(run "$p" "$WORK/compact.json" | digest)" "$want"
check SD1d-banner-first "$(run "$p" "$WORK/startup.json" | head -2 | tail -1 | cut -c1-3)" "┌─ "

# SD2: resume -> none
check SD2-resume "$(run "$p" "$WORK/resume.json" | grep -c 'memory digest:')" 0

# SD3: empty stdin -> digest, exit 0
run "$p" - >/dev/null; rc=$?
check SD3-empty-source "$(run "$p" - | grep -c 'memory digest:')/$rc" 1/0

# SD4: no .claude/memory -> no block
mkdir -p "$WORK/sd4"
check SD4-no-memory "$(run "$WORK/sd4" - | grep -c 'memory digest:')" 0

# SD5: TODO without ### Actionable -> no todo line (others stay)
p=$(mkproj sd5)
blk "$p" 1 open "Only blocker"
printf '### Backlog\n- [ ] hidden\n' > "$p/.claude/tasks/TODO.md"
check SD5-no-actionable "$(run "$p" - | digest)" 'memory digest:
- open: BLK-001 Only blocker'

# SD6: a 400-char journal line with an em dash, cut at 160, valid UTF-8
p=$(mkproj sd6)
long=$(printf 'a — %.0s' $(seq 1 130))
printf '## d\n- %s\n' "$long" > "$p/.claude/memory/journal.md"
for loc in C.UTF-8 C; do
  out=$(cd "$p" && LC_ALL=$loc bash "$SS" </dev/null 2>/dev/null | digest | tail -1)
  ok=$(printf '%s' "$out" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1 && echo valid || echo invalid)
  check "SD6-valid-utf8-$loc" "$ok" valid
  check "SD6-ellipsis-$loc" "${out: -1}" "…"
done
out=$(cd "$p" && LC_ALL=C.UTF-8 bash "$SS" </dev/null 2>/dev/null | digest | tail -1)
check SD6-len-160 "${#out}" 160

# SD7: 3 open BLK + 3 long todos + a journal line over the 800 cap: todo
# lines drop from the last, the journal and every BLK line stay
rep() { printf "%$2s" '' | tr ' ' "$1"; }
p=$(mkproj sd7)
for i in 1 2 3; do blk "$p" "$i" open "$(rep b 100)"; done
printf '### Actionable\n- [ ] A%s\n- [ ] B%s\n- [ ] C%s\n' \
  "$(rep x 200)" "$(rep x 200)" "$(rep x 200)" > "$p/.claude/tasks/TODO.md"
printf '## d\n- %s\n' "$(rep j 100)" > "$p/.claude/memory/journal.md"
want="memory digest:
- open: BLK-001 $(rep b 100)
- open: BLK-002 $(rep b 100)
- open: BLK-003 $(rep b 100)
- todo: A$(rep x 150)…
- todo: B$(rep x 150)…
- journal: $(rep j 100)"
out=$(run "$p" - | digest)
check SD7-drops-last-todo "$out" "$want"
check SD7-le-800 "$([ "${#out}" -le 800 ] && echo yes || echo no)" yes

# SD7b: the worst case (10 open BLK, long titles, 3 long todos, 160-char
# journal): all todos drop, 3 BLK + count + journal stay, whole lines, <= 800
p=$(mkproj sd7b)
for i in 1 2 3 4 5 6 7 8 9 10; do blk "$p" "$i" open "$(rep b 300)"; done
blk "$p" 11 upstream "Up"
printf '### Actionable\n- [ ] %s\n- [ ] %s\n' "$(rep x 300)" "$(rep x 300)" \
  > "$p/.claude/tasks/TODO.md"
printf '## d\n- %s\n' "$(rep j 300)" > "$p/.claude/memory/journal.md"
out=$(run "$p" - | digest)
check SD7b-le-800 "$([ "${#out}" -le 800 ] && echo yes || echo no)" yes
check SD7b-no-todo "$(printf '%s\n' "$out" | grep -c '^- todo:')" 0
check SD7b-3-blk "$(printf '%s\n' "$out" | grep -c '^- open: BLK-')" 3
check SD7b-count-line "$(printf '%s\n' "$out" | grep -x -- '- open: +7 more, +1 upstream')" '- open: +7 more, +1 upstream'
check SD7b-journal "$(printf '%s\n' "$out" | tail -1)" "- journal: $(rep j 148)…"
check SD7b-lines-le-160 "$(printf '%s\n' "$out" | awk 'length($0) > 160' | wc -l | tr -d ' ')" 0

# SD9: copy of the script beside a failing / malformed lib; blockers dir
mkdir -p "$WORK/sd9/hooks" "$WORK/sd9/lib"
cp "$SS" "$WORK/sd9/hooks/session-start.sh"
for f in "$ROOT"/lib/*; do
  [ "$(basename "$f")" = memory.sh ] || ln -s "$f" "$WORK/sd9/lib/"
done
S9="$WORK/sd9/hooks/session-start.sh"
p=$(mkproj sd9)
blk "$p" 1 open "Never shown"
printf '#!/usr/bin/env bash\nexit 2\n' > "$WORK/sd9/lib/memory.sh"
out=$(run "$p" - "$S9"); rc=$?
check SD9a-exit2-rc "$rc" 0
check SD9a-banner "$(printf '%s' "$out" | grep -c 'make doctor')" 1
check SD9a-no-digest "$(printf '%s' "$out" | grep -c 'memory digest:')" 0
printf '#!/usr/bin/env bash\nprintf "| BLK-1 |\\n| BLK-2 | x\\n| BLK-3 | d | t | weird |\\ngarbage\\n"\n' \
  > "$WORK/sd9/lib/memory.sh"
out=$(run "$p" - "$S9"); rc=$?
check SD9b-malformed-rc "$rc" 0
check SD9b-banner "$(printf '%s' "$out" | grep -c 'make doctor')" 1
check SD9b-no-digest "$(printf '%s' "$out" | grep -c 'memory digest:')" 0
p=$(mkproj sd9d); mkdir "$p/.claude/memory/blockers.md"
out=$(run "$p" -); rc=$?
check SD9c-dir-rc "$rc" 0
check SD9c-banner "$(printf '%s' "$out" | grep -c 'make doctor')" 1
check SD9c-no-digest "$(printf '%s' "$out" | grep -c 'memory digest:')" 0

# SD10: PATH without jq, piped resume -> no digest, banner intact
bin="$WORK/nojq"; mkdir -p "$bin"
for c in bash git cat sed awk grep tail head cut dirname readlink wc tr \
  sort uniq timeout iconv env date basename mktemp find ls cp rm mkdir \
  cmp stat id uname tee printf; do
  src=$(command -v "$c" 2>/dev/null) && ln -sf "$src" "$bin/$c"
done
p=$(mkproj sd10); blk "$p" 1 open "Hidden"
out=$(cd "$p" && PATH="$bin" bash "$SS" <"$WORK/resume.json" 2>/dev/null)
check SD10-no-jq-no-digest "$(printf '%s' "$out" | grep -c 'memory digest:')" 0
check SD10-no-jq-banner "$(printf '%s' "$out" | grep -c 'make doctor')" 1
check SD10-jq-really-absent "$(PATH="$bin" command -v jq | wc -l | tr -d ' ')" 0

printf 'session-digest: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
