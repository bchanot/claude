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

# node + npm are needed by the plugins step (install-plugins.sh: gsd-pi et al.);
# Claude Code itself now installs via its own native installer below. On a fresh
# machine node/npm may be absent — install the current LTS via nvm, not abort.
install_node_via_nvm() {
  info "Node.js/npm missing — installing LTS via nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  # shellcheck source=/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm install --lts
}

if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
  install_node_via_nvm
fi

if ! command -v node &>/dev/null; then
  err "Node.js install failed — install it manually: https://nodejs.org"
fi

NODE_MAJOR=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_MAJOR" -lt 18 ]; then
  err "Node.js >= 18 required (found $(node -v))"
fi
ok "Node.js $(node -v)"

if ! command -v npm &>/dev/null; then
  err "npm not found (expected alongside Node.js)"
fi
ok "npm $(npm -v)"

# ── 2. Install Claude Code CLI ──
echo ""
echo "── Installing Claude Code..."

# Idempotent + official channel. Skip if already present (mirrors the RTK/GSD
# guard) — the binary is a native-installer symlink at ~/.local/bin/claude that
# self-updates. On a fresh machine install via the official native installer
# (code.claude.com/docs quickstart), NOT npm: npm is no longer a documented
# channel, would collide with the native symlink (EEXIST), and bypasses the
# built-in auto-update. Upgrades are `make update`'s job, not first-time install.
if command -v claude &>/dev/null; then
  ok "Claude Code already installed ($(claude --version 2>/dev/null | head -1))"
elif curl -fsSL https://claude.ai/install.sh | bash; then
  # Native installer targets ~/.local/bin — put it on PATH for the auth +
  # verification steps that follow in this same (non-login) shell.
  export PATH="$HOME/.local/bin:$PATH"
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

# ── 5b. Optional: connect a Google account for /seo FULL ──
echo ""
if [ -f "$HOME/.claude/seo-data/tokens.json" ]; then
  ok "seo-data: a Google account is already connected"
else
  info "SEO data layer (GSC + CrUX) is optional. To enable real Search Console"
  info "data in /seo FULL: add GOOGLE_OAUTH_* + CRUX_API_KEY to ~/.claude/.env,"
  info "then run:  make seo-connect"
fi

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
