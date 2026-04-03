#!/usr/bin/env bash
# ============================================================
# Claude Code — Config doctor
# Diagnoses symlinks, prerequisites, plugins, permissions,
# and token budget. Run after install or when something breaks.
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ERRORS=0; WARNS=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; WARNS=$((WARNS + 1)); }
info() { echo -e "  ${BLUE}→${NC} $1"; }

REPO="$(cd "$(dirname "$0")" && pwd)"
VERSION=$(cat "$REPO/version.txt" 2>/dev/null || echo "unknown")

# Load shared detection library
# shellcheck source=lib/detect-plugins.sh
source "$REPO/lib/detect-plugins.sh"

echo ""
echo "═══ claude-config doctor (v${VERSION}) ═══"
echo ""

# ────────────────────────────────────────────────────────────
# 1. Core symlinks
# ────────────────────────────────────────────────────────────
echo "── Symlinks ──"

check_symlink() {
  local name="$1"
  local target="$HOME/.claude/$name"

  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    fail "~/.claude/$name — MISSING"
    return
  fi

  if [ -L "$target" ]; then
    local real
    real=$(readlink -f "$target" 2>/dev/null || readlink "$target")
    if [ ! -e "$real" ]; then
      fail "~/.claude/$name → $real — BROKEN SYMLINK"
    else
      pass "~/.claude/$name"
    fi
  else
    warn "~/.claude/$name exists but is NOT a symlink (expected symlink to repo)"
  fi
}

check_symlink "CLAUDE.md"
check_symlink "settings.json"
check_symlink "agents"
check_symlink "skills"
check_symlink "hooks/session-start.sh"

echo ""

# ────────────────────────────────────────────────────────────
# 2. GStack submodule
# ────────────────────────────────────────────────────────────
echo "── GStack submodule ──"

if [ -d "$REPO/skills-external/gstack" ] || [ -f "$REPO/skills-external/gstack/.git" ]; then
  pass "Submodule present at skills-external/gstack"
else
  warn "Submodule not initialized — run: git submodule update --init"
fi

if [ -L "$HOME/.claude/skills/gstack" ]; then
  real=$(readlink -f "$HOME/.claude/skills/gstack" 2>/dev/null || readlink "$HOME/.claude/skills/gstack")
  if [ -d "$real" ]; then
    pass "Symlink OK → $real"
  else
    fail "Symlink broken → $real"
  fi
else
  warn "GStack not symlinked — run: bash link.sh"
fi

echo ""

# ────────────────────────────────────────────────────────────
# 3. Prerequisites
# ────────────────────────────────────────────────────────────
echo "── Prerequisites ──"

if command -v git &>/dev/null; then
  pass "git $(git --version | awk '{print $3}')"
else
  fail "git not found"
fi

if command -v node &>/dev/null; then
  NODE_VER=$(node --version | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_VER" -ge 18 ]; then
    pass "Node.js $(node --version)"
  else
    warn "Node.js $(node --version) — need >=18"
  fi
else
  fail "Node.js not found"
fi

if command -v cargo &>/dev/null; then
  pass "Cargo $(cargo --version | awk '{print $2}')"
else
  warn "Cargo not found (RTK unavailable)"
fi

if command -v python3 &>/dev/null; then
  pass "Python $(python3 --version | awk '{print $2}')"
else
  warn "Python3 not found"
fi

if command -v claude &>/dev/null; then
  pass "Claude Code $(claude --version 2>/dev/null | head -1 || echo 'installed')"
else
  fail "Claude Code not found — install from https://code.claude.com"
fi

echo ""

# ────────────────────────────────────────────────────────────
# 4. Key plugins
# ────────────────────────────────────────────────────────────
echo "── Plugins ──"

if detect_rtk; then
  pass "RTK installed"
else
  warn "RTK not installed — run install-plugins.sh"
fi

if detect_superpowers; then
  pass "Superpowers plugin detected"
else
  fail "Superpowers not detected — orchestrators (/init-project, /ship-feature) will fail"
fi

if detect_context7; then
  pass "Context7 MCP configured"
else
  info "Context7 MCP not configured (optional — needed for fast-evolving libs)"
fi

echo ""

# ────────────────────────────────────────────────────────────
# 5. Permissions check
# ────────────────────────────────────────────────────────────
echo "── Permissions ──"

SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ] || [ -L "$SETTINGS" ]; then
  if grep -q '"disableBypassPermissionsMode"' "$SETTINGS" 2>/dev/null; then
    pass "Bypass mode disabled"
  else
    warn "disableBypassPermissionsMode not found in settings"
  fi

  DENY_COUNT=$(python3 -c "
import json
with open('$SETTINGS') as f:
    d = json.load(f)
print(len(d.get('permissions',{}).get('deny',[])))
" 2>/dev/null || echo "?")
  pass "Deny rules: $DENY_COUNT"
else
  fail "~/.claude/settings.json not found"
fi

echo ""

# ────────────────────────────────────────────────────────────
# 6. Token budget estimate
# ────────────────────────────────────────────────────────────
echo "── Token budget estimate ──"

TOTAL_CHARS=0

# Skill descriptions
for f in "$HOME/.claude/skills/"*/SKILL.md; do
  [ -f "$f" ] || continue
  desc=$(sed -n 's/^description: //p' "$f" 2>/dev/null || true)
  TOTAL_CHARS=$((TOTAL_CHARS + ${#desc}))
done

# Agent descriptions
for f in "$HOME/.claude/agents/"*.md; do
  [ -f "$f" ] || continue
  desc=$(sed -n '/^---$/,/^---$/{ s/^description: //p }' "$f" 2>/dev/null || true)
  TOTAL_CHARS=$((TOTAL_CHARS + ${#desc}))
done

if [ "$TOTAL_CHARS" -gt 6000 ]; then
  warn "Custom descriptions: ~${TOTAL_CHARS} chars (budget ~8000) — risk of truncation"
elif [ "$TOTAL_CHARS" -gt 4000 ]; then
  info "Custom descriptions: ~${TOTAL_CHARS} chars (within budget, moderate margin)"
else
  pass "Custom descriptions: ~${TOTAL_CHARS} chars (comfortable)"
fi

echo ""

# ────────────────────────────────────────────────────────────
# 7. File consistency
# ────────────────────────────────────────────────────────────
echo "── Consistency ──"

# Check all skills have disable-model-invocation
MISSING_DMI=()
for f in "$HOME/.claude/skills/"*/SKILL.md; do
  [ -f "$f" ] || continue
  name=$(basename "$(dirname "$f")")
  if ! grep -q "disable-model-invocation" "$f" 2>/dev/null; then
    MISSING_DMI+=("$name")
  fi
done
if [ ${#MISSING_DMI[@]} -eq 0 ]; then
  pass "All skills have disable-model-invocation"
else
  warn "Skills missing disable-model-invocation: ${MISSING_DMI[*]}"
fi

# Check CRLF
CRLF_FILES=()
for f in "$REPO"/*.md "$REPO"/agents/*.md "$REPO"/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  if grep -qP '\r' "$f" 2>/dev/null; then
    CRLF_FILES+=("$(basename "$f")")
  fi
done
if [ ${#CRLF_FILES[@]} -eq 0 ]; then
  pass "No CRLF line endings detected"
else
  warn "CRLF detected in: ${CRLF_FILES[*]}"
fi

echo ""

# ────────────────────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════"
if [ "$ERRORS" -gt 0 ]; then
  echo -e "${RED}  $ERRORS error(s)${NC}, ${YELLOW}$WARNS warning(s)${NC}"
  echo ""
  echo "  Fix: cd $REPO && bash link.sh && bash install-plugins.sh"
  exit 1
elif [ "$WARNS" -gt 0 ]; then
  echo -e "  ${GREEN}No errors${NC}, ${YELLOW}$WARNS warning(s)${NC}"
else
  echo -e "  ${GREEN}All checks passed ✓${NC}"
fi
echo ""
