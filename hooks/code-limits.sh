#!/usr/bin/env bash
# code-limits.sh — PostToolUse (Edit|Write): the lines a file gained over 80
# columns, in OUR code only (lib/code-origin.sh), once per file per session,
# as additionalContext. A signal, never a gate: every failure exits 0 with
# no output (BDR-083, BDR-087, BDR-037).
set -u
export LC_ALL=C.UTF-8 # gawk length() and ${#} count characters (LRN-033)
exec 2>/dev/null # a hook never writes to stderr
LIMIT=80
CAP=5
MAX_BYTES=524288
EXT_RE='\.(sh|bash|ts|js|mjs|py|rs|jq)$'
SID_RE='^[A-Za-z0-9_-]+$'
LIB="$(cd "$(dirname "$(readlink -f "$0")")/../lib" 2>/dev/null && pwd)"

field() { printf '%s' "$PAYLOAD" | jq -r "$1 // empty" 2>/dev/null; }

hash16() { # hash16 <text> -> 16 hex chars, empty when no hasher exists
  local h
  h="$(printf '%s' "$1" | { sha256sum 2>/dev/null \
    || shasum -a 256 2>/dev/null; } | cut -c1-16)"
  printf '%s' "$h"
}

is_ours() { # is_ours <file> <state dir>: origin cached per repo
  local repo key line
  repo="$(git -C "$(dirname "$1")" rev-parse --show-toplevel 2>/dev/null)" \
    || return 1
  key="$2/origin-$(hash16 "$repo")"
  if [ -s "$key" ]; then line="$(cat "$key")"
  else
    line="$(bash "$LIB/code-origin.sh" "$repo" 2>/dev/null)"
    case "$line" in *"no commit"*) ;; *) printf '%s\n' "$line" > "$key" ;;
    esac
  fi
  [ "${line%% *}" = ours ]
}

numbered_added() { # numbered_added <file> -> "<line no>\t<text>" per add
  local dir; dir="$(dirname "$1")"
  if git -C "$dir" ls-files --error-unmatch -- "$1" >/dev/null 2>&1; then
    git -C "$dir" diff --no-ext-diff --no-textconv --no-color -U0 -- "$1" \
      | awk '/^@@/ { split($3, a, ","); n = substr(a[1], 2); next }
             /^\+\+\+ / { next }
             /^\+/ { print n "\t" substr($0, 2); n++ }'
  else
    field '.tool_input.content // .tool_input.new_string' \
      | awk '{ print (ENVIRON["CL_EDIT"] ? "?" : NR) "\t" $0 }'
  fi
}

over_lines() { # over_lines <file> -> "<line no>:<width>" per long add
  local rec n line
  while IFS= read -r rec; do
    n="${rec%%$'\t'*}"; line="${rec#*$'\t'}"
    [ "${#line}" -gt "$LIMIT" ] || continue
    printf '%s:%s\n' "$n" "${#line}"
  done < <(numbered_added "$1")
}

report() { # report <file> <hits>
  local n list
  n="$(printf '%s\n' "$2" | wc -l | tr -d ' ')"
  list="$(printf '%s\n' "$2" | head -"$CAP" \
    | sed -E 's/^([^:]*):(.*)$/L\1 (\2)/' | paste -sd, - | sed 's/,/, /g')"
  jq -cn --arg c "code-limits: $1 has $n added line(s) over $LIMIT \
columns: $list; our code keeps $LIMIT (CLAUDE.md Limits)." \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
}

physical_path() { # physical_path <file>: dir symlinks resolved (BSD-safe)
  local dir; dir="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" || return 1
  printf '%s/%s' "$dir" "$(basename "$1")"
}

checkable() { # checkable <file> <session>: worth reading at all
  [[ "$1" =~ $EXT_RE ]] && [[ "$2" =~ $SID_RE ]] && [ -f "$1" ] \
    && [ "$(wc -c < "$1")" -le "$MAX_BYTES" ]
}

main() {
  command -v jq >/dev/null 2>&1 || return 0
  PAYLOAD="$(head -c "$MAX_BYTES")"
  local file sid dir mark hits
  file="$(field .tool_input.file_path)"; sid="$(field .session_id)"
  checkable "$file" "$sid" || return 0
  file="$(physical_path "$file")" || return 0
  [ -n "$(field .tool_input.new_string)" ] && export CL_EDIT=1
  dir="${TMPDIR:-/tmp}/claude-code-limits-$sid"
  mark="$dir/$(hash16 "$file")"
  [ "$mark" != "$dir/" ] || return 0
  # mkdir success is atomic proof the dir is ours; else accept only an
  # owned 700 dir (find does not follow a symlink operand)
  mkdir -m 700 "$dir" 2>/dev/null || [ -n "$(find "$dir" -maxdepth 0 \
    -type d -user "$(id -u)" -perm 700 2>/dev/null)" ] || return 0
  [ -e "$mark" ] && return 0
  is_ours "$file" "$dir" || return 0
  hits="$(over_lines "$file")"
  [ -n "$hits" ] || return 0
  : > "$mark"
  report "$file" "$hits"
}

main 2>/dev/null
exit 0
