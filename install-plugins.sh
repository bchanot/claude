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
if touch "$LOG_FILE" 2>/dev/null; then
  exec > >(tee -a "$LOG_FILE") 2>&1
  info "Logging to $LOG_FILE"
else
  warn "Cannot write log to $REPO — continuing without log file"
fi

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
  if [ "$NODE_VER" -ge 22 ]; then
    ok "Node.js $(node --version)"; NODE_OK=true
  else
    warn "Node.js $(node --version) is too old (need >=22 — GSD v2 requires it)"
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

# --- pipx (for Graphifyy) ---
if command -v pipx &>/dev/null; then
  ok "pipx $(pipx --version 2>/dev/null)"
else
  info "Installing pipx..."
  case $OS in
    macos)        brew install pipx ;;
    linux-apt)    sudo apt-get install -y pipx ;;
    linux-dnf)    sudo dnf install -y pipx ;;
    linux-pacman) sudo pacman -S --noconfirm python-pipx ;;
    *) warn "Cannot auto-install pipx on $OS" ;;
  esac
  pipx ensurepath 2>/dev/null || true
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
  # --- bun (required by GStack ./setup) ---
  if ! command -v bun &>/dev/null; then
    info "Installing bun (required by GStack)..."
    BUN_VERSION="1.3.10"
    tmpfile=$(mktemp)
    curl -fsSL "https://bun.sh/install" -o "$tmpfile"
    BUN_VERSION="$BUN_VERSION" bash "$tmpfile" && rm -f "$tmpfile"
    export PATH="$HOME/.bun/bin:$PATH"
    command -v bun &>/dev/null && ok "bun $(bun --version)" || err "bun install failed"
  else
    ok "bun $(bun --version)"
  fi

  info "Running GStack setup..."
  if [ -x "$GSTACK_DIR/setup" ]; then
    if (cd "$GSTACK_DIR" && ./setup); then
      : # setup succeeded
    else
      warn "GStack ./setup failed — check output above"
    fi
  else
    warn "GStack ./setup not found or not executable — skipping"
  fi
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
# Only init if not already configured (avoids overwriting custom RTK config)
if ! grep -q "rtk" "$HOME/.claude/settings.json" 2>/dev/null; then
  info "Configuring RTK PreToolUse hook (global)..."
  rtk init -g --auto-patch
  ok "RTK configured"
else
  ok "RTK hook already present in settings.json — skipping init"
fi
echo ""

# ============================================================
# STEP 4 — GSD v2
# ============================================================
# GSD v2 (gsd-pi) is a standalone CLI built on the Pi SDK.
# It is NOT a Claude Code plugin — it runs as an external process ('gsd' command).
# Usage: run 'gsd' in your terminal from a project directory.
# Slash commands (/gsd auto, /gsd status, etc.) are internal to a GSD session.
echo "── Step 4: GSD v2 — gsd-pi ─────────────────────────────────"
echo ""
if command -v gsd &>/dev/null; then
  ok "gsd already installed ($(gsd --version 2>/dev/null | head -1 || echo 'installed'))"
else
  GSD_VER=$(pinned_version "gsd")
  if [ "$GSD_VER" != "latest" ]; then
    info "Installing gsd-pi@${GSD_VER} (pinned in plugins.lock.json)..."
    npm install -g "gsd-pi@${GSD_VER}"
  else
    info "Installing gsd-pi@latest (consider pinning in plugins.lock.json)..."
    npm install -g gsd-pi
  fi
  command -v gsd &>/dev/null && ok "GSD v2 installed ($(gsd --version 2>/dev/null | head -1))" \
    || err "GSD v2 install failed — check npm output above"
fi
echo ""

# ============================================================
# STEP 5 — RUFLO CLI (enterprise multi-agent orchestration)
# ============================================================
# Ruflo (formerly claude-flow) is an enterprise multi-agent orchestration CLI.
# 310+ tools, 100+ agent types, WASM kernel, self-learning architecture.
# Use only for projects requiring complex multi-agent coordination.
# Default install ~340MB. Minimal: npm install -g ruflo@latest --omit=optional (~15s)
echo "── Step 5: Ruflo CLI ──────────────────────────────────────"
echo ""
if detect_ruflo; then
  ok "Ruflo CLI already installed ($(ruflo --version 2>/dev/null | head -1 || echo 'installed'))"
else
  RUFLO_VER=$(pinned_version "ruflo")
  if [ "$RUFLO_VER" != "latest" ]; then
    info "Installing ruflo@${RUFLO_VER} (pinned, minimal --omit=optional)..."
    npm install -g "ruflo@${RUFLO_VER}" --omit=optional
  else
    info "Installing ruflo@latest (minimal --omit=optional)..."
    npm install -g ruflo@latest --omit=optional
  fi
  command -v ruflo &>/dev/null && ok "Ruflo CLI installed ($(ruflo --version 2>/dev/null | head -1))" \
    || err "Ruflo install failed — run manually: npm install -g ruflo@latest --omit=optional"
fi
if command -v ruflo &>/dev/null; then
  info "Init in a project: ruflo init --wizard"
  info "Spawn agent: ruflo agent spawn -t coder"
  info "Start swarm: ruflo swarm init"
  info "Diagnostics: ruflo doctor"
fi

# ============================================================
# STEP 6 — MARKETPLACE PLUGINS (user scope, explicit)
# ============================================================
# All claude plugin install commands use --scope user to ensure
# they install to ~/.claude/plugins/ regardless of working directory.
echo "── Step 6: Marketplace plugins (scope: user) ────────────────"
echo ""

install_plugin() {
  local name="$1"
  local source="$2"
  if claude plugin list 2>/dev/null | grep -qi "$name"; then
    ok "$name (already installed)"
    return
  fi
  info "Installing $name..."
  if claude plugin install --scope user "$name@$source" 2>/dev/null; then
    ok "$name"
  else
    err "$name — FAILED (run manually: claude plugin install --scope user $name@$source)"
  fi
}

# Anthropic bundled plugins (from anthropics/claude-code repo)
# These are NOT in claude-plugins-official — they require the claude-code marketplace
info "Adding Anthropic bundled plugins marketplace..."
claude plugin marketplace add anthropics/claude-code 2>/dev/null || true

info "Adding Anthropic skills marketplace..."
claude plugin marketplace add anthropics/skills 2>/dev/null || true
install_plugin "security-guidance"  "claude-code-plugins"
# skill-creator is in "example-skills" plugin from anthropics/skills marketplace
# (not in claude-code marketplace — it's a separate repo)
install_plugin "example-skills"     "anthropic-agent-skills"
# install_plugin "frontend-design"    "claude-code-plugins"
install_plugin "pr-review-toolkit"  "claude-code-plugins"
install_plugin "plugin-dev"         "claude-code-plugins"

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
# STEP 7 — CONTEXT7 CLI (ctx7)
# ============================================================
echo "── Step 7: Context7 CLI ─────────────────────────────────────"
echo ""
if command -v ctx7 &>/dev/null; then
  ok "ctx7 already installed ($(ctx7 --version 2>/dev/null | head -1 || echo 'installed'))"
else
  CTX7_VER=$(pinned_version "ctx7")
  if [ "$CTX7_VER" != "latest" ]; then
    info "Installing ctx7@${CTX7_VER} (pinned in plugins.lock.json)..."
    npm install -g "ctx7@${CTX7_VER}"
  else
    info "Installing ctx7@latest (consider pinning in plugins.lock.json)..."
    npm install -g ctx7
  fi
  command -v ctx7 &>/dev/null && ok "ctx7 installed ($(ctx7 --version 2>/dev/null | head -1))" \
    || err "ctx7 install failed — run manually: npm install -g ctx7"
fi
# Suggest setup for Claude Code integration (optional — ctx7 also works standalone)
if command -v ctx7 &>/dev/null; then
  info "Run 'ctx7 setup --claude' to configure Context7 for Claude Code"
  info "Or use ctx7 standalone: ctx7 docs /vercel/next.js \"middleware\""
  info "Free higher rate limits: ctx7 login (OAuth) or --api-key from context7.com/dashboard"
fi

# ============================================================
# STEP 8 — GRAPHIFYY (codebase knowledge graph)
# ============================================================
echo "── Step 8: Graphifyy — Knowledge Graph ──────────────────────"
echo ""
if command -v graphify &>/dev/null; then
  ok "graphify already installed"
else
  info "Installing graphifyy via pipx..."
  pipx install graphifyy 2>/dev/null \
    && ok "graphifyy installed" \
    || err "graphifyy install failed — run manually: pipx install graphifyy"
fi
if command -v graphify &>/dev/null; then
  info "Running graphify install (dependencies)..."
  graphify install 2>/dev/null || warn "graphify install failed — run manually"
  info "Configuring Claude Code integration..."
  graphify claude install 2>/dev/null || warn "graphify claude install failed — run manually"
  ok "Graphifyy configured for Claude Code"
fi
echo ""

# ============================================================
# STEP 9 — EMIL DESIGN ENG (UI polish / animation skill)
# ============================================================
echo "── Step 9: Emil Design Engineering ─────────────────────────"
echo ""
EMIL_DIR="$REPO/skills-external/emil-design-eng"
EMIL_URL="https://raw.githubusercontent.com/emilkowalski/skill/main/skills/emil-design-eng/SKILL.md"
mkdir -p "$EMIL_DIR"
if [ -f "$EMIL_DIR/SKILL.md" ]; then
  ok "emil-design-eng already downloaded"
else
  info "Downloading SKILL.md from emilkowalski/skill..."
  curl -fsSL "$EMIL_URL" -o "$EMIL_DIR/SKILL.md" \
    && ok "emil-design-eng installed" \
    || err "emil-design-eng download failed — try: curl -fsSL $EMIL_URL -o $EMIL_DIR/SKILL.md"
fi
# Symlink handled by link.sh
if [ -L "$HOME/.claude/skills/emil-design-eng" ]; then
  ok "emil-design-eng symlink OK"
else
  info "Symlinking — will be created by link.sh"
fi
echo ""

# ============================================================
# STEP 10 — SHELL CONFIG (alias + env vars)
# ============================================================
echo "── Step 10: Claude Code shell config (alias + env vars) ────"
echo ""

# Detect shell profile
SHELL_PROFILE=""
if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "$SHELL" 2>/dev/null)" = "zsh" ]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [ -n "${BASH_VERSION:-}" ] || [ "$(basename "$SHELL" 2>/dev/null)" = "bash" ]; then
  SHELL_PROFILE="$HOME/.bashrc"
fi
# Fallback to .profile (works with sh, dash, etc.)
[ -z "$SHELL_PROFILE" ] && SHELL_PROFILE="$HOME/.profile"

CLAUDE_LINES=(
  "alias claude='claude --effort max'"
  'export CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1'
)

# Clean up old CLAUDE_EFFORT env var if present (replaced by alias)
if grep -qF 'export CLAUDE_EFFORT=max' "$SHELL_PROFILE" 2>/dev/null; then
  sed -i '/export CLAUDE_EFFORT=max/d' "$SHELL_PROFILE"
  # Also remove orphaned comment lines left by previous installs
  sed -i '/^# Claude Code — added by install-plugins.sh$/{ N; /^\n$/d; }' "$SHELL_PROFILE"
  info "Removed old CLAUDE_EFFORT=max from $SHELL_PROFILE (replaced by alias)"
fi

ADDED=0
for line in "${CLAUDE_LINES[@]}"; do
  if grep -qF "$line" "$SHELL_PROFILE" 2>/dev/null; then
    ok "$line (already in $SHELL_PROFILE)"
  else
    echo "" >> "$SHELL_PROFILE"
    echo "# Claude Code — added by install-plugins.sh" >> "$SHELL_PROFILE"
    echo "$line" >> "$SHELL_PROFILE"
    ok "$line → $SHELL_PROFILE"
    ADDED=1
  fi
done

if [ "$ADDED" -eq 1 ]; then
  info "Restart your shell or run: source $SHELL_PROFILE"
fi
echo ""

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                     Install Summary                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  ALWAYS ON (installed at user scope):"
echo "    ✅ security-guidance   — PreToolUse security hook (0 tokens) [claude-code-plugins]"
echo "    ✅ rtk                 — token compression hook (0 tokens)"
echo "    ✅ superpowers         — brainstorm/plan/implement/debug workflow"
echo ""
echo "  TOGGLE (installed but start OFF — /plugin-check recommends when needed):"
echo "    🔄 gstack              — ~/.claude/skills/gstack/ (→ submodule)"
echo "    🔄 gsd v2              — standalone CLI 'gsd' (gsd-pi, not a Claude Code plugin)"
echo "    🔄 plugin-dev          — create plugins/skills (~100 tokens) [claude-code-plugins]"
echo "    🔄 pr-review-toolkit   — /pr-review-toolkit:review-pr (~300 tokens) [claude-code-plugins]"
echo "    🔄 frontend-design     — UI design skill (~200 tokens) [claude-code-plugins]"
echo "    🔄 ui-ux-pro-max       — user scope (~400 tokens)"
echo "    🔄 context7 CLI        — ctx7 (npm global, standalone or MCP setup)"
echo "    🔄 ruflo CLI           — enterprise multi-agent orchestration (~500-1500 tokens)"
echo "    🔄 graphifyy           — codebase knowledge graph (pipx, PreToolUse hook)"
echo "    🔄 emil-design-eng     — UI polish, animations, component craft (curl → symlink)"
echo ""
echo "  All plugins installed at: user scope (~/.claude/plugins/)"
echo "  GStack at: ~/.claude/skills/gstack/ (symlink → submodule)"
echo "  Emil Design Eng at: ~/.claude/skills/emil-design-eng/ (symlink → skills-external)"
echo ""
echo "  → Restart Claude Code — plugins load automatically"
echo ""
