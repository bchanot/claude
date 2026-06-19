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
# Expected: CLAUDE.md, settings.json, agents, skills, templates, hooks/session-start.sh
_EXPECTED_LINKS=7
_LINK_PASS=0

check_symlink() {
  local name="$1"
  local target="$HOME/.claude/$name"

  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    fail "$HOME/.claude/$name — MISSING"
    return
  fi

  if [ -L "$target" ]; then
    # readlink -f is not available on macOS BSD — use -f with fallback
    local real
    real=$(readlink -f "$target" 2>/dev/null) || real=$(readlink "$target")
    if [ ! -e "$real" ]; then
      fail "$HOME/.claude/$name → $real — BROKEN SYMLINK"
    else
      pass "$HOME/.claude/$name"; _LINK_PASS=$((_LINK_PASS + 1))
    fi
  else
    warn "$HOME/.claude/$name exists but is NOT a symlink (expected symlink to repo)"
  fi
}

check_symlink "CLAUDE.md"
check_symlink "settings.json"
check_symlink "agents"
check_symlink "skills"
check_symlink "templates"
check_symlink "lib"
check_symlink "hooks/session-start.sh"
info "Symlinks: ${_LINK_PASS}/${_EXPECTED_LINKS} OK"
unset _EXPECTED_LINKS _LINK_PASS

echo ""

# ────────────────────────────────────────────────────────────
# 2. GStack submodule
# ────────────────────────────────────────────────────────────
echo "── GStack submodule ──"

GSTACK_DIR="$REPO/skills-external/gstack"
if [ -f "$GSTACK_DIR/.git" ] || [ -d "$GSTACK_DIR/.git" ]; then
  pass "Submodule initialized at skills-external/gstack"
  warn "GStack tracks branch = main (no commit hash pin). Review upstream before updating."
elif [ -d "$GSTACK_DIR" ]; then
  warn "skills-external/gstack exists but submodule not initialized — run: git submodule update --init"
else
  warn "GStack submodule missing — run: git submodule update --init"
fi

if [ -L "$HOME/.claude/skills/gstack" ]; then
  real=$(readlink -f "$HOME/.claude/skills/gstack" 2>/dev/null || readlink "$HOME/.claude/skills/gstack")
  if [ -d "$real" ]; then
    pass "Symlink OK → $real"
    # Check for skills/ subdirectory (referenced by plugin-advisor PHASE 1).
    # `|| echo 0` is required because under `set -o pipefail`, a missing
    # gstack/skills/ dir makes find exit non-zero, killing the script.
    gstack_skills_count=$( { find "$HOME/.claude/skills/gstack/skills/" -maxdepth 1 -mindepth 1 2>/dev/null || true; } | wc -l | tr -d ' ')
    if [ "${gstack_skills_count:-0}" -gt 0 ]; then
      pass "GStack: ${gstack_skills_count} skills available"
    else
      warn "GStack symlink OK but no skills/ subdirectory found — may need: cd skills-external/gstack && ./setup"
    fi
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
  pass "Context7 CLI (ctx7) installed"
else
  info "Context7 CLI not installed (optional — needed for fast-evolving libs: npm install -g ctx7)"
fi

if detect_gsd; then
  pass "GSD v2 installed ($(gsd --version 2>/dev/null | head -1 || echo 'gsd'))"
else
  info "GSD v2 not installed (optional — run: npm install -g gsd-pi)"
fi

if detect_graphifyy; then
  pass "Graphifyy installed (graphify CLI)"
else
  info "Graphifyy not installed (optional — codebase knowledge graph: pipx install graphifyy)"
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

  if [ "$DENY_COUNT" = "?" ]; then
    warn "Could not parse deny count (python3 unavailable or JSON parse error)"
  else
    EXPECTED_DENY=100
    if [ "$DENY_COUNT" -eq "$EXPECTED_DENY" ] 2>/dev/null; then
      pass "Deny rules: $DENY_COUNT"
    else
      warn "Deny rules: $DENY_COUNT (expected $EXPECTED_DENY) — settings may have been manually modified"
    fi
  fi
else
  fail "$HOME/.claude/settings.json not found"
fi

echo ""

# ────────────────────────────────────────────────────────────
# 6. Token budget estimate
# ────────────────────────────────────────────────────────────
echo "── Token budget estimate ──"
# Reference: Claude Code Pro plan ~11k tokens/5h session (session budget, not context window).
# Seuils: WARNING >15%, CRITICAL >30% of session budget.

CLAUDE_MD_CHARS=$(wc -c < "$REPO/CLAUDE.md" 2>/dev/null || echo 0)
CLAUDE_MD_TOKENS=$((CLAUDE_MD_CHARS / 4))

# Skill descriptions only (frontmatter description field — loaded passively at startup)
SKILL_DESC_CHARS=0
for f in "$HOME/.claude/skills/"*/SKILL.md; do
  [ -f "$f" ] || continue
  desc=$(grep "^description:" "$f" 2>/dev/null | head -1 | sed 's/^description: *//' )
  SKILL_DESC_CHARS=$((SKILL_DESC_CHARS + ${#desc}))
done
SKILL_DESC_TOKENS=$((SKILL_DESC_CHARS / 4))
SKILL_COUNT=$(find "$HOME/.claude/skills/" -maxdepth 2 -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')

# Plugin passive cost estimates (tokens)
PLUGIN_TOKENS=0
if detect_superpowers 2>/dev/null; then PLUGIN_TOKENS=$((PLUGIN_TOKENS + 800)); fi
if detect_gstack      2>/dev/null; then PLUGIN_TOKENS=$((PLUGIN_TOKENS + 2750)); fi
if detect_uiux_pro_max    2>/dev/null; then PLUGIN_TOKENS=$((PLUGIN_TOKENS + 400)); fi
if detect_context7    2>/dev/null; then PLUGIN_TOKENS=$((PLUGIN_TOKENS + 200)); fi
if detect_graphifyy   2>/dev/null; then PLUGIN_TOKENS=$((PLUGIN_TOKENS + 300)); fi

TOTAL_TOKENS=$((CLAUDE_MD_TOKENS + SKILL_DESC_TOKENS + PLUGIN_TOKENS))
SESSION_BUDGET=11000
PCT=$((TOTAL_TOKENS * 100 / SESSION_BUDGET))

echo ""
echo "  CLAUDE.md:           ~${CLAUDE_MD_TOKENS}t"
echo "  Skill descriptions:  ~${SKILL_DESC_TOKENS}t  (${SKILL_COUNT} skills)"
echo "  Plugin passive cost: ~${PLUGIN_TOKENS}t  (active plugins)"
echo "  ─────────────────────────────────────────"
info "  Total:               ~${TOTAL_TOKENS}t"
info "  Session budget (Pro): ${SESSION_BUDGET}t"
info "  Usage:               ~${PCT}%"
echo ""

if [ "$PCT" -gt 30 ]; then
  warn "CRITICAL: ${PCT}% of session budget — /plugin-check to disable unused plugins"
elif [ "$PCT" -gt 15 ]; then
  warn "WARNING: ${PCT}% of session budget — consider disabling unused toggle plugins"
else
  pass "Budget: ${PCT}% (comfortable)"
fi

# Per-file breakdown (skill bodies — loaded on demand, shown for awareness)
if [ "$TOTAL_TOKENS" -gt 2000 ]; then
  info "Skill/agent bodies (loaded on demand, >200t each):"
  for f in "$HOME/.claude/skills/"*/SKILL.md "$HOME/.claude/agents/"*.md; do
    [ -f "$f" ] || continue
    size=$(wc -c < "$f" 2>/dev/null || echo 0)
    tokens=$((size / 4))
    if [ "$tokens" -gt 200 ]; then
      label=$(basename "$(dirname "$f")" 2>/dev/null)
      [ "$label" = "." ] && label=$(basename "$f")
      info "  ~${tokens}t  ${label}"
    fi
  done
fi

echo ""

# ────────────────────────────────────────────────────────────
# 7. File consistency
# ────────────────────────────────────────────────────────────
echo "── Consistency ──"

# Check gstack shared infrastructure symlinks
if [ -L "$HOME/.claude/skills/gstack/bin" ]; then
  pass "gstack/bin/ symlink OK"
else
  warn "gstack/bin/ symlink missing — run: bash link.sh"
fi
if [ -L "$HOME/.claude/skills/gstack/browse/dist" ]; then
  pass "gstack/browse/dist/ symlink OK"
else
  warn "gstack/browse/dist/ symlink missing — run: bash link.sh"
fi

# Check owned skills have disable-model-invocation (skip external/symlinked skills)
MISSING_DMI=()
for f in "$HOME/.claude/skills/"*/SKILL.md; do
  [ -f "$f" ] || continue
  dir=$(dirname "$f")
  # Skip external skills (symlinked directory or symlinked SKILL.md — not owned by this repo)
  [ -L "$dir" ] && continue
  [ -L "$f" ] && continue
  name=$(basename "$dir")
  if ! grep -q "disable-model-invocation" "$f" 2>/dev/null; then
    MISSING_DMI+=("$name")
  fi
done
if [ ${#MISSING_DMI[@]} -eq 0 ]; then
  pass "All owned skills have disable-model-invocation"
else
  warn "Owned skills missing disable-model-invocation: ${MISSING_DMI[*]}"
fi

# Check expected skills are present
EXPECTED_SKILLS=(
  "analyze" "doc" "health" "init-project" "onboard" "plugin-check"
  "refactor" "ship-feature" "status"
)
MISSING_SKILLS=()
for skill in "${EXPECTED_SKILLS[@]}"; do
  if [ ! -f "$HOME/.claude/skills/${skill}/SKILL.md" ]; then
    MISSING_SKILLS+=("${skill}/")
  fi
done
if [ ${#MISSING_SKILLS[@]} -eq 0 ]; then
  pass "All ${#EXPECTED_SKILLS[@]} expected skills present (analyze, doc, health, init-project, onboard, plugin-check, refactor, ship-feature, status)"
else
  warn "Missing skills: ${MISSING_SKILLS[*]} — run: bash link.sh"
fi

# Check expected agents are present
EXPECTED_AGENTS=(
  "analyzer" "interviewer" "plugin-advisor" "doc-syncer"
  "refactorer" "scaffolder" "onboarder" "status-reporter"
)
MISSING_AGENTS=()
for agent in "${EXPECTED_AGENTS[@]}"; do
  if [ ! -f "$HOME/.claude/agents/${agent}.md" ]; then
    MISSING_AGENTS+=("${agent}.md")
  fi
done
if [ ${#MISSING_AGENTS[@]} -eq 0 ]; then
  pass "All 8 agents present (analyzer, interviewer, plugin-advisor, doc-syncer, refactorer, scaffolder, onboarder, status-reporter)"
else
  warn "Missing agents: ${MISSING_AGENTS[*]} — run: bash link.sh"
fi

# Check CRLF — portable: grep -P not available on macOS BSD grep
CRLF_FILES=()
for f in "$REPO"/*.md "$REPO"/agents/*.md "$REPO"/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  if grep -c $'\r' "$f" 2>/dev/null | grep -q "^[^0]"; then
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
