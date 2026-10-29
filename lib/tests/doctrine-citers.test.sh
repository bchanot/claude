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
# Since BDR-125 phase 1 doctrine also lives in rules/ and lib/: a
# `rules/<f>.md § Label` / `lib/<f>.md § Label` citation resolves against
# that file (T4-T6).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

# _citers_extract <file>… → "file:line:name" per cited section (quoted) or label (§)
_citers_extract() {
  /usr/bin/grep -nHoE 'CLAUDE(\.global)?\.md[^"“]{0,12}["“][^"”[:space:]][^"”]{1,59}["”]' "$@" 2>/dev/null \
    | sed -E 's/^([^:]+:[0-9]+):.*["“]([^"”]+)["”]$/\1:\2/'
  /usr/bin/grep -nHoE 'CLAUDE(\.global)?\.md[^§]{0,60}§ ?[A-Z][A-Za-z][A-Za-z -]{1,40}' "$@" 2>/dev/null \
    | sed -E 's/^([^:]+:[0-9]+):.*§ ?([A-Za-z][A-Za-z -]+)$/\1:\2/; s/[[:space:]]+$//'
}

# _citers_resolve <doctrine> <name> → rc 0 when a heading starts with <name>
# (then end, space, `:`, `(` or `—`) or a bold label `**<name>` appears.
# Fixed-string awk: the name is never read as a regex (BSD grep -E rejects
# some, and "Alpha" must not resolve against "## Alphabet").
_citers_resolve() {
  awk -v n="$2" '
    /^#+ / {
      t = $0; sub(/^#+ /, "", t)
      if (substr(t, 1, length(n)) == n) {
        r = substr(t, length(n) + 1)
        if (r == "" || r ~ /^[ :(]/ || index(r, "—") == 1) found = 1
      }
    }
    index($0, "**" n) { found = 1 }
    END { exit !found }' "$1"
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

# _citers_extract_files <file>… → "file:line:target:name" per citation of a
# heading in another doctrine file: `rules/<f>.md § Label` or
# `lib/<f>.md § Label`, backticks around the path and quotes around the
# label allowed. A quoted label runs to its closing quote (`—` included); an
# unquoted one ends at the first character that is not a letter, space or
# hyphen: quote a label that prose follows. A citation of
# `.claude/rules/<f>.md § X` would be read as `rules/<f>.md` (none exist;
# ERE has no lookbehind and the portability census bans grep -P).
_citers_extract_files() {
  /usr/bin/grep -nHoE '(rules|lib)/[a-z0-9-]+\.md`? § ?"[^"]{2,60}"' "$@" 2>/dev/null \
    | sed -E 's/^([^:]+:[0-9]+):(.*\.md)`? § ?"([^"]+)"$/\1:\2:\3/'
  /usr/bin/grep -nHoE '(rules|lib)/[a-z0-9-]+\.md`? § ?[A-Z][A-Za-z][A-Za-z -]{1,40}' "$@" 2>/dev/null \
    | sed -E 's/^([^:]+:[0-9]+):(.*\.md)`? § ?(.*)$/\1:\2:\3/; s/[[:space:]]+$//'
}

# citers_check_files <root> <file>… → DANGLING lines; rc = their count (capped 99)
citers_check_files() {
  local root="$1" line file lno target name n=0; shift
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    file="${line%%:*}"; lno="$(printf '%s' "$line" | cut -d: -f2)"
    target="$(printf '%s' "$line" | cut -d: -f3)"; name="${line#*:*:*:}"
    if [ ! -f "$root/$target" ] || ! _citers_resolve "$root/$target" "$name"; then
      echo "DANGLING: $file:$lno → $target § \"$name\""; n=$((n+1))
    fi
  done < <(_citers_extract_files "$@")
  return $(( n > 99 ? 99 : n ))
}

# ── flip-test: a synthetic dangling citation must be caught ──────────────────
FIX="$(mktemp -d)"; trap 'rm -rf "$FIX"' EXIT
# shellcheck disable=SC2016  # literal backticks in the fixture heading
printf '## Alpha\n\n**Always English, always caveman**: rule.\n\n## Memory registries (`x`)\n' > "$FIX/doctrine.md"
printf 'ok: see CLAUDE.md "Alpha" and CLAUDE.md "Memory registries" (Always English, always caveman)\n' > "$FIX/good.md"
printf 'bad: (see CLAUDE.md "Memory registries" § Language) and CLAUDE.md "Beta"\n' > "$FIX/bad.md"
printf '## Alphabet\n' > "$FIX/prefix.md"
printf 'prefix: see CLAUDE.md "Alpha"\n' > "$FIX/alpha.md"
citers_check "$FIX/prefix.md" "$FIX/alpha.md" >/dev/null
check T2d-name-prefix-of-heading-stays-dangling "$?" 1
citers_check "$FIX/doctrine.md" "$FIX/good.md" >/dev/null; check T1-resolving-citations-pass "$?" 0
out=$(citers_check "$FIX/doctrine.md" "$FIX/bad.md"); rc=$?
check T2-dangling-section-and-label-caught "$rc" 2
check T2b-names-the-culprit "$(printf '%s\n' "$out" | grep -c 'bad.md:1')" 2
check T2c-label-named "$(printf '%s\n' "$out" | grep -c '"Language"')" 1
mkdir -p "$FIX/rules" "$FIX/lib"
printf '## Versioning\nx\n' > "$FIX/rules/api.md"
printf '## WRITE (before the commit)\n' > "$FIX/lib/cc.md"
# shellcheck disable=SC2016  # literal backticks in the fixture
printf 'ok: see `rules/api.md` § Versioning, and lib/cc.md § WRITE (x)\n' > "$FIX/fgood.md"
printf 'quoted: rules/api.md § "Versioning" first\n' >> "$FIX/fgood.md"
printf '## Design work — full toolchain (tiered)\n' > "$FIX/rules/web.md"
printf 'dash: rules/web.md § "Design work — full toolchain" first\n' >> "$FIX/fgood.md"
printf 'bad: rules/api.md § "Version", rules/none.md § Alpha, lib/cc.md § Read\n' > "$FIX/fbad.md"
printf 'dash: rules/web.md § "Design work — full kit" first\n' >> "$FIX/fbad.md"
citers_check_files "$FIX" "$FIX/fgood.md" >/dev/null; check T4-file-citations-resolve "$?" 0
out=$(citers_check_files "$FIX" "$FIX/fbad.md"); rc=$?
check T5-file-dangling-caught "$rc" 4
check T5d-quoted-label-whole "$(printf '%s\n' "$out" | grep -c 'full kit')" 1
check T5b-missing-file-named "$(printf '%s\n' "$out" | grep -c 'rules/none.md')" 1
check T5c-prefix-not-a-heading "$(printf '%s\n' "$out" | grep -c '"Version"')" 1

# ── real census: the repo's own citers against CLAUDE.global.md ──────────────
mapfile -t FILES < <(cd "$ROOT" && find skills agents lib rules hooks -type f \( -name '*.md' -o -name '*.sh' \) \
  -not -path 'skills/graphify/*' -not -path 'skills/impeccable/*' -not -path 'skills/synced/*' \
  -not -path 'agents/impeccable-*' -not -path 'lib/tests/*' | sort)
out=$(cd "$ROOT" && citers_check CLAUDE.global.md "${FILES[@]}"); rc=$?
[ -n "$out" ] && printf '%s\n' "$out"
check T3-repo-citations-resolve "$rc" 0
out=$(cd "$ROOT" && citers_check_files "$ROOT" "${FILES[@]}" CLAUDE.global.md); rc=$?
[ -n "$out" ] && printf '%s\n' "$out"
check T6-repo-file-citations-resolve "$rc" 0
# T7: the real citers bite — the same two files against a copy of
# rules/rest-api.md whose heading is renamed (never edit the live rules/)
mkdir -p "$FIX/copy/rules"
cp "$ROOT/rules/rest-api.md" "$FIX/copy/rules/rest-api.md"
(cd "$ROOT" && citers_check_files "$FIX/copy" lib/architecture-defaults.md \
  lib/project-archetypes/rest-api-node.md) >/dev/null
check T7a-real-citers-control "$?" 0
sed 's/^## Versioning$/## Version policy/' "$ROOT/rules/rest-api.md" > "$FIX/copy/rules/rest-api.md"
(cd "$ROOT" && citers_check_files "$FIX/copy" lib/architecture-defaults.md \
  lib/project-archetypes/rest-api-node.md) >/dev/null
check T7b-real-rename-bites "$?" 2
# the hook's pointer is checked whole, not as its "Design work" prefix
check T7c-hook-label-whole "$(cd "$ROOT" && _citers_extract_files hooks/design-toolchain-reminder.sh \
  | grep -c ':rules/web-building.md:Design work — full toolchain$')" 2

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
