#!/usr/bin/env bash
# lib/tests/doctrine-citers.test.sh — every citation of a CLAUDE.global.md
# section or bold label from skills/agents/lib/rules/hooks must resolve
# (BDR-100). Born from the 2026-09-24 density pass: a bold label was reworded
# and five skills kept pointing at "§ Language" for a day. A flip-test proves
# the checker bites before the real census runs (LRN-096).
#
# Only citations that NAME the doctrine count: `CLAUDE.md "Section"` and
# `CLAUDE.md … § Label`. Bare `section "…"` / `§ X` inside a skill refer to the
# skill's own sections and are out of scope.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

# _citers_extract <file>… → "file:line:name" per cited section (quoted) or label (§)
_citers_extract() {
  /usr/bin/grep -nHoE 'CLAUDE(\.global)?\.md[^"“]{0,12}["“][^"”]{2,60}["”]' "$@" 2>/dev/null \
    | sed -E 's/^([^:]+:[0-9]+):.*["“]([^"”]+)["”]$/\1:\2/'
  /usr/bin/grep -nHoE 'CLAUDE(\.global)?\.md[^§]{0,60}§ ?[A-Z][A-Za-z][A-Za-z -]{1,40}' "$@" 2>/dev/null \
    | sed -E 's/^([^:]+:[0-9]+):.*§ ?([A-Za-z][A-Za-z -]+)$/\1:\2/; s/[[:space:]]+$//'
}

# _citers_resolve <doctrine> <name> → rc 0 when a heading or a bold label starts with <name>
_citers_resolve() {
  /usr/bin/grep -qE "^#+ ${2}( |$|:|\(|—)" "$1" && return 0
  /usr/bin/grep -qF -- "**${2}" "$1"
}

# citers_check <doctrine> <file>… → prints DANGLING lines; rc = their count (capped 99)
citers_check() {
  local doctrine="$1" line name file lno n=0; shift
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    file="${line%%:*}"; lno="$(printf '%s' "$line" | cut -d: -f2)"; name="${line#*:*:}"
    _citers_resolve "$doctrine" "$name" || { echo "DANGLING: $file:$lno → \"$name\""; n=$((n+1)); }
  done < <(_citers_extract "$@")
  return $(( n > 99 ? 99 : n ))
}

# ── flip-test: a synthetic dangling citation must be caught ──────────────────
FIX="$(mktemp -d)"; trap 'rm -rf "$FIX"' EXIT
# shellcheck disable=SC2016  # literal backticks in the fixture heading
printf '## Alpha\n\n**Always English, always caveman**: rule.\n\n## Memory registries (`x`)\n' > "$FIX/doctrine.md"
printf 'ok: see CLAUDE.md "Alpha" and CLAUDE.md "Memory registries" (Always English, always caveman)\n' > "$FIX/good.md"
printf 'bad: (see CLAUDE.md "Memory registries" § Language) and CLAUDE.md "Beta"\n' > "$FIX/bad.md"
citers_check "$FIX/doctrine.md" "$FIX/good.md" >/dev/null; check T1-resolving-citations-pass "$?" 0
out=$(citers_check "$FIX/doctrine.md" "$FIX/bad.md"); rc=$?
check T2-dangling-section-and-label-caught "$rc" 2
check T2b-names-the-culprit "$(printf '%s\n' "$out" | grep -c 'bad.md:1')" 2
check T2c-label-named "$(printf '%s\n' "$out" | grep -c '"Language"')" 1

# ── real census: the repo's own citers against CLAUDE.global.md ──────────────
mapfile -t FILES < <(cd "$ROOT" && find skills agents lib rules hooks -type f \( -name '*.md' -o -name '*.sh' \) \
  -not -path 'skills/graphify/*' -not -path 'skills/impeccable/*' -not -path 'skills/synced/*' \
  -not -path 'agents/impeccable-*' -not -path 'lib/tests/*' | sort)
out=$(cd "$ROOT" && citers_check CLAUDE.global.md "${FILES[@]}"); rc=$?
[ -n "$out" ] && printf '%s\n' "$out"
check T3-repo-citations-resolve "$rc" 0

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
