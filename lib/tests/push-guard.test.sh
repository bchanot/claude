#!/usr/bin/env bash
# lib/tests/push-guard.test.sh
# hooks/push-guard.sh (BDR-111): denies `git push` in manual push mode,
# silent otherwise. Also locks the settings.json wiring and the banner line.
set -u
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
H="$ROOT/hooks/push-guard.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

# ── fixtures ──
mkrepo() { mkdir -p "$1" && git init -q "$1"; }
mkdir -p "$WORK/plain"
mkrepo "$WORK/auto"
mkrepo "$WORK/manual"; git -C "$WORK/manual" config gitflow.autopush false
mkdir -p "$WORK/manual/sub" "$WORK/manual/my dir"
mkrepo "$WORK/bad"; git -C "$WORK/bad" config gitflow.autopush flase
mkrepo "$WORK/manual2"; git -C "$WORK/manual2" config gitflow.autopush false
printf '[gitflow]\n\tautopush = false\n' > "$WORK/gconf"
mkdir -p "$WORK/shim"
cat > "$WORK/shim/jq" <<EOF
#!/bin/sh
[ "\$1" = -cn ] && exit 1
exec $(command -v jq) "\$@"
EOF
chmod +x "$WORK/shim/jq"

# ── harness ──
OUT=""; RC=0
run() { # run <cmd> <cwd>
  local payload
  payload=$(jq -n --arg c "$1" --arg d "$2" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},cwd:$d}')
  OUT=$(printf '%s' "$payload" | bash "$H" 2>/dev/null); RC=$?
}
verdict() {
  if [ "$RC" -ne 0 ]; then echo "error:$RC"; return; fi
  if [ -z "$OUT" ]; then echo allow; return; fi
  if [ "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$OUT" 2>/dev/null)" = deny ]
  then echo deny; else echo "error:badjson"; fi
}
fire() { run "$1" "$2"; verdict; }
reason() { jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$OUT"; }

M="$WORK/manual"

# ── auto / none: silent ──
check T1-plain-allow  "$(fire 'git push' "$WORK/plain")" allow
check T2-auto-allow   "$(fire 'git push' "$WORK/auto")" allow
check T3-auto-upstream "$(fire 'git push -u origin feature/x' "$WORK/auto")" allow

# ── manual: deny ──
run 'git push' "$M"
check T4-push "$(verdict)" deny
check T4b-one-line "$(printf '%s' "$OUT" | wc -l | tr -d ' ')" 0
check T5-push-u "$(fire 'git push -u origin feature/x' "$M")" deny
check T6-dash-C "$(fire "git -C \"$M\" push" "$WORK/plain")" deny
check T7-cd-sub "$(fire 'cd sub && git push' "$M")" deny
check T8-dry-run "$(fire 'git push --dry-run' "$M")" deny
check T9-dash-c "$(fire 'git -c a=b push origin HEAD' "$M")" deny
check T10-subshell "$(fire '(cd sub && git push)' "$M")" deny
check T11-bash-c "$(fire "bash -c 'git push'" "$M")" deny
check T12-semicolon "$(fire 'git push; echo done' "$M")" deny
check T13-abs-git "$(fire '/usr/bin/git push' "$M")" deny
check T14-no-pager "$(fire 'git --no-pager push' "$M")" deny
check T15-quoted-dir "$(fire "cd \"$M/my dir\"; git push" "$WORK/plain")" deny
check T16-amp "$(fire 'git push&&echo ok' "$M")" deny
check T17-cd-dashdash "$(fire "cd -- $M && git push" "$WORK/plain")" deny
check T18-backslash-nl "$(fire $'git \\\n  push' "$M")" deny
check T19-pipe "$(fire 'git push|tee /dev/null' "$M")" deny
check T20-subtree "$(fire 'git subtree push --prefix=x origin main' "$M")" deny
check T21-cd-amp "$(fire "(cd $M&&git push)" "$WORK/plain")" deny
check T22-alias "$(fire 'git -c alias.p=push p' "$M")" deny
check T23-send-pack "$(fire 'git send-pack origin' "$M")" deny
check T24-grep-overblock "$(fire 'grep -rn "git push" skills/' "$M")" deny
check T25-config-overblock "$(fire 'git config --get push.default' "$M")" deny

# ── manual: allow ──
check T26-commit-msg "$(fire 'git status && git commit -m "fix push guard"' "$M")" allow
check T27-gitflow "$(fire 'bash ~/.claude/lib/gitflow.sh finish' "$M")" allow
check T28-pushd "$(fire 'git pushd' "$M")" allow
check T29-stash "$(fire 'git stash' "$M")" allow
check T30-echo "$(fire 'echo pushed' "$M")" allow
check T31-rg-C "$(fire 'rg -C 3 push src/' "$M")" allow
check T32-branch "$(fire 'git branch --show-current' "$M")" allow

# ── invalid value: fail closed ──
run 'git push' "$WORK/bad"
check T33-invalid "$(verdict)" deny
R=$(reason)
check T33b-not-boolean "$(grep -c 'not a boolean' <<<"$R")" 1
check T33c-raw-value "$(grep -c 'flase' <<<"$R")" 1

# ── global key ──
g() { # g <cmd> <cwd>: run with the global config pointing at gconf
  local saved=$GIT_CONFIG_GLOBAL
  GIT_CONFIG_GLOBAL="$WORK/gconf"; fire "$1" "$2"
  GIT_CONFIG_GLOBAL=$saved
}
check T34a-global-auto-cwd "$(g 'git push' "$WORK/auto")" deny
check T34b-global-cd "$(g "cd \"$WORK/auto\" && git push" "$WORK/plain")" deny
check T34c-control "$(fire 'git push' "$WORK/auto")" allow

# ── toggle control ──
check T35a-manual2 "$(fire 'git push' "$WORK/manual2")" deny
git -C "$WORK/manual2" config --unset gitflow.autopush
check T35b-unset "$(fire 'git push' "$WORK/manual2")" allow

# ── fail closed on internal error ──
# T36: a jq shim that fails on `jq -cn` makes the guard's deny path error.
saved_path=$PATH; PATH="$WORK/shim:$PATH"
run 'git push' "$M"
PATH=$saved_path
check T36-static-deny "$(verdict)" deny
check T36b-internal "$(grep -c 'internal error' <<<"$(reason)")" 1
check T36c-rc "$RC" 0
run 'git push' "$M"
R=$(reason)
check T37a-bang "$(grep -c '! git push' <<<"$R")" 1
check T37b-mode "$(grep -c 'manual push mode' <<<"$R")" 1

# T47: jq absent from PATH: guard warns on stderr and stays inactive.
mkdir -p "$WORK/nojq"
for tool in bash cat git grep sed tr dirname basename mktemp; do
  real=$(command -v "$tool") || continue
  case "$real" in /*) ln -sf "$real" "$WORK/nojq/$tool" ;; esac
done
payload47=$(jq -n --arg c 'git push' --arg d "$M" \
  '{tool_input:{command:$c},cwd:$d}')
out47=$(cd "$M" && printf '%s' "$payload47" \
  | PATH="$WORK/nojq" "$(command -v bash)" "$H" 2>"$WORK/nojq.err"); rc47=$?
check T47a-rc "$rc47" 0
check T47b-stdout-empty "$out47" ""
check T47c-warn "$(grep -c 'jq missing' "$WORK/nojq.err")" 1

# ── payload edge cases ──
run_empty=$(printf '{}' | bash "$H" 2>/dev/null); rc=$?
check T38-empty-stdout "$run_empty" ""
check T38b-rc "$rc" 0
nocwd=$(jq -n '{tool_input:{command:"git push"}}')
out=$(cd "$M" && printf '%s' "$nocwd" | bash "$H" 2>/dev/null)
check T39-no-cwd "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$out")" deny

# ── hardening: candidate cap, git failure, quote-prefixed cd ──
cmd48=""; for i in $(seq 1 25); do cmd48="${cmd48}cd /x$i;"; done
run "$cmd48 git push" "$WORK/auto"
check T48-cap-deny "$(verdict)" deny
check T48-cap-reason "$(grep -c 'too many directory tokens' <<<"$(reason)")" 1
cmd48b=""; for i in 1 2 3 4 5; do cmd48b="${cmd48b}cd \"$M\";"; done
run "$cmd48b git push" "$WORK/plain"
check T48b-dedup-detect "$(verdict)" deny
check T48b-manual-reason "$(grep -c 'manual push mode' <<<"$(reason)")" 1

# T49: git absent from PATH: the mode cannot be read, so deny (fail closed).
mkdir -p "$WORK/nogit"
for tool in bash cat grep sed tr jq dirname basename mktemp head sort wc; do
  real=$(command -v "$tool") || continue
  case "$real" in /*) ln -sf "$real" "$WORK/nogit/$tool" ;; esac
done
payload49=$(jq -n --arg c 'git push' --arg d "$M" \
  '{tool_input:{command:$c},cwd:$d}')
out49=$(printf '%s' "$payload49" | PATH="$WORK/nogit" "$(command -v bash)" "$H" 2>/dev/null); rc49=$?
check T49-rc "$rc49" 0
check T49-deny "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$out49")" deny
check T49-reason "$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$out49" | grep -cE 'git|internal error')" 1

# T49b: an existing but unenterable candidate dir fails closed.
mkdir -p "$WORK/locked"; chmod 000 "$WORK/locked"
if [ -r "$WORK/locked" ] || (cd "$WORK/locked" 2>/dev/null); then
  echo "SKIP T49b-unreadable (chmod 000 ineffective for this user)"
else
  check T49b-unreadable "$(fire "cd \"$WORK/locked\" && git push" "$WORK/plain")" deny
fi
chmod 755 "$WORK/locked"

# T50: a cd that follows a quote is still extracted.
check T50-bash-c-cd "$(fire "bash -c 'cd \"$M\" && git push'" "$WORK/plain")" deny
check T50b-unquoted-arg "$(fire "bash -c 'cd $M && git push'" "$WORK/plain")" deny

# ── settings.json wiring (file content only) ──
S="$ROOT/settings.json"
check T40-wiring "$(jq -e '.hooks.PreToolUse[]
  | select(any(.hooks[]; .command=="bash ~/.claude/hooks/push-guard.sh"))
  | .matcher=="Bash|Monitor" and .hooks[0].timeout==10' "$S" 2>&1)" true

has_deny() { jq -e --arg e "$1" '.permissions.deny | index($e)' "$S" >/dev/null; }
missing=""
while IFS= read -r e; do
  has_deny "$e" || missing="$missing [$e]"
done <<'EOF'
Bash(git *config *gitflow.*)
Bash(git *config *remove-section*gitflow*)
Bash(git *config *rename-section*gitflow*)
Bash(git -c gitflow.*)
Bash(git * -c gitflow.*)
Bash(*--config-env*gitflow*)
Bash(*GIT_CONFIG_PARAMETERS*)
Bash(*GIT_CONFIG_COUNT*)
Bash(* GIT_CONFIG_GLOBAL=*)
Bash(* GIT_CONFIG_SYSTEM=*)
Edit(**/.git/config)
Write(**/.git/config)
Edit(**/.gitconfig)
Write(**/.gitconfig)
Edit(~/.gitconfig)
Write(~/.gitconfig)
Edit(~/.config/git/config)
Write(~/.config/git/config)
EOF
check T41-new-deny-present "$missing" ""

# Nothing removed: every deny entry of the pre-run-B settings is still there.
base=HEAD
lost=$(git -C "$ROOT" show "$base:settings.json" 2>/dev/null \
  | jq -r --slurpfile now "$S" \
    '.permissions.deny[] | select(. as $e | ($now[0].permissions.deny | index($e)) == null)')
check T42-nothing-removed "$lost" ""

soft=$(jq -r '.autoMode.soft_deny[]' "$S")
check T43a-soft-rule "$(grep -c 'manual-push mode' <<<"$soft" | tr -d ' ')" 1
check T43b-clearance "$(grep -c "does not clear it: the user types \`! git push\`" <<<"$soft")" 1

# ── session banner ──
banner() { # banner <dir>
  (cd "$1" && SESSION_START_OFFLINE=1 bash "$ROOT/hooks/session-start.sh" \
    </dev/null 2>/dev/null)
}
out=$(banner "$M")
check T44-banner-control "$(grep -c 'Claude Code config' <<<"$out")" 1
check T45-banner-manual "$(grep -c 'push : manual (autopush=false)' <<<"$out")" 1
out=$(banner "$WORK/auto")
check T46a-auto-control "$(grep -c 'Claude Code config' <<<"$out")" 1
check T46b-auto-silent "$(grep -c 'push : manual' <<<"$out")" 0

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
