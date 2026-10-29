#!/usr/bin/env bash
# lib/tests/user-rules.test.sh — user-scope rules (rules/*.md, deployed as
# ~/.claude/rules): every frontmatter parses (one-line JSON `paths:` or no
# frontmatter at all) and the always-on set is exactly the two rules chat
# needs (BDR-125 phase 1 moved default-language to lib/architecture-defaults.md
# and the Supabase / cloud-functions bodies to path rules). Globs are not
# matched here: user rules span every stack; the load is proved by an
# InstructionsLoaded session (contract context-diet, criterion 15).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../project-rules.sh disable=SC1091
source "$ROOT/lib/project-rules.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

# rule_kind <file> → path | always | bad
rule_kind() {
  local fm
  fm=$(_rules_frontmatter "$1") || { echo always; return; }
  _rules_globs "$fm" >/dev/null
  case $? in 0) echo path ;; 1) echo always ;; *) echo bad ;; esac
}
# always_on <dir> → the always-on rule file names, space-joined
always_on() {
  local f out=""
  for f in "$1"/*.md; do
    [ "$(rule_kind "$f")" = always ] && out="$out ${f##*/}"
  done
  printf '%s\n' "${out# }"
}

# ── flip controls: the checker bites (LRN-096) ──
FIX="$(mktemp -d)"; trap 'rm -rf "$FIX"' EXIT
printf -- '---\npaths: ["**/*.css"]\n---\n\n# A\n' > "$FIX/a.md"
printf '# B, always-on\n' > "$FIX/b.md"
printf -- '---\npaths:\n  - "**/*.css"\n---\n\n# C\n' > "$FIX/c.md"
check F1-path-rule "$(rule_kind "$FIX/a.md")" path
check F2-no-frontmatter-always "$(rule_kind "$FIX/b.md")" always
check F3-multiline-paths-bad "$(rule_kind "$FIX/c.md")" bad
check F4-extra-always-on-seen "$(always_on "$FIX")" "b.md"
# the R2 lock itself bites on a dir whose always-on set differs
cp "$FIX/b.md" "$FIX/writing-style.md"; cp "$FIX/b.md" "$FIX/secure-by-default.md"
check F5-lock-bites "$([ "$(always_on "$FIX")" = "secure-by-default.md writing-style.md" ] && echo match || echo mismatch)" mismatch

# ── the real rules ──
bad=""
for f in "$ROOT"/rules/*.md; do
  [ "$(rule_kind "$f")" = bad ] && bad="$bad ${f##*/}"
done
check R1-every-frontmatter-parses "${bad# }" ""
check R2-always-on-set "$(always_on "$ROOT/rules")" "secure-by-default.md writing-style.md"
check R3-moved-rules-path "$(rule_kind "$ROOT/rules/supabase.md")/$(rule_kind "$ROOT/rules/cloud-functions.md")" path/path

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
