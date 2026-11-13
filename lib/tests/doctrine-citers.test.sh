#!/usr/bin/env bash
# lib/tests/doctrine-citers.test.sh — every citation of a CLAUDE.global.md
# section or bold label from skills/agents/lib/rules/hooks (file citations
# also from templates/ and .claude/rules/) must resolve (BDR-100). Born from
# the 2026-09-24 density pass: a bold label was reworded and five skills kept
# pointing at "§ Language" for a day. A flip-test proves
# the checker bites before the real census runs (LRN-096).
#
# Only citations that NAME the doctrine count: `CLAUDE.md "Section"` and
# `CLAUDE.md … § Label`. Bare `section "…"` / `§ X` inside a skill refer to the
# skill's own sections and are out of scope.
# Since BDR-125 phase 1 doctrine also lives in rules/ and lib/: a
# `rules/<f>.md § Label` / `lib/<f>.md § Label` citation resolves against
# that file (T4-T6), nested dirs and `~/.claude/` prefixes included.
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
# `lib/<f>.md § Label` (nested dirs allowed: `lib/<dir>/<f>.md`), backticks
# around the path and quotes around the label allowed. A quoted label runs to
# its closing quote (`—` included); an unquoted one ends at the first
# character that is not a letter, space or hyphen: quote a label that prose
# follows. The path needs a left boundary (`foo-rules/x.md` is not
# `rules/x.md`). A `~/.claude/`, `$HOME/.claude/` or `${HOME}/.claude/` prefix
# maps to this repo's tree and is dropped from the target; a bare
# `.claude/` stays (see citers_check_files); `templates/project-rules/<f>.md`
# is its own target. An absolute `/home/<u>/…` path is unsupported (read as
# a bare `.claude/…` or by its suffix).
CITE_PATH='(^|[^A-Za-z0-9_-])((~|\$[{]?HOME[}]?)/\.claude/|\.claude/)?'
CITE_PATH+='(templates/project-)?(rules|lib)/([a-z0-9-]+/)*[a-z0-9-]+\.md'
# Strip: optional boundary char (absent at column 1, never `~ $ .`) and the
# home prefix.
CITE_STRIP='s/^([^:]+:[0-9]+):[^A-Za-z0-9_~$.-]?'
CITE_STRIP+='((~|\$[{]?HOME[}]?)\/\.claude\/)?(.*\.md)`? § ?'
_citers_extract_files() {
  {
    /usr/bin/grep -nHoE "$CITE_PATH"'`? § ?"[^"]{2,60}"' "$@" 2>/dev/null
    /usr/bin/grep -nHoE "$CITE_PATH"'`? § ?[A-Z][A-Za-z][A-Za-z -]{1,40}' \
      "$@" 2>/dev/null
  } | sed -E \
    -e "$CITE_STRIP"'"([^"]+)"$/\1:\4:\5/' \
    -e t \
    -e "$CITE_STRIP"'(.*)$/\1:\4:\5/' \
    -e 's/[[:space:]]+$//'
}

# citers_check_files <root> <file>… → DANGLING lines; rc = their count (capped 99)
# A bare `.claude/rules/<f>.md` is a project path: cited from this repo's own
# rules (`.claude/rules/*`, `rules/*`) it is this repo's file, from anywhere
# else (skills, agents, templates…) it names the copy emitted from
# `templates/project-rules/<f>.md`.
citers_check_files() {
  local root="$1" line file lno target name n=0; shift
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    file="${line%%:*}"; lno="$(printf '%s' "$line" | cut -d: -f2)"
    target="$(printf '%s' "$line" | cut -d: -f3)"; name="${line#*:*:*:}"
    case "$target:$file" in
      .claude/rules/*:.claude/rules/*|.claude/rules/*:*/.claude/rules/*|\
      .claude/rules/*:rules/*) ;;
      .claude/rules/*:*)
        target="templates/project-rules/${target#.claude/rules/}" ;;
    esac
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

# T8a-T8i: blind spots of the file-citation census (nested dirs, project
# rules, home prefixes, left boundary, templates, quoted label kept whole)
mkdir -p "$FIX/lib/sub" "$FIX/.claude/rules" "$FIX/templates/project-rules"
printf '## Alpha\n' > "$FIX/lib/sub/x.md"
printf 'nested: lib/sub/x.md § Alpha\n' > "$FIX/n1.md"
rows=$(_citers_extract_files "$FIX/n1.md")
citers_check_files "$FIX" "$FIX/n1.md" >/dev/null
check T8a-nested-lib-resolves "$rows|$?" "$FIX/n1.md:1:lib/sub/x.md:Alpha|0"
printf 'nested: lib/sub/x.md § Beta\n' > "$FIX/n2.md"
out=$(citers_check_files "$FIX" "$FIX/n2.md"); rc=$?
hits=$(printf '%s\n' "$out" | grep -c 'lib/sub/x.md')
check T8b-nested-lib-dangling "$rc|$hits" "1|1"
printf '## Gamma\n' > "$FIX/.claude/rules/p.md"
printf '.claude/rules/p.md § Gamma\nalso .claude/rules/p.md § Gamma.\n' \
  > "$FIX/.claude/rules/c.md"
citers_check_files "$FIX" "$FIX/.claude/rules/c.md" >/dev/null
check T8c-project-rules-resolve "$?" 0
printf 'skill: .claude/rules/q.md § Delta.\n' > "$FIX/s.md"
printf '## Delta\n' > "$FIX/templates/project-rules/q.md"
citers_check_files "$FIX" "$FIX/s.md" >/dev/null; rc1=$?
rm "$FIX/templates/project-rules/q.md"
printf '## Delta\n' > "$FIX/rules/q.md"
printf '## Delta\n' > "$FIX/.claude/rules/q.md"
citers_check_files "$FIX" "$FIX/s.md" >/dev/null
check T8d-project-rules-not-user-rules "$rc1|$?" "0|1"
{
  printf '%s/.claude/rules/api.md § Versioning.\n' '~'
  printf '%s/.claude/lib/cc.md § WRITE.\n' "\$HOME"
  printf 'tilde: %s/.claude/rules/api.md § Versioning.\n' '~'
  printf 'braces: %s/.claude/lib/cc.md § WRITE.\n' "\${HOME}"
  printf 'quoted: %s/.claude/lib/cc.md § "WRITE (before the commit)".\n' \
    "\$HOME"
} > "$FIX/h.md"
rows=$(_citers_extract_files "$FIX/h.md" | wc -l)
citers_check_files "$FIX" "$FIX/h.md" >/dev/null
check T8e-home-prefix-maps-to-repo "$rows|$?" "5|0"
printf 'prose: foo-rules/api.md § Versioning\n' > "$FIX/b.md"
check T8g-left-boundary "$(_citers_extract_files "$FIX/b.md")" ""
printf '## Eps\n' > "$FIX/templates/project-rules/t.md"
printf 'tpl: templates/project-rules/t.md § Eps.\n' > "$FIX/t1.md"
printf 'tpl: templates/project-rules/t.md § Zeta.\n' > "$FIX/t2.md"
citers_check_files "$FIX" "$FIX/t1.md" >/dev/null; rc1=$?
citers_check_files "$FIX" "$FIX/t2.md" >/dev/null
check T8h-template-rules-path "$rc1|$?" "0|1"
# the retired design hook's pointer shape: ~ prefix + quoted label
printf '%s\n' '  ~/.claude/rules/web-building.md § "Design work — full toolchain"' > "$FIX/pointer.sh"
check T8i-tilde-quoted-label-whole "$(_citers_extract_files "$FIX/pointer.sh" | cut -d: -f3-)" 'rules/web-building.md:Design work — full toolchain'

# ── real census: the repo's own citers against CLAUDE.global.md ──────────────
# (`impeccabl[e]` is a glob: the pack census must not read it as a citer.)
mapfile -t FILES < <(cd "$ROOT" && find skills agents lib rules hooks -type f \( -name '*.md' -o -name '*.sh' \) \
  -not -path 'skills/graphify/*' -not -path 'skills/impeccabl[e]/*' -not -path 'skills-external/impeccable/*' -not -path 'skills/synced/*' \
  -not -path 'agents/impeccable-*' -not -path 'lib/tests/*' | sort)
# T6 also scans the templates and this repo's own project rules; T3 must not
# (there `CLAUDE.md` means a project CLAUDE.md, not the doctrine).
mapfile -t FILES_ALL < <(cd "$ROOT" && find skills agents lib rules hooks \
  templates .claude/rules -type f \( -name '*.md' -o -name '*.sh' \) \
  -not -path 'skills/graphify/*' -not -path 'skills/impeccabl[e]/*' -not -path 'skills-external/impeccable/*' \
  -not -path 'skills/synced/*' -not -path 'agents/impeccable-*' \
  -not -path 'lib/tests/*' | sort)
# T8f: the T6 list reaches the two blind trees, the T3 list does not
all_hits=$(printf '%s\n' "${FILES_ALL[@]}" | grep -c '^templates/')
rules_hits=$(printf '%s\n' "${FILES_ALL[@]}" | grep -c '^\.claude/rules/')
t3_hits=$(printf '%s\n' "${FILES[@]}" \
  | grep -c -e '^templates/' -e '^\.claude/')
check T8f-scan-lists "$([ "$all_hits" -ge 1 ] && [ "$rules_hits" -ge 1 ] \
  && [ "$t3_hits" -eq 0 ] && echo ok)" ok
out=$(cd "$ROOT" && citers_check CLAUDE.global.md "${FILES[@]}"); rc=$?
[ -n "$out" ] && printf '%s\n' "$out"
check T3-repo-citations-resolve "$rc" 0
out=$(cd "$ROOT" && citers_check_files "$ROOT" "${FILES_ALL[@]}" \
  CLAUDE.global.md); rc=$?
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

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
