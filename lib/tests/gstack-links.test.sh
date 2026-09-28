#!/usr/bin/env bash
# lib/tests/gstack-links.test.sh — lib/gstack-links.sh's
# link_gstack_helpers(): whole-class mirroring of a gstack skill dir
# (SKILL.md excluded), whole-dir symlink for a clean non-skill dir/file,
# skip-whole for a non-skill dir hiding a nested SKILL.md
# (browser-skills/, openclaw/-style), skip-by-name for `.git*` and
# `node_modules`, idempotent re-run (echoes 0, nothing changes), a stale
# dst-is-symlink-to-src planted by gstack ./setup (removed, dst becomes
# a real dir, nothing written into src), and a dst path that would
# resolve inside src (refused, rc 1, nothing created). Covers contract
# criterion 3 (whole class) and the r4 confirmation-pass fixtures.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/lib/gstack-links.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
SRC="$WORK/src"
DST="$WORK/dst"

# ── fixture src: one skill dir (browse), one nested skill-dir tree
# (review, with a sub-directory of its own), plain shared assets
# (bin/, ETHOS.md), the top-level gstack SKILL.md itself, vcs metadata,
# and the two non-skill-dir-hiding-a-nested-SKILL.md cases (other/deep,
# node_modules/pkg) ──
mkdir -p "$SRC/bin" "$SRC/browse/dist" "$SRC/review/specialists" \
  "$SRC/.git" "$SRC/other/deep" "$SRC/node_modules/pkg"
echo x > "$SRC/bin/x"
echo ethos > "$SRC/ETHOS.md"
echo skill > "$SRC/SKILL.md"
echo browse-skill > "$SRC/browse/SKILL.md"
echo browse-bin > "$SRC/browse/dist/browse"
echo review-skill > "$SRC/review/SKILL.md"
echo checklist > "$SRC/review/checklist.md"
echo spec-a > "$SRC/review/specialists/a.md"
echo head > "$SRC/.git/HEAD"
echo nested > "$SRC/other/deep/SKILL.md"
echo pkg-skill > "$SRC/node_modules/pkg/SKILL.md"

# shellcheck source=../gstack-links.sh disable=SC1091
source "$LIB"

# ── T1: first run mirrors the whole class, exposes no SKILL.md ──
n1=$(link_gstack_helpers "$SRC" "$DST" 2>/dev/null)
check T1-bin-resolves \
  "$([ -f "$DST/bin/x" ] && cat "$DST/bin/x" || echo missing)" x
check T1-ethos-resolves \
  "$([ -f "$DST/ETHOS.md" ] && cat "$DST/ETHOS.md" || echo missing)" ethos
check T1-browse-dist-resolves \
  "$([ -f "$DST/browse/dist/browse" ] && cat "$DST/browse/dist/browse" \
    || echo missing)" browse-bin
check T1-review-checklist-resolves \
  "$([ -f "$DST/review/checklist.md" ] && cat "$DST/review/checklist.md" \
    || echo missing)" checklist
check T1-review-specialists-resolves \
  "$([ -f "$DST/review/specialists/a.md" ] \
    && cat "$DST/review/specialists/a.md" || echo missing)" spec-a
check T1-no-skillmd-anywhere \
  "$(find -L "$DST" -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')" 0
check T1-no-dotgit "$([ -e "$DST/.git" ] && echo present || echo absent)" \
  absent
check T1-no-other "$([ -e "$DST/other" ] && echo present || echo absent)" \
  absent
check T1-no-node-modules \
  "$([ -e "$DST/node_modules" ] && echo present || echo absent)" absent
check T1-count-positive "$([ "$n1" -gt 0 ] && echo yes || echo no)" yes

# ── T2: idempotent re-run — echoes 0, tree unchanged ──
n2=$(link_gstack_helpers "$SRC" "$DST" 2>/dev/null)
check T2-echoes-zero "$n2" 0
check T2-bin-still-resolves \
  "$([ -f "$DST/bin/x" ] && cat "$DST/bin/x" || echo missing)" x

# ── T3: dst is a symlink to src (gstack ./setup's stale-link case) —
# removed, dst becomes a real dir, nothing written into src ──
DST3="$WORK/dst-symlinked"
ln -s "$SRC" "$DST3"
n3=$(link_gstack_helpers "$SRC" "$DST3" 2>/dev/null)
check T3-dst-is-real-dir "$([ -d "$DST3" ] && [ ! -L "$DST3" ] \
  && echo yes || echo no)" yes
check T3-bin-resolves \
  "$([ -f "$DST3/bin/x" ] && cat "$DST3/bin/x" || echo missing)" x
check T3-nothing-written-in-src \
  "$(find "$SRC" -type l 2>/dev/null | wc -l | tr -d ' ')" 0
check T3-count-positive "$([ "$n3" -gt 0 ] && echo yes || echo no)" yes

# ── T4: dst path resolves inside src — refused, rc 1, nothing created ──
DST4="$SRC/helpers"
out4=$(link_gstack_helpers "$SRC" "$DST4" 2>&1 >/dev/null)
rc4=$?
n4=$(link_gstack_helpers "$SRC" "$DST4" 2>/dev/null)
check T4-rc "$rc4" 1
check T4-echoes-zero "$n4" 0
check T4-nothing-created "$([ -e "$DST4" ] && echo present || echo absent)" \
  absent
check T4-warns "$(printf '%s' "$out4" | grep -qi 'refusing' \
  && echo yes || echo no)" yes

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
