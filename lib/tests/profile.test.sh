#!/usr/bin/env bash
# lib/tests/profile.test.sh — lib/profile.sh + lib/profile-state.jq on a
# fixture repo: fragments, the four precedence levels, the deniedMcpServers
# union, set/unset/enable/disable merge semantics, refusals (rc 2, nothing
# written), the /mcp toggle, root walk-up, timing. Hermetic:
# PROFILE_REPO_OVERRIDE + PROFILE_USER_SETTINGS + PROFILE_CLAUDE_JSON, no claude.
set -u
unset CLAUDE_PROFILE CLAUDE_PROFILE_SETTINGS
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
check_has() { case "$2" in *"$3"*) pass=$((pass+1));; *) fail=$((fail+1));
  printf 'FAIL %s: [%s] does not contain [%s]\n' "$1" "$2" "$3";; esac; }

FX="$(mktemp -d)"; trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/lib/profiles" "$FX/skills" "$FX/proj/.claude" "$FX/proj/sub/deeper" "$FX/home" "$FX/nowhere"
mk_pack() { mkdir -p "$FX/skills/pack-$1/.claude-plugin"
  printf '{"name":"pack-%s","defaultEnabled":%s}\n' "$1" "$2" > "$FX/skills/pack-$1/.claude-plugin/plugin.json"; }
mk_pack a true; mk_pack b false   # pack-c has no dir (missing)
frag() { # name pack-a pack-b pack-c ui deny(yes|no) [model]
  local d="" m=""
  [ "$6" = yes ] && d=', "deniedMcpServers": [{"serverName": "claude.ai X"}, {"serverName": "claude.ai Y"}]'
  [ -n "${7:-}" ] && m=", \"model\": \"$7\""
  printf '{"enabledPlugins": {"model-router@skills-dir": true, "pack-a@skills-dir": %s, "pack-b@skills-dir": %s, "pack-c@skills-dir": %s, "ui@mk": %s}%s%s}\n' \
    "$2" "$3" "$4" "$5" "$d" "$m" > "$FX/lib/profiles/$1.json"; }
frag fullx true false false true no      # = manifest defaults + user ui on
frag devx true false false false yes
frag minix false false false false yes haiku
printf -- '- **fullx**: everything\n- **devx**: dev only\n- **minix**: nothing\n' > "$FX/lib/profiles/README.md"
printf '{"enabledPlugins": {"ui@mk": true}}\n' > "$FX/home/settings.json"
printf '{}\n' > "$FX/home/claude.json"
printf '# proj\n' > "$FX/proj/CLAUDE.md"
P() { PROFILE_REPO_OVERRIDE="$FX" PROFILE_USER_SETTINGS="$FX/home/settings.json" \
      PROFILE_CLAUDE_JSON="$FX/home/claude.json" bash "$ROOT/lib/profile.sh" -C "$FX/proj" "$@"; }
plain() { P current --plain | tr '\n' ' '; }
L="$FX/proj/.claude/settings.local.json"

out="$(P list)"; check_has T1-list "$out" "dev only"; check_has T1-list-name "$out" "devx"
out="$(P show devx)"; check_has T2-show-on "$out" "pack-a@skills-dir"
check_has T2-show-missing "$out" "off  missing (no skills/pack-c/)"
check_has T2-show-deny "$out" "connectors denied: claude.ai X, claude.ai Y"

out="$(plain)"
check_has T3-default "$out" "profile=fullx source=default flag=- pack-a=on pack-b=off pack-c=off plugin:model-router@skills-dir=on plugin:ui@mk=on model=- model-source=- mcp-off=-"
out="$(P current)"; check_has T3-human "$out" "profile: fullx [default]"

# precedence, before any local write: project settings.json over user
printf '{"enabledPlugins": {"pack-b@skills-dir": true}, "model": "opus"}\n' > "$FX/proj/.claude/settings.json"
out="$(plain)"; check_has T6-project "$out" "profile=custom source=default flag=- pack-a=on pack-b=on "
check_has T6-project-model "$out" "model=opus model-source=project "
rm "$FX/proj/.claude/settings.json"

# set keeps the other keys, writes the managed ones
printf '{"permissions": {"allow": ["Bash(ls)"]}, "model": "sonnet"}\n' > "$L"
out="$(P set devx)"; rc=$?
check T4-set-rc "$rc" 0; check_has T4-set-hint "$out" "/reload-plugins"
check T4-keep-perm "$(jq -c .permissions "$L")" '{"allow":["Bash(ls)"]}'
check T4-keep-model "$(jq -r .model "$L")" sonnet
check T4-deny "$(jq -c '[.deniedMcpServers[].serverName]' "$L")" '["claude.ai X","claude.ai Y"]'
out="$(plain)"
check_has T5-local "$out" "profile=devx source=local flag=- pack-a=on pack-b=off pack-c=off plugin:model-router@skills-dir=on plugin:ui@mk=off connector:claude.ai X=denied connector:claude.ai Y=denied model=sonnet model-source=local mcp-off=-"

# local over project; flag over local
printf '{"enabledPlugins": {"pack-b@skills-dir": true}}\n' > "$FX/proj/.claude/settings.json"
out="$(plain)"; check_has T6-local-over-project "$out" "profile=devx source=local flag=- pack-a=on pack-b=off "
printf '{"enabledPlugins": {"pack-b@skills-dir": true}}\n' > "$FX/flag.json"
out="$(CLAUDE_PROFILE_SETTINGS="$FX/flag.json" CLAUDE_PROFILE=x plain)"
check_has T6-flag "$out" "profile=custom source=flag flag=x pack-a=on pack-b=on "
rm "$FX/proj/.claude/settings.json"

# union of deniedMcpServers: flag fullx over local devx keeps the denies → custom
out="$(CLAUDE_PROFILE_SETTINGS="$FX/lib/profiles/fullx.json" CLAUDE_PROFILE=fullx plain)"
check_has T7-union "$out" "profile=custom source=flag flag=fullx "
check_has T7-union-denied "$out" "connector:claude.ai X=denied "

# refusals
cp "$L" "$FX/before.json"; printf '{"enabledPlugins": \n' > "$L"; cp "$L" "$FX/broken.json"
out="$(P set devx 2>&1)"; rc=$?
check T8-invalid-rc "$rc" 2; check_has T8-invalid-msg "$out" "not valid JSON"
check T8-invalid-untouched "$(cmp -s "$FX/broken.json" "$L" && echo same)" same
cp "$FX/before.json" "$L"
out="$(PROFILE_REPO_OVERRIDE="$FX" PROFILE_USER_SETTINGS="$FX/home/settings.json" PROFILE_CLAUDE_JSON="$FX/home/claude.json" \
       bash "$ROOT/lib/profile.sh" -C "$FX/nowhere" set devx 2>&1)"; rc=$?
check T9-root-rc "$rc" 2; check_has T9-root-msg "$out" "not a project root"; check T9-root-nothing "$(ls -A "$FX/nowhere")" ""
out="$(P set nope 2>&1)"; rc=$?; check T10-unknown-rc "$rc" 2; check_has T10-unknown-list "$out" "fullx"

# enable / disable, three spellings, flag note
P enable b >/dev/null; check T11-enable "$(jq -r '.enabledPlugins["pack-b@skills-dir"]' "$L")" true
P disable pack-b >/dev/null; check T11-disable "$(jq -r '.enabledPlugins["pack-b@skills-dir"]' "$L")" false
P enable pack-b@skills-dir >/dev/null; check T11-enable-id "$(jq -r '.enabledPlugins["pack-b@skills-dir"]' "$L")" true
out="$(P enable zzz 2>&1)"; rc=$?; check T11-unknown "$rc" 2
out="$(CLAUDE_PROFILE_SETTINGS="$FX/flag.json" CLAUDE_PROFILE=x P enable a 2>&1)"
check_has T11-flag-note "$out" "relaunch: cc <name> <profile>"
P disable b >/dev/null

# unset: managed keys gone, permissions kept; model removed only when it is the profile's
P unset >/dev/null
check T12-unset-ep "$(jq -c '.enabledPlugins // "gone"' "$L")" '"gone"'
check T12-unset-deny "$(jq -c '.deniedMcpServers // "gone"' "$L")" '"gone"'
check T12-unset-perm "$(jq -c .permissions "$L")" '{"allow":["Bash(ls)"]}'
check T12-unset-model-kept "$(jq -r .model "$L")" sonnet
P set minix >/dev/null; check T12-minix-model "$(jq -r .model "$L")" haiku
P unset >/dev/null; check T12-minix-model-gone "$(jq -r '.model // "gone"' "$L")" gone

# /mcp toggle; unreadable ~/.claude.json; disableClaudeAiConnectors any-source
printf '{"projects": {"%s": {"disabledMcpServers": ["foo", "bar"]}}}\n' "$FX/proj" > "$FX/home/claude.json"
out="$(P current)"; check_has T13-mcp-off "$out" "profile: custom (off: foo,bar) [default]"
out="$(plain)"; check_has T13-mcp-off-plain "$out" "mcp-off=foo,bar"
printf '{broken\n' > "$FX/home/claude.json"
out="$(plain)"; rc=$?; check T14-unknown-rc "$rc" 0; check_has T14-unknown "$out" "mcp-off=unknown"
printf '{}\n' > "$FX/home/claude.json"
printf '{"enabledPlugins": {"ui@mk": true}, "disableClaudeAiConnectors": true}\n' > "$FX/home/settings.json"
out="$(plain)"; check_has T15-all-denied "$out" "connector:*=denied"; check_has T15-custom "$out" "profile=custom "
printf '{"enabledPlugins": {"ui@mk": true}}\n' > "$FX/home/settings.json"

# a missing pack still written; diff
P set devx >/dev/null; check T16-missing-written "$(jq -r '.enabledPlugins["pack-c@skills-dir"]' "$L")" false
out="$(P diff fullx)"; check_has T17-diff-ui "$out" "ui@mk: off → on"
check_has T17-diff-conn "$out" "connectors denied: claude.ai X, claude.ai Y → "
out="$(P diff devx)"; check T17-nodiff "$out" "no difference from devx"

# shellcheck + width
check T18-shellcheck "$(shellcheck "$ROOT/lib/profile.sh" >/dev/null 2>&1 && echo ok)" ok
check T18-width "$(LC_ALL=C awk 'length($0) > 80' "$ROOT/lib/profile.sh" "$ROOT/lib/profile-state.jq" | wc -l | tr -d ' ')" 0

# root walk-up from a subdirectory; a bare dir stays itself
out="$(PROFILE_REPO_OVERRIDE="$FX" PROFILE_USER_SETTINGS="$FX/home/settings.json" PROFILE_CLAUDE_JSON="$FX/home/claude.json" \
       bash "$ROOT/lib/profile.sh" -C "$FX/proj/sub/deeper" current --plain | tr '\n' ' ')"
check_has T19-walkup "$out" "profile=devx source=local "

# managed-connector match: a user-scope deny of an unmanaged connector keeps
# the profile name, shows in the plain lines, and never appears in diff
printf '{"enabledPlugins": {"ui@mk": true}, "deniedMcpServers": [{"serverName": "claude.ai Gmail"}]}\n' > "$FX/home/settings.json"
P set devx >/dev/null; out="$(plain)"
check_has T21-managed-name "$out" "profile=devx source=local "
check_has T21-plain-all "$out" "connector:claude.ai Gmail=denied"
check T21-diff "$(P diff devx)" "no difference from devx"
printf '{"enabledPlugins": {"ui@mk": true}}\n' > "$FX/home/settings.json"

# diff skips the model line when the fragment has none
check_has T22-diff-nomodel "$(P diff devx; jq -r .model "$L")" "no difference from devx"

# name allowlist: a refused name writes nothing and reads no path
cp "$L" "$FX/before-names.json"
for v in "set ../../settings" "show ../x" "diff a/b" "enable ../x" "disable y/z"; do
  # shellcheck disable=SC2086
  out="$(P $v 2>&1)"; rc=$?
  check "T23-name-rc-$v" "$rc" 2; check_has "T23-name-msg-$v" "$out" "invalid"
done
check T23-untouched "$(cmp -s "$FX/before-names.json" "$L" && echo same)" same
check T23-no-escape "$([ -e "$FX/lib/settings.json" ] && echo leaked)" ""

# unset with nothing managed left: no write; no local file: none created
P unset >/dev/null; cp "$L" "$FX/before-unset.json"
out="$(P unset)"; check_has T24-nothing "$out" "nothing to unset"
check T24-untouched "$(cmp -s "$FX/before-unset.json" "$L" && echo same)" same
rm "$L"; P unset >/dev/null; check T24-no-file "$([ -e "$L" ] && echo created)" ""

# project root = parent of the git common dir; a worktree and a nested dir
# holding its own CLAUDE.md both resolve to the main checkout
G="$FX/gmain"; mkdir -p "$G/pkg/inner"; printf '# pkg\n' > "$G/pkg/inner/CLAUDE.md"
git init -q "$G"
git -C "$G" -c core.hooksPath=/dev/null -c user.email=t@t -c user.name=t commit -q --allow-empty -m x
git -C "$G" -c core.hooksPath=/dev/null worktree add -q "$FX/wt" -b wt 2>/dev/null
PX() { local d="$1"; shift; PROFILE_REPO_OVERRIDE="$FX" PROFILE_USER_SETTINGS="$FX/home/settings.json" \
       PROFILE_CLAUDE_JSON="$FX/home/claude.json" bash "$ROOT/lib/profile.sh" -C "$d" "$@"; }
PX "$FX/wt" set devx >/dev/null; rc=$?
check T25-worktree-rc "$rc" 0
check T25-worktree-main "$(jq -r '.enabledPlugins["pack-a@skills-dir"]' "$G/.claude/settings.local.json")" true
check T25-worktree-none "$([ -e "$FX/wt/.claude/settings.local.json" ] && echo local)" ""
check_has T25-nested "$(PX "$G/pkg/inner" current --plain | tr '\n' ' ')" "profile=devx source=local "

# the walk stops below $HOME: a repo AT $HOME is not the project root
H2="$FX/home2"; mkdir -p "$H2/work"; git init -q "$H2"; printf '# w\n' > "$H2/work/CLAUDE.md"
HOME="$H2" PX "$H2/work" set devx >/dev/null; rc=$?
check T26-home-rc "$rc" 0
check T26-home-local "$([ -f "$H2/work/.claude/settings.local.json" ] && echo yes)" yes
check T26-home-not-root "$([ -e "$H2/.claude" ] && echo leaked)" ""

# timing: two jq calls, under 100 ms here (spec target 50 ms, measured in Task 12)
t0=$(date +%s%N); P current --plain >/dev/null; t1=$(date +%s%N)
ms=$(( (t1 - t0) / 1000000 )); echo "current --plain: ${ms} ms"
check T20-timing "$([ "$ms" -le 100 ] && echo fast || echo "slow:${ms}ms")" fast

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
