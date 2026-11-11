#!/usr/bin/env bash
# Deterministic RED suite for /prune-memory — RED-1, RED-2, RED-5, RED-6, RED-7, RED-9.
# Each MUST be red on the current (v1) skill. Pure mechanical oracles,
# no LLM. Faithful: RED-2/RED-6/RED-9 execute the REAL bash blocks extracted
# from SKILL.md (no copy that could drift).
#
# Sandbox only (mktemp). NEVER touches real registries or the repo.
# Usage: bash run-deterministic.sh    (exit 0 = all green, 1 = >=1 red)
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="${SKILL:-$HERE/../SKILL.md}"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/prune-red.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

fail=0
red()   { printf 'RED-%s: RED   (skill defective, expected pre-GREEN) -- %s\n' "$1" "$2"; fail=1; }
green() { printf 'RED-%s: GREEN (skill fixed) -- %s\n' "$1" "$2"; }

# Pull the real fenced ```bash block under a "## <heading>" from SKILL.md.
# Verified by the extract-check before the suite was written.
extract_block() {
  awk -v h="$1" '
    $0 ~ "^## " h "( |$)" {f=1}
    f && /^```bash/ {c=1; next}
    f && /^```/ && c {c=0; f=0; next}
    c {print}
  ' "$SKILL"
}

# ---- RED-1: no claim of a verification that never ran -----------------------
if grep -qE 'Fixed in v1\.1|TDD found it' "$SKILL"; then
  red 1 "false 'Fixed in v1.1 (TDD found it)' claim present in SKILL.md"
else
  green 1 "no unproven verification claim in SKILL.md"
fi

# ---- RED-2: STEP 0 PRECHECK must refuse a dirty registry tree ---------------
S2="$SANDBOX/red2"; mkdir -p "$S2/.claude/memory"
git -C "$S2" init -q
printf '## BDR-001 -- seed\n' > "$S2/.claude/memory/decisions.md"
git -C "$S2" add -A
git -C "$S2" -c user.email=t@t -c user.name=t commit -qm seed >/dev/null 2>&1
printf 'uncommitted dirty line\n' >> "$S2/.claude/memory/decisions.md"
extract_block "STEP 0" > "$S2/step0.sh"
( cd "$S2" && bash step0.sh >/dev/null 2>&1 ); code=$?
if [ "$code" -ne 0 ]; then
  green 2 "STEP 0 exits $code on dirty tree (blocks the run)"
else
  red 2 "STEP 0 exits 0 on dirty tree -- prose-only STOP, no machine block"
fi

# ---- RED-5: STEP 4 verify must catch a safety-critical content mutation -----
# Leans on the clean-tree precondition (RED-2): git HEAD is the pre-prune
# backup, so STEP 4 can diff against it. A GREEN verify must FLAG any deleted
# permanent/negation line; v1 has no such check and falsely certifies OK.
S5="$SANDBOX/red5"; mkdir -p "$S5/.claude/memory"
git -C "$S5" init -q
printf '# Journal\n\n## 2025-11-03\n- PERMANENT rule: NEVER deploy migration 0007 without the backfill job first.\n' \
  > "$S5/.claude/memory/journal.md"
git -C "$S5" add -A
git -C "$S5" -c user.email=t@t -c user.name=t commit -qm seed >/dev/null 2>&1
# Simulate a BAD prune that collapses away the safety-critical NEVER line:
printf '# Journal\n\n## 2025-11\n- Shipped auth migration; minor cleanup.\n' \
  > "$S5/.claude/memory/journal.md"
extract_block "STEP 4" > "$S5/step4.sh"
out5="$( cd "$S5" && bash step4.sh 2>/dev/null )"
if printf '%s\n' "$out5" | grep -qiE 'FIDELITY FAIL|safety-critical'; then
  green 5 "STEP 4 flags the removed safety-critical NEVER line"
else
  red 5 "STEP 4 certifies OK after a safety-critical line was deleted (no fidelity check)"
fi

# ---- RED-6: STEP 4 verify runs memory.sh check (duplicate ID caught) --------
# v2 registries carry no Index; the structural verify is `memory.sh check`
# (heading shape, unique IDs). HOME is pinned to a sandbox whose .claude/lib
# is this repo's lib, so the run never depends on the machine's ~/.claude.
S6="$SANDBOX/red6"; mkdir -p "$S6/.claude/memory" "$S6/home/.claude"
ln -s "$HERE/../../../lib" "$S6/home/.claude/lib"
cp "$HERE/fixtures/red6-check/.claude/memory/decisions.md" \
   "$S6/.claude/memory/decisions.md"
extract_block "STEP 4" > "$S6/step4.sh"
out="$( cd "$S6" && HOME="$S6/home" bash step4.sh 2>&1 )"
if printf '%s\n' "$out" | grep -qE 'duplicate BDR-009'; then
  green 6 "verify runs memory.sh check and names the duplicate BDR-009"
else
  red 6 "verify misses the duplicate BDR-009 (no memory.sh check in STEP 4)"
fi

# ---- RED-7: STEP 2 plan example must use FICTIONAL ids, never live registry ids
# Live ids in the worked example PRIME the skill to act on those exact entries on
# real data (observed 2026-06-25: it merged the example's LRN-014 + LRN-016 on the
# live learnings.md, though they are complementary, not overlapping). Fictional ids
# (9xx) cannot match a real registry. Reads SKILL.md only — sandbox-safe.
# /usr/bin/grep (not the system grep, which may be ugrep — a leading-dash pattern
# like `-9..` is then misparsed as an option, erroring to an empty + FALSE GREEN).
ex7="$(awk '/^PRUNE PLAN/{f=1} f{print} /^Approve per category/{f=0; exit}' "$SKILL")"
bad7="$(printf '%s\n' "$ex7" | /usr/bin/grep -oE '(BDR|LRN|BLK|EVAL)-[0-9]+' | /usr/bin/grep -vE '9[0-9][0-9]$' | sort -u | tr '\n' ' ')"
if [ -n "${bad7// /}" ]; then
  red 7 "STEP 2 example uses LIVE-range ids (prime real-data ops): ${bad7% }"
else
  green 7 "STEP 2 example uses only fictional (9xx) ids"
fi

# ---- RED-9: STEP 1 reads statuses through the classifier (v1 + v2) ---------
# Runs the shipped STEP 1 block (LRN-276) on sandbox registries written with
# printf; HOME pinned like RED-6. Rows asserted whole-line, fixed string.
TAB=$'\t'
S9A="$SANDBOX/red9a"; S9B="$SANDBOX/red9b"
mkdir -p "$S9A/.claude/memory" "$S9B/.claude/memory"
printf -- '---\nformat: 2\n---\n# Decisions\n\n' > "$S9A/.claude/memory/decisions.md"
printf '## BDR-901 — old idea [proposed] (2026-01-01)\n- **Context**: resolved later\n\n' \
  >> "$S9A/.claude/memory/decisions.md"
printf '## BDR-902 — kept [accepted] (2026-02-01)\n- **Status (2026-03-01)**: superseded by BDR-903\n' \
  >> "$S9A/.claude/memory/decisions.md"
printf '## BLK-903 — c\n- **Status**: upstream\n' > "$S9A/.claude/memory/blockers.md"
printf '## BDR-904 — x\ndate: 2026-01-01 · status: accepted\n\n' > "$S9B/.claude/memory/decisions.md"
printf '## BDR-905 — y\nStatus: closed.\n\n' >> "$S9B/.claude/memory/decisions.md"
printf '## BDR-906 — z\nStatus: proposed\n- **Statut** : accepted (2026-05-01)\n\n' \
  >> "$S9B/.claude/memory/decisions.md"
printf '## BDR-907 — w\n- Status: proposed\nSuperseded by BDR-911 (2026-05-01).\n' \
  >> "$S9B/.claude/memory/decisions.md"
extract_block "STEP 1" > "$SANDBOX/step1.sh"
mkdir -p "$SANDBOX/home9/.claude"; ln -s "$HERE/../../../lib" "$SANDBOX/home9/.claude/lib"
out9a="$( cd "$S9A" && HOME="$SANDBOX/home9" bash "$SANDBOX/step1.sh" 2>&1 )"
out9b="$( cd "$S9B" && HOME="$SANDBOX/home9" bash "$SANDBOX/step1.sh" 2>&1 )"
msg9=""
has9() { printf '%s\n' "$1" | /usr/bin/grep -qxF "$2"; }
has9 "$out9a" "BDR-901${TAB}open${TAB}proposed" || msg9="v2 BDR-901 row missing"
printf '%s\n' "$out9a" | /usr/bin/grep -qF "BDR-902${TAB}" \
  && msg9="${msg9:-v2 BDR-902 listed after superseded}"
has9 "$out9a" "BLK-903${TAB}open${TAB}upstream" || msg9="${msg9:-BLK-903 row missing}"
has9 "$out9b" "BDR-904${TAB}open${TAB}accepted" || msg9="${msg9:-v1 BDR-904 row missing}"
printf '%s\n' "$out9b" | /usr/bin/grep -qF "BDR-905${TAB}unreadable${TAB}" \
  || msg9="${msg9:-v1 BDR-905 not unreadable}"
has9 "$out9b" "BDR-906${TAB}open${TAB}accepted" || msg9="${msg9:-v1 BDR-906 row missing}"
printf '%s\n' "$out9b" | /usr/bin/grep -qF "BDR-907${TAB}open${TAB}" \
  && msg9="${msg9:-v1 BDR-907 listed open}"
[ "$(/usr/bin/grep -c 'status: ' "$SKILL")" = 0 ] || msg9="${msg9:-SKILL.md keeps a raw status: line}"
[ "$(/usr/bin/grep -c 'frontmatter' "$SKILL")" = 0 ] || msg9="${msg9:-SKILL.md keeps frontmatter wording}"
if [ -z "$msg9" ]; then
  green 9 "STEP 1 block classifies v1 + v2 statuses, SKILL.md has no raw status wording"
else
  red 9 "$msg9"
fi

echo "----"
if [ "$fail" -eq 0 ]; then
  echo "SUITE: all GREEN"
else
  echo "SUITE: >=1 RED red (skill defective as expected pre-GREEN)"
fi
exit "$fail"
