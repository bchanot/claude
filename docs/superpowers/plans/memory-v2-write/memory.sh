#!/usr/bin/env bash
# lib/memory.sh — the single writer and reader of the .claude/memory
# registries (BDR-125 phase 4a). Sourceable; every verb takes an optional
# leading `-C <dir>` (a dispatched agent's cwd is the session's, never the
# project's):
#   add <kind> --title <t> --body-file <f> [--status <s>] [--supersedes <ID>]
#                 append one entry, next ID from the headings, under the
#                 lock; the new ID is the only stdout line
#   status <ID> <text>   append `- **Status (<date>)**: <text>` to the entry
#   journal <line>       append `- <line>` under today's `## YYYY-MM-DD`
#   index [<kind>]       ID | Date | Title | Status, from headings and bodies
#   check [--staged] [<memory-dir>]   heading shape, unique IDs, no Index in
#                 a v2 file (v1 reported, never failed); --staged: no line
#                 removed inside an existing entry of a staged v2 registry
#   upgrade [<memory-dir>]   v1 → v2: Index-only dates and statuses become
#                 body lines, `format: 2`, `## Index` removed, oracle first
# <kind> = decision | learning | blocker | eval. MEMORY_DATE overrides today.
# Status of an entry: the last candidate wins. A candidate is the heading's
# trailing `[tag]`, or a body line whose bold label names Status, Resolution,
# Action, UPDATE or FINAL (v1: `Status:`), holding a status word. A word in
# prose is never one (the BLK-032..034 false-open). Words rank in
# _MEM_WORDS order, `open` last: "accepted, check OPEN" reads accepted.
# Lock: <git-common-dir>/memory.lock created under noclobber (flock(1) is
# absent on macOS), a lock older than 30 s is stolen. Registry headings
# are scanned outside ``` fences only.

MEM_GREP="${MEM_GREP:-/usr/bin/grep}"
_MEM_WORDS='resolved superseded deprecated upstream accepted implemented'
_MEM_WORDS+=' shipped proposed keep correct deprecate open'
_MEM_AWK='
function mem_word(s,   t, i, n, w) {
  t = tolower(s); n = split(MEMW, w, " ")
  for (i = 1; i <= n; i++)
    if (t ~ ("(^|[^a-z])" w[i] "([^a-z]|$)")) return w[i]
  return "" }
function mem_tag(line) {
  if (!match(line, /\[[^]]*\]( \([0-9-]+\))? *$/)) return ""
  return mem_word(substr(line, RSTART)) }
function mem_cand(line,   lab) {
  if (line ~ /^- \*\*[^*]+\*\*/) {
    lab = line; sub(/^- \*\*/, "", lab); sub(/\*\*.*/, "", lab)
    return tolower(lab) ~ /status|resolution|action|update|final/ \
      && mem_word(line) != "" }
  return line ~ /^(- )?[Ss]tatus:/ && mem_word(line) != "" }
function mem_key(line, key) {
  return line == "## " key || index(line, "## " key " — ") == 1 }
'

_mem_date() { printf '%s\n' "${MEMORY_DATE:-$(date +%F)}"; }

_mem_kind() {  # <kind> → "<file> <PREFIX>", rc 2 when unknown
  case "$1" in
    decision) echo "decisions.md BDR" ;;
    learning) echo "learnings.md LRN" ;;
    blocker)  echo "blockers.md BLK" ;;
    eval)     echo "evals.md EVAL" ;;
    *) echo "memory: unknown kind: $1 (decision|learning|blocker|eval)" >&2
       return 2 ;;
  esac
}

_mem_id_file() {  # <ID> → its registry path, rc 2 when the prefix is unknown
  case "$1" in
    BDR-[0-9]*)  echo .claude/memory/decisions.md ;;
    LRN-[0-9]*)  echo .claude/memory/learnings.md ;;
    BLK-[0-9]*)  echo .claude/memory/blockers.md ;;
    EVAL-[0-9]*) echo .claude/memory/evals.md ;;
    *) echo "memory: not an entry ID: $1" >&2; return 2 ;;
  esac
}

_mem_is_v2() {  # <file> → rc 0 when the frontmatter carries `format: 2`
  awk 'NR == 1 && $0 != "---" { exit }
       NR > 1 && $0 == "---" { exit }
       $0 == "format: 2" { v2 = 1; exit }
       END { exit !v2 }' "$1"
}

_mem_has_id() {  # <file> <ID> → rc 0 when a heading carries the ID
  awk -v k="$2" "$_MEM_AWK"'
    /^```/ { fence = !fence; next }
    !fence && mem_key($0, k) { found = 1; exit }
    END { exit !found }' "$1"
}

_mem_next_id() {  # <file> <PREFIX> → max heading ID + 1, zero-padded
  awk -v p="$2" '
    /^```/ { fence = !fence; next }
    !fence && match($0, "^## " p "-[0-9]+") {
      n = substr($0, length(p) + 5, RLENGTH - length(p) - 4) + 0
      if (n > m) m = n }
    END { printf "%s-%03d\n", p, m + 1 }' "$1"
}

memory_entry_status() {  # <file> <ID> → winning candidate line, rc 1 if none
  awk -v k="$2" -v MEMW="$_MEM_WORDS" "$_MEM_AWK"'
    /^```/ { fence = !fence; next }
    fence { next }
    /^## / { if (on) exit
             if (mem_key($0, k)) { on = 1; if (mem_tag($0) != "") last = $0 }
             next }
    on && mem_cand($0) { last = $0 }
    END { if (last == "") exit 1; print last }' "$1"
}

memory_status_word() {  # <line> → its status word, else its first 40 chars
  awk -v MEMW="$_MEM_WORDS" "$_MEM_AWK"'
    { w = mem_word($0); print (w != "" ? w : substr($0, 1, 40)) }' <<< "$1"
}

_mem_lock_dir() {  # → the lock path for the current repository
  local d
  if d=$(git rev-parse --git-common-dir 2>/dev/null); then
    echo "$d/memory.lock"; return
  fi
  echo "${TMPDIR:-/tmp}/memory-$(pwd | cksum | cut -d' ' -f1).lock"
}

_mem_lock() {  # <lock file> → rc 0 held, rc 2 after MEM_LOCK_TRIES waits
  # noclobber = open(O_EXCL) by bash itself: mkdir is not atomic under
  # uutils coreutils 0.10 (two concurrent mkdir both succeed)
  local lock="$1" tries=0 now t
  until (set -C; date +%s > "$lock") 2>/dev/null; do
    now=$(date +%s); t=$(cat "$lock" 2>/dev/null)
    case "$t" in ''|*[!0-9]*) t=$now ;; esac  # holder still writing it
    if [ $((now - t)) -gt 30 ]; then rm -f "$lock"; continue; fi
    tries=$((tries + 1))
    [ "$tries" -lt "${MEM_LOCK_TRIES:-50}" ] \
      || { echo "memory: lock busy: $lock" >&2; return 2; }
    sleep 0.2
  done
}

_mem_unlock() { rm -f "$1"; }

_mem_locked() {  # <fn> [args…] → run fn under the lock, its rc
  local lock rc
  lock=$(_mem_lock_dir)
  _mem_lock "$lock" || return 2
  "$@"; rc=$?
  _mem_unlock "$lock"
  return "$rc"
}

_mem_one_line() {  # <what> <text> → rc 2 when empty or multi-line
  case "$2" in
    ''|*$'\n'*) echo "memory: $1 must be one non-empty line" >&2; return 2 ;;
  esac
}

_mem_insert() {  # <file> <key> <line> → line ends the section, rc 1 if absent
  local tmp
  tmp=$(mktemp) || { echo "memory: no temp file" >&2; return 2; }
  awk -v k="$2" -v ins="$3" "$_MEM_AWK"'
    function flush(  i) { print ins; for (i = 1; i <= n; i++) print buf[i]
                          n = 0; done = 1 }
    /^```/ { fence = !fence }
    on && !fence && /^## / { flush(); on = 0 }
    !done && !on && !fence && mem_key($0, k) { on = 1; print; next }
    on { if ($0 == "" || $0 == "---") { buf[++n] = $0; next }
         for (i = 1; i <= n; i++) print buf[i]; n = 0; print; next }
    { print }
    END { if (on) flush(); exit !done }' "$1" > "$tmp"
  case $? in
    0) cat "$tmp" > "$1" || { rm -f "$tmp"; return 2; } ;;
    *) rm -f "$tmp"; return 1 ;;
  esac
  rm -f "$tmp"
}

memory_status() {  # <ID> <text>
  local file
  _mem_one_line "status text" "$2" || return 2
  file=$(_mem_id_file "$1") || return 2
  _mem_has_id "$file" "$1" \
    || { echo "memory: no entry $1 in $file" >&2; return 2; }
  _mem_locked _mem_insert "$file" "$1" "- **Status ($(_mem_date))**: $2" \
    || { echo "memory: $1 status not written" >&2; return 2; }
}

_mem_journal_locked() {  # <file> <date> <line>
  _mem_insert "$1" "$2" "$3"
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
  [ -s "$3" ] || { echo "memory: empty or missing body: $3" >&2; return 2; }
  if [ "$1" = BLK ] && ! "$MEM_GREP" -q '`' "$3"; then
    echo "memory: a blocker body quotes ≥1 error in backticks" >&2; return 2
  fi
  case "$5" in ''|"$1"-[0-9]*) ;; *)
    echo "memory: --supersedes takes a $1 ID: $5" >&2; return 2 ;;
  esac
}

_mem_entry_text() {  # <title> <body-file> <status> <supersedes> → stdout
  local tag=""
  [ -z "$3" ] || tag=" [$3]"
  printf '%s%s (%s)\n' "$1" "$tag" "$(_mem_date)"
  awk '{ l[NR] = $0 } END { n = NR; while (n > 0 && l[n] == "") n--
                            for (i = 1; i <= n; i++) print l[i] }' "$2"
  [ -z "$4" ] || printf 'Supersedes [[%s]].\n' "$4"
}

_mem_add_locked() {  # <file> <PREFIX> <entry-file> <supersedes>
  local id bak rc=0
  id=$(_mem_next_id "$1" "$2")
  bak=$(mktemp) || { echo "memory: no temp file" >&2; return 2; }
  cat "$1" > "$bak"
  { printf '\n## %s — ' "$id"; cat "$3"; } >> "$1" || rc=2
  if [ "$rc" = 0 ] && [ -n "$4" ]; then
    _mem_insert "$1" "$4" "- **Status ($(_mem_date))**: superseded by $id" \
      || rc=2
  fi
  if [ "$rc" = 0 ] && _mem_is_v2 "$1"; then memory_check_file "$1" || rc=2; fi
  if [ "$rc" != 0 ]; then
    cat "$bak" > "$1"; echo "memory: add refused, $1 restored" >&2
  else echo "$id"; fi
  rm -f "$bak"
  return "$rc"
}

memory_add() {  # <kind> <title> <body-file> <status> <supersedes>
  local spec file entry rc
  spec=$(_mem_kind "$1") || return 2
  file=".claude/memory/${spec% *}"
  _mem_add_valid "${spec#* }" "$2" "$3" "$4" "$5" || return 2
  [ -f "$file" ] || { echo "memory: no registry: $file" >&2; return 2; }
  [ -z "$5" ] || _mem_has_id "$file" "$5" \
    || { echo "memory: no entry $5 in $file" >&2; return 2; }
  _mem_is_v2 "$file" || echo "memory: v1 registry (no format: 2): $file" >&2
  entry=$(mktemp) || { echo "memory: no temp file" >&2; return 2; }
  _mem_entry_text "$2" "$3" "$4" "$5" > "$entry"
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

_mem_prefix() {  # <file> → the frontmatter entry_prefix, rc 2 when none
  local p
  p=$(awk 'NR > 1 && $0 == "---" { exit }
           sub(/^entry_prefix: /, "") { print; exit }' "$1")
  [ -n "$p" ] || { echo "memory: $1: no entry_prefix" >&2; return 2; }
  echo "$p"
}

memory_check_file() {  # <file> → rc 2 with each culprit line named
  local p
  p=$(_mem_prefix "$1") || return 2
  awk -v p="$p" -v f="$1" '
    /^```/ { fence = !fence; next }
    fence { next }
    $0 == "## Index" { print f ":" NR ": ## Index in a v2 registry"; bad = 1 }
    !match($0, "^## " p "-[0-9]") { next }
    !match($0, "^## " p "-[0-9][0-9][0-9]+ — .") {
      print f ":" NR ": heading shape: " $0; bad = 1; next }
    seen[$2]++ { print f ":" NR ": duplicate " $2; bad = 1 }
    END { exit bad ? 2 : 0 }' "$1" | sed 's/^/memory: /' >&2
  return "${PIPESTATUS[0]}"
}

_MEM_REGISTRIES='decisions learnings blockers evals'

memory_check() {  # [--staged] [<memory-dir>] → rc 2 on any culprit
  local staged="" dir f rc=0
  [ "${1:-}" = --staged ] && { staged=1; shift; }
  dir="${1:-.claude/memory}"
  for f in $_MEM_REGISTRIES; do
    f="$dir/$f.md"
    [ -f "$f" ] || continue
    if ! _mem_is_v2 "$f"; then echo "memory: v1: $f" >&2; continue; fi
    memory_check_file "$f" || rc=2
    [ -z "$staged" ] || _mem_check_staged "$f" || rc=2
  done
  return "$rc"
}

_mem_check_staged() {  # <file> → rc 2 when a staged hunk removes an entry line
  local first
  git cat-file -e "HEAD:./$1" 2>/dev/null || return 0
  first=$(git show "HEAD:./$1" | awk '/^```/ { fence = !fence; next }
    !fence && /^## (BDR|LRN|BLK|EVAL)-[0-9]/ { print NR; exit }')
  [ -n "$first" ] || return 0
  git diff --cached -U0 -- "$1" | awk -v first="$first" -v f="$1" '
    /^@@ / { split($2, a, ","); start = substr(a[1], 2) + 0
             cnt = (2 in a) ? a[2] + 0 : 1
             if (cnt > 0 && start + cnt - 1 >= first) {
               print "memory: " f ": line " start " removed inside an entry" \
                     " (curation: /prune-memory then /commit-change)"
               bad = 1 } }
    END { exit bad ? 2 : 0 }' >&2
}

_mem_index_rows() {  # <file> <PREFIX> → "ID | date | title | word" rows
  awk -v p="$2" -v MEMW="$_MEM_WORDS" "$_MEM_AWK"'
    function row() { if (id != "") print "| " id " | " d " | " t " | " s " |" }
    /^```/ { fence = !fence; next }
    fence { next }
    /^## / { row(); id = ""
      if (!match($0, "^## " p "-[0-9]+")) next
      id = $2; t = $0; sub(/^## [^ ]+( — )?/, "", t); d = ""; s = mem_tag(t)
      if (match(t, / \([0-9-]+\) *$/)) {
        d = substr(t, RSTART + 2, RLENGTH - 3); t = substr(t, 1, RSTART - 1) }
      else if (match(t, / — [0-9][0-9][0-9][0-9]-[0-9-]+ *$/)) {
        d = substr(t, RSTART + 5); t = substr(t, 1, RSTART - 1) }
      sub(/ \[[^]]*\] *$/, "", t); gsub(/\|/, "/", t); next }
    id == "" { next }
    d == "" && sub(/^- \*\*Date\*\*: */, "") { d = substr($0, 1, 10) }
    mem_cand($0) { s = mem_word($0) }
    END { row() }' "$1"
}

memory_index() {  # [<kind>] → one table per registry
  local kinds="decision learning blocker eval" k spec file
  [ -z "${1:-}" ] || kinds="$1"
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
    function need(i,   c, w) {
      c = col[i]; w = mem_word(c)
      if (p == "EVAL" || w == "") return ""
      if (p == "LRN") return c ~ /^superseded by/ ? c : ""
      if (st[i] == "" || (w ~ /^(superseded|deprecated)$/ && st[i] != w))
        return c
      return "" }
    function flush(  i, s) {
      if (cur != "" && (s = need(cur)) != "")
        print "- **Status (" today ", upgrade)**: " s
      for (i = 1; i <= n; i++) print buf[i]
      n = 0 }
    FNR == 1 { pass++ }
    pass == 1 { split($0, r, "\t"); dt[r[1]] = r[2]; col[r[1]] = r[3]; next }
    pass == 2 { split($0, r, / \| /); sub(/^\| /, "", r[1])
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
  memory_check_file "$2" || return 2
  o=$(_mem_index_rows "$1" "$3"); n=$(_mem_index_rows "$2" "$3")
  awk -F'\t' -v p="$3" -v MEMW="$_MEM_WORDS" "$_MEM_AWK"'
    function f(s, k) { split(s, a, / \| /); return a[k] }
    FNR == 1 { pass++ }
    pass == 1 { dt[$1] = $2; col[$1] = $3; next }
    { id = f($0, 1); sub(/^\| /, "", id) }
    pass == 2 { old[id] = f($0, 4); sub(/ \|$/, "", old[id]); next }
    !(id in col) { next }
    { d = f($0, 2); s = f($0, 4); sub(/ \|$/, "", s); w = mem_word(col[id])
      if (p == "LRN" && col[id] !~ /^superseded by/) w = ""
      if (p == "EVAL") w = ""
      want = (w ~ /^(superseded|deprecated)$/ || old[id] == "") ? w : old[id]
      if (dt[id] != "" && d == "") bad = bad " " id ":date"
      if (want != "" && s != want) bad = bad " " id ":" s "!=" want }
    END { if (bad != "") { print "memory: upgrade lost:" bad; exit 2 } }' \
    "$4" <(printf '%s\n' "$o") <(printf '%s\n' "$n") >&2
}

_mem_upgrade_file() {  # <file> → rc 0 upgraded or already v2, rc 2 refused
  local p rows new rc=0 first
  IFS= read -r first < "$1"
  [ "$first" = --- ] \
    || { echo "memory: $1: no frontmatter, not upgraded" >&2; return 2; }
  _mem_is_v2 "$1" && { echo "memory: $1 already v2" >&2; return 0; }
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
  for f in $_MEM_REGISTRIES; do
    [ -f "$dir/$f.md" ] || continue
    _mem_upgrade_file "$dir/$f.md" || rc=2
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
