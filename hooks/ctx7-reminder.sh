#!/usr/bin/env bash
# ctx7-reminder.sh
#
# UserPromptSubmit hook. When the current project uses fast-moving libs
# (lib/fast-libs.sh) it injects ONE reminder per session to consult ctx7
# (find-docs skill) before coding against their APIs, pointing at the
# .ctx7-cache/ state. Closes the ad-hoc-coding gap: find-docs' description
# fires on doc *questions* and ship-feature/init-project pre-fetch, but
# nothing covered a plain "add a useEffect here" prompt (BDR-078; second
# deliberate ctx7 surface, scoped refinement of BDR-053 single-surface).
#
# Soft nudge: always exits 0, never blocks. Stable-tech projects (no
# manifest, or no fast-lib match) stay silent.

set -euo pipefail

input="$(cat)"

field() { # $1=json key — extracted from hook stdin, empty on failure
  printf '%s' "$input" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('$1',''))" \
    2>/dev/null || true
}

prompt="$(field prompt)"
case "$prompt" in
  '<task-notification>'*) exit 0 ;; # harness turn, not a user request
esac

cwd="$(field cwd)"
[ -n "$cwd" ] || cwd="$PWD"

# Cheap bail-out before any lib work: no manifest → no fast-libs.
[ -f "$cwd/package.json" ] || [ -f "$cwd/requirements.txt" ] \
  || [ -f "$cwd/pyproject.toml" ] || exit 0

# One fire per session: the doctrine holds for the whole session,
# repeating it on every prompt would be token spam.
session_id="$(field session_id)"
sentinel="${TMPDIR:-/tmp}/.ctx7-reminder-${session_id:-nosession}"
[ -e "$sentinel" ] && exit 0

# Resolve the lib next to this hook (repo layout), fall back to the
# installed copy — both paths exist through the link.sh symlinks.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
libsh="${script_dir}/../lib/fast-libs.sh"
[ -f "$libsh" ] || libsh="${HOME}/.claude/lib/fast-libs.sh"
[ -f "$libsh" ] || exit 0

libs="$(bash "$libsh" detect "$cwd" 2>/dev/null || true)"
[ -n "$libs" ] || exit 0

status="$(bash "$libsh" cache-status "$cwd" 2>/dev/null || true)"
: > "$sentinel" || true
list="$(printf '%s' "$libs" | tr '\n' ' ' | sed 's/ *$//')"

if [ "$status" = "fresh" ]; then
  printf '📚 Fast-moving libs in this project (%s) — fresh .ctx7-cache/ present: read the matching cache file before relying on their APIs.\n' "$list"
else
  printf '📚 Fast-moving libs in this project (%s) — .ctx7-cache/ %s: consult ctx7 (find-docs skill) before writing code against their APIs. Stable techs need nothing.\n' "$list" "${status:-missing}"
fi

exit 0
