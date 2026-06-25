#!/usr/bin/env bash
# Deterministic RED suite for /prune-memory — RED-1, RED-2, RED-5, RED-6.
# Each MUST be red on the current (v1) skill. Pure mechanical oracles,
# no LLM. Faithful: RED-2/RED-6 execute the REAL bash blocks extracted
# from SKILL.md (no copy that could drift).
#
# Sandbox only (mktemp). NEVER touches real registries or the repo.
# Usage: bash run-deterministic.sh    (exit 0 = all green, 1 = >=1 red)
set -uo pipefail

SKILL="${SKILL:-$HOME/.claude/skills/prune-memory/SKILL.md}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/prune-red.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

fail=0
red()   { printf 'RED-%s: RED   (skill defective, expected pre-GREEN) -- %s\n' "$1" "$2"; fail=1; }
green() { printf 'RED-%s: GREEN (skill fixed) -- %s\n' "$1" "$2"; }

# Pull the real fenced ```bash block under a "## <heading>" from SKILL.md.
# Verified by the extract-check before the suite was written.
extract_block() {
  awk -v h="$1" '
    $0 ~ "^## " h {f=1}
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

# ---- RED-6: STEP 4 verify must not false-orphan a title-less heading --------
S6="$SANDBOX/red6"; mkdir -p "$S6/.claude/memory"
cp "$HERE/fixtures/red6-orphan/.claude/memory/decisions.md" \
   "$S6/.claude/memory/decisions.md"
extract_block "STEP 4" > "$S6/step4.sh"
out="$( cd "$S6" && bash step4.sh 2>/dev/null )"
if printf '%s\n' "$out" | grep -qE '^ORPHAN INDEX: BDR-009'; then
  red 6 "verify emits FALSE 'ORPHAN INDEX: BDR-009' (body exists; trailing-space bug)"
else
  green 6 "verify does not false-orphan the title-less heading"
fi

echo "----"
if [ "$fail" -eq 0 ]; then
  echo "SUITE: all GREEN"
else
  echo "SUITE: >=1 RED red (skill defective as expected pre-GREEN)"
fi
exit "$fail"
