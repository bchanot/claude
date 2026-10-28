#!/usr/bin/env bash
# lib/tests/memory.test.sh — lib/memory.sh (add / status / journal / index /
# check / upgrade) and the shared status parser. Hermetic fixtures under one
# mktemp dir with its own git repo; flip-tests first (LRN-096), then the
# real check on this repo's registries.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MEM="$ROOT/lib/memory.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
FIX=$(mktemp -d); trap 'rm -rf "$FIX"' EXIT
cd "$FIX" || exit 1
git init -q . && git config user.email t@t && git config user.name t
export MEMORY_DATE=2026-10-27
mkdir -p .claude/memory
reg() {  # <file> <type> <PREFIX> <title> → a v2 registry with no entry
  printf -- '---\nformat: 2\ntype: %s\nentry_prefix: %s\n---\n\n# %s\n' \
    "$2" "$3" "$4" > ".claude/memory/$1"
}
reg decisions.md decisions_registry BDR 'Decisions registry (BDR)'
reg learnings.md learnings_registry LRN 'Learnings registry (LRN)'
reg blockers.md blockers_registry BLK 'Blockers registry (BLK)'
reg evals.md evals_registry EVAL 'Evals registry (EVAL)'
printf -- '---\ntype: journal\n---\n\n# Journal\n\n## 2026-10-26\n- old\n' \
  > .claude/memory/journal.md
B=.claude/memory/blockers.md
printf -- "- **Friction**: \`make\` red\n- **Cause**: x\n\n" > body.md

# T1 add: next ID from headings, canonical heading, ID alone on stdout
out=$(bash "$MEM" add blocker --title 'make red' --body-file body.md \
  --status open)
check T1-first-id "$out" BLK-001
check T1b-heading "$(grep -c '^## BLK-001 — make red \[open\] (2026-10-27)$' "$B")" 1
check T1c-body-trimmed "$(tail -1 "$B")" '- **Cause**: x'
check T1d-second-id "$(bash "$MEM" add blocker --title 'two' --body-file body.md)" BLK-002
check T1e-check-green "$(bash "$MEM" check; echo $?)" 0
check T1f-index-row "$(bash "$MEM" index blocker | grep -c '^| BLK-001 | 2026-10-27 | make red | open |$')" 1

# T2 add refuses, rc 2, registry unchanged
sum=$(cksum < "$B")
refused() {  # <name> <add args…> → the add is rc 2
  local name="$1"; shift
  bash "$MEM" add "$@" >/dev/null 2>&1
  check "T2-$name" "$?" 2
}
refused kind unknown --title t --body-file body.md
refused bracket blocker --title 'a[b]' --body-file body.md
refused pipe blocker --title 'a|b' --body-file body.md
refused no-body blocker --title t --body-file missing.md
refused status-bracket blocker --title t --body-file body.md --status 'a]'
refused cross-prefix blocker --title t --body-file body.md --supersedes LRN-001
refused unknown-sup blocker --title t --body-file body.md --supersedes BLK-099
refused no-value blocker --title t --body-file
refused bad-option blocker --title t --body-file body.md --bogus x
printf 'no backtick here\n' > plain.md
bash "$MEM" add blocker --title t --body-file plain.md 2>/dev/null
check T2b-blocker-needs-backtick "$?" 2
check T2c-unchanged "$(cksum < "$B")" "$sum"
bash "$MEM" add learning --title t --body-file plain.md >/dev/null
check T2d-learning-without-backtick "$?" 0
printf 'x\n```\nopen fence\n' > fence.md
bash "$MEM" add learning --title f --body-file fence.md 2>/dev/null
check T2e-open-fence-body "$?" 2

# T3 status: a dated line ends the entry, before the next heading's blank
bash "$MEM" status BLK-001 'resolved abc1234'
check T3-rc "$?" 0
check T3b-placed "$(awk '/^## BLK-001/{on=1} on && /^- \*\*Status/{print; exit}' "$B")" \
  '- **Status (2026-10-27)**: resolved abc1234'
check T3c-before-next "$(awk '/Status \(2026-10-27\)/{getline n; print n; exit}' "$B")" ''
bash "$MEM" status BLK-002 'upstream, open'
check T3d-at-eof "$(tail -1 "$B")" '- **Status (2026-10-27)**: upstream, open'
bash "$MEM" status BLK-404 x 2>/dev/null
check T3e-unknown-id "$?" 2
bash "$MEM" status BLK-001 "$(printf 'a\nb')" 2>/dev/null
check T3f-multi-line "$?" 2
bash "$MEM" status BLK-001 'reopened by abc' 2>/dev/null
check T3g-needs-status-word "$?" 2
bash "$MEM" status BLK-002 'open \b \n \| kept'
check T3h-backslash-verbatim "$(tail -1 "$B")" \
  '- **Status (2026-10-27)**: open \b \n \| kept'

# T4 journal: appended under today, heading created once, old date untouched
J=.claude/memory/journal.md
bash "$MEM" journal 'first'
bash "$MEM" journal '- second'
check T4-heading-once "$(grep -c '^## 2026-10-27$' "$J")" 1
check T4b-order "$(tail -2 "$J" | tr '\n' '|')" '- first|- second|'
check T4c-old-kept "$(sed -n '/^## 2026-10-26$/,/^$/p' "$J" | grep -c '^- old$')" 1
bash "$MEM" journal "$(printf 'a\nb')" 2>/dev/null
check T4d-multi-line "$?" 2
bash "$MEM" journal 'grep \bword\b w/ \n'
check T4e-backslash-verbatim "$(tail -1 "$J")" '- grep \bword\b w/ \n'

# T5 --supersedes: forward link on the new entry, status line on the old one
L=.claude/memory/learnings.md
new=$(bash "$MEM" add learning --title 'better' --body-file plain.md \
  --supersedes LRN-001)
check T5-id "$new" LRN-002
check T5b-forward "$(tail -1 "$L")" 'Supersedes [[LRN-001]].'
word() {  # <file> <ID> → the entry's status word, through the lib
  # shellcheck source=/dev/null
  (. "$MEM"; memory_status_word "$(memory_entry_status "$1" "$2")")
}
check T5c-old-status "$(word "$L" LRN-001)" superseded
check T5d-index "$(bash "$MEM" index learning | grep -c '^| LRN-001 | 2026-10-27 | t | superseded |$')" 1

# T6 lock: a held lock refuses, a stale one is stolen, concurrent adds get
# distinct IDs
lock="$(git rev-parse --git-common-dir)/memory.lock"
date +%s > "$lock"
sum=$(cksum < .claude/memory/evals.md)
MEM_LOCK_TRIES=2 bash "$MEM" add eval --title t --body-file plain.md 2>/dev/null
check T6-held-rc "$?" 2
check T6b-held-unchanged "$(cksum < .claude/memory/evals.md)" "$sum"
echo $(( $(date +%s) - 60 )) > "$lock"
check T6c-stale-stolen "$(bash "$MEM" add eval --title t --body-file plain.md)" EVAL-001
check T6d-lock-released "$([ -e "$lock" ] && echo held || echo free)" free
for i in 1 2 3 4 5; do
  bash "$MEM" add decision --title "d$i" --body-file plain.md > "out$i" &
done
wait
check T6e-distinct "$(cat out1 out2 out3 out4 out5 | sort -u | wc -l | tr -d ' ')" 5
check T6f-max "$(cat out1 out2 out3 out4 out5 | sort | tail -1)" BDR-005
check T6g-check-green "$(bash "$MEM" check; echo $?)" 0

# T7 check: shape, duplicate, Index in v2 are rc 2; v1 is named, not failed
cp .claude/memory/decisions.md d.bak
printf '\n## BDR-005 — again\nx\n' >> .claude/memory/decisions.md
err=$(bash "$MEM" check 2>&1 >/dev/null); rc=$?
check T7-duplicate-rc "$rc" 2
check T7b-duplicate-named "$(printf '%s\n' "$err" | grep -c 'duplicate BDR-005')" 1
cat d.bak > .claude/memory/decisions.md
printf '\n## BDR-7 — short\nx\n' >> .claude/memory/decisions.md
bash "$MEM" check 2>/dev/null
check T7c-shape-rc "$?" 2
cat d.bak > .claude/memory/decisions.md
printf '\n## Index\n' >> .claude/memory/decisions.md
bash "$MEM" check 2>/dev/null
check T7d-index-in-v2-rc "$?" 2
cat d.bak > .claude/memory/decisions.md
mkdir v1 && printf '# Decisions\n\n## BDR-001 - legacy\n' > v1/decisions.md
err=$(bash "$MEM" check v1 2>&1 >/dev/null); rc=$?
check T7e-v1-rc "$rc" 0
check T7f-v1-named "$(printf '%s\n' "$err" | grep -c '^memory: v1: v1/decisions.md$')" 1
printf '\n## BDR-006 — fenced\n```\nx\n' >> .claude/memory/decisions.md
err=$(bash "$MEM" check 2>&1 >/dev/null); rc=$?
check T7g-open-fence-rc "$rc" 2
check T7h-open-fence-named "$(printf '%s\n' "$err" | grep -c 'fence open at end')" 1
cat d.bak > .claude/memory/decisions.md
# a duplicate a merge left behind blocks neither add nor a staged append
printf '\n## BDR-005 — merged twice (2026-10-27)\nx\n' >> .claude/memory/decisions.md
check T7i-dup-still-adds "$(bash "$MEM" add decision --title after --body-file plain.md)" BDR-006
check T7j-dup-still-reported "$(bash "$MEM" check >/dev/null 2>&1; echo $?)" 2
git add -A && git commit -qm dup
bash "$MEM" add decision --title later --body-file plain.md >/dev/null
git add .claude/memory/decisions.md
check T7k-dup-staged-append "$(bash "$MEM" check --staged >/dev/null 2>&1; echo $?)" 0
git reset -q
cat d.bak > .claude/memory/decisions.md

# T8 check --staged: an append passes, a removed entry line is rc 2
git add -A && git commit -qm base
bash "$MEM" add blocker --title three --body-file body.md >/dev/null
git add "$B"
check T8-append-staged "$(bash "$MEM" check --staged; echo $?)" 0
git commit -qm three
sed 's/^## BLK-001 — make red/## BLK-001 — make RED/' "$B" > b.tmp \
  && cat b.tmp > "$B"
git add "$B"
err=$(bash "$MEM" check --staged 2>&1 >/dev/null); rc=$?
check T8b-removed-line-rc "$rc" 2
check T8c-named "$(printf '%s\n' "$err" | grep -c 'removed inside an entry')" 1
git checkout -q HEAD -- "$B"
cp "$B" b.keep
sed '/^format: 2$/d' b.keep > "$B" && git add "$B"
check T8d-downgrade-refused "$(bash "$MEM" check --staged >/dev/null 2>&1; echo $?)" 2
git rm -q --cached "$B"
check T8e-deletion-refused "$(bash "$MEM" check --staged >/dev/null 2>&1; echo $?)" 2
git reset -q && cat b.keep > "$B"

# T9 upgrade: Index-only dates and statuses become body lines, the marker
# lands, the Index goes, headings untouched; idempotent; refusals keep the file
mkdir -p up/.claude/memory && cd up || exit 1
cat > .claude/memory/decisions.md <<'EOF'
---
type: decisions_registry
entry_prefix: BDR
---

# Decisions registry (BDR)

## Index

| ID | Date | Title | Status |
|----|------|-------|--------|
| BDR-001 | 2026-01-01 | kept | accepted |
| BDR-002 | 2026-01-02 | stale index | accepted |
| BDR-003 | 2026-01-03 | gone | superseded by BDR-004 |
| BDR-004 | 2026-01-04 | no status | accepted |
| BDR-005 | 2026-01-05 | suffix date | accepted |

---

## BDR-001 — kept (2026-01-01)
- **Status**: accepted

## BDR-002 — stale index
- **Date**: 2026-01-02
- **Status**: shipped

## BDR-003 — gone
- **Status**: accepted

## BDR-004 — no status
body

## BDR-005 — suffix date — 2026-01-05
- **Status**: accepted
EOF
cat > .claude/memory/learnings.md <<'EOF'
---
type: learnings_registry
entry_prefix: LRN
---

# Learnings registry (LRN)

## Index

| ID | Date | Pattern | Applies to |
|----|------|---------|------------|
| LRN-001 | 2026-02-01 | old | superseded by LRN-002 |
| LRN-002 | 2026-02-02 | new | any shell |

## LRN-001 — old
x

## LRN-002 — new
y
EOF
D=.claude/memory/decisions.md
heads=$(grep '^## BDR-' "$D")
err=$(bash "$MEM" upgrade 2>&1 >/dev/null); rc=$?
check T9-rc "$rc" 0
check T9n-dropped-named "$(printf '%s\n' "$err" | grep -c '^memory: BDR-002: kept body shipped, dropped Index accepted$')" 1
check T9b-marker "$(sed -n 2p "$D")" 'format: 2'
check T9c-no-index "$(grep -c '^## Index$\|^| BDR-' "$D")" 0
check T9d-headings-same "$(grep '^## BDR-' "$D")" "$heads"
check T9e-index-out "$(bash "$MEM" index decision | sed -n '5,8p' | tr '\n' '#')" \
  '| BDR-001 | 2026-01-01 | kept | accepted |#| BDR-002 | 2026-01-02 | stale index | shipped |#| BDR-003 | 2026-01-03 | gone | superseded |#| BDR-004 | 2026-01-04 | no status | accepted |#'
for loc in C en_US.UTF-8; do
  check "T9r-suffix-date-$loc" "$(LC_ALL=$loc bash "$MEM" index decision | grep -c '^| BDR-005 | 2026-01-05 | suffix date | accepted |$')" 1
done
check T9f-lrn-superseded "$(bash "$MEM" index learning | grep -c '^| LRN-001 | 2026-02-01 | old | superseded |$')" 1
check T9g-lrn-applies-dropped "$(grep -c 'any shell' .claude/memory/learnings.md)" 0
check T9h-check-green "$(bash "$MEM" check; echo $?)" 0
sum=$(cksum < "$D")
bash "$MEM" upgrade >/dev/null 2>&1
check T9i-idempotent "$(cksum < "$D")" "$sum"
cat > .claude/memory/blockers.md <<'EOF'
---
type: blockers_registry
entry_prefix: BLK
---

## Index

| ID | Date | Friction | Status |
|----|------|----------|--------|
| BLK-001 | 2026-03-01 | dup | open |

## BLK-001 — dup
- **Status**: open

## BLK-001 — dup again
EOF
sum=$(cksum < .claude/memory/blockers.md)
bash "$MEM" upgrade >/dev/null 2>&1
check T9j-oracle-refuses "$?" 2
check T9k-refused-untouched "$(cksum < .claude/memory/blockers.md)" "$sum"
printf '# Evals\n\n## EVAL-001 | 2026 | pipe dialect\n' > .claude/memory/evals.md
bash "$MEM" upgrade >/dev/null 2>&1
check T9l-no-frontmatter-v2 "$(sed -n 2p .claude/memory/evals.md)" 'format: 2'
check T9m-pipe-heading "$(grep -c '^## EVAL-001 — pipe dialect (2026)$' .claude/memory/evals.md)" 1
printf -- '---\ntype: evals_registry\nentry_prefix: EVAL\n---\n\n## Index\n\n| ID | Date | Output | Action |\n|----|------|--------|--------|\n\n## EVAL-001 - hyphen dialect\nx\n' \
  > .claude/memory/evals.md
bash "$MEM" upgrade >/dev/null 2>&1
check T9o-hyphen-upgraded "$(grep -c '^## EVAL-001 — hyphen dialect$' .claude/memory/evals.md)" 1
printf -- '---\ntype: evals_registry\nentry_prefix: EVAL\n---\n\n## Index\n\n| ID | Date | Output | Action |\n|----|------|--------|--------|\n\n## EVAL-001 — empty index (2026-04-01)\nx\n' \
  > .claude/memory/evals.md
bash "$MEM" upgrade >/dev/null 2>&1
check T9p-empty-index-upgraded "$(sed -n 2p .claude/memory/evals.md)" 'format: 2'
check T9q-empty-index-heading "$(grep -c '^## EVAL-001 — empty index' .claude/memory/evals.md)" 1
cd "$FIX" || exit 1

# T10 parser: header tag and labelled lines only, last wins, open ranks last
cp "$ROOT/lib/tests/fixtures/blockers-v2-status.md" st.md
check T10-header-tag "$(word st.md BLK-032)" resolved
check T10b-prose-open-ignored "$(word st.md BLK-033)" resolved
check T10c-fail-open-ignored "$(word st.md BLK-034)" resolved
check T10d-final-wins "$(word st.md BLK-008)" resolved
check T10e-accepted-before-open "$(word st.md BLK-040)" accepted
check T10f-mid-title-bracket "$(word st.md BLK-041)" open
check T10h-title-prose-ignored "$(word st.md BLK-043)" open
check T10i-dated-lead-word "$(word st.md BLK-044)" open
# shellcheck source=/dev/null
check T10j-tag-only "$(. "$MEM"; memory_entry_status st.md BLK-043)" '[open]'
closed() {  # <word> → yes when memory_closed accepts it
  # shellcheck source=/dev/null
  (. "$MEM"; memory_closed "$1") && echo yes || echo no; }
check T10k-closed "$(closed resolved)$(closed superseded)$(closed deprecated)" yesyesyes
check T10l-not-closed "$(closed accepted)$(closed open)$(closed upstream)" nonono
mkdir -p v1h/.claude/memory
printf '# Blockers\n\n## BLK-001 - hyphen\n- **Status**: resolved\n\n## BLK-002 | 2026-05-18 | pipe\nStatus: open\n' \
  > v1h/.claude/memory/blockers.md
check T10m-hyphen-dialect "$(word v1h/.claude/memory/blockers.md BLK-001)" resolved
check T10n-pipe-dialect "$(word v1h/.claude/memory/blockers.md BLK-002)" open
bash "$MEM" -C v1h status BLK-002 'resolved by abc' 2>/dev/null
check T10o-status-on-v1-pipe "$(word v1h/.claude/memory/blockers.md BLK-002)" resolved
# shellcheck source=/dev/null
(. "$MEM"; memory_entry_status st.md BLK-042) >/dev/null
check T10g-no-candidate-rc "$?" 1

# T11 -C runs from elsewhere
check T11-dash-C "$(cd / && bash "$MEM" -C "$FIX" index blocker | grep -c '^| BLK-00')" 3
bash "$MEM" -C /nonexistent check 2>/dev/null
check T11b-bad-dir "$?" 2
bash "$MEM" frobnicate 2>/dev/null
check T11c-usage "$?" 2

# T14 r3: any-level ID allocation, open fence refused, v1 status as a body
# line, token lock, empty-lock steal, journal exact key, --staged dir
cd "$FIX" || exit 1
mkdir -p h3/.claude/memory && cd h3 || exit 1
printf '# Decisions\n\n### BDR-001 — a\nx\n\n### BDR-007 — b\ny\n' \
  > .claude/memory/decisions.md
check T14-h3-next "$(bash "$MEM" add decision --title c --body-file "$FIX/plain.md" 2>/dev/null)" BDR-008
printf '# Blockers\n\n## BLK-001 - legacy\n- Status: open\n' \
  > .claude/memory/blockers.md
bash "$MEM" add blocker --title fixed --body-file "$FIX/body.md" \
  --status resolved >/dev/null 2>&1
check T14b-v1-no-tag "$(grep -c '^## BLK-002 — fixed (2026-10-27)$' .claude/memory/blockers.md)" 1
check T14c-v1-status-line "$(sed -n '/^## BLK-002/{n;p;}' .claude/memory/blockers.md)" '- **Status**: resolved'
bash "$MEM" add blocker --title t --body-file "$FIX/body.md" --status fixed 2>/dev/null
check T14d-status-word-required "$?" 2
cd "$FIX" || exit 1
cp .claude/memory/evals.md e.bak
printf '\n```\nunclosed\n' >> .claude/memory/evals.md
sum=$(cksum < .claude/memory/evals.md)
bash "$MEM" add eval --title t --body-file plain.md >/dev/null 2>&1
check T14e-open-fence-refused "$?" 2
check T14f-open-fence-untouched "$(cksum < .claude/memory/evals.md)" "$sum"
cat e.bak > .claude/memory/evals.md
lock="$(git rev-parse --git-common-dir)/memory.lock"
echo "$(date +%s) someone.1" > "$lock"
# shellcheck source=/dev/null
(. "$MEM"; _mem_unlock "$lock" me.2)
check T14g-foreign-token-kept "$(cut -d' ' -f2 "$lock")" someone.1
: > "$lock"
check T14h-empty-lock-stolen "$(bash "$MEM" add eval --title e --body-file plain.md)" EVAL-002
echo "$(( $(date +%s) - 60 )) dead.1" > "$lock"
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  bash "$MEM" add learning --title "r$i" --body-file plain.md > "lr$i" &
done
wait
check T14i-twelve-distinct "$(cat lr1 lr2 lr3 lr4 lr5 lr6 lr7 lr8 lr9 lr10 lr11 lr12 | sort -u | wc -l | tr -d ' ')" 12
check T14j-no-lock-left "$([ -e "$lock" ] || [ -e "$lock.steal" ] && echo left || echo none)" none
check T14k-check-green "$(bash "$MEM" check; echo $?)" 0
J=.claude/memory/journal.md
printf '\n## 2026-10-28 (cont. 1) — legacy\n- kept\n' >> "$J"
MEMORY_DATE=2026-10-28 bash "$MEM" journal 'new day'
check T14l-cont-not-matched "$(grep -c '^## 2026-10-28$' "$J")" 1
check T14m-cont-untouched "$(sed -n '/(cont. 1)/{n;p;}' "$J")" '- kept'
bash "$MEM" check --staged /abs 2>/dev/null
check T14n-staged-absolute "$?" 2
bash "$MEM" status BLK-404 'open' 2>&1 >/dev/null | grep -c restored > rs
check T14o-no-restore-noise "$(tr -d ' ' < rs)" 0

# T15 upgrade migrates every measured v1 dialect; the oracle refuses what it
# cannot prove. Blockers fixtures: the open set (reconcile's reader) before
# and after must be the same, the check green, a second run a no-op
v1blk() {  # <dir> <body…> → <dir>/blockers.md with a v1 frontmatter
  mkdir -p "$1"; { printf -- '---\ntype: blockers_registry\n'
    printf 'entry_prefix: BLK\n---\n\n# Blockers\n'; shift; printf '%s\n' "$@"
  } > "$(dirname "$1/x")/blockers.md"; }
memory_word_of() {  # <file> <ID> → the strict reader's status word
  bash -c '. "$1"; memory_status_word "$(memory_entry_status "$2" "$3")"' \
    _ "$MEM" "$1" "$2"; }
openset() { bash -c '. "$1/lib/reconcile.sh"; reconcile_blk_open "$2"' _ \
  "$ROOT" "$1" | cut -f1 | tr '\n' ' '; }
dialect() {  # <name> <heading regex expected> — fixture already in d15/<name>
  local f="d15/$1/blockers.md" before
  before=$(openset "$f")
  bash "$MEM" upgrade "d15/$1" >/dev/null 2>&1
  check "T15-$1-rc" "$?" 0
  check "T15-$1-v2" "$(sed -n 2p "$f")" 'format: 2'
  check "T15-$1-heading" "$(grep -c "$2" "$f")" 1
  check "T15-$1-check" "$(bash "$MEM" check "d15/$1" 2>&1; echo $?)" 0
  # a ### file: reconcile's v1 reader never saw its entries (asserted below)
  [ "${3:-}" = unseen ] && before=$(openset "$f")
  check "T15-$1-verdicts" "$(openset "$f")" "$before"
  sum=$(cksum < "$f"); bash "$MEM" upgrade "d15/$1" >/dev/null 2>&1
  check "T15-$1-idempotent" "$(cksum < "$f")" "$sum"; }
v1blk d15/hyphen '## BLK-001 - hyphen, resolved' 'Status: resolved' '' \
  '## BLK-002 - hyphen, open' 'Status: open'
dialect hyphen '^## BLK-001 — hyphen, resolved$'
v1blk d15/pipe '## BLK-001 | 2026-05-18 | pipe, resolved' 'Status: resolved' '' \
  '## BLK-002 | 2026-05-19 | pipe, open' 'Status: open'
dialect pipe '^## BLK-001 — pipe, resolved (2026-05-18)$'
v1blk d15/hashes '### BLK-001 — three hashes, resolved' 'Status: resolved' '' \
  '### BLK-002 — three hashes, open' 'Status: open'
dialect hashes '^## BLK-001 — three hashes, resolved$' unseen
# ### entries were never in the v1 reader's set: no repair line, strict read
check T15-hashes-no-repair "$(grep -c 'upgrade)' d15/hashes/blockers.md)" 0
check T15-hashes-1-resolved "$(memory_word_of d15/hashes/blockers.md BLK-001)" resolved
check T15-hashes-2-open "$(memory_word_of d15/hashes/blockers.md BLK-002)" open
# probe d: a ### entry after a ## one must not leak its status into it
v1blk d15/probed '## BLK-003 — three, open' 'Status: open' '' \
  '### BLK-001 — x' 'Status: resolved'
bash "$MEM" upgrade d15/probed >/dev/null 2>&1
check T15-probed-no-repair "$(grep -c 'upgrade)' d15/probed/blockers.md)" 0
check T15-probed-open "$(memory_word_of d15/probed/blockers.md BLK-003)" open
# a heading line quoted inside a ``` fence does not end the entry's range
v1blk d15/fenced '## BLK-003 — three' 'Status: resolved' '```' \
  '### BLK-001 — quoted' '```' 'Status: open'
bash "$MEM" upgrade d15/fenced >/dev/null 2>&1
check T15-fenced-no-repair "$(grep -c 'upgrade)' d15/fenced/blockers.md)" 0
check T15-fenced-open "$(memory_word_of d15/fenced/blockers.md BLK-003)" open
# status words inside a ``` fence are not the entry's status
v1blk d15/fstat-a '## BLK-003 — three' 'Status: open' '```' 'Status: resolved' '```'
bash "$MEM" upgrade d15/fstat-a >/dev/null 2>&1
check T15-fenced-status-a-no-repair "$(grep -c 'upgrade)' d15/fstat-a/blockers.md)" 0
check T15-fenced-status-a "$(memory_word_of d15/fstat-a/blockers.md BLK-003)" open
v1blk d15/fstat-b '## BLK-003 — three' 'Status: open' '```' \
  '## BLK-009 — quoted' 'Status: resolved' '```'
bash "$MEM" upgrade d15/fstat-b >/dev/null 2>&1
check T15-fenced-status-b-no-repair "$(grep -c 'upgrade)' d15/fstat-b/blockers.md)" 0
check T15-fenced-status-b "$(memory_word_of d15/fstat-b/blockers.md BLK-003)" open
# `## ID—x` (no space) is no v1-visible heading: no silent flip
v1blk d15/nospace '## BLK-001—x' 'Status: resolved' '' \
  '## BLK-002 — y' 'Status: open'
sum=$(cksum < d15/nospace/blockers.md)
bash "$MEM" upgrade d15/nospace >/dev/null 2>&1
check T15-nospace-refused "$?" 2
check T15-nospace-untouched "$(cksum < d15/nospace/blockers.md)" "$sum"
check T15-nospace-no-repair "$(grep -c 'upgrade)' d15/nospace/blockers.md)" 0
# RECONCILE_GREP reaches reconcile's v1 pipeline
v1blk d15/v1only '## BLK-001 — v1 file' 'Status: resolved'
printf '#!/bin/sh\necho STUB >&2\nexec /usr/bin/grep "$@"\n' > gstub
chmod +x gstub
stubbed=$(RECONCILE_GREP="$PWD/gstub" bash -c \
  '. "$1/lib/reconcile.sh"; reconcile_blk_current_status "$2" BLK-001' \
  _ "$ROOT" d15/v1only/blockers.md 2>&1 >/dev/null | grep -c STUB)
check T15-reconcile-grep "$([ "$stubbed" -gt 0 ] && echo reached || echo missed)" reached
v1blk d15/suffix '## BLK-001 — suffix — RESOLVED' 'Status: resolved in repo' \
  '' '## BLK-002 — suffix, open' 'Status: open'
dialect suffix '^## BLK-001 — suffix — RESOLVED$'
v1blk d15/datestatus '## BLK-001 — one line' \
  'date: 2026-06-02 · status: RESOLVED 2026-06-04' '' \
  '## BLK-002 — one line open' 'date: 2026-06-02 · status: open'
dialect datestatus '^- \*\*Status ([0-9-]*, upgrade)\*\*: resolved$'
check T15-datestatus-one-line "$(grep -c 'upgrade)' d15/datestatus/blockers.md)" 1
v1blk d15/statut '## BLK-001 — fr' '- **Statut** : resolved' '' \
  '## BLK-002 — fr open' '- **Statut** : open'
dialect statut '^- \*\*Status ([0-9-]*, upgrade)\*\*: resolved$'
mkdir -p d15/nofm
printf '# Blockers\n\n## BLK-001 | 2026-05-18 | no frontmatter\n%s\n' \
  '- **Statut** : resolved' > d15/nofm/blockers.md
dialect nofm '^## BLK-001 — no frontmatter (2026-05-18)$'
check T15-nofm-template "$(sed -n 1,3p d15/nofm/blockers.md | tr '\n' '#')" \
  '---#format: 2#type: blockers_registry#'
check T15-nofm-body "$(grep -c '^# Blockers$' d15/nofm/blockers.md)" 1
# an em-dash heading stays byte-identical, a dated one included
v1blk d15/keep '## BLK-001 — keep — 2026-05-18' 'Status: open'
bash "$MEM" upgrade d15/keep >/dev/null 2>&1
check T15-keep-heading "$(grep -c '^## BLK-001 — keep — 2026-05-18$' d15/keep/blockers.md)" 1
# v1 open, strict reader closed: kept and named (BLK-032..034)
v1blk d15/fix '## BLK-001 — prose' 'Status: Resolved'
err=$(bash "$MEM" upgrade d15/fix 2>&1 >/dev/null)
check T15-fix-named "$(printf '%s\n' "$err" | grep -c 'BLK-001: v1 reader open, strict reader closed')" 1
# tampered: no status line lands, the oracle refuses, the file is untouched
v1blk d15/tamper '## BLK-001 | 2026-05-18 | lost closure' \
  'date: 2026-06-02 · status: RESOLVED'
sum=$(cksum < d15/tamper/blockers.md)
err=$(bash -c '. "$1"; _mem_upgrade_repair() { :; }; memory_upgrade "$2"' \
  _ "$MEM" d15/tamper 2>&1 >/dev/null)
check T15-tamper-rc "$?" 2
check T15-tamper-culprit "$(printf '%s\n' "$err" | grep -c 'moved a verdict: BLK-001')" 1
check T15-tamper-untouched "$(cksum < d15/tamper/blockers.md)" "$sum"

# T12 this repo's registries pass the check
check T12-live-check "$(bash "$MEM" -C "$ROOT" check >/dev/null 2>&1; echo $?)" 0

# T13 templates are born v2; the session banner names a v1 project only
for t in decisions learnings blockers evals; do
  check "T13-template-$t-v2" "$(sed -n 2p "$ROOT/templates/memory/$t.md")" 'format: 2'
  check "T13b-template-$t-no-index" "$(grep -c '^## Index$' "$ROOT/templates/memory/$t.md")" 0
done
banner() { (cd "$1" && SESSION_START_OFFLINE=1 bash "$ROOT/hooks/session-start.sh" \
  </dev/null 2>/dev/null) | grep -c "${2:-registry v1}"; }
check T13c-banner-v1-v2 "$(banner "$FIX/v1h" 'registry v1: 1 file(s) (memory.sh check)')/$(banner "$FIX")" 1/0
cp "$FIX/v1h/.claude/memory/blockers.md" v1h.bak
printf -- '---\nformat: 2\n---\n' > "$FIX/v1h/.claude/memory/blockers.md"
check T13d-banner-flips-off "$(banner "$FIX/v1h")" 0
cat v1h.bak > "$FIX/v1h/.claude/memory/blockers.md"
echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
