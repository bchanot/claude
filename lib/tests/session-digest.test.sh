#!/usr/bin/env bash
# lib/tests/session-digest.test.sh — memory digest at the end of the
# session-start banner (phase 4c, Task 7). Fixture projects under mktemp -d.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SS="$ROOT/hooks/session-start.sh"
WORK="$(mktemp -d)" || exit 1; trap 'rm -rf "$WORK"' EXIT
export SESSION_START_OFFLINE=1
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

# Stub claude (BLK-043): a hook run that calls the CLI logs a line here
# instead of starting a session that re-runs this hook.
# shellcheck source=lib/tests/claude-stub.sh
. "$ROOT/lib/tests/claude-stub.sh" || exit 1
claude_stub_install "$WORK"

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

# todos <proj> <text...>: write the project TODO.md fixture (\n expands)
todos() {
  local IFS= p=$1; shift
  printf '%b' "$*" > "$p/.claude/tasks/TODO.md"
}
# todo_lines <proj>: the digest's todo lines, one per output line
todo_lines() { run "$1" - | digest | grep '^- todo:'; }

# SD5: TODO without Actionable -> fallback to the file's first item
p=$(mkproj sd5)
blk "$p" 1 open "Only blocker"
todos "$p" '### Backlog\n- [ ] hidden\n'
check SD5-no-actionable "$(run "$p" - | digest)" 'memory digest:
- open: BLK-001 Only blocker
- todo: hidden'

# SD5b: a `##` Actionable section wins over earlier items
p=$(mkproj sd5b)
todos "$p" '### Backlog\n- [ ] early\n## Actionable\n- [ ] act\n'
check SD5b-section-wins "$(todo_lines "$p")" '- todo: act'

# SD5c: empty section (only checked) -> fallback, capped at 3
p=$(mkproj sd5c)
todos "$p" '## Actionable\n- [x] done\n\n## Later\n' \
  '- [ ] fb1\n- [ ] fb2\n- [ ] fb3\n- [ ] fb4\n'
check SD5c-fallback-cap "$(todo_lines "$p")" '- todo: fb1
- todo: fb2
- todo: fb3'

# SD5d: indented items never count, in the section nor in the fallback
p=$(mkproj sd5d)
todos "$p" '## Actionable\n- [ ] top\n  - [ ] sub\n'
check SD5d-section "$(todo_lines "$p")" '- todo: top'
todos "$p" '# T\n  - [ ] sub\n- [ ] top\n    - [ ] deep\n'
check SD5d-fallback "$(todo_lines "$p")" '- todo: top'

# SD5e: items and headings inside <!-- --> never count
p=$(mkproj sd5e)
todos "$p" '- [ ] first\n<!--\n- [ ] ghost\n### Actionable\n-->\n- [ ] real\n'
check SD5e-fallback "$(todo_lines "$p")" '- todo: first
- todo: real'
todos "$p" '## Actionable\n<!--\n- [ ] ghost\n# x\n-->\n- [ ] real\n' \
  '<!-- one line - [ ] no -->\n## Z\n- [ ] after\n'
check SD5e-in-section "$(todo_lines "$p")" '- todo: real'

# SD5f: `#### Actionable` and `### Actionables` are not sections
p=$(mkproj sd5f)
todos "$p" '- [ ] first\n#### Actionable\n- [ ] x\n### Actionables\n- [ ] y\n'
check SD5f-not-sections "$(todo_lines "$p")" '- todo: first
- todo: x
- todo: y'

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
# lines drop from the last, a marker counts them, the journal and every
# BLK line stay
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
- todo: +2 not shown, read .claude/tasks/TODO.md
- journal: $(rep j 100)"
out=$(run "$p" - | digest)
check SD7-drops-last-todo "$out" "$want"
check SD7-le-800 "$([ "${#out}" -le 800 ] && echo yes || echo no)" yes

# SD7c: 3 todos fit between 751 and 800 chars: all shown, no marker
p=$(mkproj sd7c)
for i in 1 2 3; do blk "$p" "$i" open "$(rep b 100)"; done
printf '### Actionable\n- [ ] A%s\n- [ ] B%s\n- [ ] C%s\n' \
  "$(rep x 91)" "$(rep x 91)" "$(rep x 91)" > "$p/.claude/tasks/TODO.md"
printf '## d\n- %s\n' "$(rep j 100)" > "$p/.claude/memory/journal.md"
out=$(run "$p" - | digest)
check SD7c-3-todos "$(printf '%s\n' "$out" | grep -c '^- todo: [ABC]')" 3
check SD7c-no-marker "$(printf '%s\n' "$out" | grep -c 'not shown')" 0
check SD7c-size \
  "$([ "${#out}" -gt 751 ] && [ "${#out}" -le 800 ] && echo ok)" ok

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
check SD7b-no-todo "$(printf '%s\n' "$out" | grep -c '^- todo: [x]')" 0
check SD7b-marker "$(printf '%s\n' "$out" |
  grep -c '^- todo: +2 not shown, read .claude/tasks/TODO.md$')" 1
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
check SD9a-unknown "$(printf '%s\n' "$out" | grep -c -x -- '- open: unknown (memory.sh index failed)')" 1
printf '#!/usr/bin/env bash\nprintf "| BLK-1 |\\n| BLK-2 | x\\n| BLK-3 | d | t | weird |\\ngarbage\\n"\n' \
  > "$WORK/sd9/lib/memory.sh"
out=$(run "$p" - "$S9"); rc=$?
check SD9b-malformed-rc "$rc" 0
check SD9b-banner "$(printf '%s' "$out" | grep -c 'make doctor')" 1
check SD9b-none "$(printf '%s\n' "$out" | grep -c -x -- '- open: none')" 1
p=$(mkproj sd9d); mkdir "$p/.claude/memory/blockers.md"
out=$(run "$p" -); rc=$?
check SD9c-dir-rc "$rc" 0
check SD9c-banner "$(printf '%s' "$out" | grep -c 'make doctor')" 1
check SD9c-none "$(printf '%s\n' "$out" | grep -c -x -- '- open: none')" 1

# SD9d: a successful read with zero open rows says so
p=$(mkproj sd9e); blk "$p" 1 resolved "Done"
check SD9d-none "$(run "$p" - | digest | grep -c -x -- '- open: none')" 1
blk "$p" 2 open "Now open"
check SD9d-not-none "$(run "$p" - | digest | grep -c -x -- '- open: none')" 0

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

# SD11: the digest section stays bash 3.2 safe (macOS)
sec=$(sed -n '/^# ── memory digest ──/,/^unset _ss_digest/p' "$SS")
check SD11-section-found "$([ -n "$sec" ] && echo yes || echo no)" yes
check SD11-bash32-safe "$(printf '%s\n' "$sec" \
  | grep -c -e 'local -n' -e '\[-1\]' -e 'mapfile' -e 'declare -A' -e 'readarray')" 0

# now_ms: milliseconds (GNU date %N), whole seconds x 1000 where unsupported
now_ms() {
  local n; n=$(date +%s%N)
  case "$n" in *N*|"") echo $(( $(date +%s) * 1000 )) ;; *) echo $((n / 1000000)) ;; esac
}
# SD12: a memory.sh that hangs costs under 3.5 s, no digest, exit 0
printf '#!/usr/bin/env bash\ncase "$*" in *index*) sleep 5 ;; esac\n' \
  > "$WORK/sd9/lib/memory.sh"
p=$(mkproj sd12); blk "$p" 1 open "Slow"
t0=$(now_ms)
out=$(run "$p" - "$S9"); rc=$?
t1=$(now_ms)
check SD12-hang-bounded "$([ $((t1 - t0)) -lt 3500 ] && echo yes || echo no)" yes
check SD12-rc "$rc" 0
check SD12-banner "$(printf '%s' "$out" | grep -c 'make doctor')" 1
check SD12-unknown "$(printf '%s\n' "$out" | grep -c -x -- '- open: unknown (memory.sh index failed)')" 1

# SD16: a memory.sh whose `check` hangs costs under 3.5 s, exit 0
printf '#!/usr/bin/env bash\ncase "$*" in *check*) sleep 10 ;; esac\n' \
  > "$WORK/sd9/lib/memory.sh"
p=$(mkproj sd16)
t0=$(now_ms)
out=$(run "$p" - "$S9"); rc=$?
t1=$(now_ms)
check SD16-hang-bounded "$([ $((t1 - t0)) -lt 3500 ] && echo yes || echo no)" yes
check SD16-rc "$rc" 0

# mkhome <name> [json]: a HOME that links the real ~/.claude entries and
# holds the given memory.json (none when omitted); prints its path.
mkhome() {
  local h="$WORK/home-$1" f
  mkdir -p "$h/.claude"
  for f in "$HOME"/.claude/*; do
    [ "$(basename "$f")" = memory.json ] || ln -sf "$f" "$h/.claude/"
  done
  [ $# -lt 2 ] || printf '%s' "$2" > "$h/.claude/memory.json"
  echo "$h"
}
digests() { grep -c 'memory digest:'; }
p=$(mkproj sd13); blk "$p" 1 open "Switched"

# SD13: the memory switch. Only a boolean enabled:false cuts the digest.
check SD13a-enabled-false "$(cd "$p" && HOME=$(mkhome a '{"enabled": false}') \
  bash "$SS" <"$WORK/startup.json" 2>/dev/null | digests)" 0
check SD13b-recall-false "$(cd "$p" && HOME=$(mkhome b '{"recall": false}') \
  bash "$SS" <"$WORK/startup.json" 2>/dev/null | digests)" 1
check SD13c-malformed "$(cd "$p" && HOME=$(mkhome c '{"enabled": fal') \
  bash "$SS" <"$WORK/startup.json" 2>/dev/null | digests)" 1
check SD13d-string-false "$(cd "$p" && HOME=$(mkhome d '{"enabled": "false"}') \
  bash "$SS" <"$WORK/startup.json" 2>/dev/null | digests)" 1
check SD13e-absent "$(cd "$p" && HOME=$(mkhome e) \
  bash "$SS" <"$WORK/startup.json" 2>/dev/null | digests)" 1
check SD13f-enabled-true "$(cd "$p" && HOME=$(mkhome f '{"enabled": true}') \
  bash "$SS" <"$WORK/startup.json" 2>/dev/null | digests)" 1
check SD13g-not-an-object "$(cd "$p" && HOME=$(mkhome g '[1]') \
  bash "$SS" <"$WORK/startup.json" 2>/dev/null | digests)" 1
# no jq: the switch is unreadable and the existing rule applies, no digest
# from a hook (stdin is not a terminal)
check SD13h-no-jq "$(cd "$p" && HOME=$(mkhome h '{"enabled": false}') \
  PATH="$bin" bash "$SS" <"$WORK/startup.json" 2>/dev/null | digests)" 0

# SD14: a foreign repository (gitflow.protect false) gets no digest
p=$(mkproj sd14); blk "$p" 1 open "Foreign"
git -C "$p" init -q
check SD14a-unset "$(run "$p" "$WORK/startup.json" | digests)" 1
git -C "$p" config gitflow.protect true
check SD14b-true "$(run "$p" "$WORK/startup.json" | digests)" 1
git -C "$p" config gitflow.protect false
check SD14c-false "$(run "$p" "$WORK/startup.json" | digests)" 0
check SD14d-banner "$(run "$p" "$WORK/startup.json" | grep -c '^$')" \
  "$(run "$p" "$WORK/startup.json" | grep -c '^$')"

# SD17: the 4d reminder line prints before the digest, never inside it
h17="$WORK/h17"; mkdir -p "$h17/.claude/plugins/store"
: > "$h17/.claude/plugins/store/memory_skills-dir-a.json"
p=$(mkproj sd17); blk "$p" 1 open "Seventeen"
out17=$(cd "$p" && HOME="$h17" bash "$SS" <"$WORK/startup.json" 2>/dev/null)
check SD17-line "$(printf '%s\n' "$out17" \
  | grep -c '^memory feedback: never run')" 1
check SD17-before-digest "$(printf '%s\n' "$out17" \
  | grep -n -e '^memory feedback' -e '^memory digest' | cut -d: -f2 \
  | tr '\n' ' ')" "memory feedback memory digest "

# SD18: a journal born from the template prints no journal line (the
# example bullets sit in an HTML comment); a real entry appended after the
# comment is the one shown (G3, code-clean 2026-11-09)
p=$(mkproj sd18)
cp "$ROOT/templates/memory/journal.md" "$p/.claude/memory/journal.md"
check SD18-template-no-journal "$(run "$p" "$WORK/startup.json" | digest | grep -c '^- journal:')" 0
printf '\n## 2026-11-09\n\n- real entry\n' >> "$p/.claude/memory/journal.md"
check SD18-real-entry "$(run "$p" "$WORK/startup.json" | digest | grep '^- journal:')" '- journal: real entry'
printf -- "- note on \`<!--\` parser\n- newest\n" >> "$p/.claude/memory/journal.md"
check SD18-inline-marker "$(run "$p" "$WORK/startup.json" | digest | grep '^- journal:')" '- journal: newest'

# SD15: no hook run of this suite called the claude CLI (BLK-043)
check SD15-no-claude-calls "$(claude_stub_calls)" 0

# SD19: no timeout and no gtimeout on PATH -> the perl alarm runner still
# bounds a hung memory.sh (stock macOS)
bin="$WORK/notmo"; mkdir -p "$bin"
for c in bash git cat sed awk grep tail head cut dirname readlink wc tr \
  sort uniq iconv env date basename mktemp find ls cp rm mkdir cmp stat id \
  uname tee printf perl sleep jq; do
  src=$(command -v "$c" 2>/dev/null) && ln -sf "$src" "$bin/$c"
done
cat > "$WORK/sd9/lib/memory.sh" <<'EOF'
#!/usr/bin/env bash
exec sleep 8
EOF
p=$(mkproj sd19)
SECONDS=0
(cd "$p" && PATH="$bin" bash "$S9" </dev/null >/dev/null 2>&1)
check SD19-no-timeout-bin "$(PATH="$bin" command -v timeout gtimeout \
  | wc -l | tr -d ' ')" 0
check SD19-perl-bounds-hang "$([ "$SECONDS" -lt 6 ] && echo yes || echo no)" yes

printf 'session-digest: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
