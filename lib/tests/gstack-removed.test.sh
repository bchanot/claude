#!/usr/bin/env bash
# lib/tests/gstack-removed.test.sh — GSTACK_REMOVED denylist honored by
# every "bring gstack back" path: profile.sh `gstack on` and
# toggle-external.sh `enable gstack` both skip a policy-removed name and
# leave it parked, restoring only what policy allows; gstack_is_removed()
# itself, positive + negative. Covers contract criterion 17. Hermetic:
# fixture repo via PROFILE_REPO_OVERRIDE / TOGGLE_EXTERNAL_REPO_OVERRIDE —
# same harness as lib/tests/profile-default.test.sh and
# lib/tests/toggle-external-repo-resolution.test.sh.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
check_has() { case "$2" in *"$3"*) pass=$((pass+1));; *) fail=$((fail+1));
  printf 'FAIL %s: [%s] does not contain [%s]\n' "$1" "$2" "$3";; esac; }
check_not() { case "$2" in *"$3"*) fail=$((fail+1));
  printf 'FAIL %s: [%s] unexpectedly contains [%s]\n' "$1" "$2" "$3";; *) pass=$((pass+1));; esac; }

# mk_fixture <dir> — minimal repo: profile.sh + toggle-external.sh +
# gstack-removed.sh under lib/, one removed name (ship) and one kept name
# (browse) parked in skills-disabled/.
mk_fixture() {
  local fx="$1"
  mkdir -p "$fx/skills" "$fx/skills-disabled/gstack__ship" \
    "$fx/skills-disabled/gstack__browse" "$fx/lib"
  cp "$ROOT/lib/profile.sh" "$ROOT/lib/toggle-external.sh" \
    "$ROOT/lib/gstack-removed.sh" "$fx/lib/"
}

# --- T1-T5: profile.sh gstack on restores browse, skips + parks ship ---
FX1="$(mktemp -d)"; mk_fixture "$FX1"
out="$(PROFILE_REPO_OVERRIDE="$FX1" bash "$FX1/lib/profile.sh" gstack on 2>&1)"
check     T1-browse-restored "$([ -e "$FX1/skills/browse" ] && echo on || echo off)" on
check     T2-ship-parked     "$([ -e "$FX1/skills-disabled/gstack__ship" ] && echo p || echo n)" p
check     T3-ship-not-live   "$([ -e "$FX1/skills/ship" ] && echo on || echo off)" off
check_has T4-skip-names-ship "$out" "ship"
check_has T5-real-count      "$out" "1 parked gstack skills restored"
rm -rf "$FX1"

# --- T6-T9: toggle-external.sh enable gstack — same skip + restore ---
FX2="$(mktemp -d)"; mk_fixture "$FX2"
out="$(TOGGLE_EXTERNAL_REPO_OVERRIDE="$FX2" bash "$FX2/lib/toggle-external.sh" enable gstack 2>&1)"
check     T6-browse-restored "$([ -e "$FX2/skills/browse" ] && echo on || echo off)" on
check     T7-ship-parked     "$([ -e "$FX2/skills-disabled/gstack__ship" ] && echo p || echo n)" p
check     T8-ship-not-live   "$([ -e "$FX2/skills/ship" ] && echo on || echo off)" off
check_has T9-skip-names-ship "$out" "ship"
rm -rf "$FX2"

# --- T10-T11: toggle-external.sh, only removed names parked — 0 restored,
# the policy message fires instead of the "re-run gstack setup" hint ---
FX3="$(mktemp -d)"
mkdir -p "$FX3/skills" "$FX3/skills-disabled/gstack__ship" "$FX3/lib"
cp "$ROOT/lib/toggle-external.sh" "$ROOT/lib/gstack-removed.sh" "$FX3/lib/"
out="$(TOGGLE_EXTERNAL_REPO_OVERRIDE="$FX3" bash "$FX3/lib/toggle-external.sh" enable gstack 2>&1)"
check_has T10-policy-msg    "$out" "policy-removed skills remain parked"
check_not T11-no-setup-hint "$out" "re-run gstack setup"
rm -rf "$FX3"

# --- T12-T13: gstack_is_removed() itself, positive + negative ---
# shellcheck source=lib/gstack-removed.sh disable=SC1091
source "$ROOT/lib/gstack-removed.sh"
gstack_is_removed ship;   check T12-removed-positive "$?" 0
gstack_is_removed browse; check T13-removed-negative "$?" 1

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
