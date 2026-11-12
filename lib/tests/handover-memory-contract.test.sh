#!/usr/bin/env bash
# lib/tests/handover-memory-contract.test.sh — handover-doc-writer STEP 9
# reads blocker statuses through reconcile_blk_classify, never by hand
# (BDR-129, BDR-133; BUGS-FOUND G5). HM1/HM2 census the prompts, HM3 runs
# the SHIPPED STEP 9 block on printf-built fixtures under one mktemp -d.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HDW="$ROOT/agents/handover-doc-writer.md"
CHW="$ROOT/agents/client-handover-writer.md"
WORK="$(mktemp -d)" || exit 1; trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
# has <file> <fixed string>: 1 when the file contains it, else 0
has() { if grep -qF -- "$2" "$1"; then echo 1; else echo 0; fi; }

# --- HM1: handover-doc-writer census
check HM1-classify "$(has "$HDW" 'reconcile_blk_classify')" 1
check HM1-memory-line "$(has "$HDW" 'MEMORY: unreadable BLK:')" 1
check HM1-reader-unavailable "$(has "$HDW" 'reader-unavailable')" 1
check HM1-synth-fence "$(grep -c '^SYNTH REPORT$' "$HDW")" 1
check HM1-no-manual "$(has "$HDW" 'parse manually')" 0
check HM1-no-relative "$(has "$HDW" 'MEMORY_DIR=".claude/memory"')" 0
check HM1-no-bash-c "$(has "$HDW" 'bash -c')" 0

# --- HM2: client-handover-writer census
check HM2-memory-parse "$(has "$CHW" 'with no `MEMORY:` line is malformed')" 1
check HM2-report-bullet "$(has "$CHW" '- Memory: <value>')" 1
check HM2-remedy "$(has "$CHW" 'memory.sh -C')" 1

# --- HM3: run the shipped STEP 9 block
# first fenced bash block under `## STEP 9`, with the two placeholders
# (project root, lib dir) substituted
mkscript() {  # <project root> <lib dir> <out file>
  awk '/^## STEP 9/ {s=1; next} s && /^## / {exit}
    s && /^```bash/ {b=1; next} b && /^```/ {exit} b' "$HDW" \
    | sed -e "s|<PROJECT root from the PACKAGE>|$1|" \
      -e "s|\$HOME/\.claude/lib|$2|" >"$3"
}
run_step9() { mkscript "$1" "$2" "$WORK/step9.sh"; bash "$WORK/step9.sh" 2>&1; }
# row <out> <id>: the row of one blocker, empty when absent
row() { printf '%s\n' "$1" | grep "^$2	" || true; }
TAB="$(printf '\t')"
# fixture <name> <body, \n escapes>: a project root with blockers.md
fixture() {
  mkdir -p "$WORK/$1/.claude/memory" || exit 1
  printf '%b' "$2" >"$WORK/$1/.claude/memory/blockers.md" || exit 1
}
LIB="$ROOT/lib"

# (a) v1: no `format: 2`; the Index claims open, the body decides
V1='# Blockers\n\n## Index\n| ID | Status |\n|---|---|\n| BLK-001 | open |\n\n'
V1+='## BLK-001 — a\n- **Statut** : resolved\n\n'
V1+='## BLK-002 — b\n- **Statut** : upstream\n\n'
V1+='## BLK-003 — c\n- **Status**: superseded by BLK-002\n\n'
V1+='## BLK-004 — d\nno status here\n\n'
V1+='## BLK-005 — e\n- **Status**: closed\n\n'
V1+='## BLK-006 — f\n- **Statut** : upstream (superseded by #42)\n\n'
V1+='## BLK-007 — g\n- **Statut** : open (not resolved)\n\n'
V1+='## BLK-008 — h\n- **Statut** : unresolved\n\n'
V1+='## BLK-010 — i\n- **Status**: open\n\n'
V1+='### BLK-009 — j\n- **Status**: open\n'
fixture v1 "$V1"
out=$(run_step9 "$WORK/v1" "$LIB")
check HM3a-resolved-absent "$(row "$out" BLK-001)" ""
check HM3a-upstream "$(row "$out" BLK-002)" "BLK-002${TAB}open${TAB}upstream"
check HM3a-superseded-absent "$(row "$out" BLK-003)" ""
check HM3a-no-status "$(row "$out" BLK-004 | cut -f1,2)" \
  "BLK-004${TAB}unreadable"
check HM3a-closed-word "$(row "$out" BLK-005 | cut -f1,2)" \
  "BLK-005${TAB}unreadable"
check HM3a-mixed "$(row "$out" BLK-006 | cut -f1,2)" \
  "BLK-006${TAB}unreadable"
check HM3a-negated "$(row "$out" BLK-007)" "BLK-007${TAB}open${TAB}open"
check HM3a-unresolved "$(row "$out" BLK-008 | cut -f1,2)" \
  "BLK-008${TAB}unreadable"
check HM3a-open "$(row "$out" BLK-010)" "BLK-010${TAB}open${TAB}open"
check HM3a-heading-level "$(row "$out" BLK-009)" \
  "BLK-009${TAB}unreadable${TAB}heading level"

# (b) v2: the heading tag or a labelled line decides, never Solution prose
V2='---\nformat: 2\n---\n# Blockers\n\n'
V2+='## BLK-001 — t [open]\n- **Solution**: resolved the issue partially\n\n'
V2+='## BLK-002 — u [open]\n- **Status (2026-11-01)**: resolved\n\n'
V2+='## BLK-003 — v [upstream]\n\n'
V2+='## BLK-004 — w\nplain prose, no status\n'
fixture v2 "$V2"
out=$(run_step9 "$WORK/v2" "$LIB")
check HM3b-open "$(row "$out" BLK-001)" "BLK-001${TAB}open${TAB}open"
check HM3b-resolved-absent "$(row "$out" BLK-002)" ""
check HM3b-upstream "$(row "$out" BLK-003)" "BLK-003${TAB}open${TAB}upstream"
check HM3b-no-status "$(row "$out" BLK-004 | cut -f1,2)" \
  "BLK-004${TAB}unreadable"

# (c) no blockers.md
mkdir -p "$WORK/none/.claude/memory" || exit 1
check HM3c-no-file "$(run_step9 "$WORK/none" "$LIB")" "blockers: no-file"

# (d) lib dir without reconcile.sh
mkdir -p "$WORK/emptylib" || exit 1
check HM3d-reader-unavailable "$(run_step9 "$WORK/v2" "$WORK/emptylib" \
  | tail -1)" "blockers: reader-unavailable"

printf 'handover-memory-contract: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
