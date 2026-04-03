#!/usr/bin/env bash
# ============================================================
# Claude Code — Plugin installer
# Run this after a fresh clone to reinstall all plugins
# and their prerequisites on a new machine.
#
# Supports: Linux (apt/dnf/pacman), macOS (brew)
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
info() { echo -e "${BLUE}→${NC} $1"; }
err()  { echo -e "${RED}✗${NC} $1"; }

REPO="$(cd "$(dirname "$0")" && pwd)"

# Log to file for post-mortem debugging (terminal output unchanged)
LOG_FILE="$REPO/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Load shared detection library
# shellcheck source=lib/detect-plugins.sh
source "$REPO/lib/detect-plugins.sh"

# Read pinned version from plugins.lock.json
# Usage: pinned_version "rtk" → prints version string or "latest"
pinned_version() {
  local key="$1"
  if [ -f "$REPO/plugins.lock.json" ] && command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
with open('$REPO/plugins.lock.json') as f:
    d = json.load(f)
v = d.get('$key', {}).get('version', 'latest')
print(v)
" 2>/dev/null || echo "latest"
  else
    echo "latest"
  fi
}

# ============================================================
# DETECT OS
# ============================================================
OS="unknown"
PKG=""
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
elif command -v apt-get &>/dev/null; then
  OS="linux-apt"; PKG="apt-get"
elif command -v dnf &>/dev/null; then
  OS="linux-dnf"; PKG="dnf"
elif command -v pacman &>/dev/null; then
  OS="linux-pacman"; PKG="pacman"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║        Claude Code — Plugin & Tool Installer             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
info "OS: $OS | Repo: $REPO"
echo ""

# ============================================================
# STEP 1 — PREREQUISITES
# ============================================================
echo "── Step 1: Prerequisites ───────────────────────────────────"
echo ""

# --- git ---
if command -v git &>/dev/null; then
  ok "git $(git --version | awk '{print $3}')"
else
  info "Installing git..."
  case $OS in
    macos)        brew install git ;;
    linux-apt)    sudo apt-get install -y git ;;
    linux-dnf)    sudo dnf install -y git ;;
    linux-pacman) sudo pacman -S --noconfirm git ;;
    *) err "Cannot auto-install git on $OS — install manually"; exit 1 ;;
  esac
  ok "git installed"
fi

# --- Node.js (>=18) ---
NODE_OK=false
if command -v node &>/dev/null; then
  NODE_VER=$(node --version | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_VER" -ge 18 ]; then
    ok "Node.js $(node --version)"; NODE_OK=true
  else
    warn "Node.js $(node --version) is too old (need >=18)"
  fi
fi
if [ "$NODE_OK" = false ]; then
  info "Installing Node.js 22 LTS..."
  case $OS in
    macos)
      brew install node@22
      export PATH="/opt/homebrew/opt/node@22/bin:$PATH"
      ;;
    linux-apt)
      curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
      sudo apt-get install -y nodejs
      ;;
    linux-dnf)
      curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
      sudo dnf install -y nodejs
      ;;
    linux-pacman)
      sudo pacman -S --noconfirm nodejs npm
      ;;
    *) warn "Cannot auto-install Node.js on $OS — install from https://nodejs.org" ;;
  esac
  command -v node &>/dev/null && ok "Node.js $(node --version)" || err "Node.js install failed"
fi

# --- Rust + Cargo (for RTK) ---
if command -v cargo &>/dev/null; then
  ok "Rust/Cargo $(cargo --version | awk '{print $2}')"
else
  info "Installing Rust (rustup)..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  source "$HOME/.cargo/env"
  ok "Rust installed: $(cargo --version)"
fi

# --- Python 3 ---
if command -v python3 &>/dev/null; then
  ok "Python $(python3 --version)"
else
  info "Installing Python 3..."
  case $OS in
    macos)        brew install python3 ;;
    linux-apt)    sudo apt-get install -y python3 ;;
    linux-dnf)    sudo dnf install -y python3 ;;
    linux-pacman) sudo pacman -S --noconfirm python ;;
    *) warn "Cannot auto-install Python on $OS" ;;
  esac
fi

# --- Claude Code CLI ---
if command -v claude &>/dev/null; then
  ok "Claude Code $(claude --version 2>/dev/null | head -1)"
else
  err "Claude Code not installed. Install from https://code.claude.com then re-run."
  exit 1
fi

echo ""

# ============================================================
# STEP 2 — GSTACK SUBMODULE
# ============================================================
echo "── Step 2: GStack submodule ─────────────────────────────────"
echo ""
# Note: GStack is managed as a git submodule in this repo.
# It lives at skills-external/gstack/ and is symlinked to ~/.claude/skills/gstack/
# by link.sh. Never clone it separately — use the submodule.
#
# First-time setup:
#   git submodule update --init --recursive
# Update to latest:
#   git submodule update --remote skills-external/gstack
#   cd skills-external/gstack && ./setup
#   git add skills-external/gstack && git commit -m "chore: update gstack"

GSTACK_DIR="$REPO/skills-external/gstack"

if [ ! -d "$GSTACK_DIR/.git" ] && [ ! -f "$GSTACK_DIR/.git" ]; then
  info "Initializing GStack submodule..."
  cd "$REPO"
  git submodule update --init --recursive
  cd - > /dev/null
fi

if [ -d "$GSTACK_DIR" ]; then
  info "Running GStack setup..."
  cd "$GSTACK_DIR" && ./setup && cd - > /dev/null
  # Symlinks are handled by link.sh — verify it was run
  if [ -L "$HOME/.claude/skills/gstack" ]; then
    ok "GStack ready (submodule initialized, symlink OK)"
  else
    warn "GStack submodule ready but not symlinked — run: bash link.sh"
  fi
else
  warn "GStack submodule directory not found after init — check .gitmodules"
fi

echo ""

# ============================================================
# STEP 3 — RTK
# ============================================================
echo "── Step 3: RTK — Rust Token Killer ─────────────────────────"
echo ""
if command -v rtk &>/dev/null; then
  ok "rtk already installed ($(rtk --version 2>/dev/null | head -1))"
else
  RTK_VER=$(pinned_version "rtk")
  if [ "$RTK_VER" != "latest" ]; then
    info "Installing RTK $RTK_VER (pinned in plugins.lock.json)..."
    cargo install --git https://github.com/rtk-ai/rtk --tag "$RTK_VER"
  else
    info "Installing RTK (latest — consider pinning in plugins.lock.json)..."
    cargo install --git https://github.com/rtk-ai/rtk
  fi
fi
info "Configuring RTK PreToolUse hook (global)..."
rtk init -g --auto-patch
ok "RTK configured"
echo ""

# ============================================================
# STEP 4 — GSD
# ============================================================
echo "── Step 4: GSD — get-shit-done ─────────────────────────────"
echo ""
info "Installing GSD globally..."
GSD_VER=$(pinned_version "gsd")
if [ "$GSD_VER" != "latest" ]; then
  info "Version $GSD_VER (pinned in plugins.lock.json)"
  npx "get-shit-done-cc@$GSD_VER" --claude --global --auto
else
  info "Version: latest (consider pinning in plugins.lock.json)"
  npx get-shit-done-cc --claude --global --auto
fi
ok "GSD installed"
echo ""

# ============================================================
# STEP 5 — MARKETPLACE PLUGINS (user scope, explicit)
# ============================================================
# All claude plugin install commands use --scope user to ensure
# they install to ~/.claude/plugins/ regardless of working directory.
echo "── Step 5: Marketplace plugins (scope: user) ────────────────"
echo ""

install_plugin() {
  local name="$1"
  local source="$2"
  info "Installing $name..."
  claude plugin install --scope user "$name@$source" 2>/dev/null \
    && ok "$name" \
    || warn "$name — skipped (already installed or failed)"
}

# Official Anthropic (always on)
install_plugin "security-guidance"  "claude-plugins-official"
install_plugin "frontend-design"    "claude-plugins-official"
install_plugin "skill-creator"      "claude-plugins-official"
install_plugin "pr-review-toolkit"  "claude-plugins-official"

echo ""

# Superpowers (always on)
info "Adding Superpowers marketplace..."
claude plugin marketplace add obra/superpowers-marketplace 2>/dev/null || true
install_plugin "superpowers" "superpowers-marketplace"

echo ""

# UI/UX Pro Max (toggle)
info "Adding UI/UX Pro Max marketplace..."
claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill 2>/dev/null || true
install_plugin "ui-ux-pro-max" "ui-ux-pro-max-skill"

echo ""

# ============================================================
# STEP 6 — CONTEXT7 MCP (manual — requires API key)
# ============================================================
echo "── Step 6: Context7 MCP ─────────────────────────────────────"
echo ""
if claude mcp list 2>/dev/null | grep -q "context7"; then
  ok "Context7 MCP already configured"
else
  warn "Context7 requires a free API key — cannot auto-install"
  echo ""
  echo "  Steps:"
  echo "  1. Get a free key at https://context7.com"
  echo "  2. Run:"
  echo "     claude mcp add --scope user context7 -- \\"
  echo "       npx -y @upstash/context7-mcp --api-key YOUR_KEY"
  echo ""
fi

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                     Install Summary                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  ALWAYS ON (installed at user scope, ~10 tokens/session each):"
echo "    ✅ security-guidance   — PreToolUse security hook (0 tokens)"
echo "    ✅ rtk                 — token compression hook (0 tokens)"
echo "    ✅ superpowers         — brainstorm/plan/implement/debug workflow"
echo "    ✅ skill-creator       — create skills from conversation"
echo "    ✅ pr-review-toolkit   — /pr-review-toolkit:review-pr"
echo ""
echo "  TOGGLE (installed but start OFF — /plugin-check recommends when needed):"
echo "    🔄 gstack              — ~/.claude/skills/gstack/ (→ submodule)"
echo "    🔄 gsd                 — ~/.claude/skills/ (npx)"
echo "    🔄 frontend-design     — user scope"
echo "    🔄 ui-ux-pro-max       — user scope"
echo "    🔄 context7 MCP        — see Step 6 above"
echo ""
echo "  All plugins installed at: user scope (~/.claude/plugins/)"
echo "  GStack at: ~/.claude/skills/gstack/ (symlink → submodule)"
echo ""
echo "  → Restart Claude Code"
echo "  → Run /reload-plugins"
echo ""
