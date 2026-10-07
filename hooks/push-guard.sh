#!/usr/bin/env bash
# push-guard.sh — PreToolUse (Bash|Monitor): refuse `git push` in manual
# push mode (BDR-111). Manual mode = `gitflow.autopush` reads false (or is
# unparseable: fail closed) in the payload cwd or in any literal -C / cd dir
# the command names; outside a repo `git config` reads global/system.
#
# Deny form: JSON on stdout, exit 0 (hookSpecificOutput.permissionDecision
# = "deny"). Silent in auto mode and on every non-push command. The guard
# sees the command TEXT only. Once a push is detected an EXIT trap emits a
# static deny (exit 0) unless a decision was recorded: internal error =
# push refused. jq missing: one stderr warning, allow (sibling hooks).
#
# OVER-BLOCKS in manual mode: any text carrying a later ` push` word after
# a `git` token (git subtree push, git stash push, git log -S "git push",
# grep -rn "git push" skills/, git config --get push.default, git add
# push.sh, git help push, a commit message quoting "git push").
# MISSES: "git" push, git "push"; ~ / $VAR / $(...) in -C or cd (never
# resolved, never eval'd); --git-dir / GIT_DIR; a push hidden in a script,
# Makefile target or user alias (the soft_deny rule covers those).
set -u
unset CDPATH

if ! command -v jq >/dev/null 2>&1; then
  echo "push-guard: jq missing, guard inactive" >&2
  exit 0
fi

payload=$(cat 2>/dev/null)
field() { printf '%s' "$payload" | jq -r "$1 // empty" 2>/dev/null; }
cmd=$(field '.tool_input.command')
cwd=$(field '.cwd')
[ -n "$cmd" ] || exit 0
[ -d "$cwd" ] || cwd=$PWD

# Fold line breaks (backslash-newline first), then drop quoted spans.
one=${cmd//$'\\\n'/ }
one=${one//$'\n'/ }
bare=$(printf '%s' "$one" | sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g")

# is_push: strict (full text), loose (quotes removed), alias definition.
is_push() {
  local strict loose alias_re
  strict='(^|[^[:alnum:]_.-])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]-][^[:space:]]*)?)*[[:space:]]+(push|send-pack)([^[:alnum:]_-]|$)'
  loose='(^|[^[:alnum:]_.-])git[[:space:]]+([^|;&()]*[[:space:]])?(push|send-pack)([^[:alnum:]_-]|$)'
  alias_re='alias\.[^=[:space:]]+=[^[:space:]]*push'
  printf '%s' "$one" | grep -qE "$strict" && return 0
  printf '%s' "$bare" | grep -qE "$loose" && return 0
  printf '%s' "$bare" | grep -qE "$alias_re"
}

is_push || exit 0

# static_deny: the fixed fail-closed answer (no jq needed to build it).
static_deny() {
  printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"push-guard: internal error while checking manual push mode — push refused (fail closed). Run it yourself in the terminal with !"}}'
}
decided=0
trap '[ "$decided" = 1 ] || static_deny; exit 0' EXIT

# unquote <tok>: strip one pair of surrounding quotes.
unquote() {
  local t=$1
  case "$t" in
    \"*\") t=${t#\"}; t=${t%\"} ;;
    \'*\') t=${t#\'}; t=${t%\'} ;;
  esac
  printf '%s' "$t"
}

# arg_tokens: the directory argument of every `cd`/`pushd`/`-C` in the text.
arg_tokens() {
  local arg='(--[[:space:]]+)?("[^"]*"|'"'[^']*'"'|[^[:space:];&|()]+)'
  {
    printf '%s' "$one" | grep -oE "(^|[[:space:];&|()])(cd|pushd)[[:space:]]+$arg"
    printf '%s' "$one" | grep -oE "(^|[[:space:]])-C[[:space:]]+$arg"
  } | sed -E 's/^[[:space:];&|()]*(cd|pushd|-C)[[:space:]]+(--[[:space:]]+)?//'
}

# candidates: cwd, then each literal dir the command names (resolved from
# cwd; unresolvable ones are skipped, never an allow).
candidates() {
  local tok dir
  printf '%s\n' "$cwd"
  arg_tokens | while IFS= read -r tok; do
    tok=$(unquote "$tok")
    case "$tok" in ''|-) continue ;; esac
    dir=$( cd -- "$cwd" && cd -- "$tok" 2>/dev/null && pwd -P ) || continue
    printf '%s\n' "$dir"
  done
}

# mode_in <dir>: prints `manual`, `invalid:<raw>` or nothing.
mode_in() {
  (
    cd -- "$1" || exit 0
    raw=$(git config gitflow.autopush 2>/dev/null)
    val=$(git config --bool --default true gitflow.autopush 2>/dev/null)
    [ "$val" = false ] && echo manual
    [ -n "$raw" ] && ! git config --bool gitflow.autopush >/dev/null 2>&1 \
      && echo "invalid:$raw"
    exit 0
  )
}

# deny <reason>: emit the deny JSON, record the decision.
deny() {
  local out
  out=$(jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}') || out=$(static_deny)
  printf '%s' "$out"
  decided=1
  exit 0
}

while IFS= read -r dir; do
  mode=$(mode_in "$dir" | head -n 1)
  case "$mode" in
    manual)
      deny "push-guard: manual push mode (gitflow.autopush=false in $dir) — Claude never pushes. Run it yourself in the terminal: ! $cmd" ;;
    invalid:*)
      deny "push-guard: gitflow.autopush='${mode#invalid:}' is not a boolean in $dir — treated as manual push mode (fail closed). Fix the value by hand, or run it yourself: ! $cmd" ;;
  esac
done < <(candidates)

decided=1
exit 0
