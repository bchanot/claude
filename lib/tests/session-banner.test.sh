#!/usr/bin/env bash
# lib/tests/session-banner.test.sh — the banner and detect_uiux_pro_max
# follow the project's effective profile, not user scope / the plugin cache
# (BDR-134). Fake HOME and projects under mktemp -d; the real ~/.claude is
# never linked or touched (only lib/ and skills/ of the repo are linked).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SS="$ROOT/hooks/session-start.sh"
DP="$ROOT/lib/detect-plugins.sh"
WORK="$(mktemp -d)" || exit 1; trap 'rm -rf "$WORK"' EXIT
export SESSION_START_OFFLINE=1
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
# has <text> <word>: 1 when the text contains the word, else 0
has() { case "$1" in *"$2"*) echo 1 ;; *) echo 0 ;; esac; }

# shellcheck source=lib/tests/claude-stub.sh
. "$ROOT/lib/tests/claude-stub.sh" || exit 1
claude_stub_install "$WORK"
# rtk pinned present, whatever the machine has
printf '#!/bin/sh\nexit 0\n' >"$WORK/stub/rtk" || exit 1
printf '#!/bin/sh\nexit 0\n' >"$WORK/stub/ctx7" || exit 1
printf '#!/bin/sh\nexit 0\n' >"$WORK/stub/graphify" || exit 1
chmod +x "$WORK/stub/rtk" "$WORK/stub/ctx7" "$WORK/stub/graphify" || exit 1

UIUX='"ui-ux-pro-max@ui-ux-pro-max-skill":true'
SEC='"security-guidance@claude-code-plugins":true'
USER_ALL='{"enabledPlugins":{'"$UIUX,$SEC"',"foo-extra@somewhere":true,
"pack-seo@skills-dir":true}}'
USER_MANAGED='{"enabledPlugins":{'"$UIUX,$SEC"'}}'

# mkhome <name> <cache:1|0> <lib:1|0> <settings>: fake HOME, two links only
mkhome() {
  local h="$WORK/$1"
  mkdir -p "$h/.claude" || exit 1
  if [ -L "$h/.claude/settings.json" ] || [ -L "$h/.claude/plugins" ]; then
    echo "fixture path is a symlink: $h" >&2; exit 1
  fi
  printf '%s\n' "$4" >"$h/.claude/settings.json" || exit 1
  [ "$2" = 1 ] && mkdir -p \
    "$h/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max"
  if [ "$3" = 1 ]; then
    ln -s "$ROOT/lib" "$h/.claude/lib" || exit 1
    [ -L "$h/.claude/lib" ] || exit 1
  fi
  ln -s "$ROOT/skills" "$h/.claude/skills" || exit 1
  [ -L "$h/.claude/skills" ] || exit 1
}
mkhome h1 1 1 "$USER_ALL"
mkhome h2 0 1 "$USER_ALL"
mkhome h3 1 0 "$USER_ALL"
mkhome h4 1 1 "$USER_MANAGED"

mkdir -p "$WORK/pdev/.claude" "$WORK/paudit/.claude" "$WORK/pfull/.claude" \
  || exit 1
cp "$ROOT/lib/profiles/dev.json" "$WORK/pdev/.claude/settings.local.json"
cp "$ROOT/lib/profiles/audit.json" "$WORK/paudit/.claude/settings.local.json"

# banner <home> <proj>: the hook output
banner() {
  (cd "$WORK/$2" && HOME="$WORK/$1" bash "$SS" </dev/null 2>/dev/null)
}
# row <marker> <text>: the marker line plus its continuation line
row() {
  awk -v m="$1" 'f && /^│ {13}/ { print; f = 0; next } { f = 0 }
    index($0, m) { print; f = 1 }' <<<"$2"
}

# SB1: dev project, user scope has ui-ux-pro-max on
out="$(banner h1 pdev)"
on="$(row '🟢 ON' "$out")"; off="$(row '⚫ OFF' "$out")"
ok="$(row '✅ ON' "$out")"
check SB1-toggle-on-no-uiux "$(has "$on" ui-ux-pro-max)" 0
check SB1-toggle-off-uiux "$(has "$off" ui-ux-pro-max)" 1
for w in rtk model-router security-guidance foo-extra; do
  check "SB1-onrow-$w" "$(has "$ok" "$w")" 1
done
for w in pr-review-toolkit pack-seo; do
  check "SB1-onrow-no-$w" "$(has "$ok" "$w")" 0
done

# SB2: audit project shows pr-review-toolkit, hides ui-ux-pro-max
out="$(banner h1 paudit)"
check SB2-onrow-pr-review "$(has "$(row '✅ ON' "$out")" pr-review-toolkit)" 1
check SB2-toggle-on-no-uiux "$(has "$(row '🟢 ON' "$out")" ui-ux-pro-max)" 0

# SB3: no profile (full): ui-ux-pro-max on, pr-review-toolkit absent
out="$(banner h1 pfull)"
check SB3-toggle-on-uiux "$(has "$(row '🟢 ON' "$out")" ui-ux-pro-max)" 1
ok="$(row '✅ ON' "$out")"
check SB3-onrow-no-pr-review "$(has "$ok" pr-review-toolkit)" 0

# SB11: every toggle on: all four in the ON row, no OFF row (SB3 output)
on="$(row '🟢 ON' "$out")"
for w in gstack ui-ux-pro-max context7 graphify; do
  check "SB11-on-$w" "$(has "$on" "$w")" 1
done
check SB11-no-off-row "$(row '⚫ OFF' "$out")" ""

# SB9: no passive-cost row and no plan budget in the banner
check SB9-no-cost-row "$(has "$out" 💰)" 0
check SB9-no-budget "$(has "$out" budget)" 0

# uiux <home> <proj>: exit status of detect_uiux_pro_max, PROFILE_PLAIN unset
uiux() {
  (cd "$WORK/$2" && unset PROFILE_PLAIN && HOME="$WORK/$1" bash -c \
    ". '$DP'; detect_uiux_pro_max; echo \$?")
}
# SB4: follows the profile, still needs the cache
check SB4-dev-off "$(uiux h1 pdev)" 1
check SB4-full-on "$(uiux h1 pfull)" 0
check SB4-not-installed "$(uiux h2 pfull)" 1

# SB5: profile.sh unreachable, user-scope fallback
check SB5-uiux-fallback "$(uiux h3 pdev)" 0
lst="$(cd "$WORK/pdev" && unset PROFILE_PLAIN && HOME="$WORK/h3" bash -c \
  ". '$DP'; list_on_plugins")"
for w in security-guidance@claude-code-plugins \
  ui-ux-pro-max@ui-ux-pro-max-skill foo-extra@somewhere; do
  check "SB5-list-$w" "$(has "$lst" "$w")" 1
done
check SB5-list-no-pack "$(has "$lst" pack-seo@skills-dir)" 0

# SB6: survives set -euo pipefail (doctor.sh options)
res="$(cd "$WORK/pfull" && unset PROFILE_PLAIN && HOME="$WORK/h4" bash -c \
  "set -euo pipefail; . '$DP'; detect_uiux_pro_max; echo u\$?;
   list_on_plugins >/dev/null; echo l\$?; echo alive" | tr '\n' ' ')"
check SB6-pipefail "$res" 'u0 l0 alive '

# SB7: empty list_on_plugins (no profile.sh, no user id) leaves no empty
# element in the ✅ row
mkhome h5 0 0 '{"enabledPlugins":{"x@y":false}}'
out="$(banner h5 pfull)"
ao="$(row '✅ ON' "$out")"; ao="${ao#*: }"; ao="${ao%│}"
ao="${ao%"${ao##*[![:space:]]}"}"
check SB7-empty-list-rtk-only "$ao" rtk

# SB8: no hook run of this suite called the claude CLI (BLK-043)
check SB8-no-claude-calls "$(claude_stub_calls)" 0

# SB10: no hand-copied passive-cost figure or dead plan path left
# gone <file> <regex> [filter]: 1 when no line (after the filter) matches
gone() {
  [ -f "$ROOT/$1" ] || { echo 0; return; }
  if grep -v "${3:-^\$}" "$ROOT/$1" | grep -qE -- "$2"; then echo 0
  else echo 1; fi
}
check SB10-hook-costs "$(gone hooks/session-start.sh \
  '_plugin_costs|TOKEN_WARN|detect_plan')" 1
check SB10-lib-detect-plan "$(gone lib/detect-plugins.sh detect_plan)" 1
check SB10-lib-plugin-dev "$(gone lib/detect-plugins.sh \
  detect_plugin_dev)" 1
check SB10-hook-plugin-dev "$(gone hooks/session-start.sh 'plugin.dev')" 1
check SB10-reporter-const "$(gone agents/status-reporter.md \
  'PLUGIN_TOKENS|~[1-9][0-9-]*t')" 1
check SB10-advisor-figures "$(gone agents/plugin-advisor.md \
  '~[1-9][0-9-]*t')" 1
check SB10-advisor-vocab "$(gone agents/plugin-advisor.md \
  'plugin-dev|PLAN:|plan budget|0t passive|rollback|gstack ON|gstack OFF|'\
'\[plugin\]|ctx7 setup|passive tokens')" 1
check SB10-gate-vocab "$(gone lib/plugin-gate.md \
  'Pre-fetch ctx7|Enable ui-ux-pro-max \(')" 1
gate="$(cat "$ROOT/lib/plugin-gate.md")"
check SB10-gate-diff "$(has "$gate" 'profile.sh" -C')" 1
check SB10-gate-diff2 "$(has "$gate" "diff '<profile>'")" 1
check SB10-gate-root "$(has "$gate" '--git-common-dir')" 1
check SB10-gate-rejected "$(has "$gate" 'rejected')" 1
check SB10-gate-quoted "$(gone lib/plugin-gate.md '-C <PROJECT_ROOT>')" 1
check SB10-advisor-fullid "$(has "$(cat "$ROOT/agents/plugin-advisor.md")" \
  'ui-ux-pro-max@ui-ux-pro-max-skill')" 1
# anchored: "120000 tokens" (the /route show sample) is not a 0-token claim
check SB10-usage-vocab "$(gone USAGE.md \
  '0 t passif|(^|[^0-9])0 token|gstack ON|gstack OFF|context7 ON|'\
'~[1-9][0-9]*t\)' COST)" 1
check SB10-usage-packs-group "$(gone USAGE.md \
  'packs gstack \(|DISABLE: pack design, packs gstack')" 1
check SB10-advisor-keep-full "$(gone agents/plugin-advisor.md 'SET : full')" 1
check SB10-usage-gate-lists "$(gone USAGE.md \
  'le gate liste ce que le profil coupe')" 1
check SB10-gate-profiles-path "$(has "$gate" '$HOME/.claude/lib/profiles/')" 1
check SB10-gate-C-oneline "$(gone lib/plugin-gate.md '-C *$')" 1
check SB10-onboard-ctx7 "$(gone skills/onboard/SKILL.md 'ctx7 setup')" 1
check SB10-onboard-install "$(gone skills/onboard/SKILL.md \
  'make plugin`? *\(installe')" 1
check SB10-gate-turns-on "$(has "$gate" 'turns on')" 1
check SB10-gate-set-tokens "$(has "$gate" \
  'web, seo, dev, design, qa, audit, minimal')" 1
check SB10-check-cmds "$(gone skills/plugin-check/SKILL.md \
  "advisor's exact commands")" 1

printf 'session-banner: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
