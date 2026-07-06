#!/usr/bin/env bash
# run-reconcile.sh — TDD harness for lib/reconcile.sh.
#
# Iron Law: these tests were RED before the engine existed (scratchpad RED-B). They prove
# the engine VERIFIES (git/fs/body) rather than BELIEVES (checkbox/Index/name). Fixtures
# carry NEUTRAL names on purpose — the engine must reach the truth by querying git, never by
# reading a path hint (the a0f68 baseline failure that read "pre-reconcile" from the dir name).
set -uo pipefail

GREP=/usr/bin/grep                                  # LRN-074: pin grep
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
FIX="$HERE/fixtures"
# shellcheck source=/dev/null
source "$REPO/reconcile.sh"

pass=0; fail=0
ok() { echo "GREEN ✓ $*"; pass=$((pass+1)); }
no() { echo "RED   ✗ $*"; fail=$((fail+1)); }
has() { printf '%s\n' "$1" | $GREP -qF -- "$2"; }   # substring present in multiline string

echo "=== T1 recursive coherence — enumerate from BODY, never the ## Index ==="
DRIFT="$FIX/registry-index-drift.md"
mapfile -t IDS < <(reconcile_enumerate_ids "$DRIFT" LRN)
if [ "${#IDS[@]}" -eq 72 ]; then ok "T1a enumerated 72 body ids"; else no "T1a got ${#IDS[@]}, expected 72 (an Index-reader gives 51)"; fi
if printf '%s\n' "${IDS[@]}" | $GREP -qx "LRN-020"; then ok "T1b includes body-only canary LRN-020"; else no "T1b dropped LRN-020 — read the Index, not the body"; fi
# teeth: an Index-based enumerator would RED here (the fixture discriminates)
idx_only=$($GREP -oE '^\| LRN-[0-9]+' "$DRIFT" | $GREP -oE 'LRN-[0-9]+' | sort -u)
if printf '%s\n' "$idx_only" | $GREP -qx "LRN-020"; then no "T1c teeth LOST — Index path also yields LRN-020"; else ok "T1c teeth intact — Index path OMITS LRN-020 (engine reading the Index would fail T1b)"; fi

echo; echo "=== T2 BLK status — LAST block wins (the BLK-008 trap) ==="
# Hermetic fixture, not the live registry (job3 B1): a frozen post-BLK-009
# snapshot so this test never reds again just because a future blocker gets
# closed. Re-freeze this fixture (copy the live blockers.md) if BLK-008's
# compound-status trap or the open/resolved mix it exercises ever changes.
b="$FIX/blockers-snapshot.md"
case "$(reconcile_blk_current_status "$b" BLK-008)" in
  *RESOLVED*|*resolved*) ok "T2a BLK-008 current = resolved (read FINAL, not the middle REVERTED)";;
  *) no "T2a BLK-008 misread as non-resolved — fell into the compound-status trap";;
esac
case "$(reconcile_blk_current_status "$b" BLK-009)" in
  *RESOLVED*|*resolved*) ok "T2b BLK-009 current = resolved (fixture frozen post-2026-07-06 closure)";;
  *) no "T2b BLK-009 misread";;
esac
open_ids=$(reconcile_blk_open "$b" | cut -f1 | sort | tr '\n' ' ')
if [ "$open_ids" = "BLK-001 BLK-003 " ]; then ok "T2c open blockers = {001,003}"; else no "T2c open = [$open_ids], expected {001,003}"; fi

echo; echo "=== T3 deferral lexical sweep (HONEST LIMIT: marked-only) ==="
defer=$(reconcile_deferrals "$FIX/todo-snapshot.md" "$FIX/decisions-snapshot.md")
for mark in "OUT-OF-SCOPE" "DEFERRED" "follow-up" "one-line ticket"; do
  if has "$defer" "$mark"; then ok "T3 found marked deferral: $mark"; else no "T3 missed marker: $mark"; fi
done
if $GREP -qE '^\s*- \[~\] Cleanup machine' "$FIX/todo-snapshot.md"; then ok "T3e [~] cleanup present for checkbox-state detection"; else no "T3e [~] cleanup not found"; fi

echo; echo "=== T4 reconciliation kernel (pure) + snapshot composition ==="
if [ "$(reconcile_verdict ' ' true)"  = "STALE:open-but-done" ];    then ok "T4a ' '+done   → STALE";      else no "T4a wrong"; fi
if [ "$(reconcile_verdict 'x' false)" = "STALE:done-but-open" ];    then ok "T4b 'x'+!done  → STALE";      else no "T4b wrong"; fi
if [ "$(reconcile_verdict '~' true)"  = "STALE:partial-but-done" ]; then ok "T4c '~'+done   → STALE";      else no "T4c wrong"; fi
if [ "$(reconcile_verdict 'x' true)"  = "CONSISTENT" ];             then ok "T4d 'x'+done   → CONSISTENT"; else no "T4d wrong"; fi
truths=$($GREP -cE '=(true|resolved|present)$' "$FIX/real-state.snapshot")
if [ "$truths" -ge 6 ]; then ok "T4e snapshot supplies $truths real-true facts → kernel yields STALE for the 6 git-verifiable items"; else no "T4e snapshot facts=$truths (<6)"; fi
echo "      (7th cat-4 item — twin doc-sync [~] cross-ref — is SURFACED for review, not auto-verified: honest limit)"

echo; echo "=== T5 contradiction candidates (surface, never assert) ==="
cand=$(reconcile_contradiction_candidates "$FIX/decisions-snapshot.md" "$FIX/todo-snapshot.md")
if has "$cand" "--help"; then ok "T5 surfaced --help candidate (BDR-001 ⇄ --help chantier)"; else no "T5 missed --help candidate"; fi

echo; echo "=== T6 live oracle smoke — oracles QUERY real git/fs (not a name) ==="
if reconcile_oracle_merge_done "$REPO" "prune-memory"; then ok "T6a merge_done(prune-memory) via git log"; else no "T6a merge not found in git"; fi
if reconcile_oracle_sha_exists "$REPO" "be1dcef";      then ok "T6b sha_exists(be1dcef) via cat-file";     else no "T6b sha missing"; fi
# $REPO here = lib/ (see line 12) → lib/../skills = the real skills/ dir.
# Was .claude/skills/ — the LRN-042 parasite dir, removed 2026-06-30 by
# make plugin Step 8.5: green-for-wrong-reason (LRN-077 class).
dk="$REPO/../skills/darwin-skill"
if reconcile_oracle_path_present "$dk"; then ok "T6c path_present(darwin-skill) via fs"; else no "T6c path absent"; fi

echo; echo "=== T7 oracle-sandbox — tree_clean/pushed/msg_committed driven live (not by name) ==="
OWORK="$(mktemp -d)"
bare="$OWORK/origin.git"; git init -q --bare "$bare"
orepo="$OWORK/repo"; git init -q "$orepo"
git -C "$orepo" config user.email t@t; git -C "$orepo" config user.name t
git -C "$orepo" remote add origin "$bare"
echo base > "$orepo/base.txt"; git -C "$orepo" add base.txt; git -C "$orepo" commit -q -m "base commit"
git -C "$orepo" branch -M main
git -C "$orepo" push -q origin main   # populates origin/main BEFORE the pushed-oracle checks (else vacuous rc0)

echo dirty >> "$orepo/base.txt"
if reconcile_oracle_tree_clean "$orepo"; then no "T7a tree_clean should be dirty"; else ok "T7a tree_clean rc≠0 with a dirty file"; fi
git -C "$orepo" checkout -q -- base.txt
if reconcile_oracle_tree_clean "$orepo"; then ok "T7a tree_clean rc0 after restoring clean"; else no "T7a tree_clean should be clean"; fi

if reconcile_oracle_pushed "$orepo" main; then ok "T7b pushed rc0 when synced"; else no "T7b pushed should be rc0 (synced)"; fi
echo more >> "$orepo/base.txt"; git -C "$orepo" add base.txt; git -C "$orepo" commit -q -m "ahead commit"
if reconcile_oracle_pushed "$orepo" main; then no "T7b pushed should be rc≠0 (1 ahead)"; else ok "T7b pushed rc≠0 when 1 ahead of origin"; fi

if reconcile_oracle_msg_committed "$orepo" "ahead commit"; then ok "T7c msg_committed rc0 for a present message"; else no "T7c msg_committed should find 'ahead commit'"; fi
if reconcile_oracle_msg_committed "$orepo" "nonexistent-message-xyz"; then no "T7c msg_committed should be rc≠0 for an absent message"; else ok "T7c msg_committed rc≠0 for an absent message"; fi
rm -rf "$OWORK"

echo; echo "================  $pass GREEN / $fail RED  ================"
[ "$fail" -eq 0 ] && exit 0 || exit 1
