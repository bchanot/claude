#!/usr/bin/env bash
# lib/tests/profile-set-managed.test.sh — `set` symmetry on managed
# externals, gstack on-demand, external from-source (BDR-079). The MCP
# assertions went with `magic` (2026-09-22): MANAGED_MCPS is empty now, the
# 21st skills that replaced it are managed as externals, so the pack's
# park/restore round-trip is what this covers on that side.
# Hermetic: fixture repo via *_REPO_OVERRIDE + fake `claude` on PATH.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

FX="$(mktemp -d)"; trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/skills" "$FX/skills-disabled" "$FX/lib/profiles" "$FX/bin" \
  "$FX/skills-external/emil-design-eng" "$FX/skills-external/other-ext" \
  "$FX/skills-external/21st-ui-build"
for g in gs-a gs-b gs-c; do
  mkdir -p "$FX/skills-external/gstack/$g"
  touch "$FX/skills-external/gstack/$g/SKILL.md"
done
cp "$ROOT/lib/profile.sh" "$ROOT/lib/toggle-external.sh" "$FX/lib/"

# Non-managed external, enabled from the start — must never be touched.
ln -s "$FX/skills-external/other-ext" "$FX/skills/other-ext"

cat > "$FX/lib/profiles/designish.profile" <<'EOF'
gs-a
gs-b
emil-design-eng   external
21st-ui-build     external
EOF
cat > "$FX/lib/profiles/backendish.profile" <<'EOF'
gs-c
EOF

# Fake claude: logs every call. No MCP state to keep — MANAGED_MCPS is empty,
# so `set` must never reach for `claude mcp` at all (asserted below).
cat > "$FX/bin/claude" <<EOF
#!/usr/bin/env bash
FX="$FX"
echo "\$*" >> "\$FX/claude-calls.log"
exit 0
EOF
chmod +x "$FX/bin/claude"

run() { PATH="$FX/bin:$PATH" PROFILE_REPO_OVERRIDE="$FX" \
  TOGGLE_EXTERNAL_REPO_OVERRIDE="$FX" bash "$FX/lib/profile.sh" "$@"; }

# --- set designish: gstack on-demand + externals from-source (21st + emil) ---
run set designish >/dev/null 2>&1
check T1-gsa-on   "$([ -e "$FX/skills/gs-a" ] && echo on || echo off)" on
check T2-gsb-on   "$([ -e "$FX/skills/gs-b" ] && echo on || echo off)" on
check T3-gsc-off  "$([ -e "$FX/skills/gs-c" ] && echo on || echo off)" off
check T4-emil-src "$([ -L "$FX/skills/emil-design-eng" ] && echo on || echo off)" on
check T5-21st-src "$([ -L "$FX/skills/21st-ui-build" ] && echo on || echo off)" on
check T6-no-mcp   "$(grep -c '^mcp ' "$FX/claude-calls.log" || true)" 0

# --- set backendish: managed leftovers parked/unregistered ---
run set backendish >/dev/null 2>&1
check T7-gsc-on    "$([ -e "$FX/skills/gs-c" ] && echo on || echo off)" on
check T8-gsa-park  "$([ -e "$FX/skills-disabled/gstack__gs-a" ] && echo p || echo n)" p
check T9-emil-off  "$([ -e "$FX/skills/emil-design-eng" ] && echo on || echo off)" off
check T10-emil-park "$([ -e "$FX/skills-disabled/emil-design-eng" ] && echo p || echo n)" p
check T11-21st-off "$([ -e "$FX/skills/21st-ui-build" ] && echo on || echo off)" off
check T12-21st-park "$([ -e "$FX/skills-disabled/21st-ui-build" ] && echo p || echo n)" p
check T13-other-untouched "$([ -e "$FX/skills/other-ext" ] && echo on || echo off)" on

# --- back to designish: parked external restored (not re-sourced) ---
run set designish >/dev/null 2>&1
check T14-emil-back "$([ -e "$FX/skills/emil-design-eng" ] && echo on || echo off)" on
check T15-park-gone "$([ -e "$FX/skills-disabled/emil-design-eng" ] && echo p || echo n)" n
check T16-21st-back "$([ -e "$FX/skills/21st-ui-build" ] && echo on || echo off)" on
check T17-no-mcp-ever "$(grep -c '^mcp ' "$FX/claude-calls.log" || true)" 0

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
