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
# shellcheck source=lib/detect-plugins.sh disable=SC1091
source "$REPO/lib/detect-plugins.sh"
# shellcheck source=lib/gstack-playwright.sh disable=SC1091
source "$REPO/lib/gstack-playwright.sh"

# ── Guard hand-curated config against installer drift ────────
# graphify's installer (Step 7) rewrites CLAUDE.md + .claude/settings.json
# (clobbers the curated graphify section + injects aggressive MANDATORY
# hooks), and `claude plugin install` (Step 5) flips enable-states in
# settings.json. These 4 files are maintained by hand + commit, never by
# the installer. Snapshot them now and restore on exit so a run leaves them
# exactly as it found them. Pre-existing local edits are preserved; only the
# installer's drift is undone. NOTE: this makes these files install-immutable
# — anything the installer should add to them must be committed by hand.
# CLAUDE.md = project memory (graphify's rewrite target); CLAUDE.global.md
# = user-scope global memory (deployed as ~/.claude/CLAUDE.md).
GUARDED_CONFIGS=("CLAUDE.md" "CLAUDE.global.md" ".claude/settings.json"
  "settings.json")
CFG_SNAPSHOT="$(mktemp -d 2>/dev/null || true)"

restore_curated_configs() {
  [ -n "$CFG_SNAPSHOT" ] || return 0
  local f
  for f in "${GUARDED_CONFIGS[@]}"; do
    if [ -f "$CFG_SNAPSHOT/$f" ] && ! cmp -s "$CFG_SNAPSHOT/$f" "$REPO/$f"; then
      cp "$CFG_SNAPSHOT/$f" "$REPO/$f"
      info "Reverted installer drift in $f (curated config kept as committed)"
    fi
  done
  rm -rf "$CFG_SNAPSHOT"
}

if [ -n "$CFG_SNAPSHOT" ]; then
  for _cfg in "${GUARDED_CONFIGS[@]}"; do
    if [ -f "$REPO/$_cfg" ]; then
      mkdir -p "$CFG_SNAPSHOT/$(dirname "$_cfg")"
      cp "$REPO/$_cfg" "$CFG_SNAPSHOT/$_cfg"
    fi
  done
  trap restore_curated_configs EXIT
else
  err "Config guard could not be created (mktemp failed) — refusing to run" \
    "unguarded: CLAUDE.md/CLAUDE.global.md/.claude/settings.json/settings.json" \
    "could be silently rewritten by the installer. Fix mktemp/TMPDIR and retry."
  exit 1
fi

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

# --- Node.js (>=24 — impeccable requires it; GSD v2 needs >=22) ---
NODE_OK=false
if command -v node &>/dev/null; then
  NODE_VER=$(node --version | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_VER" -ge 24 ]; then
    ok "Node.js $(node --version)"; NODE_OK=true
  else
    warn "Node.js $(node --version) is too old (need >=24 — impeccable requires it)"
  fi
fi
if [ "$NODE_OK" = false ]; then
  info "Installing Node.js 24 LTS..."
  case $OS in
    macos)
      brew install node@24
      export PATH="/opt/homebrew/opt/node@24/bin:$PATH"
      ;;
    linux-apt)
      curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
      sudo apt-get install -y nodejs
      ;;
    linux-dnf)
      curl -fsSL https://rpm.nodesource.com/setup_24.x | sudo bash -
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

# --- npm (bundled with Node, but distro `apt install nodejs` can ship it separately) ---
# BLK-013 fix-forward: node>=22 present does NOT imply npm present. GSD (gsd-pi)
# and ctx7 install via `npm install -g`, so a missing npm makes `make plugin`
# die with Error 127 mid-run. The Node block above short-circuits when node is
# already recent (NODE_OK=true) and never checks npm, so guarantee it here.
if ! command -v npm &>/dev/null; then
  info "npm missing (Node without npm) — enabling via corepack, else package manager..."
  if command -v corepack &>/dev/null; then
    sudo corepack enable npm 2>/dev/null || corepack enable npm 2>/dev/null || true
  fi
  if ! command -v npm &>/dev/null; then
    case $OS in
      linux-apt)    sudo apt-get install -y npm || true ;;
      linux-dnf)    sudo dnf install -y npm || true ;;
      linux-pacman) sudo pacman -S --noconfirm npm || true ;;
      macos)        brew install node || true ;;   # brew's node bundles npm
      *) : ;;
    esac
  fi
  if command -v npm &>/dev/null; then
    ok "npm $(npm --version)"
  else
    err "npm still missing — GSD/ctx7 need it; install npm manually then re-run"; exit 1
  fi
fi

# --- Rust + Cargo (for RTK) ---
if command -v cargo &>/dev/null; then
  ok "Rust/Cargo $(cargo --version | awk '{print $2}')"
else
  info "Installing Rust (rustup)..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  # shellcheck source=/dev/null
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

# --- jq (required by active hooks: statusline.sh, rtk-rewrite.sh) ---
if command -v jq &>/dev/null; then
  ok "jq $(jq --version 2>/dev/null | sed 's/^jq-//')"
else
  info "Installing jq..."
  case $OS in
    macos)        brew install jq ;;
    linux-apt)    sudo apt-get install -y jq ;;
    linux-dnf)    sudo dnf install -y jq ;;
    linux-pacman) sudo pacman -S --noconfirm jq ;;
    *) warn "Cannot auto-install jq on $OS — statusline/rtk hooks need it" ;;
  esac
  if command -v jq &>/dev/null; then
    ok "jq installed"
  else
    warn "jq install failed — statusline & rtk-rewrite hooks require it"
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

  # On a distro newer than gstack's pinned Playwright supports, bump Playwright
  # BEFORE ./setup so its frozen-lockfile install picks up the new version and
  # the browse binary is rebuilt against it (avoids the "does not support
  # chromium" fail). Non-fatal if it can't — gstack is OFF by default.
  # See BLK-008 / LRN-040 / BDR-029; logic lives in lib/gstack-playwright.sh.
  gstack_bump_playwright_if_unsupported "$GSTACK_DIR"

  info "Running GStack setup..."
  _gstack_setup_ok=0
  if [ -x "$GSTACK_DIR/setup" ]; then
    if (cd "$GSTACK_DIR" && ./setup); then
      _gstack_setup_ok=1
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
  fi
  # Success message gated on the real setup outcome — an unconditional ok
  # after a `|| warn` reads as success even when setup failed (LRN-071 class).
  if [ "$_gstack_setup_ok" -eq 1 ]; then
    ok "GStack ready (disabled by default — enable: bash lib/toggle-external.sh enable gstack)"
  else
    warn "GStack NOT ready — ./setup did not complete (see warnings above)"
  fi

  # GStack shared infrastructure: bin/ (CLI tools) and browse/dist/ (compiled binary).
  # Per-skill SKILL.md symlinks don't expose these, but multiple skills hardcode
  # ~/.claude/skills/gstack/bin/ and gstack/browse/dist/.
  GSTACK_DST="$HOME/.claude/skills/gstack"
  if [ -d "$GSTACK_DIR/bin" ]; then
    mkdir -p "$GSTACK_DST"
    [ -L "$GSTACK_DST/bin" ] || ln -sf "$GSTACK_DIR/bin" "$GSTACK_DST/bin"
    ok "gstack/bin/ symlink OK"
  fi
  if [ -d "$GSTACK_DIR/browse/dist" ]; then
    mkdir -p "$GSTACK_DST/browse"
    [ -L "$GSTACK_DST/browse/dist" ] || ln -sf "$GSTACK_DIR/browse/dist" "$GSTACK_DST/browse/dist"
    ok "gstack/browse/dist/ symlink OK"
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
# PATH bridge: cargo installs to ~/.cargo/bin, which hand-managed shell
# profiles routinely lose (LRN-036 class). This installer sources cargo env
# so `command -v rtk` passes HERE — but Claude's tool shell never gets that
# PATH: the rewrite hook then drops every COMPOUND rewrite (it can only
# absolute-path the string head) and compression silently dies (measured:
# 6/5070 commands compressed over 30 days). ~/.local/bin is on the standard
# PATH — bridge with a symlink. Idempotent; -x on a broken link is false,
# so a stale link self-repairs.
if [ -x "$HOME/.cargo/bin/rtk" ] && [ ! -x "$HOME/.local/bin/rtk" ]; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$HOME/.cargo/bin/rtk" "$HOME/.local/bin/rtk"
  ok "rtk bridged into ~/.local/bin (cargo bin dir is not on the tool-shell PATH)"
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
# (security-guidance, superpowers). Idempotent: skips if already
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
# plugin-dev dropped 2026-07-02 (audit #14): installed 2026-06-23, never
# enabled, pure disk weight — reinstall deliberately if plugin authoring
# becomes a need: claude plugin install plugin-dev@claude-code-plugins

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

# Caveman plugin removed (cleanup/caveman-always-on, v3.5.0): on a
# subscription plan its ~75% output-token compression has no cost benefit,
# and the plugin's always-on SessionStart/UserPromptSubmit hooks added
# friction on validation gates and client deliverables. The unrelated
# memory-registry terse-format convention (CLAUDE.global.md) is kept.

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
# ctx7 auth — detect, then offer login ONLY in an interactive TTY. A non-interactive
# run (CI / headless / re-run) must never open a browser or block on OAuth.
if command -v ctx7 &>/dev/null; then
  # Deterministic offline oracle: ctx7's OAuth token lives here (XDG-aware).
  # Present => authenticated; absent => anonymous. No subprocess, no network, no browser.
  ctx7_creds="${XDG_CONFIG_HOME:-$HOME/.config}/context7/credentials.json"
  if [ -f "$ctx7_creds" ]; then
    ok "ctx7 authenticated (full rate limits)"
  else
    info "ctx7 works anonymously — docs + library already usable, no auth required."
    if [ -t 0 ] && [ -t 1 ]; then
      # Interactive terminal: offer to log in now (opens a browser).
      printf '%b' "${BLUE}→${NC} Authenticate ctx7 now for higher rate limits? [y/N] "
      read -r ctx7_ans || ctx7_ans=""
      if [[ "$ctx7_ans" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        if ctx7 login; then
          ok "ctx7 authenticated (full rate limits)"
        else
          warn "ctx7 login did not finish — re-run 'ctx7 login' anytime"
        fi
      else
        info "Skipped — authenticate later with:  ctx7 login"
      fi
    else
      # Non-interactive (CI / headless / re-run): never block — just guide.
      info "For higher rate limits, authenticate:  ctx7 login   (opens a browser)"
      info "  headless:  ctx7 login --no-browser   (prints a URL to open yourself)"
    fi
  fi
  # CLI + Skills mode: install the find-docs skill into ~/.claude/skills when
  # absent (it is gitignored — ctx7 owns it, this regenerates it on a fresh
  # clone). Guarded on absence so a re-run never clobbers a customized config.
  if [ ! -f "$HOME/.claude/skills/find-docs/SKILL.md" ]; then
    if ctx7 setup --claude --cli -y </dev/null &>/dev/null; then
      ok "ctx7 CLI + Skills configured (find-docs skill installed)"
    else
      warn "ctx7 setup failed — run manually: ctx7 setup --claude --cli"
    fi
  fi
  # Single ctx7 surface = the find-docs skill (BDR-053). setup also (re)writes
  # ~/.claude/rules/context7.md — a session-start duplicate of the skill
  # (~490 tok/session, job1 F10). Purge it unconditionally so re-runs and
  # manual `ctx7 setup` invocations stay rule-free.
  rm -f "$HOME/.claude/rules/context7.md"
  # BDR-078: re-apply the coverage extension to the generated skill — the
  # before-writing-code trigger (description) + the cache-first rule (body).
  # The dist is machine-owned (gitignored, regenerated on fresh clones), so
  # the durable copy of this patch lives HERE. Idempotent: grep-guarded.
  _fd="$HOME/.claude/skills/find-docs/SKILL.md"
  if [ -f "$_fd" ] && ! grep -q 'fast-libs.sh detect' "$_fd"; then
    if python3 - "$_fd" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
DESC = """
  Also use BEFORE writing or modifying code that uses a fast-moving library
  (anything `bash ~/.claude/lib/fast-libs.sh detect .` reports — React,
  Next.js, Prisma, Tailwind, Astro, Svelte…), even when the user asked for
  code rather than documentation — unless a fresh `.ctx7-cache/` file already
  covers the API involved. Stable technologies (C, C++98, POSIX shell, SQL…)
  need no lookup."""
BODY = """
## Cache first

Before any fetch, check the project's `.ctx7-cache/`
(`bash ~/.claude/lib/fast-libs.sh cache-status .`): a fresh (<7 days)
`<lib>*.md` may already answer — read it instead of calling ctx7. When a
`docs` call supports code you are about to write, save the output for the
next consumer:
`npx ctx7@latest docs <id> "<query>" | tee .ctx7-cache/<lib>-<topic>.md`.
"""
i = s.index("\n---", 3)          # closing frontmatter fence
s = s[:i] + "\n" + DESC + s[i:]
m = "using the Context7 CLI.\n"  # intro line under the H1
j = s.index(m) + len(m) if m in s else len(s)
s = s[:j] + BODY + s[j:]
open(p, "w", encoding="utf-8").write(s)
PY
    then
      ok "find-docs skill extended (BDR-078 fast-libs trigger + cache-first)"
    else
      warn "find-docs BDR-078 patch failed — re-run 'make plugin' or patch by hand"
    fi
  fi
  info "Standalone usage:  ctx7 docs /vercel/next.js \"middleware\""
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
  _graphify_ok=1
  info "Running graphify install (dependencies)..."
  graphify install 2>/dev/null || { warn "graphify install failed — run manually"; _graphify_ok=0; }
  info "Configuring Claude Code integration..."
  graphify claude install 2>/dev/null || { warn "graphify claude install failed — run manually"; _graphify_ok=0; }
  # Success message gated on the real outcome (LRN-071 class: an
  # unconditional ok after `|| warn` lies when a step failed).
  if [ "$_graphify_ok" -eq 1 ]; then
    ok "Graphify configured for Claude Code"
  else
    warn "Graphify NOT fully configured — re-run the failed step manually"
  fi
fi
echo ""

# ============================================================
# STEP 7.5 — SEMGREP (SAST engine for the security gate)
# ============================================================
echo "── Step 7.5: Semgrep — SAST security gate ───────────────────"
echo ""
if command -v semgrep &>/dev/null; then
  ok "semgrep already installed ($(semgrep --version 2>/dev/null | head -1))"
else
  SEMGREP_VER=$(pinned_version "semgrep")
  if [ "$SEMGREP_VER" != "latest" ]; then
    info "Installing semgrep ${SEMGREP_VER} (pinned in plugins.lock.json)..."
    pipx install "semgrep==${SEMGREP_VER}" 2>/dev/null
  else
    info "Installing semgrep latest (consider pinning in plugins.lock.json)..."
    pipx install semgrep 2>/dev/null
  fi
  if command -v semgrep &>/dev/null; then
    ok "semgrep installed ($(semgrep --version 2>/dev/null | head -1))"
  else
    err "semgrep install failed — run manually: pipx install semgrep"
  fi
fi
# Login is Pro-rules only and optional — NEVER run automatically (ctx7
# pattern: guide, don't block). The gate uses pinned public rulesets.
if command -v semgrep &>/dev/null; then
  info "Optional Pro rules:  semgrep login   (never run automatically)"
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

# ── Step 8d: Impeccable (design detector + skill + subagents) ──
# 45 deterministic detector rules (`impeccable detect`, exit 0/2), the
# /impeccable skill (23 verbs) and 4 `impeccable-*` subagents.
#
# GLOBAL scope, no staging: the installer writes ~/.claude/skills/impeccable/
# (skill + its self-contained engine binary) and ~/.claude/agents/
# impeccable-*.md, and both of those are symlinks into this repo — so the
# global install IS the repo install. Machine-owned and gitignored on both
# sides. `--scope=project` was wrong twice over: it writes <cwd>/.claude/,
# which serves only the directory it ran in, and the staged `mv` that
# followed it moved the skill alone, silently dropping the subagents.
#
# The pin rots. The CLI downloads its skill dist at install time and an older
# release's artifact eventually disappears (`impeccable@3.2.0` → "Download
# failed: invalid zip data", 2026-09-22) — which is what left `make plugin`
# telling the user to run the command by hand. So a pin failure falls back to
# @latest and says, loudly, that the lock needs bumping.
echo "── Step 8d: Impeccable — design detector, skill + agents ──"
echo ""
IMP_SKILL_DIR="$HOME/.claude/skills/impeccable"
IMP_PARKED="$REPO/skills-disabled/impeccable"
IMP_VER=$(pinned_version "impeccable")
NODE_MAJOR=$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1)

# One install attempt. $1 = "latest" or an exact version. On failure, IMP_FAIL
# holds the reason. The exit code alone is not enough: with a copy already in
# place, a rotted pin exits 0 ("Could not check for skill updates: invalid
# zip data … Existing skills were left unchanged"), exactly like a genuine
# up-to-date no-op ("Skills are up to date") — only the output tells them
# apart. Probed 2026-09-22 on 4.1.0 vs 3.2.0 in a sandbox HOME.
imp_install() {
  local pkg="impeccable" out rc=0
  [ "$1" != "latest" ] && pkg="impeccable@$1"
  out=$(npx -y "$pkg" skills install -y --providers=claude --scope=global \
    --no-hooks 2>&1) || rc=$?
  IMP_FAIL=$(printf '%s\n' "$out" \
    | grep -E 'Download failed|Could not check for skill updates' \
    | head -1 || true)
  if [ "$rc" -ne 0 ] && [ -z "$IMP_FAIL" ]; then
    IMP_FAIL="installer exited $rc"
  fi
  [ -z "$IMP_FAIL" ]
}

# Precondition: ~/.claude/{skills,agents} must already be link.sh's symlinks.
# Installing before they exist materializes real directories there, and
# link.sh then refuses to replace them ("is a real directory") — a worse
# failure than skipping, because it needs manual repair.
IMP_READY=true
for _imp_d in skills agents; do
  if [ "$(readlink "$HOME/.claude/$_imp_d" 2>/dev/null || true)" != "$REPO/$_imp_d" ]; then
    IMP_READY=false
  fi
done

if [ "$IMP_READY" != true ]; then
  warn "impeccable: ~/.claude/skills and ~/.claude/agents are not this repo's symlinks yet"
  warn "  → run 'make link' first, then re-run 'make plugin'"
elif [ -z "${NODE_MAJOR:-}" ] || [ "$NODE_MAJOR" -lt 24 ]; then
  if [ -f "$IMP_SKILL_DIR/SKILL.md" ] || [ -f "$IMP_PARKED/SKILL.md" ]; then
    ok "impeccable already present (update skipped — needs Node >= 24, found ${NODE_MAJOR:-none})"
  else
    warn "impeccable: needs Node >= 24 (found ${NODE_MAJOR:-none}) — skipped. Bump Node, then: make plugin"
  fi
else
  # A profile may hold impeccable parked in skills-disabled/. Install writes
  # to the live slot, so remember the state and put the fresh copy back where
  # it was — otherwise `make plugin` silently re-enables a disabled skill.
  IMP_WAS_PARKED=false
  [ -d "$IMP_PARKED" ] && IMP_WAS_PARKED=true
  IMP_USED=""
  if [ "$IMP_VER" != "latest" ]; then
    info "Installing impeccable ${IMP_VER} (pinned in plugins.lock.json, global scope)..."
    if imp_install "$IMP_VER"; then
      IMP_USED="$IMP_VER"
    else
      warn "impeccable@${IMP_VER} did not install (${IMP_FAIL}) — that release's skill dist is gone upstream"
      info "Falling back to impeccable@latest..."
      if imp_install latest; then
        IMP_USED="latest"
        warn "installed @latest instead of the pin. Bump \"impeccable\".version in plugins.lock.json to the version this produced, so the next run is reproducible again."
      fi
    fi
  else
    info "Installing impeccable latest (consider pinning in plugins.lock.json)..."
    imp_install latest && IMP_USED="latest"
  fi

  if [ -n "$IMP_USED" ] && [ -f "$IMP_SKILL_DIR/SKILL.md" ]; then
    IMP_SKILL_VER=$(sed -n 's/^version:[[:space:]]*//p' "$IMP_SKILL_DIR/SKILL.md" | head -1)
    # -L: ~/.claude/agents is a symlink, and find would otherwise stop on it.
    IMP_AGENTS=$(find -L "$HOME/.claude/agents" -maxdepth 1 -name 'impeccable-*.md' 2>/dev/null | wc -l)
    ok "impeccable installed (CLI ${IMP_USED}, skill ${IMP_SKILL_VER:-?}, ${IMP_AGENTS} agents)"
    if [ "$IMP_AGENTS" -eq 0 ]; then
      warn "no impeccable-* agent landed in agents/ — the skill's finish/document verbs dispatch to them"
    fi
    if [ "$IMP_WAS_PARKED" = true ]; then
      rm -rf "${IMP_PARKED:?}"
      mv "$IMP_SKILL_DIR" "$IMP_PARKED"
      info "impeccable was parked by a profile — refreshed copy returned to skills-disabled/"
    fi
    info "Per-project step, in the agent chat of each frontend project:  /impeccable init"
    info "  (writes PRODUCT.md — the design context every impeccable verb reads)"
  elif [ -f "$IMP_SKILL_DIR/SKILL.md" ] || [ -f "$IMP_PARKED/SKILL.md" ]; then
    ok "impeccable already present (install failed: ${IMP_FAIL:-no SKILL.md written} — existing copy kept)"
  else
    warn "impeccable install failed (${IMP_FAIL:-no SKILL.md written}) — run manually: npx impeccable skills install -y --providers=claude --scope=global --no-hooks"
  fi
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
)

# `skills add` resolves its target (.agents/skills/, skills-lock.json) RELATIVE
# TO THE CWD. Running it from the repo (which carries gitignored .agents/ and
# .claude/ dirs) makes skills land in $REPO/.agents/skills instead of
# $HOME/.agents/skills — where link.sh expects them — and the bug is
# self-reinforcing once $REPO/.agents exists. Always install from $HOME.
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
    info "Installing $_name via: npx -y skills add $_src (from \$HOME)"
    if (cd "$HOME" && npx -y skills add "$_src" 2>/dev/null); then
      if [ -d "$_dst" ]; then
        ok "$_name installed"
      else
        warn "$_name installed but not at expected path $_dst"
      fi
    else
      err "$_name install failed — run manually: (cd \"\$HOME\" && npx -y skills add $_src)"
    fi
  done
fi

# Earlier runs (before this CWD fix) scattered skills into the repo's gitignored
# .agents/skills and .claude/skills. They shadow the canonical $HOME copies and
# confuse skill discovery — remove them. Both are gitignored, so this is safe.
for _stray in "$REPO/.agents/skills" "$REPO/.claude/skills"; do
  if [ -d "$_stray" ]; then
    rm -rf "$_stray"
    info "Removed stray repo-local skills dir: $_stray"
  fi
done
echo ""

# ============================================================
# STEP 8.7 — 21ST.DEV CLI + SKILL PACK — installed but DISABLED by default
# ============================================================
# `@21st-dev/cli` (bin `21st`): one browser login (`21st login`, token in
# ~/.config/21st), no API key, no MCP process loaded into every session. It
# ships a pack of
# verified skills (21st-ui-build / -explore / -review / -cli-use / -ai /
# -registry / -design-sync) that drive the CLI from Claude Code.
#
# Machine-owned dist (impeccable pattern): `21st skills install` writes to
# <HOME>/.claude/skills/<name>/ and REFUSES to follow a symlink anywhere on
# that path — and ~/.claude/skills IS a symlink to this repo's skills/. So
# install under a staged HOME, then move each skill into skills-external/
# (gitignored), where toggle-external.sh / profile.sh symlink it in.
#
# Default policy: pack DISABLED at install time — every skill description
# loads into every session. Enable on demand:
#   bash lib/toggle-external.sh enable 21st     (whole pack)
#   /profile design                             (the 5 design skills)
echo "── Step 8.7: 21st.dev CLI + skill pack ─────────────────────"
echo ""
if command -v 21st &>/dev/null; then
  ok "21st CLI already installed"
else
  TFD_VER=$(pinned_version "21st")
  if [ "$TFD_VER" != "latest" ]; then
    info "Installing @21st-dev/cli@${TFD_VER} (pinned in plugins.lock.json)..."
    npm install -g "@21st-dev/cli@${TFD_VER}"
  else
    info "Installing @21st-dev/cli@latest (consider pinning in plugins.lock.json)..."
    npm install -g @21st-dev/cli
  fi
  if command -v 21st &>/dev/null; then
    ok "21st CLI installed"
  else
    err "21st CLI install failed — run manually: npm install -g @21st-dev/cli"
  fi
fi

# Skill pack — staged install, then moved under skills-external/.
if command -v 21st &>/dev/null; then
  TFD_STAGE=$(mktemp -d)
  if HOME="$TFD_STAGE" 21st skills install --global --agent claude >/dev/null 2>&1; then
    TFD_N=0
    for _tfd in "$TFD_STAGE"/.claude/skills/*/; do
      [ -f "${_tfd}SKILL.md" ] || continue
      _tfd_name=$(basename "$_tfd")
      rm -rf "${REPO:?}/skills-external/${_tfd_name:?}"
      mv "$_tfd" "$REPO/skills-external/$_tfd_name"
      TFD_N=$((TFD_N + 1))
    done
    if [ "$TFD_N" -gt 0 ]; then
      ok "21st skill pack synced to skills-external/ ($TFD_N skills)"
    else
      warn "21st skills install ran but produced no SKILL.md — layout changed? Inspect: 21st skills install --global --agent claude"
    fi
  elif [ -f "$REPO/skills-external/21st-ui-build/SKILL.md" ]; then
    ok "21st skill pack already present (refresh failed — existing copy kept)"
  else
    warn "21st skill pack install failed — run manually: 21st skills install --global --agent claude"
  fi
  rm -rf "$TFD_STAGE"
fi

# Auth — detect, then offer login ONLY in an interactive TTY. A non-interactive
# run (CI / headless / re-run) must never open a browser or block on OAuth.
# Search and logo lookup are free; retrieving component code and 21st AI need
# the session. Mirrors the ctx7 auth block (Step 6).
if command -v 21st &>/dev/null; then
  # `whoami` is a local token read (no network): "Logged in as <user> (saved …)."
  TFD_WHO="$(21st whoami 2>/dev/null | head -1)"
  if [[ "$TFD_WHO" == "Logged in as "* ]]; then
    ok "21st: ${TFD_WHO%.}"
  elif [ -t 0 ] && [ -t 1 ]; then
    printf '%b' "${BLUE}→${NC} Sign in to 21st now? (opens a browser) [y/N] "
    read -r tfd_ans || tfd_ans=""
    if [[ "$tfd_ans" =~ ^[Yy]([Ee][Ss])?$ ]]; then
      if 21st login; then
        ok "21st authenticated"
      else
        warn "21st login did not finish — re-run '21st login' anytime"
      fi
    else
      info "Skipped — sign in later with:  21st login"
    fi
  else
    info "Not signed in. Component retrieval and 21st AI need:  21st login"
  fi
fi

# Default-disabled, same policy as before the MCP→CLI move.
if [ -x "$REPO/lib/toggle-external.sh" ]; then
  TFD_STATUS="$(bash "$REPO/lib/toggle-external.sh" status 21st 2>/dev/null || echo missing)"
  if [ "$TFD_STATUS" = "enabled" ]; then
    info "Disabling the 21st skill pack by default (enable on demand)..."
    bash "$REPO/lib/toggle-external.sh" disable 21st >/dev/null
    ok "21st skill pack disabled — enable with: bash lib/toggle-external.sh enable 21st"
  else
    ok "21st skill pack disabled (default)"
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
  'export CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1'
)

# Ubuntu 24.04+ (and other distros) restrict unprivileged user namespaces via
# AppArmor, which breaks Chromium's sandbox → gstack's browser (/browse, /qa)
# crashes with "No usable sandbox". Persist gstack's documented opt-out, but
# only where the restriction is actually active (precise, distro-agnostic).
if [ "$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null)" = "1" ]; then
  CLAUDE_LINES+=('export GSTACK_CHROMIUM_NO_SANDBOX=1')
fi

# Remove obsolete effort config — effort is now set in settings.json
# ("effortLevel"), which supersedes both the old CLAUDE_EFFORT env var and the
# `claude --effort max` alias (the alias would even override settings.json).
EFFORT_CLEANED=0
if grep -qF 'export CLAUDE_EFFORT=max' "$SHELL_PROFILE" 2>/dev/null; then
  sed -i '/export CLAUDE_EFFORT=max/d' "$SHELL_PROFILE"; EFFORT_CLEANED=1
fi
if grep -qF "alias claude='claude --effort max'" "$SHELL_PROFILE" 2>/dev/null; then
  sed -i "\#alias claude='claude --effort max'#d" "$SHELL_PROFILE"; EFFORT_CLEANED=1
fi
if [ "$EFFORT_CLEANED" -eq 1 ]; then
  # Remove orphaned comment lines left before the deleted entries
  sed -i '/^# Claude Code — added by install-plugins.sh$/{ N; /^\n$/d; }' "$SHELL_PROFILE"
  info "Removed obsolete effort alias/env from $SHELL_PROFILE (effort set in settings.json)"
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
# STEP 10 — REFRESH SYMLINKS (final, so this script is self-sufficient)
# ============================================================
# Steps 2/8/8.5 INSTALL skills (gstack submodule, emil/frontend/motion, npx
# darwin-skill) that link.sh must symlink into ~/.claude/skills/. Since
# link.sh runs BEFORE this script in install.sh, those symlinks would be missing
# on a fresh run until link.sh is run again by hand. Re-run it here so
# `make plugin` (and `make install`) finish complete — nothing left to do.
echo "── Step 10: Refreshing symlinks (link.sh) ─────────────────"
echo ""
if [ -f "$REPO/link.sh" ]; then
  bash "$REPO/link.sh"
else
  warn "link.sh not found — run it manually to create skill symlinks"
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
echo "  TOGGLE (plugin state = settings.json enabledPlugins; skills/CLIs = profiles):"
echo "    🔄 gstack              — disabled by default (toggle: lib/toggle-external.sh enable gstack)"
echo "    🔄 gsd v2              — standalone CLI 'gsd' (gsd-pi, not a Claude Code plugin)"
echo "    🔄 pr-review-toolkit   — /review-pr + 6 PR agents (~2.2k tokens when enabled) [claude-code-plugins]"
echo "    🔄 ui-ux-pro-max       — user scope (~780 tokens when enabled)"
echo "    🔄 context7 CLI        — ctx7 (npm global, standalone or MCP setup)"
echo "    🔄 graphifyy (CLI: graphify) — codebase knowledge graph (pipx, PreToolUse hook)"
echo "    🔄 emil-design-eng     — UI polish, animations, component craft (curl → symlink)"
echo "    🔄 frontend-design     — distinctive frontend interfaces, anti-AI-slop (anthropic-agent-skills)"
echo "    🔄 impeccable          — /impeccable design verbs + 45-rule deterministic detector (npx impeccable detect)"
echo "    🔄 design-motion-principles — motion/animation design, 3-designer lens (kylezantos)"
echo "    🔄 darwin-skill        — autonomous skill optimizer (npx skills, ~/.agents/skills/)"
echo "    🔄 21st skill pack     — 21st.dev CLI skills, 7 (toggle: lib/toggle-external.sh enable 21st)"
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
