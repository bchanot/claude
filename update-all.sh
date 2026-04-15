#!/usr/bin/env bash
# ============================================================
# Claude Code — Update all components
# Pulls latest config, updates submodules, refreshes symlinks,
# and runs doctor to verify.
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
info() { echo -e "${BLUE}→${NC} $1"; }

REPO="$(cd "$(dirname "$0")" && pwd)"
VERSION=$(cat "$REPO/version.txt" 2>/dev/null || echo "unknown")

# Load shared detection library
# shellcheck source=lib/detect-plugins.sh
source "$REPO/lib/detect-plugins.sh"

echo ""
echo "═══ claude-config update (v${VERSION}) ═══"
echo ""

# ── 0. Update Claude Code CLI ──
echo "── Updating Claude Code CLI..."
if command -v claude &>/dev/null; then
  CURRENT_VER=$(claude --version 2>/dev/null | head -1 || echo "unknown")
  info "Current: $CURRENT_VER"
  if npm install -g @anthropic-ai/claude-code@latest 2>/dev/null; then
    NEW_VER=$(claude --version 2>/dev/null | head -1 || echo "unknown")
    if [ "$CURRENT_VER" = "$NEW_VER" ]; then
      ok "Claude Code already up to date ($NEW_VER)"
    else
      ok "Claude Code updated: $CURRENT_VER → $NEW_VER"
    fi
  else
    warn "Claude Code update failed — try manually: npm install -g @anthropic-ai/claude-code@latest"
  fi
else
  warn "Claude Code not found — install first with: make install"
fi

echo ""

# ── 1. Pull latest config ──
echo "── Pulling latest config..."
cd "$REPO"
if git pull --rebase 2>/dev/null; then
  ok "Config repo updated"
else
  warn "git pull failed — check for uncommitted changes"
fi

# ── 2. Update GStack submodule ──
echo ""
echo "── Updating GStack submodule..."
warn "GStack tracks branch = main (no commit hash). Review upstream commits before updating."
echo ""
printf "  Proceed with GStack update? [y/N] "
read -r _gstack_confirm
if [[ "$_gstack_confirm" =~ ^[Yy]$ ]]; then
  if git submodule update --remote skills-external/gstack 2>/dev/null; then
    if [ -d "skills-external/gstack" ]; then
      if [ -x "skills-external/gstack/setup" ]; then
        if (cd skills-external/gstack && ./setup) 2>/dev/null; then
          ok "GStack updated"
        else
          warn "GStack ./setup failed — submodule updated but setup did not complete"
        fi
      else
        warn "GStack ./setup not found or not executable — skipping"
        ok "GStack submodule pointer updated"
      fi
    fi
  else
    warn "GStack submodule update failed — run: git submodule update --init"
  fi
else
  info "GStack update skipped"
fi

# ── 3. Update RTK (if pinned version available) ──
echo ""
echo "── Updating RTK..."
if command -v cargo &>/dev/null; then
  RTK_VERSION=""
  if [ -f "$REPO/plugins.lock.json" ] && command -v python3 &>/dev/null; then
    RTK_VERSION=$(python3 -c "
import json
with open('$REPO/plugins.lock.json') as f:
    d = json.load(f)
print(d.get('rtk',{}).get('version',''))
" 2>/dev/null || true)
  fi

  if [ -n "$RTK_VERSION" ] && [ "$RTK_VERSION" != "latest" ]; then
    info "Pinned version: $RTK_VERSION"
    info "Compiling from source — this may take a few minutes..."
    cargo install --git https://github.com/rtk-ai/rtk --tag "$RTK_VERSION" --force \
      && ok "RTK updated to $RTK_VERSION" \
      || warn "RTK update failed"
  else
    info "No pinned version — installing latest"
    info "Compiling from source — this may take a few minutes..."
    cargo install --git https://github.com/rtk-ai/rtk --force \
      && ok "RTK updated (latest)" \
      || warn "RTK update failed"
  fi
else
  warn "Cargo not available — skipping RTK"
fi

# ── 4. Update GSD v2 ──
echo ""
echo "── Updating GSD v2 (gsd-pi)..."
if command -v gsd &>/dev/null; then
  GSD_VER=""
  if [ -f "$REPO/plugins.lock.json" ] && command -v python3 &>/dev/null; then
    GSD_VER=$(python3 -c "
import json
with open('$REPO/plugins.lock.json') as f:
    d = json.load(f)
print(d.get('gsd',{}).get('version',''))
" 2>/dev/null || true)
  fi

  if [ -n "$GSD_VER" ] && [ "$GSD_VER" != "latest" ]; then
    info "Pinned version: $GSD_VER"
    npm install -g "gsd-pi@${GSD_VER}" 2>/dev/null \
      && ok "GSD v2 updated to $GSD_VER" \
      || warn "GSD v2 update failed"
  else
    info "No pinned version — installing latest"
    npm install -g gsd-pi 2>/dev/null \
      && ok "GSD v2 updated (latest)" \
      || warn "GSD v2 update failed"
  fi
else
  warn "GSD v2 not installed — skipping (run: npm install -g gsd-pi)"
fi

# ── 5. Update Context7 CLI ──
echo ""
echo "── Updating Context7 CLI..."
if command -v ctx7 &>/dev/null; then
  CTX7_VER=""
  if [ -f "$REPO/plugins.lock.json" ] && command -v python3 &>/dev/null; then
    CTX7_VER=$(python3 -c "
import json
with open('$REPO/plugins.lock.json') as f:
    d = json.load(f)
print(d.get('ctx7',{}).get('version',''))
" 2>/dev/null || true)
  fi

  if [ -n "$CTX7_VER" ] && [ "$CTX7_VER" != "latest" ]; then
    info "Pinned version: $CTX7_VER"
    npm install -g "ctx7@${CTX7_VER}" 2>/dev/null \
      && ok "ctx7 updated to $CTX7_VER" \
      || warn "ctx7 update failed"
  else
    npm install -g ctx7@latest 2>/dev/null \
      && ok "ctx7 updated (latest)" \
      || warn "ctx7 update failed"
  fi
else
  info "ctx7 not installed — skipping"
fi

# ── 6. Update Graphifyy ──
echo ""
echo "── Updating Graphifyy..."
if command -v graphify &>/dev/null; then
  pipx upgrade graphifyy 2>/dev/null \
    && ok "graphifyy updated" \
    || warn "graphifyy update failed — try: pipx upgrade graphifyy"
else
  info "graphifyy not installed — skipping"
fi

# ── 7. Update Emil Design Engineering skill ──
echo ""
echo "── Updating Emil Design Engineering..."
EMIL_DIR="$REPO/skills-external/emil-design-eng"
EMIL_URL="https://raw.githubusercontent.com/emilkowalski/skill/main/skills/emil-design-eng/SKILL.md"
if [ -d "$EMIL_DIR" ]; then
  info "Fetching latest SKILL.md from emilkowalski/skill..."
  curl -fsSL "$EMIL_URL" -o "$EMIL_DIR/SKILL.md.tmp" \
    && mv "$EMIL_DIR/SKILL.md.tmp" "$EMIL_DIR/SKILL.md" \
    && ok "emil-design-eng updated" \
    || warn "emil-design-eng update failed"
else
  info "emil-design-eng not installed — skipping (run: make plugin)"
fi

# ── 8. Update marketplace plugins ──
echo ""
echo "── Updating marketplace plugins..."
if command -v claude &>/dev/null; then
  _plugins=$(claude plugin list 2>/dev/null \
    | grep -oP '(?<=❯ )\S+' || true)
  if [ -n "$_plugins" ]; then
    while IFS= read -r _p; do
      _name="${_p%%@*}"
      info "Updating $_name..."
      claude plugin update "$_name" 2>/dev/null \
        && ok "$_name updated" \
        || warn "$_name update failed"
    done <<< "$_plugins"
  else
    info "No marketplace plugins installed — skipping"
  fi
else
  warn "Claude Code not found — skipping plugin update"
fi

# ── 9. Refresh symlinks ──
echo ""
echo "── Refreshing symlinks..."
bash "$REPO/link.sh"

# ── 10. Run doctor ──
echo ""
bash "$REPO/doctor.sh"
