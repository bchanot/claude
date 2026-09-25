#!/usr/bin/env bash
# lib/tests/profile-default.test.sh — default profile (full) when nothing is
# selected: `current` is label-driven (BDR-030 — gstack starts off, so a
# parked count says nothing about which profile is on), `reset` lands on
# DEFAULT_PROFILE, `gstack off` resolves the default through active_profile(),
# and hooks/statusline.sh falls back to the same constant. Covers contract
# criteria 2/3/4/5. Hermetic: fixture repo via *_REPO_OVERRIDE + fake `claude`
# on PATH — same harness as profile-set-managed.test.sh.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
check_has() { case "$2" in *"$3"*) pass=$((pass+1));; *) fail=$((fail+1));
  printf 'FAIL %s: [%s] does not contain [%s]\n' "$1" "$2" "$3";; esac; }
check_not() { case "$2" in *"$3"*) fail=$((fail+1));
  printf 'FAIL %s: [%s] unexpectedly contains [%s]\n' "$1" "$2" "$3";; *) pass=$((pass+1));; esac; }

FX="$(mktemp -d)"; trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/skills" "$FX/skills-disabled" "$FX/lib/profiles" "$FX/bin" \
  "$FX/hooks" "$FX/skills-external/emil-design-eng"
for g in gs-a gs-b gs-c; do
  mkdir -p "$FX/skills-external/gstack/$g"
  touch "$FX/skills-external/gstack/$g/SKILL.md"
done
cp "$ROOT/lib/profile.sh" "$ROOT/lib/toggle-external.sh" "$FX/lib/"
cp "$ROOT/hooks/statusline.sh" "$FX/hooks/"

cat > "$FX/lib/profiles/full.profile" <<'EOF'
gs-a
gs-b
emil-design-eng   external
EOF
cat > "$FX/lib/profiles/otherish.profile" <<'EOF'
gs-c
EOF

# Fake claude: logs every call, prints nothing — skill_status greps for
# "✔ enabled" and finds nothing, so every managed plugin reads back
# "disabled" and set/reset never touch real plugin state.
cat > "$FX/bin/claude" <<EOF
#!/usr/bin/env bash
FX="$FX"
echo "\$*" >> "\$FX/claude-calls.log"
exit 0
EOF
chmod +x "$FX/bin/claude"

run() { PATH="$FX/bin:$PATH" PROFILE_REPO_OVERRIDE="$FX" \
  TOGGLE_EXTERNAL_REPO_OVERRIDE="$FX" bash "$FX/lib/profile.sh" "$@"; }
statusline() { echo '{}' | bash "$FX/hooks/statusline.sh"; }
first_word() { printf '%s' "${1%% *}"; }

# --- T1: clean seed, no cache — current names the default, "not applied" ---
out="$(run current)"
check     T1-first-word     "$(first_word "$out")" full
check_has T1-not-applied    "$out" "default — not applied yet"
check_not T1-no-all-gstack  "$out" "all gstack"

# --- T2: clean seed, no cache — gstack off is a clean no-op (rc 0) ---
run gstack off >/dev/null 2>&1; rc=$?
check T2-rc "$rc" 0

# --- T2b: one gstack skill manually linked, no cache — off parks just it ---
ln -s "$FX/skills-external/gstack/gs-c" "$FX/skills/gs-c"
run gstack off >/dev/null 2>&1; rc=$?
check T2b-rc         "$rc" 0
check T2b-gsc-parked "$([ -e "$FX/skills-disabled/gstack__gs-c" ] && echo p || echo n)" p
check T2b-gsa-absent "$([ -e "$FX/skills/gs-a" ] && echo on || echo off)" off
rm -rf "$FX/skills-disabled/gstack__gs-c"   # back to the clean seed

# --- T3: cache "none" (CRLF) — off is still a clean no-op ---
printf 'none\r\n' > "$FX/.active-profile"
run gstack off >/dev/null 2>&1; rc=$?
check T3-rc "$rc" 0

# --- T4: cache names an unknown profile — off errors, current says so ---
printf 'ghost\n' > "$FX/.active-profile"
run gstack off >/dev/null 2>&1; rc=$?
check T4-rc "$rc" 1
out="$(run current)"
check     T4-first-word "$(first_word "$out")" ghost
check_has T4-unknown     "$out" "unknown profile"

# --- T5: reset lands on the default profile, exclusively ---
run reset >/dev/null 2>&1
check T5-cache   "$(cat "$FX/.active-profile" 2>/dev/null)" full
check T5-gsa-on  "$([ -e "$FX/skills/gs-a" ] && echo on || echo off)" on
check T5-gsb-on  "$([ -e "$FX/skills/gs-b" ] && echo on || echo off)" on
check T5-gsc-off "$([ -e "$FX/skills/gs-c" ] && echo on || echo off)" off
check T5-emil-on "$([ -e "$FX/skills/emil-design-eng" ] && echo on || echo off)" on
out="$(run current)"
check     T5-first-word  "$(first_word "$out")" full
check_has T5-match        "$out" "100% match"
check_not T5-not-applied  "$out" "not applied"

# --- T6: current is label-driven even for a gstack-only profile ---
run set otherish >/dev/null 2>&1
out="$(run current)"
check T6-first-word "$(first_word "$out")" otherish
run reset >/dev/null 2>&1
check T6-gsc-parked "$([ -e "$FX/skills-disabled/gstack__gs-c" ] && echo p || echo n)" p
check T6-gsa-on     "$([ -e "$FX/skills/gs-a" ] && echo on || echo off)" on
check T6-cache      "$(cat "$FX/.active-profile" 2>/dev/null)" full

# --- T7: gstack on restores parked skills, keeps the profile label ---
run set otherish >/dev/null 2>&1
run gstack on >/dev/null 2>&1
out="$(run current)"
check     T7-first-word "$(first_word "$out")" otherish
check_not T7-no-default "$out" "default"

# --- T8-T11: statusline fallback + constant read ---
rm -f "$FX/.active-profile"
out="$(statusline)"
check_has T8-full "$out" "profile: full"

printf 'otherish\n' > "$FX/.active-profile"
out="$(statusline)"
check_has T9-otherish "$out" "profile: otherish"

printf '  none \r' > "$FX/.active-profile"
out="$(statusline)"
check_has T10-full "$out" "profile: full"

sed -i 's/^DEFAULT_PROFILE="full"/DEFAULT_PROFILE="otherish"/' "$FX/lib/profile.sh"
rm -f "$FX/.active-profile"
out="$(statusline)"
check_has T11-otherish "$out" "profile: otherish"

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
