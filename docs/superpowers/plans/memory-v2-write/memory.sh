#!/usr/bin/env bash
# lib/memory.sh — the single writer and reader of the .claude/memory
# registries (BDR-125 phase 4a). Sourceable; every verb takes an optional
# leading `-C <dir>` (a dispatched agent's cwd is the session's, never the
# project's):
#   add <kind> --title <t> --body-file <f> [--status <s>] [--supersedes <ID>]
#                 append one entry, next ID from the headings, under the
#                 lock; the new ID is the only stdout line
#   status <ID> <text>   append `- **Status (<date>)**: <text>` to the entry;
#                 <text> starts with a status word ("open, reopened by …")
#   journal <line>       append `- <line>` under today's `## YYYY-MM-DD`
#   index [<kind>]       ID | Date | Title | Status, from headings and bodies
#   check [--staged] [<memory-dir>]   heading shape, unique IDs, no Index,
#                 no open fence in a v2 file (v1 reported, never failed);
#                 --staged: only NEW culprits vs HEAD, no line removed
#                 inside an entry, no v2 registry deleted or downgraded
#   upgrade [<memory-dir>]   v1 → v2: Index-only dates and statuses become
#                 body lines, `format: 2`, `## Index` removed, oracle first
# <kind> = decision | learning | blocker | eval. MEMORY_DATE overrides today.
# Status of an entry: the last candidate wins. A candidate is the heading's
# trailing `[tag]`, or a body line whose bold label names Status, Resolution,
# Action, UPDATE or FINAL (v1: `Status:`), holding a status word. A word in
# prose (title included) is never one (the BLK-032..034 false-open). A dated
# `**Status (YYYY-MM-DD…)**:` line reads its leading word; other lines rank
# words in _MEM_WORDS order, `open` last: "accepted, check OPEN" = accepted.
# Closed = resolved | superseded | deprecated (memory_closed).
# Lock: <git-common-dir>/memory.lock created under noclobber (flock(1) is
# absent on macOS), holding "<epoch> <token>"; released only by its token;
# a lock older than 30 s (or seen empty 10 times) is stolen by one waiter
# at a time (memory.lock.steal). Every writer runs on a verified backup
# of its file, restored on failure or signal. Next ID = max over headings
# of any level, fenced or not. Free text reaches awk through ENVIRON,
# never `-v` (which expands backslash escapes).

MEM_GREP="${MEM_GREP:-/usr/bin/grep}"
_MEM_TABLE='decision decisions BDR
learning learnings LRN
blocker blockers BLK
eval evals EVAL'
_MEM_WORDS='resolved superseded deprecated upstream accepted implemented'
_MEM_WORDS+=' shipped proposed keep correct deprecate open'
_MEM_AWK='
function mem_word(s,   t, i, n, w) {
  t = tolower(s); n = split(MEMW, w, " ")
  for (i = 1; i <= n; i++)
    if (t ~ ("(^|[^a-z])" w[i] "([^a-z]|$)")) return w[i]
  return "" }
function mem_lead(s,   v, i, n, w) {
  v = s; sub(/^[^:]*\*\*: */, "", v); v = tolower(v)
  sub(/[^a-z].*$/, "", v); n = split(MEMW, w, " ")
  for (i = 1; i <= n; i++) if (v == w[i]) return v
  return "" }
function mem_lineword(s,   w) {
  if (s ~ /^- \*\*Status \([0-9]/ && (w = mem_lead(s)) != "") return w
  return mem_word(s) }
function mem_tag(line) {
  if (!match(line, /\[[^]]*\]( \([0-9-]+\))? *$/)) return ""
  if (mem_word(substr(line, RSTART)) == "") return ""
  line = substr(line, RSTART); sub(/\].*$/, "]", line); return line }
function mem_cand(line,   lab) {
  if (line ~ /^- \*\*[^*]+\*\*/) {
    lab = line; sub(/^- \*\*/, "", lab); sub(/\*\*.*/, "", lab)
    if (tolower(lab) !~ /status|resolution|action|update|final/) return ""
    return mem_lineword(line) }
  if (line ~ /^(- )?[Ss]tatus:/) return mem_word(line)
  return "" }
function mem_key(line, key,   c) {
  if (index(line, "## " key) != 1) return 0
  c = substr(line, length(key) + 4, 1)
  return c == "" || c !~ /[0-9A-Za-z]/ }
function mem_want(p, c, st,   w) {
  w = mem_word(c)
  if (p == "EVAL" || w == "") return ""
  if (p == "LRN") return c ~ /^superseded by/ ? c : ""
  if (st == "" || (w ~ /^(superseded|deprecated)$/ && st != w)) return c
  return "" }
'

_mem_date() { printf '%s\n' "${MEMORY_DATE:-$(date +%F)}"; }

_mem_table() {  # <out col> [<key col> <value>] → matching cells, rc 2 if none
  # the one reader of _MEM_TABLE (1 kind, 2 registry basename, 3 prefix)
  awk -v o="$1" -v c="${2:-0}" -v v="${3:-}" '
    c == 0 || $c == v { print $o; f = 1 }
    END { exit f ? 0 : 2 }' <<< "$_MEM_TABLE"
}

_mem_names() { _mem_table 2; }  # the four registry basenames

_mem_kind() {  # <kind> → "<file>.md <PREFIX>", rc 2 when unknown
  local file
  file=$(_mem_table 2 1 "$1") || {
    echo "memory: unknown kind: $1 (decision|learning|blocker|eval)" >&2
    return 2; }
  echo "$file.md $(_mem_table 3 1 "$1")"
}

_mem_id_file() {  # <ID> → its registry path, rc 2 when the prefix is unknown
  local file
  file=$(_mem_table 2 3 "${1%%-[0-9]*}") \
    || { echo "memory: not an entry ID: $1" >&2; return 2; }
  echo ".claude/memory/$file.md"
}

_mem_prefix() {  # <registry path> → its prefix by basename, rc 2 if none
  local base="${1##*/}"
  _mem_table 3 2 "${base%.md}" \
    || { echo "memory: $1: not a registry name" >&2; return 2; }
}

memory_is_v2() {  # <file> → rc 0 when the frontmatter carries `format: 2`
  awk 'NR == 1 && $0 != "---" { exit }
       NR > 1 && $0 == "---" { exit }
       $0 == "format: 2" { v2 = 1; exit }
       END { exit !v2 }' "$1"
}

_mem_has_id() {  # <file> <ID> → rc 0 when a heading carries the ID
  MEM_K="$2" awk "$_MEM_AWK"'
    BEGIN { k = ENVIRON["MEM_K"] }
    /^```/ { fence = !fence; next }
    !fence && mem_key($0, k) { found = 1; exit }
    END { exit !found }' "$1"
}

_mem_next_id() {  # <file> <PREFIX> → max heading ID + 1, zero-padded
  # every heading level, fenced or not: a gap is harmless, a duplicate is
  # not (trucks_at_work writes `### BDR-001`; a stray fence hides headings)
  awk -v p="$2" '
    match($0, "^#+ *" p "-[0-9]+") {
      n = substr($0, RSTART, RLENGTH); sub(/^#+ *[A-Z]+-/, "", n)
      if (n + 0 > m) m = n + 0 }
    END { printf "%s-%03d\n", p, m + 1 }' "$1"
}

_mem_heading_has() {  # <file> <ID> → rc 0 when a heading of any level has it
  awk -v id="$2" 'match($0, "^#+ *" id "([^0-9]|$)") { f = 1; exit }
                  END { exit !f }' "$1"
}

_mem_fence_open() {  # <file> → rc 0 when a ``` fence is left open
  awk '/^```/ { n++ } END { exit !(n % 2) }' "$1"
}

memory_entry_status() {  # <file> <ID> → the winning candidate, rc 1 if none
  # a heading candidate prints its `[tag]` only, never the title
  MEM_K="$2" awk -v MEMW="$_MEM_WORDS" "$_MEM_AWK"'
    BEGIN { k = ENVIRON["MEM_K"] }
    /^```/ { fence = !fence; next }
    fence { next }
    /^## / { if (on) exit
             if (mem_key($0, k)) { on = 1; t = mem_tag($0)
                                   if (t != "") last = t }
             next }
    on && mem_cand($0) != "" { last = $0 }
    END { if (last == "") exit 1; print last }' "$1"
}

memory_status_word() {  # <line> → its status word, else its first 40 chars
  MEM_L="$1" awk -v MEMW="$_MEM_WORDS" "$_MEM_AWK"'
    BEGIN { s = ENVIRON["MEM_L"]; w = mem_lineword(s)
            print (w != "" ? w : substr(s, 1, 40)) }'
}

memory_closed() {  # <status word> → rc 0 when it closes the entry
  case "$1" in resolved|superseded|deprecated) return 0 ;; esac
  return 1
}

_mem_lock_path() {  # → the lock file for the current repository
  local d
  if d=$(git rev-parse --git-common-dir 2>/dev/null); then
    echo "$d/memory.lock"; return
  fi
  echo "${TMPDIR:-/tmp}/memory-$(pwd | cksum | cut -d' ' -f1).lock"
}

_mem_stale() {  # <lock content> <times seen empty> → rc 0 when stealable
  local t="${1%% *}"
  if [ -z "$1" ]; then [ "$2" -ge 10 ]; return; fi
  case "$t" in ''|*[!0-9]*) return 1 ;; esac
  [ $(( $(date +%s) - t )) -gt 30 ]
}

_mem_steal() {  # <lock> → remove a stale lock; one stealer at a time
  local g="$1.steal" seen
  if ! (set -C; date +%s > "$g") 2>/dev/null; then
    _mem_stale "$(cat "$g" 2>/dev/null) x" 0 && rm -f "$g"  # dead stealer
    return 0
  fi
  seen=$(cat "$1" 2>/dev/null)
  _mem_stale "$seen" 10 && rm -f "$1"  # age re-read under the guard
  rm -f "$g"
}

_mem_lock() {  # <lock file> <token> → rc 0 held, rc 2 after MEM_LOCK_TRIES
  # noclobber = open(O_EXCL) by bash itself: mkdir is not atomic under
  # uutils coreutils 0.10 (two concurrent mkdir both succeed)
  local lock="$1" tries=0 empty=0 t
  until (set -C; echo "$(date +%s) $2" > "$lock") 2>/dev/null; do
    t=$(cat "$lock" 2>/dev/null)
    if [ -z "$t" ]; then empty=$((empty + 1)); else empty=0; fi
    if _mem_stale "$t" "$empty"; then _mem_steal "$lock"; continue; fi
    tries=$((tries + 1))
    [ "$tries" -lt "${MEM_LOCK_TRIES:-50}" ] \
      || { echo "memory: lock busy: $lock" >&2; return 2; }
    sleep 0.2
  done
}

_mem_unlock() {  # <lock> <token> → remove the lock only when it is ours
  [ "$(cut -d' ' -f2 < "$1" 2>/dev/null)" = "$2" ] && rm -f "$1"
  return 0
}

_mem_restore() {  # <backup> <file> → put the verified copy back if changed
  [ -s "$1" ] || return 0
  cmp -s "$1" "$2" && return 0
  cat "$1" > "$2" && echo "memory: $2 restored" >&2
}

_mem_backed() {  # <fn> <file> [args…] → fn on a verified backup of <file>,
  # restored when fn fails or a signal lands. Runs inside _mem_locked: the
  # trap reads that frame's __mem_lock / __mem_tok (dynamic scope), and
  # every name here is __-prefixed so fn's own locals never shadow it.
  local __mem_bak __mem_file="$2" __mem_old __mem_rc
  __mem_bak=$(mktemp) || { echo "memory: no temp file" >&2; return 2; }
  if ! { cat "$2" > "$__mem_bak" && cmp -s "$2" "$__mem_bak"; }; then
    rm -f "$__mem_bak"; echo "memory: backup of $2 failed, nothing written" >&2
    return 2
  fi
  __mem_old=$(trap -p INT TERM HUP)
  trap '_mem_restore "$__mem_bak" "$__mem_file"
        _mem_unlock "$__mem_lock" "$__mem_tok"; exit 130' INT TERM HUP
  "$@"; __mem_rc=$?
  trap - INT TERM HUP; eval "$__mem_old"
  [ "$__mem_rc" = 0 ] || _mem_restore "$__mem_bak" "$__mem_file"
  rm -f "$__mem_bak"
  return "$__mem_rc"
}

_mem_locked() {  # <fn> <file> [args…] → fn under the lock, its rc; fn's
  local __mem_lock __mem_tok out rc   # stdout is printed after the unlock
  __mem_lock=$(_mem_lock_path); __mem_tok="$$.$RANDOM"
  out=$(mktemp) || { echo "memory: no temp file" >&2; return 2; }
  _mem_lock "$__mem_lock" "$__mem_tok" || { rm -f "$out"; return 2; }
  _mem_backed "$@" > "$out"; rc=$?
  _mem_unlock "$__mem_lock" "$__mem_tok"
  cat "$out"; rm -f "$out"
  return "$rc"
}

_mem_one_line() {  # <what> <text> → rc 2 when empty or multi-line
  case "$2" in
    ''|*$'\n'*) echo "memory: $1 must be one non-empty line" >&2; return 2 ;;
  esac
}

_mem_insert() {  # <file> <key> <line> [exact] → line ends the section,
  local tmp      # rc 1 if absent; exact: the heading is `## <key>` alone
  tmp=$(mktemp) || { echo "memory: no temp file" >&2; return 2; }
  MEM_K="$2" MEM_INS="$3" MEM_X="${4:-}" awk "$_MEM_AWK"'
    BEGIN { k = ENVIRON["MEM_K"]; ins = ENVIRON["MEM_INS"]
            x = ENVIRON["MEM_X"] != "" }
    function hit(l) { return x ? l == "## " k : mem_key(l, k) }
    function flush(  i) { print ins; for (i = 1; i <= n; i++) print buf[i]
                          n = 0; done = 1 }
    /^```/ { fence = !fence }
    on && !fence && /^## / { flush(); on = 0 }
    !done && !on && !fence && hit($0) { on = 1; print; next }
    on { if ($0 == "" || $0 == "---") { buf[++n] = $0; next }
         for (i = 1; i <= n; i++) print buf[i]; n = 0; print; next }
    { print }
    END { if (on) flush(); exit !done }' "$1" > "$tmp"
  case $? in
    0) cat "$tmp" > "$1" || {
         echo "memory: write-back of $1 failed; full copy kept: $tmp" >&2
         return 2; } ;;
    *) rm -f "$tmp"; return 1 ;;
  esac
  rm -f "$tmp"
}

_mem_status_text() {  # <text> → rc 2 unless it starts with a status word
  local w
  w=$(tr '[:upper:]' '[:lower:]' <<< "${1%%[^A-Za-z]*}")
  case " $_MEM_WORDS " in *" $w "*) [ -n "$w" ] && return 0 ;; esac
  echo "memory: status text starts with a status word: $_MEM_WORDS" >&2
  return 2
}

memory_status() {  # <ID> <text>
  local file rc
  _mem_one_line "status text" "$2" || return 2
  _mem_status_text "$2" || return 2
  file=$(_mem_id_file "$1") || return 2
  [ -f "$file" ] || { echo "memory: no registry: $file" >&2; return 2; }
  _mem_locked _mem_insert "$file" "$1" "- **Status ($(_mem_date))**: $2"
  rc=$?
  case "$rc" in
    0) return 0 ;;
    1) echo "memory: no entry $1 in $file" >&2 ;;
    *) echo "memory: $1 status not written" >&2 ;;
  esac
  return 2
}

_mem_journal_locked() {  # <file> <date> <line>
  _mem_insert "$1" "$2" "$3" exact
  case $? in
    1) printf '\n## %s\n%s\n' "$2" "$3" >> "$1" ;;
    0) return 0 ;;
    *) return 2 ;;
  esac
}

memory_journal() {  # <line> → `- <line>` under today's heading
  local file=.claude/memory/journal.md line="$1"
  _mem_one_line "journal line" "$line" || return 2
  [ -f "$file" ] || { echo "memory: no $file" >&2; return 2; }
  case "$line" in '- '*) ;; *) line="- $line" ;; esac
  _mem_locked _mem_journal_locked "$file" "$(_mem_date)" "$line" \
    || { echo "memory: journal line not written" >&2; return 2; }
}

_mem_add_valid() {  # <PREFIX> <title> <body-file> <status> <supersedes>
  _mem_one_line title "$2" || return 2
  case "$2$4" in *'['*|*']'*|*'|'*)
    echo "memory: title and status take no [ ] |" >&2; return 2 ;;
  esac
  [ "${#2}" -le 160 ] || { echo "memory: title over 160 chars" >&2; return 2; }
  case "$4" in *$'\n'*) _mem_one_line status "$4"; return 2 ;; esac
  [ -z "$4" ] || _mem_status_text "$4" || return 2
  [ -s "$3" ] || { echo "memory: empty or missing body: $3" >&2; return 2; }
  ! _mem_fence_open "$3" \
    || { echo "memory: body leaves a code fence open" >&2; return 2; }
  if [ "$1" = BLK ] && ! "$MEM_GREP" -q '`' "$3"; then
    echo "memory: a blocker body quotes ≥1 error in backticks" >&2; return 2
  fi
  case "$5" in ''|"$1"-[0-9]*) ;; *)
    echo "memory: --supersedes takes a $1 ID: $5" >&2; return 2 ;;
  esac
}

_mem_entry_text() {  # <title> <body-file> <status> <supersedes> <v1>
  local tag=""   # v1: the status is a body line (the v1 reconcile reader
  [ -z "$3" ] || [ -n "$5" ] || tag=" [$3]"   # never reads the heading)
  printf '%s%s (%s)\n' "$1" "$tag" "$(_mem_date)"
  [ -z "$3" ] || [ -z "$5" ] || printf -- '- **Status**: %s\n' "$3"
  awk '{ l[NR] = $0 } END { n = NR; while (n > 0 && l[n] == "") n--
                            for (i = 1; i <= n; i++) print l[i] }' "$2"
  [ -z "$4" ] || printf 'Supersedes [[%s]].\n' "$4"
}

_mem_add_locked() {  # <file> <PREFIX> <entry-file> <supersedes>
  local f="$1" id pre rc=0   # runs under _mem_locked: failure = restore
  if _mem_fence_open "$f"; then
    echo "memory: $f leaves a code fence open; fix it first" >&2; return 2
  fi
  id=$(_mem_next_id "$f" "$2")
  if _mem_heading_has "$f" "$id"; then
    echo "memory: $id already in a heading of $f" >&2; return 2
  fi
  pre=$(mktemp) || { echo "memory: no temp file" >&2; return 2; }
  cat "$f" > "$pre"
  { printf '\n## %s — ' "$id"; cat "$3"; } >> "$f" || rc=2
  if [ "$rc" = 0 ] && [ -n "$4" ]; then
    _mem_insert "$f" "$4" "- **Status ($(_mem_date))**: superseded by $id" \
      || rc=2
  fi
  if [ "$rc" = 0 ] && memory_is_v2 "$f"; then
    memory_check_file "$f" "$2" "$pre" || rc=2
  fi
  rm -f "$pre"
  [ "$rc" = 0 ] && echo "$id"
  return "$rc"
}

memory_add() {  # <kind> <title> <body-file> <status> <supersedes>
  local spec file entry rc v1=""
  spec=$(_mem_kind "$1") || return 2
  file=".claude/memory/${spec% *}"
  _mem_add_valid "${spec#* }" "$2" "$3" "$4" "$5" || return 2
  [ -f "$file" ] || { echo "memory: no registry: $file" >&2; return 2; }
  [ -z "$5" ] || _mem_has_id "$file" "$5" \
    || { echo "memory: no entry $5 in $file" >&2; return 2; }
  memory_is_v2 "$file" || {
    v1=1; echo "memory: v1 registry (no format: 2): $file" >&2; }
  entry=$(mktemp) || { echo "memory: no temp file" >&2; return 2; }
  _mem_entry_text "$2" "$3" "$4" "$5" "$v1" > "$entry"
  _mem_locked _mem_add_locked "$file" "${spec#* }" "$entry" "$5"; rc=$?
  rm -f "$entry"
  return "$rc"
}

_mem_add_cli() {  # <kind> --title t --body-file f [--status s] [--supersedes I]
  local kind="${1:-}" title="" body="" st="" sup=""
  [ $# -gt 0 ] && shift
  while [ $# -gt 0 ]; do
    [ $# -ge 2 ] || { echo "memory: add: $1 needs a value" >&2; return 2; }
    case "$1" in
      --title) title="$2" ;;
      --body-file) body="$2" ;;
      --status) st="$2" ;;
      --supersedes) sup="$2" ;;
      *) echo "memory: add: unknown option: $1" >&2; return 2 ;;
    esac
    shift 2
  done
  memory_add "$kind" "$title" "$body" "$st" "$sup"
}

_mem_culprits() {  # <file> <PREFIX> → "<line>\t<reason>" per culprit
  awk -v p="$2" '
    /^```/ { fence = !fence; next }
    fence { next }
    $0 == "## Index" { print NR "\t## Index in a v2 registry" }
    !match($0, "^## " p "-[0-9]") { next }
    !match($0, "^## " p "-[0-9][0-9][0-9]+ — .") {
      print NR "\theading shape: " $0; next }
    seen[$2]++ { print NR "\tduplicate " $2 }
    END { if (fence) print NR "\tcode fence open at end of file" }' "$1"
}

memory_check_file() {  # <file> <PREFIX> [<reference>] [<name>] → rc 2 on a
  # culprit. With a reference only culprits absent from it count (a merge
  # duplicate never blocks the next append); an open fence always counts
  local p="$2" ref="${3:-/dev/null}" name="${4:-$1}"
  [ -s "$ref" ] || ref=/dev/null
  awk -F'\t' -v f="$name" '
    FILENAME == ARGV[1] { old[$2]++; next }
    $2 !~ /^code fence/ && old[$2]-- > 0 { next }
    { print "memory: " f ":" $1 ": " $2; bad = 1 }
    END { exit bad ? 2 : 0 }' \
    <(_mem_culprits "$ref" "$p") <(_mem_culprits "$1" "$p") >&2
}

memory_check() {  # [--staged] [<memory-dir>] → rc 2 on any culprit
  local staged="" dir f rc=0
  [ "${1:-}" = --staged ] && { staged=1; shift; }
  dir="${1:-.claude/memory}"
  case "$staged:$dir" in 1:/*|1:..|1:../*|1:*/../*|1:*/..)
    echo "memory: check --staged takes a repo-relative dir: $dir" >&2
    return 2 ;;
  esac
  for f in $(_mem_names); do
    f="$dir/$f.md"
    if [ -n "$staged" ]; then _mem_check_staged "$f" || rc=2; continue; fi
    [ -f "$f" ] || continue
    if ! memory_is_v2 "$f"; then echo "memory: v1: $f" >&2; continue; fi
    memory_check_file "$f" "$(_mem_prefix "$f")" || rc=2
  done
  return "$rc"
}

_mem_blob() {  # <rev:path> <out file> → rc 1 when the blob is absent
  git cat-file -e "$1" 2>/dev/null && git show "$1" > "$2"
}

_mem_check_staged() {  # <file> → rc 2 on a new culprit or a lost v2 file
  local h s rc=0
  h=$(mktemp) || { echo "memory: no temp file" >&2; return 2; }
  s=$(mktemp) || { rm -f "$h"; echo "memory: no temp file" >&2; return 2; }
  _mem_blob "HEAD:./$1" "$h" || : > "$h"
  _mem_blob ":./$1" "$s" || : > "$s"
  if [ -s "$h" ] && memory_is_v2 "$h" && ! { [ -s "$s" ] && memory_is_v2 "$s"; }
  then
    echo "memory: $1: staged deletion, emptying or loss of format: 2" >&2
    rc=2
  elif [ -s "$s" ] && memory_is_v2 "$s"; then
    memory_check_file "$s" "$(_mem_prefix "$1")" "$h" "$1" || rc=2
    _mem_removed_lines "$1" "$h" || rc=2
  fi
  rm -f "$h" "$s"
  return "$rc"
}

_mem_removed_lines() {  # <file> <HEAD copy> → rc 2 when a hunk removes an
  local p first        # entry line (an Index sits above the first entry)
  [ -s "$2" ] || return 0
  p=$(_mem_prefix "$1" 2>/dev/null) || return 0
  first=$(awk -v p="$p" '/^```/ { fence = !fence; next }
    !fence && match($0, "^## " p "-[0-9]") { print NR; exit }' "$2")
  [ -n "$first" ] || return 0
  git -c diff.interHunkContext=0 diff --cached --no-color --no-ext-diff \
    --no-textconv -U0 -- "$1" | awk -v first="$first" -v f="$1" '
    /^@@ / { split($2, a, ","); start = substr(a[1], 2) + 0
             cnt = (2 in a) ? a[2] + 0 : 1
             if (cnt > 0 && start + cnt - 1 >= first) {
               print "memory: " f ": line " start " removed inside an entry" \
                     " (fix it, then commit with /commit-change)"
               bad = 1 } }
    END { exit bad ? 2 : 0 }' >&2
}

_mem_index_rows() {  # <file> <PREFIX> → "| ID | date | title | word |" rows
  awk -v p="$2" -v MEMW="$_MEM_WORDS" "$_MEM_AWK"'
    function row() { if (id != "") print "| " id " | " d " | " t " | " s " |" }
    /^```/ { fence = !fence; next }
    fence { next }
    /^## / { row(); id = ""
      if (!match($0, "^## " p "-[0-9]+")) next
      id = $2; t = $0; sub(/^## [^ ]+( — )?/, "", t); d = ""
      s = mem_word(mem_tag(t))
      if (match(t, / \([0-9-]+\) *$/)) {
        d = substr(t, RSTART + 2, RLENGTH - 3); t = substr(t, 1, RSTART - 1) }
      else if (match(t, / — [0-9][0-9][0-9][0-9]-[0-9-]+ *$/)) {
        d = substr(t, RSTART); t = substr(t, 1, RSTART - 1)
        sub(/^ — /, "", d) }
      sub(/ \[[^]]*\] *$/, "", t); gsub(/\|/, "/", t); next }
    id == "" { next }
    d == "" && sub(/^- \*\*Date\*\*: */, "") { d = substr($0, 1, 10) }
    (w = mem_cand($0)) != "" { s = w }
    END { row() }' "$1"
}

memory_index() {  # [<kind>] → one table per registry
  local kinds k spec file
  kinds=${1:-$(awk '{ print $1 }' <<< "$_MEM_TABLE")}
  for k in $kinds; do
    spec=$(_mem_kind "$k") || return 2
    file=".claude/memory/${spec% *}"
    [ -f "$file" ] || continue
    printf '%s\n\n| ID | Date | Title | Status |\n|---|---|---|---|\n' "$file"
    _mem_index_rows "$file" "${spec#* }"
    echo
  done
}

_mem_index_table() {  # <file> → "ID<TAB>date<TAB>last column" per Index row
  awk '$0 == "## Index" { on = 1; next }
       on && /^## / { exit }
       on && /^\| *[A-Z]+-[0-9]+ *\|/ {
         n = split($0, c, "|")
         for (i = 2; i < n; i++) gsub(/^ +| +$/, "", c[i])
         print c[2] "\t" c[3] "\t" c[n - 1] }' "$1"
}

_mem_upgrade_text() {  # <rows> <file> <PREFIX> → the v2 text on stdout
  awk -v p="$3" -v today="$(_mem_date)" -v MEMW="$_MEM_WORDS" "$_MEM_AWK"'
    function flush(  i, s, w) {
      w = mem_word(col[cur])
      if (cur != "" && (s = mem_want(p, col[cur], st[cur])) != "")
        print "- **Status (" today ", upgrade)**: " s
      else if (cur != "" && w != "" && p !~ /^(LRN|EVAL)$/ && w != st[cur])
        print "memory: " cur ": kept body " st[cur] ", dropped Index " \
              col[cur] > "/dev/stderr"
      for (i = 1; i <= n; i++) print buf[i]
      n = 0 }
    FILENAME == ARGV[1] { split($0, r, "\t"); dt[r[1]] = r[2]
                          col[r[1]] = r[3]; next }
    FILENAME == ARGV[2] { split($0, r, / \| /); sub(/^\| /, "", r[1])
                sub(/ \|$/, "", r[4]); hd[r[1]] = r[2] != ""; st[r[1]] = r[4]
                next }
    FNR == 1 { print; print "format: 2"; next }
    /^```/ { fence = !fence }
    $0 == "## Index" { skip = 1; next }
    skip { if (/^\|/) { tbl = 1; next }
           if (!tbl || $0 == "") { if (tbl) skip = 0; next }
           skip = 0 }
    !fence && /^## / { flush(); split($0, w, " ")
      cur = (w[2] in col) ? w[2] : ""; print
      if (cur != "" && !hd[cur] && dt[cur] != "") print "- **Date**: " dt[cur]
      next }
    cur != "" && ($0 == "" || $0 == "---") { buf[++n] = $0; next }
    { for (i = 1; i <= n; i++) print buf[i]; n = 0; print }
    END { flush() }' "$1" <(_mem_index_rows "$2" "$3") "$2"
}

_mem_upgrade_oracle() {  # <old> <new> <PREFIX> <rows> → rc 2 on a lost fact
  local o n
  [ "$("$MEM_GREP" -E "^## $3-[0-9]" "$1")" \
    = "$("$MEM_GREP" -E "^## $3-[0-9]" "$2")" ] \
    || { echo "memory: upgrade changed a heading: $1" >&2; return 2; }
  memory_check_file "$2" "$3" || return 2
  o=$(_mem_index_rows "$1" "$3"); n=$(_mem_index_rows "$2" "$3")
  awk -F'\t' -v p="$3" -v MEMW="$_MEM_WORDS" "$_MEM_AWK"'
    function f(s, k) { split(s, a, / \| /); return a[k] }
    FILENAME == ARGV[1] { dt[$1] = $2; col[$1] = $3; next }
    { id = f($0, 1); sub(/^\| /, "", id) }
    FILENAME == ARGV[2] { old[id] = f($0, 4); sub(/ \|$/, "", old[id]); next }
    !(id in col) { next }
    { d = f($0, 2); s = f($0, 4); sub(/ \|$/, "", s)
      m = mem_want(p, col[id], old[id])
      want = m != "" ? mem_word(m) : old[id]
      if (dt[id] != "" && d == "") bad = bad " " id ":date"
      if (want != "" && s != want) bad = bad " " id ":" s "!=" want }
    END { if (bad != "") { print "memory: upgrade lost:" bad; exit 2 } }' \
    "$4" <(printf '%s\n' "$o") <(printf '%s\n' "$n") >&2
}

_mem_upgrade_ready() {  # <file> → rc 0 upgradable, 1 already v2, 2 refused
  local first p
  IFS= read -r first < "$1"
  [ "$first" = --- ] \
    || { echo "memory: $1: no frontmatter, not upgraded" >&2; return 2; }
  memory_is_v2 "$1" && { echo "memory: $1 already v2" >&2; return 1; }
  p=$(_mem_prefix "$1") || return 2
  awk -v p="$p" '/^```/ { fence = !fence; next }
    !fence && match($0, "^## " p "-[0-9]+") \
      && substr($0, RLENGTH + 1) !~ /^( — |$)/ {
      print "memory: " FILENAME ": heading dialect \"" \
            substr($0, RLENGTH + 1, 3) "\": not upgraded"; bad = 1; exit }
    END { exit bad ? 2 : 0 }' "$1" >&2
}

_mem_upgrade_file() {  # <file> → rc 0 upgraded or already v2, rc 2 refused
  local p rows new rc=0
  _mem_upgrade_ready "$1"; rc=$?
  [ "$rc" = 1 ] && return 0
  [ "$rc" = 0 ] || return 2
  p=$(_mem_prefix "$1") || return 2
  rows=$(mktemp) || { echo "memory: no temp file" >&2; return 2; }
  new=$(mktemp) || { rm -f "$rows"; echo "memory: no temp file" >&2; return 2; }
  _mem_index_table "$1" > "$rows"
  { _mem_upgrade_text "$rows" "$1" "$p" > "$new" \
      && _mem_upgrade_oracle "$1" "$new" "$p" "$rows" \
      && cat "$new" > "$1"; } || rc=2
  rm -f "$rows" "$new"
  [ "$rc" = 0 ] && echo "memory: upgraded $1"
  [ "$rc" = 0 ] || echo "memory: $1 left as it was" >&2
  return "$rc"
}

memory_upgrade() {  # [<memory-dir>] → every template-born registry to v2
  local dir="${1:-.claude/memory}" f rc=0
  for f in $(_mem_names); do
    [ -f "$dir/$f.md" ] || continue
    _mem_locked _mem_upgrade_file "$dir/$f.md" || rc=2
  done
  return "$rc"
}

_memory_main() {
  set -uo pipefail
  if [ "${1:-}" = "-C" ]; then
    cd "${2:-}" 2>/dev/null \
      || { echo "memory: no dir ${2:-}" >&2; return 2; }
    shift 2
  fi
  case "${1:-}:$#" in
    add:*)     shift; _mem_add_cli "$@" ;;
    status:3)  memory_status "$2" "$3" ;;
    journal:2) memory_journal "$2" ;;
    index:[12]) memory_index "${2:-}" ;;
    check:*)   shift; memory_check "$@" ;;
    upgrade:[12]) memory_upgrade "${2:-}" ;;
    *) echo "usage: memory.sh [-C dir] add <kind> --title t --body-file f" \
            "[--status s] [--supersedes ID] | status <ID> <text> | journal" \
            "<line> | index [kind] | check [--staged] [dir] | upgrade [dir]" >&2
       return 2 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then _memory_main "$@"; fi
