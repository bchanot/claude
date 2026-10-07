#!/usr/bin/env bash
# push-guard.sh — PreToolUse (Bash|Monitor): refuse `git push` in manual
# push mode (BDR-111). Manual mode = `gitflow.autopush` reads false (or is
# unparseable or unreadable: fail closed) in the payload cwd or in any literal -C / cd dir
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
# MISSES: "git" push, git "push", git pu\sh, git $'push', $g push; ~ / $VAR /
# $(...) in -C or cd (never resolved, never eval'd); --git-dir / GIT_DIR; a
# push hidden in a script, Makefile target, user alias or an alias planted
# by a redirect into .git/config; cumulative relative `cd a && cd b` (each
# dir is resolved from cwd, not from the previous cd). LIMITS: more than 20
# distinct cd/-C dir tokens in one command is refused outright. The
# soft_deny rule covers every miss above.
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
# A quote or backtick may precede the command word (bash -c 'cd d && ...').
arg_tokens() {
  local pre='[[:space:];&|()"'"'"'`]'
  local arg='(--[[:space:]]+)?("[^"]*"|'"'[^']*'"'|[^[:space:];&|()"'"'"'`]+)'
  {
    printf '%s' "$one" | grep -oE "(^|$pre)(cd|pushd)[[:space:]]+$arg"
    printf '%s' "$one" | grep -oE "(^|$pre)-C[[:space:]]+$arg"
  } | sed -E "s/^$pre*(cd|pushd|-C)[[:space:]]+(--[[:space:]]+)?//"
}

# resolve_dir <tok>: absolute dir for a literal token, from cwd. A missing
# dir yields nothing (skipped); an existing but unenterable one yields its
# path so mode_in fails closed on it.
resolve_dir() {
  (
    cd -- "$cwd" 2>/dev/null || exit 1
    [ -d "$1" ] || exit 1
    if cd -- "$1" 2>/dev/null; then pwd -P; exit 0; fi
    case "$1" in /*) printf '%s\n' "$1" ;; *) printf '%s/%s\n' "$PWD" "$1" ;; esac
  )
}

# candidates: cwd, then each distinct literal dir of $tokens, deduplicated
# after resolution (unresolvable ones are skipped, never an allow).
candidates() {
  local tok
  printf '%s\n' "$cwd"
  printf '%s\n' "$tokens" | while IFS= read -r tok; do
    tok=$(unquote "$tok")
    case "$tok" in ''|-) continue ;; esac
    resolve_dir "$tok"
  done | sort -u
}

# mode_in <dir>: prints `manual`, `auto` (key unset or true),
# `invalid:<raw>` (not a boolean) or `failed:<what>` (git or cd failed).
mode_in() {
  (
    cd -- "$1" 2>/dev/null || { echo "failed:cannot enter the directory"; exit 0; }
    val=$(git config --bool gitflow.autopush 2>/dev/null); rc=$?
    case "$rc" in
      0) if [ "$val" = false ]; then echo manual; else echo auto; fi ;;
      1) echo auto ;;
      *) raw=$(git config gitflow.autopush 2>/dev/null)
         if [ -n "$raw" ]; then echo "invalid:$raw"
         else echo "failed:git exited $rc"; fi ;;
    esac
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

# Cap the distinct dir tokens before resolving any (hook timeout is 10 s).
tokens=$(arg_tokens | sort -u)
ntok=$(printf '%s\n' "$tokens" | grep -c .)
if [ "$ntok" -gt 20 ]; then
  deny "push-guard: too many directory tokens in one command ($ntok > 20) — push refused (fail closed). Split the command, or run it yourself: ! $cmd"
fi

evaluated=0
while IFS= read -r dir; do
  mode=$(mode_in "$dir" | head -n 1)
  case "$mode" in
    manual)
      deny "push-guard: manual push mode (gitflow.autopush=false in $dir) — Claude never pushes. Run it yourself in the terminal: ! $cmd" ;;
    invalid:*)
      deny "push-guard: gitflow.autopush='${mode#invalid:}' is not a boolean in $dir — treated as manual push mode (fail closed). Fix the value by hand, or run it yourself: ! $cmd" ;;
    failed:*)
      deny "push-guard: could not read gitflow.autopush in $dir (${mode#failed:}) — git failed, push refused (fail closed). Run it yourself in the terminal: ! $cmd" ;;
    auto) evaluated=$((evaluated + 1)) ;;
  esac
done < <(candidates)

# Zero cleanly evaluated candidates: leave decided=0, the EXIT trap denies.
[ "$evaluated" -gt 0 ] && decided=1
exit 0
