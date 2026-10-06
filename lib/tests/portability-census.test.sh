#!/usr/bin/env bash
# lib/tests/portability-census.test.sh — regression guard for GNU-only shell
# idioms that break on macOS (BSD userland). Deterministic idioms only:
#   sed -i with no suffix, stat -c, realpath -m, touch -d, grep -P,
#   a bare /bin/grep (LRN-074: pin /usr/bin/grep).
# Not covered on purpose: `cmd | grep -q` under pipefail (not decidable by
# text; fixed structurally by taking the producer out of the pipe).
# Usage: portability-census.test.sh [file…]
#   no args: flip-test, then scan tracked *.sh + hooks/*
#   args   : scan only those files; exit 2 on any hit
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

RE="sed -i ['\"]|stat -c|realpath -m|touch -d|grep -[A-Za-z]*P([^A-Za-z]|$)"
RE="$RE|(^|[^a-z])/bin/grep"

# file:line (or file:*) exempt from the scan, each with its reason.
ALLOW=(
  "lib/tests/guard-bash.test.sh:221"  # deny fixture: GNU spelling
  "lib/tests/guard-bash.test.sh:225"  # deny fixture: GNU spelling
  "lib/tests/portability-census.test.sh:*"  # spells the idioms
)

_allowed() {
  local entry
  for entry in "${ALLOW[@]}"; do
    entry="${entry%%  #*}"
    [ "$entry" = "$1:$2" ] || [ "$entry" = "$1:*" ] && return 0
  done
  return 1
}

# scan <file>… → prints file:line:text per hit, rc 2 when any
scan() {
  local f rel line lno text hits=0
  for f in "$@"; do
    rel="${f#"$ROOT"/}"
    while IFS= read -r line; do
      lno="${line%%:*}"; text="${line#*:}"
      case "$text" in [[:space:]]*"#"*|"#"*) continue ;; esac
      _allowed "$rel" "$lno" && continue
      printf 'GNU-ONLY: %s:%s:%s\n' "$rel" "$lno" "$text"; hits=$((hits+1))
    done < <(grep -nE -- "$RE" "$f" 2>/dev/null)
  done
  [ "$hits" -eq 0 ] || return 2
}

if [ "$#" -gt 0 ]; then scan "$@"; exit $?; fi

# flip-test: a planted GNU idiom must be caught before the real census runs
PLANT="$(mktemp -d)" || exit 1; trap 'rm -rf "$PLANT"' EXIT
printf '#!/usr/bin/env bash\nsed -i '"'"'s/a/b/'"'"' x\n' > "$PLANT/planted.sh"
scan "$PLANT/planted.sh" >/dev/null; flip=$?
if [ "$flip" -ne 2 ]; then echo "FAIL flip: plant not caught"; exit 1; fi

mapfile -t FILES < <(cd "$ROOT" && git ls-files '*.sh' 'hooks/*' \
  | sed "s#^#$ROOT/#")
scan "${FILES[@]}"; rc=$?
[ "$rc" -eq 0 ] && echo "PASS portability census (${#FILES[@]} files)"
exit "$rc"
