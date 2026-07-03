#!/usr/bin/env bash
# lib/tests/design-toolchain-reminder.test.sh
set -u
H="$(cd "$(dirname "$0")/../.." && pwd)/hooks/design-toolchain-reminder.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
# fire() -> "fire" if the hook emits the reminder, else "quiet".
fire() { if printf '{"prompt":"%s"}' "$1" | bash "$H" | grep -q "design-toolchain"; then
  echo fire; else echo quiet; fi; }

# --- Dropped/neutralized tokens must be QUIET (non-UI senses) ---
check D1-design      "$(fire 'a design decision for the API')" quiet
check D2-component   "$(fire 'this system component')"         quiet
check D3-composant   "$(fire 'le composant backend')"          quiet
check D4-theme       "$(fire 'the theme of the audit')"        quiet
check D5-transition  "$(fire 'state transition to develop')"   quiet
check D6-frontend    "$(fire 'frontend architecture')"         quiet
check D7-palette     "$(fire 'a palette of options')"          quiet
check D8-dash-file   "$(fire 'ecc_dashboard.py')"              quiet

# --- Real UI signals must still FIRE ---
check F1-button      "$(fire 'add a button')"            fire
check F2-navbar      "$(fire 'the navbar layout')"       fire
check F3-landing     "$(fire 'build a landing page')"    fire
check F4-glass       "$(fire 'a glassmorphism card')"    fire
check F5-redesign    "$(fire 'redesign the app')"        fire
check F6-frontdesign "$(fire 'frontend design work')"    fire
check F7-admin-dash  "$(fire 'admin dashboard screen')"  fire
check F8-animation   "$(fire 'add an animation')"        fire
check F9-designsys   "$(fire 'our design system')"       fire

# --- Fire is logged (time + token + excerpt) ---
tmp="$(mktemp -d)"
printf '{"prompt":"a glassmorphism card"}' | HOME="$tmp" bash "$H" >/dev/null 2>&1
check L1-logged "$(grep -c 'glassmorph' "$tmp/.claude/logs/design-toolchain-fires.log" 2>/dev/null)" 1
rm -rf "$tmp"

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
