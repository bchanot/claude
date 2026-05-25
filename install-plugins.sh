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
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
elif command -v apt-get &>/dev/null; then
  OS="linux-apt"
elif command -v dnf &>/dev/null; then
  OS="linux-dnf"
elif command -v pacman &>/dev/null; then
  OS="linux-pacman"
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
  if command -v node &>/dev/null; then
    ok "Node.js $(node --version)"
  else
    err "Node.js install failed"
  fi
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

# --- shellcheck ---
if command -v shellcheck &>/dev/null; then
  ok "shellcheck $(shellcheck --version 2>/dev/null | grep '^version:' | awk '{print $2}')"
else
  info "Installing shellcheck..."
  case $OS in
    macos)        brew install shellcheck ;;
    linux-apt)    sudo apt-get install -y shellcheck ;;
    linux-dnf)    sudo dnf install -y shellcheck ;;
    linux-pacman) sudo pacman -S --noconfirm shellcheck ;;
    *)
      # Binary fallback for systems without package manager access
      ARCH=$(uname -m)
      if curl -sL "https://github.com/koalaman/shellcheck/releases/download/v0.10.0/shellcheck-v0.10.0.linux.${ARCH}.tar.xz" | tar -xJ --strip-components=1 -C "$HOME/.local/bin" "shellcheck-v0.10.0/shellcheck" 2>/dev/null; then
        chmod +x "$HOME/.local/bin/shellcheck"
        ok "shellcheck installed (binary fallback)"
      else
        warn "Cannot auto-install shellcheck on $OS"
      fi
      ;;
  esac
  if command -v shellcheck &>/dev/null; then
    ok "shellcheck installed"
  else
    warn "shellcheck install failed"
  fi
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
    if command -v bun &>/dev/null; then
      ok "bun $(bun --version)"
    else
      err "bun install failed"
    fi
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

  # Default policy: gstack is installed but DISABLED — enable on demand
  # via `bash lib/toggle-external.sh enable gstack`. Rationale: gstack
  # ships ~40 skills that all load into context; keep them off until
  # the user signals a project where they matter (browser QA, deploy).
  if [ -x "$REPO/lib/toggle-external.sh" ] \
     && [ "$(bash "$REPO/lib/toggle-external.sh" status gstack 2>/dev/null)" = "enabled" ]; then
    info "Disabling gstack by default (no context cost until enabled)..."
    bash "$REPO/lib/toggle-external.sh" disable gstack >/dev/null
    ok "gstack installed, disabled — enable with: bash lib/toggle-external.sh enable gstack"
  else
    ok "GStack ready (submodule initialized, symlinks staged)"
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
  if command -v gsd &>/dev/null; then
    ok "GSD v2 installed ($(gsd --version 2>/dev/null | head -1))"
  else
    err "GSD v2 install failed — check npm output above"
  fi
fi
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

# Enable a marketplace plugin in user scope. `claude plugin install` only
# copies the plugin into ~/.claude/plugins/cache — it does NOT register
# it in settings.json's enabledPlugins map. Without an explicit enable,
# the plugin sits dormant. Use this for plugins that should be ALWAYS ON
# (security-guidance, superpowers, caveman). Idempotent: skips if already
# present in enabledPlugins.
enable_plugin() {
  local name="$1"
  local source="$2"
  local key="${name}@${source}"
  if [ -f "$HOME/.claude/settings.json" ] && command -v python3 &>/dev/null; then
    if python3 -c "
import json, sys
with open('$HOME/.claude/settings.json') as f:
    d = json.load(f)
sys.exit(0 if d.get('enabledPlugins', {}).get('$key') else 1)
" 2>/dev/null; then
      ok "$name (already enabled)"
      return
    fi
  fi
  info "Enabling $name..."
  if claude plugin enable "$key" 2>/dev/null; then
    ok "$name enabled"
  else
    err "$name enable failed — run manually: claude plugin enable $key"
  fi
}

# Anthropic bundled plugins (from anthropics/claude-code repo)
# These are NOT in claude-plugins-official — they require the claude-code marketplace
info "Adding Anthropic bundled plugins marketplace..."
claude plugin marketplace add anthropics/claude-code 2>/dev/null || true

info "Adding Anthropic skills marketplace..."
claude plugin marketplace add anthropics/skills 2>/dev/null || true
install_plugin "security-guidance"  "claude-code-plugins"
enable_plugin  "security-guidance"  "claude-code-plugins"
# skill-creator is in "example-skills" plugin from anthropics/skills marketplace
# (not in claude-code marketplace — it's a separate repo)
install_plugin "example-skills"     "anthropic-agent-skills"
install_plugin "pr-review-toolkit"  "claude-code-plugins"
install_plugin "plugin-dev"         "claude-code-plugins"

echo ""

# Superpowers (always on)
info "Adding Superpowers marketplace..."
claude plugin marketplace add obra/superpowers-marketplace 2>/dev/null || true
install_plugin "superpowers" "superpowers-marketplace"
enable_plugin  "superpowers" "superpowers-marketplace"

echo ""

# UI/UX Pro Max (toggle)
info "Adding UI/UX Pro Max marketplace..."
claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill 2>/dev/null || true
install_plugin "ui-ux-pro-max" "ui-ux-pro-max-skill"

echo ""

# ============================================================
# STEP 5.5 — CAVEMAN (full: plugin + standalone hooks + MCP shrink)
# ============================================================
# Caveman compresses output tokens (~75%) via caveman-speak. The "full"
# install layers three things on top of each other:
#   1. Plugin       — /caveman command, cavecrew subagents, mode tracker hooks
#   2. Hooks        — statusline + stats badge written into ~/.claude/
#   3. MCP shrink   — caveman-shrink proxy that compresses tool input tokens
# Per-repo rule files (--with-init / --all) are skipped — they would litter
# this config repo with caveman-rules.md noise meant for project repos.
echo "── Step 5.5: Caveman (full: plugin + hooks + MCP shrink) ────"
echo ""

info "Adding Caveman marketplace..."
claude plugin marketplace add JuliusBrussee/caveman 2>/dev/null || true
install_plugin "caveman" "caveman"
enable_plugin  "caveman" "caveman"

# Standalone hooks (statusline + stats badge). The plugin already wires
# SessionStart + UserPromptSubmit hooks from its own path; this installer
# adds the statusLine config and ~/.claude/hooks/caveman-stats.js that
# the plugin doesn't carry.
CAVEMAN_HOOKS_URL="https://raw.githubusercontent.com/JuliusBrussee/caveman/main/hooks/install.sh"
if [ -f "$HOME/.claude/hooks/caveman-statusline.sh" ] \
   && grep -q 'caveman-statusline' "$HOME/.claude/settings.json" 2>/dev/null; then
  ok "Caveman standalone hooks already installed"
else
  info "Installing Caveman standalone hooks (statusline + stats)..."
  CAVEMAN_HOOKS_TMP="$(mktemp -t caveman-hooks-XXXXXX.sh)"
  if curl -fsSL "$CAVEMAN_HOOKS_URL" -o "$CAVEMAN_HOOKS_TMP" \
     && bash "$CAVEMAN_HOOKS_TMP"; then
    ok "Caveman hooks installed"
    # Caveman's hooks installer hardcodes the absolute home path
    # ($HOME/.claude/hooks/caveman-*.js) into settings.json. The repo's
    # settings.json is symlinked to ~/.claude/settings.json — committing
    # the absolute path would leak this user's username to every machine
    # that clones the repo. Rewrite to portable ~/.claude/hooks/... form.
    if [ -f "$HOME/.claude/settings.json" ] && command -v python3 &>/dev/null; then
      python3 - "$HOME/.claude/settings.json" "$HOME" <<'PY'
import json, sys, re
path, home = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
def rewrite(node):
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "command" and isinstance(v, str) and "caveman" in v:
                node[k] = re.sub(rf'"?{re.escape(home)}/.claude/hooks/(caveman-[^"\s]+)"?',
                                 r'~/.claude/hooks/\1', v)
            else:
                rewrite(v)
    elif isinstance(node, list):
        for item in node:
            rewrite(item)
rewrite(data)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PY
      ok "Caveman hook paths normalized to ~/.claude/hooks/... (portable)"
    fi
  else
    err "Caveman hooks install failed — re-run manually: bash <(curl -fsSL $CAVEMAN_HOOKS_URL)"
  fi
  rm -f "$CAVEMAN_HOOKS_TMP"
fi

# MCP shrink — caveman-shrink is a *proxy* that wraps an upstream MCP
# server and compresses prose fields in its responses. It cannot run
# standalone (it errors with "missing upstream command"). We don't auto-
# register it: the user must pick an upstream MCP server to wrap (e.g.
# the filesystem server, the GitHub server, …) and add a wrapped entry
# to ~/.claude.json manually. Print the snippet so they can copy-paste.
if claude mcp list 2>/dev/null | grep -q '^caveman-shrink-'; then
  ok "caveman-shrink wrapper already registered (custom upstream)"
else
  info "caveman-shrink MCP — manual setup needed (it's a proxy, needs an upstream):"
  cat <<'EOF'
    Add a wrapped MCP entry to ~/.claude.json under "mcpServers", e.g.
    to compress filesystem-server responses:

    {
      "mcpServers": {
        "caveman-shrink-fs": {
          "command": "npx",
          "args": [
            "-y", "caveman-shrink",
            "npx", "-y", "@modelcontextprotocol/server-filesystem",
            "/path/to/dir"
          ]
        }
      }
    }

    Or via CLI (replace upstream with your target server):
      claude mcp add caveman-shrink-fs --scope user -- \
        npx -y caveman-shrink npx -y @modelcontextprotocol/server-filesystem /path
EOF
  warn "caveman-shrink not auto-registered (would fail health check without upstream)"
fi

echo ""

# ============================================================
# STEP 6 — CONTEXT7 CLI (ctx7)
# ============================================================
echo "── Step 6: Context7 CLI ─────────────────────────────────────"
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
  if command -v ctx7 &>/dev/null; then
    ok "ctx7 installed ($(ctx7 --version 2>/dev/null | head -1))"
  else
    err "ctx7 install failed — run manually: npm install -g ctx7"
  fi
fi
# Suggest setup for Claude Code integration (optional — ctx7 also works standalone)
if command -v ctx7 &>/dev/null; then
  info "Run 'ctx7 setup --claude' to configure Context7 for Claude Code"
  info "Or use ctx7 standalone: ctx7 docs /vercel/next.js \"middleware\""
  info "Free higher rate limits: ctx7 login (OAuth) or --api-key from context7.com/dashboard"
fi

# ============================================================
# STEP 7 — GRAPHIFYY (codebase knowledge graph)
# ============================================================
echo "── Step 7: Graphifyy — Knowledge Graph ──────────────────────"
echo ""
if command -v graphify &>/dev/null; then
  ok "graphify already installed"
else
  info "Installing graphifyy via pipx..."
  if pipx install graphifyy 2>/dev/null; then
    ok "graphifyy installed"
  else
    err "graphifyy install failed — run manually: pipx install graphifyy"
  fi
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
# STEP 8 — EMIL DESIGN ENG (UI polish / animation skill)
# ============================================================
echo "── Step 8: Emil Design Engineering ─────────────────────────"
echo ""
EMIL_DIR="$REPO/skills-external/emil-design-eng"
EMIL_URL="https://raw.githubusercontent.com/emilkowalski/skill/main/skills/emil-design-eng/SKILL.md"
mkdir -p "$EMIL_DIR"
if [ -f "$EMIL_DIR/SKILL.md" ]; then
  ok "emil-design-eng already downloaded"
else
  info "Downloading SKILL.md from emilkowalski/skill..."
  if curl -fsSL "$EMIL_URL" -o "$EMIL_DIR/SKILL.md"; then
    ok "emil-design-eng installed"
  else
    err "emil-design-eng download failed — try: curl -fsSL $EMIL_URL -o $EMIL_DIR/SKILL.md"
  fi
fi
# Symlink handled by link.sh
if [ -L "$HOME/.claude/skills/emil-design-eng" ]; then
  ok "emil-design-eng symlink OK"
else
  info "Symlinking — will be created by link.sh"
fi
echo ""

# ── Step 8b: Frontend Design (Anthropic example-skills) ───────
echo "── Step 8b: Frontend Design (Anthropic) ────────────────────"
echo ""
FD_DIR="$REPO/skills-external/frontend-design"
FD_PLUGIN_CACHE="$HOME/.claude/plugins/cache/anthropic-agent-skills/example-skills"
FD_LATEST="$(find "$FD_PLUGIN_CACHE" -maxdepth 1 -type d 2>/dev/null | sort | tail -1)"
mkdir -p "$FD_DIR"
if [ -n "$FD_LATEST" ] && [ -f "$FD_LATEST/skills/frontend-design/SKILL.md" ]; then
  cp "$FD_LATEST/skills/frontend-design/SKILL.md" "$FD_DIR/SKILL.md"
  [ -f "$FD_LATEST/skills/frontend-design/LICENSE.txt" ] && cp "$FD_LATEST/skills/frontend-design/LICENSE.txt" "$FD_DIR/LICENSE.txt"
  ok "frontend-design synced from anthropic-agent-skills plugin cache"
else
  if [ -f "$FD_DIR/SKILL.md" ]; then
    ok "frontend-design already present (plugin cache not found for update)"
  else
    warn "frontend-design: anthropic-agent-skills plugin not cached — install via: claude plugin install example-skills@anthropic-agent-skills"
  fi
fi
if [ -L "$HOME/.claude/skills/frontend-design" ]; then
  ok "frontend-design symlink OK"
else
  info "Symlinking — will be created by link.sh"
fi
echo ""

# ── Step 8c: Design Motion Principles (kylezantos) ─────────
echo "── Step 8c: Design Motion Principles ─────────────────────"
echo ""
DMP_DIR="$REPO/skills-external/design-motion-principles"
if [ -f "$DMP_DIR/SKILL.md" ]; then
  ok "design-motion-principles already present"
else
  warn "design-motion-principles: not installed — clone from https://github.com/kylezantos/design-motion-principles"
fi
if [ -L "$HOME/.claude/skills/design-motion-principles" ]; then
  ok "design-motion-principles symlink OK"
else
  info "Symlinking — will be created by link.sh"
fi
echo ""

# ============================================================
# STEP 8.5 — EXTERNAL SKILLS (npx skills add …)
# ============================================================
# Cross-agent skills distributed via the `skills` npm package
# (vercel-labs/skills). Installed into ~/.agents/skills/ and
# symlinked into $REPO/skills/ by link.sh using absolute paths.
echo "── Step 8.5: External skills via npx ──────────────────────"
echo ""

NPX_SKILLS=(
  "alchaincyf/darwin-skill"
  "alchaincyf/find-skills"
)

if ! command -v npx &>/dev/null; then
  warn "npx not available — skipping external skills"
else
  for _src in "${NPX_SKILLS[@]}"; do
    _name="${_src##*/}"
    _dst="$HOME/.agents/skills/$_name"
    if [ -d "$_dst" ]; then
      ok "$_name already installed ($_dst)"
      continue
    fi
    info "Installing $_name via: npx -y skills add $_src"
    if npx -y skills add "$_src" 2>/dev/null; then
      if [ -d "$_dst" ]; then
        ok "$_name installed"
      else
        warn "$_name installed but not at expected path $_dst"
      fi
    else
      err "$_name install failed — run manually: npx -y skills add $_src"
    fi
  done
fi
echo ""

# ============================================================
# STEP 8.7 — MAGIC MCP (21st-dev) — installed but DISABLED by default
# ============================================================
# Magic MCP is a stdio MCP server providing UI component generation
# from 21st.dev. Toggled via lib/toggle-external.sh (same interface as
# gstack, emil-design-eng, etc.). Registered in Claude Code user scope.
#
# Default policy: DISABLED at install time. Rationale: MCP tools load
# into every Claude Code session and consume context tokens. Enable
# only when you're actively using Magic.
#
# API key: read from $REPO/.env (MAGIC_API_KEY=...) — NEVER committed.
# Template: $REPO/.env.example. Get a key at https://21st.dev/magic
echo "── Step 8.7: Magic MCP (21st-dev) ──────────────────────────"
echo ""
if [ -x "$REPO/lib/toggle-external.sh" ]; then
  MAGIC_STATUS="$(bash "$REPO/lib/toggle-external.sh" status magic 2>/dev/null || echo missing)"
  if [ "$MAGIC_STATUS" = "enabled" ]; then
    info "Disabling magic MCP by default (enable on demand)..."
    bash "$REPO/lib/toggle-external.sh" disable magic >/dev/null
    ok "magic MCP disabled — enable with: bash lib/toggle-external.sh enable magic"
  else
    ok "magic MCP disabled (default)"
  fi
  if [ ! -f "$REPO/.env" ] || ! grep -q '^MAGIC_API_KEY=' "$REPO/.env" 2>/dev/null; then
    warn "MAGIC_API_KEY not found in $REPO/.env — copy .env.example and set your key before enabling"
  fi
else
  warn "lib/toggle-external.sh not found or not executable — skipping"
fi
echo ""

# ============================================================
# STEP 9 — SHELL CONFIG (alias + env vars)
# ============================================================
echo "── Step 9: Claude Code shell config (alias + env vars) ─────"
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
    {
      echo ""
      echo "# Claude Code — added by install-plugins.sh"
      echo "$line"
    } >> "$SHELL_PROFILE"
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
echo "    ✅ caveman             — output compression (~75%) + caveman-shrink MCP (input)"
echo ""
echo "  TOGGLE (installed but start OFF — /plugin-check recommends when needed):"
echo "    🔄 gstack              — disabled by default (toggle: lib/toggle-external.sh enable gstack)"
echo "    🔄 gsd v2              — standalone CLI 'gsd' (gsd-pi, not a Claude Code plugin)"
echo "    🔄 plugin-dev          — create plugins/skills (~100 tokens) [claude-code-plugins]"
echo "    🔄 pr-review-toolkit   — /pr-review-toolkit:review-pr (~300 tokens) [claude-code-plugins]"
echo "    🔄 ui-ux-pro-max       — user scope (~400 tokens)"
echo "    🔄 context7 CLI        — ctx7 (npm global, standalone or MCP setup)"
echo "    🔄 graphifyy           — codebase knowledge graph (pipx, PreToolUse hook)"
echo "    🔄 emil-design-eng     — UI polish, animations, component craft (curl → symlink)"
echo "    🔄 frontend-design     — distinctive frontend interfaces, anti-AI-slop (anthropic-agent-skills)"
echo "    🔄 design-motion-principles — motion/animation design, 3-designer lens (kylezantos)"
echo "    🔄 darwin-skill        — autonomous skill optimizer (npx skills, ~/.agents/skills/)"
echo "    🔄 find-skills         — skill discovery helper (npx skills, ~/.agents/skills/)"
echo "    🔄 magic MCP           — 21st-dev UI generation MCP (toggle: lib/toggle-external.sh enable magic)"
echo ""
echo "  All plugins installed at: user scope (~/.claude/plugins/)"
echo "  GStack skills symlinked individually into ~/.claude/skills/ (→ submodule)"
echo "  Emil Design Eng at: ~/.claude/skills/emil-design-eng/ (symlink → skills-external)"
echo "  Frontend Design at: ~/.claude/skills/frontend-design/ (symlink → skills-external)"
echo "  Design Motion Principles at: ~/.claude/skills/design-motion-principles/ (symlink → skills-external)"
echo "  npx skills at: ~/.agents/skills/ (symlinked into ~/.claude/skills/)"
echo ""
echo "  → Restart Claude Code — plugins load automatically"
echo ""
