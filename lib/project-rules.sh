#!/usr/bin/env bash
# lib/project-rules.sh — project-scope path rules (.claude/rules/<name>.md),
# BDR-125 phase 0. One deterministic oracle for the make-test suite, the
# /onboard split mode, the onboarder and the scaffolder. Every subcommand
# takes an optional leading `-C <dir>` (a dispatched agent's cwd is the
# session's, never the project's):
#   check [rules-dir]   every path rule parses and every glob matches ≥1
#                       path; rc 2 with the culprit named
#   matches <glob>      rc 0 + the first hits, rc 1 none
#   sections [--depth 2|3] <file>   chars, line, heading per ## section
#                       (--depth 3 adds the ### subsections; a section
#                       ends at the next heading of level ≤ its own)
#   extract <file> <heading> <out> <globs-json>   move one section to a
#                       rule (bare heading = ##; "### title" = a subsection;
#                       a ### moved last keeps its parent's trailing ---)
#   emit <skeleton> <out>   the rule with the matching globs only (rc 1
#                           when none matches, nothing written)
# Globs match the WORKING TREE (compgen -G with globstar and dotglob,
# no brace expansion: one glob per extension; a symlinked dir matches
# when the glob names it, globstar never descends into a symlink met
# under `**`;
# dotglob makes `*` match dotfiles; the engine reaches hidden dirs too. Its
# matcher looks gitignore-style (InstructionsLoaded log, 2026-10-26:
# `paths: ["rules/**"]` logged as `globs: ["rules"]` and loaded on a Read
# of `.claude/rules/*.md`): a trailing `/**` dropped, a pattern without an
# inner `/` matching at any depth. A glob can thus load where this check
# does not look; the load proof is the logged session, not this check),
# dependency dirs excluded (unless the glob names one: `vendor/**` is a
# valid rule): the engine matches the path the model reads,
# tracked or not; a typo matches nothing either way. A frontmatter line
# `# static-check: skip` exempts a rule whose files only exist mid-run. A
# rule without frontmatter or without `paths:` is an always-on rule:
# reported, never failed. No `head` after a producer: an early reader
# gives the writer SIGPIPE (rc 141 under pipefail).

_RULES_DEPS='(^|/)(node_modules|\.venv|venv|vendor|target|dist|build|\.git)/'

_rules_frontmatter() {  # <file> → frontmatter body on stdout, rc 1 if none
  awk 'NR == 1 && $0 != "---" { exit 1 }
       NR > 1 && $0 == "---" { found = 1; exit }
       NR > 1 { print }
       END { exit found ? 0 : 1 }' "$1"
}

# <frontmatter text> → one glob per line. rc 1: no paths: line (always-on);
# rc 2: a paths: value that is not a non-empty JSON array of strings.
_rules_globs() {
  local line arr
  line=$(printf '%s\n' "$1" | grep -E '^paths:') || return 1
  arr=${line#paths:}
  printf '%s' "$arr" \
    | jq -e 'type == "array" and length > 0 and all(type == "string")' \
      >/dev/null 2>&1 || return 2
  printf '%s' "$arr" | jq -r '.[]'
}

_rules_hits() {  # <glob> → matching paths outside dependency dirs, rc 1 none
  case "$1" in  # a glob that names a dependency dir is not filtered
    node_modules/*|.venv/*|venv/*|vendor/*|target/*|dist/*|build/*|.git/*)
      ( shopt -s globstar dotglob; compgen -G "$1" ) 2>/dev/null; return ;;
  esac
  ( shopt -s globstar dotglob; compgen -G "$1" ) 2>/dev/null \
    | grep -Ev "$_RULES_DEPS"
}

_rules_matching() {  # <globs, one per line> → JSON array of the matching ones
  local g out=""
  while IFS= read -r g; do
    [ -n "$g" ] && _rules_hits "$g" >/dev/null && out="$out, \"$g\""
  done <<< "$1"
  [ -n "$out" ] || return 1
  printf '[%s]\n' "${out#, }"
}

_rules_check_file() {  # <rule.md> → rc 0 ok or always-on, rc 1 with culprits
  local fm globs skip=0 g bad=0
  fm=$(_rules_frontmatter "$1") \
    || { echo "$1: always-on (no frontmatter)"; return 0; }
  globs=$(_rules_globs "$fm")
  case $? in
    1) echo "$1: always-on (no paths:)"; return 0 ;;
    2) echo "$1: paths: must be one line:" \
         "paths: [\"a\", \"b\"]"; return 1 ;;
  esac
  printf '%s\n' "$fm" | grep -qx '# static-check: skip' && skip=1
  while IFS= read -r g; do
    if [ "$skip" = 1 ]; then echo "$1: SKIP $g"; continue; fi
    _rules_hits "$g" >/dev/null \
      || { echo "$1: glob matches nothing: $g"; bad=1; }
  done <<< "$globs"
  [ "$bad" = 0 ]
}

project_rules_check() {  # [rules-dir] → rc 0 all ok, rc 2 with culprits named
  local dir="${1:-.claude/rules}" f n=0 bad=0
  [ -d "$dir" ] \
    || { echo "project-rules: 0 rule(s) ok ($dir absent)"; return 0; }
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    n=$((n + 1))
    _rules_check_file "$f" || bad=1
  done
  [ "$bad" = 0 ] || return 2
  echo "project-rules: $n rule(s) ok"
}

project_rules_matches() {  # <glob> → rc 0 + the first 3 hits, rc 1 none
  # awk reads the pipe to its end: a `head` reader would SIGPIPE the
  # producer on any glob with more than a pipe buffer of hits (rc 141).
  _rules_hits "$1" | awk 'NR <= 3 { print } END { exit NR == 0 }' \
    || { echo "no match: $1" >&2; return 1; }
}

project_rules_sections() {  # [--depth 2|3] <file> → chars, line, heading
  local depth=2
  if [ "${1:-}" = "--depth" ]; then depth="${2:-}"; shift 2; fi
  case "$depth" in 2|3) ;; *)
    echo "project-rules: --depth takes 2 or 3" >&2; return 2 ;; esac
  [ $# -eq 1 ] \
    || { echo "project-rules: sections [--depth 2|3] <file>" >&2; return 2; }
  [ -f "$1" ] || { echo "project-rules: $1 not found" >&2; return 2; }
  awk -v depth="$depth" '
    function flush2() {
      if (h2 != "") printf "%d\t%d\t%s\n", c2, l2, h2; h2 = "" }
    function flush3() {
      if (h3 != "") printf "%d\t%d\t%s\n", c3, l3, h3; h3 = "" }
    /^```/ { fence = !fence }
    /^# / && !fence { flush3(); flush2() }
    /^## / && !fence { flush3(); flush2(); h2 = $0; l2 = NR; c2 = 0 }
    /^### / && !fence && depth == 3 { flush3(); h3 = $0; l3 = NR; c3 = 0 }
    h2 != "" { c2 += length($0) + 1 }
    h3 != "" { c3 += length($0) + 1 }
    END { flush3(); flush2() }' "$1" | sort -t "$(printf '\t')" -k2,2n
}

_rules_heading_line() {  # <heading arg> → "## t" | "### t" on stdout, rc 2
  case "$1" in
    '## '*|'### '*) printf '%s\n' "$1" ;;
    '# '*|'####'*)
      echo "project-rules: heading level must be ## or ###: $1" >&2
      return 2 ;;
    *) printf '## %s\n' "$1" ;;
  esac
}

_rules_heading_count() {  # <file> <heading line> → fence-aware count
  awk -v h="$2" '/^```/ { fence = !fence }
                 !fence && $0 == h { n++ }
                 END { print n + 0 }' "$1"
}

_rules_section_body() {  # <file> <heading line> → body, ---/blank trimmed
  awk -v h="$2" '
    BEGIN { lvl = index(h, " ") - 1 }
    /^```/ { fence = !fence }
    !fence && $0 == h { on = 1; next }
    !fence && on && match($0, /^#+ /) && RLENGTH - 1 <= lvl { exit }
    on { buf[++n] = $0 }
    END { while (n > 0 && (buf[n] == "" || buf[n] == "---")) n--
          for (i = 1; i <= n; i++) print buf[i] }' "$1"
}

_rules_without_section() {  # <file> <heading line> → the file minus it
  # a ### ended by a lower-level heading gives its trailing ---/blank run
  # back to the source (the parent's closing separator); a ## keeps today's
  # behaviour, its run travels with it
  awk -v h="$2" '
    BEGIN { lvl = index(h, " ") - 1 }
    /^```/ { fence = !fence }
    !fence && $0 == h { skip = 1; n = 0; next }
    !fence && skip && match($0, /^#+ /) && RLENGTH - 1 <= lvl {
      if (lvl == 3 && RLENGTH - 1 < lvl) for (i = 1; i <= n; i++) print buf[i]
      skip = 0 }
    skip { if ($0 == "" || $0 == "---") buf[++n] = $0; else n = 0; next }
    { print }' "$1"
}

_rules_globs_all_match() {  # <globs-json> → rc 0 valid and every glob matches
  local globs g
  globs=$(_rules_globs "paths: $1") || {
    echo "project-rules: globs must be a JSON array of strings: $1" >&2
    return 1; }
  while IFS= read -r g; do
    _rules_hits "$g" >/dev/null \
      || { echo "project-rules: glob matches nothing: $g" >&2; return 1; }
  done <<< "$globs"
}

_rules_out_path_ok() {  # <out> → rc 2 when absolute, has a .. part, or exists
  # shortcut: lexical only, a symlinked component is not resolved (no
  # portable realpath -m); upgrade = resolve the parent dir with cd -P
  case "$1" in
    /*) echo "project-rules: out must be relative: $1" >&2; return 2 ;;
    ..|../*|*/..|*/../*)
      echo "project-rules: out must not contain ..: $1" >&2; return 2 ;;
  esac
  if [ -e "$1" ] || [ -L "$1" ]; then
    echo "project-rules: $1 exists" >&2; return 2
  fi
}

project_rules_extract() {  # <file> <heading> <out.md> <globs-json>
  local src="$1" out="$3" globs="$4" hline tmp
  hline=$(_rules_heading_line "$2") || return 2
  [ "$(_rules_heading_count "$src" "$hline")" = 1 ] || {
    echo "project-rules: heading must occur exactly once: $hline" >&2
    return 2; }
  _rules_out_path_ok "$out" || return 2
  _rules_globs_all_match "$globs" || return 2
  mkdir -p "$(dirname "$out")" \
    || { echo "project-rules: cannot create $(dirname "$out")" >&2; return 2; }
  tmp=$(mktemp) || { echo "project-rules: no temp file" >&2; return 2; }
  { printf -- '---\npaths: %s\n---\n\n# %s\n' "$globs" "${hline#* }" \
      && _rules_section_body "$src" "$hline"; } > "$out" \
    || { rm -f "$tmp" "$out"
         echo "project-rules: $out not written, $src untouched" >&2
         return 2; }
  if ! { _rules_without_section "$src" "$hline" > "$tmp" \
         && cat "$tmp" > "$src"; }; then
    rm -f "$tmp" "$out"
    echo "project-rules: $src not rewritten, $out removed" >&2
    return 2
  fi
  rm -f "$tmp"
  echo "project-rules: moved '$hline' to $out"
}

project_rules_emit() {  # <skeleton.md> <out.md> → the rule, matching globs only
  local fm globs kept
  fm=$(_rules_frontmatter "$1") \
    || { echo "project-rules: $1: no frontmatter" >&2; return 2; }
  globs=$(_rules_globs "$fm") \
    || { echo "project-rules: $1: no valid paths: array" >&2; return 2; }
  kept=$(_rules_matching "$globs") \
    || { echo "project-rules: $1: no glob matches, not emitted" >&2; return 1; }
  [ -e "$2" ] && { echo "project-rules: $2 exists" >&2; return 2; }
  mkdir -p "$(dirname "$2")"
  { printf -- '---\npaths: %s\n---\n' "$kept"
    awk 'body { print } NR > 1 && $0 == "---" { body = 1 }' "$1"; } > "$2"
  echo "project-rules: emitted $2 paths: $kept"
}

_project_rules_main() {
  set -uo pipefail
  if [ "${1:-}" = "-C" ]; then
    cd "${2:?dir}" 2>/dev/null \
      || { echo "project-rules: no dir $2" >&2; return 2; }
    shift 2
  fi
  case "${1:-}" in
    check)    project_rules_check "${2:-.claude/rules}" ;;
    matches)  project_rules_matches "${2:?glob}" ;;
    sections) project_rules_sections "${@:2}" ;;
    extract)  project_rules_extract "${2:?file}" "${3:?heading}" "${4:?out}" \
                                    "${5:?globs-json}" ;;
    emit)     project_rules_emit "${2:?skeleton}" "${3:?out}" ;;
    *) echo "usage: project-rules.sh [-C dir] check [rules-dir] | matches" \
            "<glob> | sections [--depth 2|3] <file> | extract <file>" \
            "<heading> <out> <globs-json> | emit <skeleton> <out>" >&2
       return 2 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then _project_rules_main "$@"; fi
