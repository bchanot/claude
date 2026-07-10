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

  # Broken symlink: points at a target that no longer exists.
  if [ -L "$target" ] && [ ! -e "$target" ]; then
    fail "$HOME/.claude/$name → $(readlink "$target") — BROKEN SYMLINK"
    return
  fi

  # Correctly wired iff the canonical path lands inside the repo. This is true
  # for a direct symlink (CLAUDE.md, settings.json) AND for a real file reached
  # through a symlinked ANCESTOR dir (hooks/, skills/, agents/, lib/, templates/
  # are dir-level symlinks — their children are real files under $REPO). A stray
  # real copy in ~/.claude resolves to itself (outside $REPO) → still flagged as
  # drift. (LRN-047: the dir-symlink layout is legitimate, must not false-warn.)
  local real
  real=$(readlink -f "$target" 2>/dev/null) || real="$target"
  case "$real" in
    "$REPO"/*) pass "$HOME/.claude/$name"; _LINK_PASS=$((_LINK_PASS + 1)) ;;
    *) warn "$HOME/.claude/$name resolves to $real (outside repo — expected a link into $REPO)" ;;
  esac
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

# GStack skills are exposed as PER-SKILL symlinks directly under skills/ (browse,
# cso, review, …) pointing into skills-external/gstack/ — there is NO single
# skills/gstack symlink (link.sh deliberately removes it: it duplicated the
# top-level gstack SKILL.md alongside the per-skill entries). The bin/ +
# browse/dist/ helper links under skills/gstack/ are checked in §7 Consistency.
# `|| true` guards pipefail if skills/ is unexpectedly absent (checked above).
gstack_skill_links=$( { find "$HOME/.claude/skills/" -maxdepth 1 -type l -lname '*skills-external/gstack/*' 2>/dev/null || true; } | wc -l | tr -d ' ')
if [ "${gstack_skill_links:-0}" -gt 0 ]; then
  pass "GStack: ${gstack_skill_links} skills linked (per-skill symlinks)"
else
  warn "GStack skills not linked — run: cd skills-external/gstack && ./setup"
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

if command -v jq &>/dev/null; then
  pass "jq $(jq --version 2>/dev/null | sed 's/^jq-//')"
else
  fail "jq not found — statusline & rtk-rewrite hooks require it"
fi

if command -v cargo &>/dev/null; then
  pass "Cargo $(cargo --version | awk '{print $2}')"
else
  # Cargo does NOT gate RTK: RTK ships as a prebuilt binary and detect_rtk finds
  # it via ~/.cargo/bin or ~/.local/bin (RTK status is shown under Plugins).
  # Cargo is only the Rust toolchain to BUILD RTK from source → optional, info.
  info "Cargo not found (optional — only needed to build RTK from source)"
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
    # Expected = deny count in the last COMMITTED settings.json. A hardcoded
    # number drifts on every legit deny-list edit (false-warned for weeks at
    # 100 vs 99 — LRN-047 class); deriving from HEAD auto-tracks legit edits
    # and still flags live-vs-committed divergence.
    EXPECTED_DENY=$(git -C "$REPO" show HEAD:settings.json 2>/dev/null | python3 -c "
import json,sys
print(len(json.load(sys.stdin).get('permissions',{}).get('deny',[])))
" 2>/dev/null || echo "?")
    if [ "$EXPECTED_DENY" = "?" ]; then
      warn "Could not derive expected deny count from committed settings.json"
    elif [ "$DENY_COUNT" -eq "$EXPECTED_DENY" ] 2>/dev/null; then
      pass "Deny rules: $DENY_COUNT (matches committed settings.json)"
    else
      warn "Deny rules: $DENY_COUNT (committed: $EXPECTED_DENY) — live settings diverge from last commit"
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
# The passive footprint (CLAUDE.md + skill descriptions + plugin session-injects)
# loads into the CONTEXT WINDOW every session — it competes with the ~200k default
# context, NOT a per-session token quota (the old "~11k/5h budget" denominator was
# a category error → false "92% CRITICAL", LRN-047). Measured ~11.4k post-audit
# 2026-07-02 (LRN-088); the chars/4 sum below is a coarse proxy of that footprint.
# Thresholds: WARNING >15% of context (~30k), CRITICAL >25% (~50k).

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
CONTEXT_WINDOW=200000   # Claude Code default context window (conservative; 1M is opt-in)
PCT=$((TOTAL_TOKENS * 100 / CONTEXT_WINDOW))

echo ""
echo "  CLAUDE.md:           ~${CLAUDE_MD_TOKENS}t"
echo "  Skill descriptions:  ~${SKILL_DESC_TOKENS}t  (${SKILL_COUNT} skills)"
echo "  Plugin passive cost: ~${PLUGIN_TOKENS}t  (active plugins)"
echo "  ─────────────────────────────────────────"
info "  Total:               ~${TOTAL_TOKENS}t  (measured ~11.4k post-audit, LRN-088)"
info "  Context window:      ${CONTEXT_WINDOW}t  (default; 1M opt-in)"
info "  Usage:               ~${PCT}% of context"
echo ""

if [ "$PCT" -gt 25 ]; then
  warn "CRITICAL: ~${PCT}% of the ${CONTEXT_WINDOW}t context — /plugin-check to disable unused plugins"
elif [ "$PCT" -gt 15 ]; then
  warn "WARNING: ~${PCT}% of the ${CONTEXT_WINDOW}t context — consider disabling unused toggle plugins"
else
  pass "Budget: ~${PCT}% of context (comfortable)"
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

# BDR-019 (2026-06-09) stripped disable-model-invocation repo-wide so the
# model/orchestrators can self-route. The old check required the key on
# every owned skill — permanent false-warn since. Inverted: warn if any
# owned skill REintroduces the key (regression watch on BDR-019).
PRESENT_DMI=()
for f in "$HOME/.claude/skills/"*/SKILL.md; do
  [ -f "$f" ] || continue
  dir=$(dirname "$f")
  # Skip external skills (symlinked directory or symlinked SKILL.md — not owned by this repo)
  [ -L "$dir" ] && continue
  [ -L "$f" ] && continue
  name=$(basename "$dir")
  if grep -q "disable-model-invocation" "$f" 2>/dev/null; then
    PRESENT_DMI+=("$name")
  fi
done
if [ ${#PRESENT_DMI[@]} -eq 0 ]; then
  pass "No owned skill carries disable-model-invocation (BDR-019)"
else
  warn "Owned skills reintroduce disable-model-invocation (BDR-019 regression): ${PRESENT_DMI[*]}"
fi

# Check expected skills are present. Repo-owned skills only: gstack skills
# (health, status, …) are OFF by default and toggled per profile — requiring
# them here false-warns on a default install, and "run link.sh" cannot
# restore them (they are profile-managed, not link.sh-managed).
EXPECTED_SKILLS=(
  "analyze" "doc" "init-project" "onboard" "plugin-check"
  "refactor" "ship-feature" "status"
)
MISSING_SKILLS=()
for skill in "${EXPECTED_SKILLS[@]}"; do
  if [ ! -f "$HOME/.claude/skills/${skill}/SKILL.md" ]; then
    MISSING_SKILLS+=("${skill}/")
  fi
done
if [ ${#MISSING_SKILLS[@]} -eq 0 ]; then
  pass "All ${#EXPECTED_SKILLS[@]} expected skills present (${EXPECTED_SKILLS[*]})"
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

# ── seo-data (GSC/CrUX data layer) — non-fatal ──
ENVF="$HOME/.claude/.env"
if grep -qE '^[[:space:]]*(export[[:space:]]+)?CRUX_API_KEY=.' "$ENVF" 2>/dev/null; then
  pass "seo-data: CRUX_API_KEY present"
else
  warn "seo-data: CRUX_API_KEY absent in ~/.claude/.env — /seo FULL falls back to lab PageSpeed"
fi
STORE="$HOME/.claude/seo-data/tokens.json"
if [ -f "$STORE" ]; then
  N=$(python3 "$REPO/lib/seo-data/tokenstore.py" list --file "$STORE" 2>/dev/null | grep -o '"label"' | wc -l)
  pass "seo-data: $N Google account(s) connected"
else
  warn "seo-data: no Google account connected (run: make seo-connect) — GSC data disabled"
fi

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
