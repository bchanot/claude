#!/usr/bin/env bash
# lib/tests/profile-set-managed.test.sh — `set` symmetry on managed
# externals + MCPs, gstack on-demand, external from-source (BDR-079).
# Hermetic: fixture repo via *_REPO_OVERRIDE + fake `claude` on PATH.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

FX="$(mktemp -d)"; trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/skills" "$FX/skills-disabled" "$FX/lib/profiles" "$FX/bin" \
  "$FX/skills-external/emil-design-eng" "$FX/skills-external/other-ext"
for g in gs-a gs-b gs-c; do
  mkdir -p "$FX/skills-external/gstack/$g"
  touch "$FX/skills-external/gstack/$g/SKILL.md"
done
cp "$ROOT/lib/profile.sh" "$ROOT/lib/toggle-external.sh" "$FX/lib/"
printf 'MAGIC_API_KEY=test-secret-000\n' > "$FX/.env"

# Non-managed external, enabled from the start — must never be touched.
ln -s "$FX/skills-external/other-ext" "$FX/skills/other-ext"

cat > "$FX/lib/profiles/designish.profile" <<'EOF'
gs-a
gs-b
emil-design-eng   external
magic             mcp
EOF
cat > "$FX/lib/profiles/backendish.profile" <<'EOF'
gs-c
EOF

# Fake claude: logs every call; keeps MCP registry state in a flat file.
cat > "$FX/bin/claude" <<EOF
#!/usr/bin/env bash
FX="$FX"
echo "\$*" >> "\$FX/claude-calls.log"
case "\$1 \${2:-}" in
  "mcp list")   cat "\$FX/mcp-state" 2>/dev/null ;;
  "mcp add")    echo "magic: stub" > "\$FX/mcp-state" ;;
  "mcp remove") : > "\$FX/mcp-state" ;;
esac
exit 0
EOF
chmod +x "$FX/bin/claude"

run() { PATH="$FX/bin:$PATH" PROFILE_REPO_OVERRIDE="$FX" \
  TOGGLE_EXTERNAL_REPO_OVERRIDE="$FX" bash "$FX/lib/profile.sh" "$@"; }

# --- set designish: gstack on-demand + external from-source + magic on ---
run set designish >/dev/null 2>&1
check T1-gsa-on   "$([ -e "$FX/skills/gs-a" ] && echo on || echo off)" on
check T2-gsb-on   "$([ -e "$FX/skills/gs-b" ] && echo on || echo off)" on
check T3-gsc-off  "$([ -e "$FX/skills/gs-c" ] && echo on || echo off)" off
check T4-emil-src "$([ -L "$FX/skills/emil-design-eng" ] && echo on || echo off)" on
check T5-magic-on "$(grep -c '^magic:' "$FX/mcp-state" 2>/dev/null)" 1
check T6-add-call "$(grep -c '^mcp add magic' "$FX/claude-calls.log")" 1

# --- set backendish: managed leftovers parked/unregistered ---
run set backendish >/dev/null 2>&1
check T7-gsc-on    "$([ -e "$FX/skills/gs-c" ] && echo on || echo off)" on
check T8-gsa-park  "$([ -e "$FX/skills-disabled/gstack__gs-a" ] && echo p || echo n)" p
check T9-emil-off  "$([ -e "$FX/skills/emil-design-eng" ] && echo on || echo off)" off
check T10-emil-park "$([ -e "$FX/skills-disabled/emil-design-eng" ] && echo p || echo n)" p
check T11-magic-off "$(grep -c '^magic:' "$FX/mcp-state" 2>/dev/null || true)" 0
check T12-rm-call  "$(grep -c '^mcp remove magic' "$FX/claude-calls.log")" 1
check T13-other-untouched "$([ -e "$FX/skills/other-ext" ] && echo on || echo off)" on

# --- back to designish: parked external restored (not re-sourced) ---
run set designish >/dev/null 2>&1
check T14-emil-back "$([ -e "$FX/skills/emil-design-eng" ] && echo on || echo off)" on
check T15-park-gone "$([ -e "$FX/skills-disabled/emil-design-eng" ] && echo p || echo n)" n
check T16-magic-back "$(grep -c '^magic:' "$FX/mcp-state" 2>/dev/null)" 1

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
