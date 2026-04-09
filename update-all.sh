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

# ── 5. Update Ruflo CLI (if installed) ──
echo ""
echo "── Updating Ruflo CLI..."
if command -v ruflo &>/dev/null || detect_ruflo; then
  RUFLO_VER=""
  if [ -f "$REPO/plugins.lock.json" ] && command -v python3 &>/dev/null; then
    RUFLO_VER=$(python3 -c "
import json
with open('$REPO/plugins.lock.json') as f:
    d = json.load(f)
print(d.get('ruflo',{}).get('version',''))
" 2>/dev/null || true)
  fi

  if [ -n "$RUFLO_VER" ] && [ "$RUFLO_VER" != "latest" ]; then
    info "Pinned version: $RUFLO_VER"
    npm install -g "ruflo@${RUFLO_VER}" 2>/dev/null \
      && ok "Ruflo updated to $RUFLO_VER" \
      || warn "Ruflo update failed"
  else
    npm install -g ruflo@latest 2>/dev/null \
      && ok "Ruflo updated (latest)" \
      || warn "Ruflo update failed"
  fi
else
  info "Ruflo not installed — skipping"
fi

# ── 6. Refresh symlinks ──
echo ""
echo "── Refreshing symlinks..."
bash "$REPO/link.sh"

# ── 7. Run doctor ──
echo ""
bash "$REPO/doctor.sh"
