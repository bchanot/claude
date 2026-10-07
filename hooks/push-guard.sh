#!/usr/bin/env bash
# push-guard.sh — PreToolUse (Bash|Monitor): refuse `git push` in manual
# push mode (BDR-111). Manual mode = `gitflow.autopush` reads false (or is
# unparseable or unreadable: fail closed) in the payload cwd or in any literal -C / cd dir
# the command names; outside a repo `git config` reads global/system. The
# mode is read by the sourced lib verb gitflow_push_mode (single reader).
#
# Deny form: JSON on stdout, exit 0 (hookSpecificOutput.permissionDecision
# = "deny"). Silent in auto mode and on every non-push command. The guard
# sees the command TEXT only. Once a push is detected an EXIT trap emits a
# static deny (exit 0) unless a decision was recorded: internal error =
# push refused. jq, cat, grep, sed, sort or head missing: one stderr
# warning, allow (sibling hooks; PATH is not command-controlled).
#
# DENIED beyond a manual-mode push: a cd/-C dir token mixing quoted and
# unquoted parts ("/m"/x"/y", a/'../b'); a cd argument touching a closing
# quote followed by another quote on the line (bash -c 'cd /x' && bash -c
# 'git push' reads as one mixed token, accepted, fail closed); a payload jq
# cannot parse whose raw text (JSON escapes folded) looks like a push: static
# deny, mode-blind, so a description naming a push also denies there.
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

# Absolute lib path, before anything else; sourced once (functions only).
_src=${BASH_SOURCE[0]}
case "$_src" in */*) _dir=${_src%/*} ;; *) _dir=. ;; esac
LIB="$(cd -P "$_dir/../lib" 2>/dev/null && pwd)/gitflow.sh"
# shellcheck source=/dev/null
if [ -r "$LIB" ]; then . "$LIB"; LIB_OK=1; else LIB_OK=0; fi

if ! command -v jq >/dev/null 2>&1; then
  echo "push-guard: jq missing, guard inactive" >&2
  exit 0
fi
for t in cat grep sed sort head; do
  command -v "$t" >/dev/null 2>&1 || {
    echo "push-guard: $t missing, guard inactive" >&2
    exit 0
  }
done

payload=$(cat 2>/dev/null)
field() { printf '%s' "$payload" | jq -r "$1 // empty" 2>/dev/null; }
# jq's rc is field's rc: a payload that does not parse becomes the text to scan.
unparsed=0
cmd=$(field '.tool_input.command') || { cmd=$payload; unparsed=1; }
cwd=$(field '.cwd')
[ -n "$cmd" ] || exit 0
[ -d "$cwd" ] || cwd=$PWD

# Fold line breaks (backslash-newline first), then drop quoted spans.
one=${cmd//$'\\\n'/ }
one=${one//$'\n'/ }
if [ "$unparsed" = 1 ]; then
  one=${one//\\n/ }; one=${one//\\r/ }; one=${one//\\t/ }; one=${one//\\\\/ }
fi
bare=$(printf '%s' "$one" | sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g")
# JSON quotes are syntax, not shell quoting: keep them for the loose regexes.
[ "$unparsed" = 1 ] && bare=$one

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
# Unparseable payload that looks like a push: the trap answers (mode-blind).
[ "$unparsed" = 1 ] && exit 0

# classify_tok <raw>: prints the literal dir of a raw dir token, rc 1 when it
# mixes quoted and unquoted parts. A token enclosed in one quote pair is
# stripped (the other quote kind inside is fine); backslashes of an unquoted
# token are unescaped (a\ b -> a b), deterministic, never eval'd.
classify_tok() {
  local t=$1 q=
  case "$t" in
    \"*\") q='"' ;;
    \'*\') q="'" ;;
  esac
  if [ -n "$q" ]; then
    t=${t#"$q"}; t=${t%"$q"}
    case "$t" in *"$q"*) return 1 ;; esac
    printf '%s' "$t"
    return 0
  fi
  case "$t" in *\"*|*\'*) return 1 ;; esac
  printf '%s' "$t" | sed -E 's/\\(.)/\1/g'
}

# arg_tokens: the directory argument of every `cd`/`pushd`/`-C` in the text,
# one shell word each (adjacent quoted and unquoted segments, \x escapes).
# A quote or backtick may precede the command word (bash -c 'cd d && ...').
arg_tokens() {
  local pre='[[:space:];&|()"'"'"'`]'
  local arg='(--[[:space:]]+)?((\\.|"[^"]*"|'"'[^']*'"'|[^[:space:];&|()"'"'"'`\\]+)+)'
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

# candidates: cwd, then each distinct literal dir of $literals, deduplicated
# after resolution (unresolvable ones are skipped, never an allow).
candidates() {
  local tok
  printf '%s\n' "$cwd"
  printf '%s\n' "$literals" | while IFS= read -r tok; do
    case "$tok" in ''|-) continue ;; esac
    resolve_dir "$tok"
  done | sort -u
}

# mode_in <dir>: prints `manual`, `auto` (key unset or true),
# `invalid:<why>` (not a boolean, unreadable) or `failed:<what>`.
mode_in() {
  (
    cd -- "$1" 2>/dev/null || { echo "failed:cannot enter the directory"; exit 0; }
    [ "$LIB_OK" = 1 ] || { echo "failed:gitflow lib missing"; exit 0; }
    out=$(gitflow_push_mode 2>&1); m=${out##*$'\n'}
    why=$(printf '%s\n' "$out" | grep -m1 '^gitflow.sh push-mode: ' \
      | sed 's/^gitflow.sh push-mode: //')
    case "$m" in
      manual|auto) echo "$m" ;;
      invalid) echo "invalid:${why:-unreadable}" ;;
      *) echo "$m" ;;
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

# literal_dirs: fills $literals from $tokens; a mixed token denies, naming
# it. Runs in the main shell (deny must end the hook, not a subshell).
literal_dirs() {
  local raw lit
  literals=""
  while IFS= read -r raw; do
    [ -n "$raw" ] || continue
    lit=$(classify_tok "$raw") || deny "push-guard: directory token $raw mixes quoted and unquoted parts — this guard refuses to interpolate it (fail closed). Quote the whole path, or run it yourself: ! $cmd"
    literals="$literals$lit"$'\n'
  done <<<"$tokens"
}

# Cap the distinct dir tokens before resolving or classifying any (hook
# timeout is 10 s).
tokens=$(arg_tokens | sort -u)
ntok=$(printf '%s\n' "$tokens" | grep -c .)
if [ "$ntok" -gt 20 ]; then
  deny "push-guard: too many directory tokens in one command ($ntok > 20) — push refused (fail closed). Split the command, or run it yourself: ! $cmd"
fi
literal_dirs

evaluated=0
while IFS= read -r dir; do
  mode=$(mode_in "$dir" | head -n 1)
  case "$mode" in
    manual)
      deny "push-guard: manual push mode (gitflow.autopush=false in $dir) — Claude never pushes. Run it yourself in the terminal: ! $cmd" ;;
    invalid:*)
      deny "push-guard: ${mode#invalid:} in $dir — treated as manual push mode (fail closed). Fix the value by hand, or run it yourself: ! $cmd" ;;
    failed:*)
      deny "push-guard: push mode unreadable in $dir (${mode#failed:}) — push refused (fail closed). Run it yourself: ! $cmd" ;;
    auto) evaluated=$((evaluated + 1)) ;;
    *)
      deny "push-guard: unexpected push mode '$mode' in $dir — push refused (fail closed). Run it yourself: ! $cmd" ;;
  esac
done < <(candidates)

# Zero cleanly evaluated candidates: leave decided=0, the EXIT trap denies.
[ "$evaluated" -gt 0 ] && decided=1
exit 0
