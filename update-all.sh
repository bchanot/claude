#!/usr/bin/env bash
# ============================================================
# Claude Code — Update all components
# Pulls latest config, updates submodules, refreshes symlinks,
# and runs doctor to verify.
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
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
  # Use the updater that matches the install channel: npm-managed installs
  # update via npm; native-installer installs self-update via `claude update`
  # (npm would EEXIST on the ~/.local/bin/claude symlink it does not own).
  if npm ls -g @anthropic-ai/claude-code &>/dev/null; then
    UPDATE_CMD=(npm install -g @anthropic-ai/claude-code@latest)
  else
    UPDATE_CMD=(claude update)
  fi
  if "${UPDATE_CMD[@]}" &>/dev/null; then
    NEW_VER=$(claude --version 2>/dev/null | head -1 || echo "unknown")
    if [ "$CURRENT_VER" = "$NEW_VER" ]; then
      ok "Claude Code already up to date ($NEW_VER)"
    else
      ok "Claude Code updated: $CURRENT_VER → $NEW_VER"
    fi
  else
    warn "Claude Code update failed — try manually: ${UPDATE_CMD[*]}"
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
  # Capture gstack state before the update so we can restore it after
  # ./setup runs (setup re-creates every symlink; without this, an
  # update would silently re-enable a tool the user had disabled).
  _gstack_state="unknown"
  if [ -x "$REPO/lib/toggle-external.sh" ]; then
    _gstack_state=$(bash "$REPO/lib/toggle-external.sh" status gstack 2>/dev/null || echo "unknown")
  fi

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

  # Refresh gstack shared infrastructure symlinks (bin/ + browse/dist/)
  GSTACK_DIR="$REPO/skills-external/gstack"
  GSTACK_DST="$HOME/.claude/skills/gstack"
  if [ -d "$GSTACK_DIR/bin" ]; then
    mkdir -p "$GSTACK_DST"
    ln -sf "$GSTACK_DIR/bin" "$GSTACK_DST/bin"
  fi
  if [ -d "$GSTACK_DIR/browse/dist" ]; then
    mkdir -p "$GSTACK_DST/browse"
    ln -sf "$GSTACK_DIR/browse/dist" "$GSTACK_DST/browse/dist"
  fi

  # Restore prior enabled/disabled state
  if [ "$_gstack_state" = "disabled" ] && [ -x "$REPO/lib/toggle-external.sh" ]; then
    bash "$REPO/lib/toggle-external.sh" disable gstack >/dev/null
    info "gstack was disabled before update — restored to disabled"
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
    if cargo install --git https://github.com/rtk-ai/rtk --tag "$RTK_VERSION" --force; then
      ok "RTK updated to $RTK_VERSION"
    else
      warn "RTK update failed"
    fi
  else
    info "No pinned version — installing latest"
    info "Compiling from source — this may take a few minutes..."
    if cargo install --git https://github.com/rtk-ai/rtk --force; then
      ok "RTK updated (latest)"
    else
      warn "RTK update failed"
    fi
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
    if npm install -g "gsd-pi@${GSD_VER}" 2>/dev/null; then
      ok "GSD v2 updated to $GSD_VER"
    else
      warn "GSD v2 update failed"
    fi
  else
    info "No pinned version — installing latest"
    if npm install -g gsd-pi 2>/dev/null; then
      ok "GSD v2 updated (latest)"
    else
      warn "GSD v2 update failed"
    fi
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
    if npm install -g "ctx7@${CTX7_VER}" 2>/dev/null; then
      ok "ctx7 updated to $CTX7_VER"
    else
      warn "ctx7 update failed"
    fi
  else
    if npm install -g ctx7@latest 2>/dev/null; then
      ok "ctx7 updated (latest)"
    else
      warn "ctx7 update failed"
    fi
  fi
else
  info "ctx7 not installed — skipping"
fi

# ── 6. Update Graphifyy ──
echo ""
echo "── Updating Graphifyy..."
if command -v graphify &>/dev/null; then
  if pipx upgrade graphifyy 2>/dev/null; then
    ok "graphifyy updated"
  else
    warn "graphifyy update failed — try: pipx upgrade graphifyy"
  fi
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
  if curl -fsSL "$EMIL_URL" -o "$EMIL_DIR/SKILL.md.tmp" \
    && mv "$EMIL_DIR/SKILL.md.tmp" "$EMIL_DIR/SKILL.md"; then
    ok "emil-design-eng updated"
  else
    warn "emil-design-eng update failed"
  fi
else
  info "emil-design-eng not installed — skipping (run: make plugin)"
fi

# ── 7.1. Update Frontend Design (from anthropic-agent-skills plugin cache) ──
echo ""
echo "── Updating Frontend Design (Anthropic)..."
FD_DIR="$REPO/skills-external/frontend-design"
FD_PLUGIN_CACHE="$HOME/.claude/plugins/cache/anthropic-agent-skills/example-skills"
FD_LATEST="$(find "$FD_PLUGIN_CACHE" -maxdepth 1 -type d 2>/dev/null | sort | tail -1)"
if [ -d "$FD_DIR" ]; then
  if [ -n "$FD_LATEST" ] && [ -f "$FD_LATEST/skills/frontend-design/SKILL.md" ]; then
    cp "$FD_LATEST/skills/frontend-design/SKILL.md" "$FD_DIR/SKILL.md"
    [ -f "$FD_LATEST/skills/frontend-design/LICENSE.txt" ] && cp "$FD_LATEST/skills/frontend-design/LICENSE.txt" "$FD_DIR/LICENSE.txt"
    ok "frontend-design synced from plugin cache"
  else
    warn "frontend-design: anthropic-agent-skills cache not found — keeping current version"
  fi
else
  info "frontend-design not installed — skipping (run: make plugin)"
fi

# ── 7.2. Update Design Motion Principles (from GitHub) ──
echo ""
echo "── Updating Design Motion Principles (kylezantos)..."
DMP_DIR="$REPO/skills-external/design-motion-principles"
if [ -d "$DMP_DIR" ]; then
  DMP_TMP="$(mktemp -d)"
  if git clone --depth 1 https://github.com/kylezantos/design-motion-principles.git "$DMP_TMP" 2>/dev/null; then
    cp -r "$DMP_TMP/skills/design-motion-principles/"* "$DMP_DIR/"
    ok "design-motion-principles synced from GitHub"
  else
    warn "design-motion-principles: GitHub fetch failed — keeping current version"
  fi
  rm -rf "$DMP_TMP"
else
  info "design-motion-principles not installed — skipping"
fi

# ── 7.5. Update external skills (npx skills) ──
echo ""
echo "── Updating external skills (npx skills)..."
if command -v npx &>/dev/null; then
  NPX_SKILLS=(
    "alchaincyf/darwin-skill"
    "alchaincyf/find-skills"
  )
  for _src in "${NPX_SKILLS[@]}"; do
    _name="${_src##*/}"
    if [ ! -d "$HOME/.agents/skills/$_name" ]; then
      info "$_name not installed — skipping (run: make plugin)"
      continue
    fi
    # `skills add` is idempotent and pulls latest from the source repo,
    # which is the closest thing to an update operation the CLI exposes.
    # Run from $HOME: the CLI resolves .agents/skills/ relative to the CWD, so
    # running from the repo would write into $REPO/.agents/skills (gitignored)
    # instead of $HOME/.agents/skills where link.sh expects it.
    if (cd "$HOME" && npx -y skills add "$_src" 2>/dev/null); then
      ok "$_name refreshed from $_src"
    else
      warn "$_name refresh failed — run manually: (cd \"\$HOME\" && npx -y skills add $_src)"
    fi
  done
else
  info "npx not available — skipping external skills"
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
      # Pass the full "name@marketplace" spec — the CLI rejects
      # the bare name when several marketplaces are registered.
      if claude plugin update "$_p" 2>/dev/null; then
        ok "$_name updated"
      else
        warn "$_name update failed"
      fi
    done <<< "$_plugins"
  else
    info "No marketplace plugins installed — skipping"
  fi
else
  warn "Claude Code not found — skipping plugin update"
fi

# ── 9. Update shellcheck ──
echo ""
echo "── Updating shellcheck..."
if command -v shellcheck &>/dev/null; then
  # Detect OS for package manager update
  if [[ "$OSTYPE" == "darwin"* ]]; then
    if brew upgrade shellcheck 2>/dev/null; then
      ok "shellcheck updated"
    else
      ok "shellcheck already up to date"
    fi
  elif command -v apt-get &>/dev/null; then
    if sudo apt-get install -y --only-upgrade shellcheck 2>/dev/null; then
      ok "shellcheck updated"
    else
      ok "shellcheck already up to date"
    fi
  elif command -v dnf &>/dev/null; then
    if sudo dnf upgrade -y shellcheck 2>/dev/null; then
      ok "shellcheck updated"
    else
      ok "shellcheck already up to date"
    fi
  elif command -v pacman &>/dev/null; then
    if sudo pacman -S --noconfirm shellcheck 2>/dev/null; then
      ok "shellcheck updated"
    else
      ok "shellcheck already up to date"
    fi
  else
    info "shellcheck installed via binary — update manually"
  fi
else
  info "shellcheck not installed — skipping (run: make plugin)"
fi

# ── 10. Refresh symlinks ──
echo ""
echo "── Refreshing symlinks..."
bash "$REPO/link.sh"

# ── 11. Run doctor ──
echo ""
bash "$REPO/doctor.sh"
