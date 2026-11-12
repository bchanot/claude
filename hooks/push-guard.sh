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
# ARGV CHECK: once the text looks like a push, the command is split into
# simple commands (quotes, escapes, `;` `&&` `||` `|` `(` `)` backticks,
# heredoc bodies dropped) and the push must sit in one of them: argv[0] is
# git (or */git) and its first non-option word is push or send-pack. A
# command whose argv[0] is a plain program (grep, cat, echo, sed, rg...) or a
# git subcommand other than push (log -S "git push", config --get
# push.default, add push.sh, help push, stash push, commit -m "git push")
# is proven not a push and allowed. `bash|sh|zsh -c <script>` recurses into
# the script (depth 3). A wrapper (sudo, env, exec, command, eval, xargs,
# timeout, nohup, find, ssh, alias, source, time, git subtree...) or an
# assignment whose value reads as a push keeps the text verdict (deny).
# awk missing, more than 2000 simple commands or a tokenizer failure keep
# the text verdict too (fail closed).
# MISSES: git pu\sh, git $'push', $g push; ~ / $VAR /
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

# Push regexes: strict (full text), loose (quotes removed), alias definition.
STRICT='(^|[^[:alnum:]_.-])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]-][^[:space:]]*)?)*[[:space:]]+(push|send-pack)([^[:alnum:]_-]|$)'
LOOSE='(^|[^[:alnum:]_.-])git[[:space:]]+([^|;&()]*[[:space:]])?(push|send-pack)([^[:alnum:]_-]|$)'
ALIAS_RE='alias\.[^=[:space:]]+=[^[:space:]]*push'

# is_push: the text prefilter; no match anywhere = not a push. The third
# form drops the quote characters only ("git" push, git "push").
is_push() {
  local unq=${one//\"/}; unq=${unq//\'/}
  printf '%s' "$one" | grep -qE "$STRICT" && return 0
  printf '%s' "$unq" | grep -qE "$STRICT" && return 0
  printf '%s' "$bare" | grep -qE "$LOOSE" && return 0
  printf '%s' "$bare" | grep -qE "$ALIAS_RE"
}

# simple_cmds: stdin text -> one simple command per line, words joined by
# \037 (quotes removed, escapes resolved, heredoc bodies dropped). Pure
# awk, never eval'd.
simple_cmds() {
  awk '
  function endword() { if (have) { line = line (nw ? "\037" : "") word; nw++ }
    word = ""; have = 0 }
  function endcmd() { if (nw) print line; line = ""; nw = 0 }
  function skip_heredocs(    k, e, ln) {
    for (k = 1; k <= nh; k++) while (i <= n) {
      e = index(substr(txt, i), "\n")
      if (e == 0) { ln = substr(txt, i); i = n + 1 }
      else { ln = substr(txt, i, e - 1); i += e }
      sub(/^\t+/, "", ln); if (ln == hd[k]) break
    }
    nh = 0 }
  function read_delim(    q, d) {
    if (substr(txt, i, 1) == "-") i++
    while (substr(txt, i, 1) ~ /[ \t]/) i++
    d = ""
    while (i <= n) { c = substr(txt, i, 1)
      if (c ~ /[ \t\n;&|()<>]/) break
      if (c == "\047" || c == "\"") { q = c; i++
        while (i <= n && substr(txt, i, 1) != q) { d = d substr(txt, i, 1); i++ }
        i++; continue }
      if (c == "\\") { d = d substr(txt, i + 1, 1); i += 2; continue }
      d = d c; i++ }
    hd[++nh] = d }
  BEGIN { RS = "\001" }
  { txt = txt $0 }
  END {
    n = length(txt); i = 1; nw = 0; nh = 0; word = ""; have = 0; line = ""
    while (i <= n) { c = substr(txt, i, 1)
      if (c == "\047") { j = index(substr(txt, i + 1), "\047"); have = 1
        if (j == 0) { word = word substr(txt, i + 1); i = n + 1 }
        else { word = word substr(txt, i + 1, j - 1); i += j + 1 }
        continue }
      if (c == "\"") { i++; have = 1
        while (i <= n) { c = substr(txt, i, 1)
          if (c == "\"") { i++; break }
          if (c == "\\" && i < n) { d = substr(txt, i + 1, 1)
            if (d ~ /["\\$`\n]/) { if (d != "\n") word = word d; i += 2; continue } }
          word = word c; i++ }
        continue }
      if (c == "\\") { if (i < n) { d = substr(txt, i + 1, 1)
          if (d != "\n") { word = word d; have = 1 } i += 2 } else i++
        continue }
      if (c == "\n") { endword(); endcmd(); i++
        if (nh) skip_heredocs(); continue }
      if (c == " " || c == "\t") { endword(); i++; continue }
      if (c == "<" && substr(txt, i + 1, 1) == "<" && substr(txt, i + 2, 1) != "<") {
        endword(); i += 2; read_delim(); continue }
      if (c ~ /[;|()`]/) { endword(); endcmd(); i++; continue }
      if (c == "&") { p = i > 1 ? substr(txt, i - 1, 1) : ""; d = substr(txt, i + 1, 1)
        if (p == ">" || p == "<" || d == ">") { word = word c; have = 1; i++; continue }
        endword(); endcmd(); i++; continue }
      word = word c; have = 1; i++ }
    endword(); endcmd() }'
}

# text_push <text>: the text verdict on one simple command (quotes gone).
text_push() { printf '%s' "$1" | grep -qE "$LOOSE|$ALIAS_RE"; }

# git_subcmd <words...>: prints git'"'"'s subcommand (first word after the
# global options; value-taking ones skip their argument).
git_subcmd() {
  local -a a=("$@"); local i=1
  while [ "$i" -lt "${#a[@]}" ]; do
    case "${a[i]}" in
      -C|-c|--git-dir|--work-tree|--namespace|--exec-path|--super-prefix|--config-env|--list-cmds)
        i=$((i + 2)); continue ;;
      -*) i=$((i + 1)); continue ;;
    esac
    printf '%s' "${a[i]}"; return 0
  done
}

# shell_c <depth> <words...>: a shell'"'"'s -c script, re-checked as a command
# of its own; no -c = text verdict.
shell_c() {
  local depth=$1; shift; local -a a=("$@"); local i=1
  while [ "$i" -lt "${#a[@]}" ]; do
    case "${a[i]}" in
      --*) ;;
      -*c*) argv_push "${a[i + 1]:-}" "$((depth + 1))"; return ;;
    esac
    i=$((i + 1))
  done
  text_push "$*"
}

# seg_push <line> <depth>: rc 0 when this simple command is a push or
# cannot be proven otherwise, rc 1 when it is proven not one.
seg_push() {
  local depth=$2 i=0 sub; local -a w
  IFS=$'\037' read -r -a w <<<"$1"
  while [ "$i" -lt "${#w[@]}" ]; do
    case "${w[i]}" in
      '{'|'}'|'!'|if|then|else|elif|fi|do|done|while|until|for|in|case|'esac'|coproc|function|select)
        i=$((i + 1)) ;;
      [A-Za-z_]*=*)
        case "${w[i]%%=*}" in *[!A-Za-z0-9_]*) break ;; esac
        text_push "${w[i]#*=}" && return 0
        i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  [ "$i" -lt "${#w[@]}" ] || return 1
  local -a a=("${w[@]:i}")
  case "${a[0]}" in
    git|*/git)
      sub=$(git_subcmd "${a[@]}")
      case "$sub" in
        push|send-pack) return 0 ;;
        subtree) text_push "${a[*]}"; return ;;
      esac
      printf '%s' "${a[*]}" | grep -qE "$ALIAS_RE" ;;
    bash|sh|zsh|dash|ksh|*/bash|*/sh|*/zsh|*/dash|*/ksh) shell_c "$depth" "${a[@]}" ;;
    eval|exec|command|builtin|env|sudo|doas|nohup|timeout|xargs|nice|ionice|time|stdbuf|script|chroot|ssh|find|watch|parallel|alias|source|.)
      text_push "${a[*]}" ;;
    *) return 1 ;;
  esac
}

# argv_push <text> <depth>: rc 1 only when every simple command of <text>
# is proven not a push; anything unclear keeps the text verdict (rc 0).
argv_push() {
  local text=$1 depth=$2 lines nseg line
  [ "$depth" -le 3 ] || return 0
  lines=$(printf '%s' "$text" | simple_cmds) || return 0
  nseg=$(printf '%s\n' "$lines" | grep -c .)
  [ "$nseg" -le 2000 ] || return 0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    seg_push "$line" "$depth" && return 0
  done <<<"$lines"
  return 1
}

is_push || exit 0
# The text looked like a push: a parsed payload gets the argv check (an
# unparseable one keeps the static deny below).
if [ "$unparsed" = 0 ] && command -v awk >/dev/null 2>&1; then
  argv_push "$cmd" 0 || exit 0
fi

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
