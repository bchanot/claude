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

echo ""
echo "═══ claude-config update (v${VERSION}) ═══"
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
if git submodule update --remote skills-external/gstack 2>/dev/null; then
  if [ -d "skills-external/gstack" ]; then
    cd skills-external/gstack && ./setup 2>/dev/null && cd "$REPO"
    ok "GStack updated"
  fi
else
  warn "GStack submodule update failed — run: git submodule update --init"
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
    cargo install --git https://github.com/rtk-ai/rtk --tag "$RTK_VERSION" --force 2>/dev/null \
      && ok "RTK updated to $RTK_VERSION" \
      || warn "RTK update failed"
  else
    info "No pinned version — installing latest"
    cargo install --git https://github.com/rtk-ai/rtk --force 2>/dev/null \
      && ok "RTK updated (latest)" \
      || warn "RTK update failed"
  fi
else
  warn "Cargo not available — skipping RTK"
fi

# ── 4. Refresh symlinks ──
echo ""
echo "── Refreshing symlinks..."
bash "$REPO/link.sh"

# ── 5. Run doctor ──
echo ""
bash "$REPO/doctor.sh"
