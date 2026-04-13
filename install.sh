#!/usr/bin/env bash
# ============================================================
# Claude Code — Bootstrap installer
# Installs Claude Code CLI, authenticates, then sets up
# symlinks and plugins for the claude-config repo.
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
info() { echo -e "${BLUE}→${NC} $1"; }
err()  { echo -e "${RED}✗${NC} $1"; exit 1; }

REPO="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "═══ claude-config bootstrap installer ═══"
echo ""

# ── 1. Check prerequisites ──
echo "── Checking prerequisites..."

if ! command -v node &>/dev/null; then
  err "Node.js not found. Install it first: https://nodejs.org"
fi

NODE_MAJOR=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_MAJOR" -lt 18 ]; then
  err "Node.js >= 18 required (found $(node -v))"
fi
ok "Node.js $(node -v)"

if ! command -v npm &>/dev/null; then
  err "npm not found"
fi
ok "npm $(npm -v)"

# ── 2. Install Claude Code CLI ──
echo ""
echo "── Installing Claude Code (latest)..."

if npm install -g @anthropic-ai/claude-code@latest; then
  ok "Claude Code installed: $(claude --version 2>/dev/null || echo 'unknown')"
else
  err "Claude Code installation failed"
fi

# ── 3. Authenticate ──
echo ""
echo "── Authentication"
echo ""
echo "  You need to log in to Claude Code."
echo "  This will open an interactive session."
echo ""
printf "  Press Enter to launch 'claude login'... "
read -r

if claude login; then
  ok "Authenticated"
else
  warn "Login exited with non-zero status"
  warn "You can retry later with: claude login"
fi

# ── 4. Init git submodules ──
echo ""
echo "── Initializing submodules..."
cd "$REPO"
if git submodule update --init 2>/dev/null; then
  ok "Submodules initialized"
else
  warn "Submodule init failed — some plugins may be unavailable"
fi

# ── 5. Symlink config into ~/.claude/ ──
echo ""
echo "── Setting up symlinks..."
bash "$REPO/link.sh"

# ── 6. Install plugins ──
echo ""
echo "── Installing plugins..."
bash "$REPO/install-plugins.sh"

# ── Done ──
echo ""
echo "═══════════════════════════════════════════"
echo ""
ok "Bootstrap complete!"
echo ""
echo "  Start Claude Code in any project with:"
echo "    claude"
echo ""
