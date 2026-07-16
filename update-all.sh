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
# TTY guard: in a non-interactive run (cron, CI, background shell) `read`
# hits EOF and dies under set -e — the whole update aborted mid-script.
# Default to the safe N and keep going; interactive behavior unchanged.
if [ -t 0 ]; then
  printf "  Proceed with GStack update? [y/N] "
  read -r _gstack_confirm
else
  info "Non-interactive run — skipping GStack update (run in a terminal to be prompted)"
  _gstack_confirm="n"
fi
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
# cargo lives in ~/.cargo/bin, which hand-managed profiles lose (BLK-016
# class) — source cargo env, as install-plugins.sh does, before concluding
# cargo is absent. Without this the step silently never updated rtk.
if ! command -v cargo &>/dev/null && [ -f "$HOME/.cargo/env" ]; then
  # shellcheck disable=SC1091
  source "$HOME/.cargo/env"
fi
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

  # Version-jump guard: a cargo build takes minutes — only pay it when the
  # target (pin, or the newest remote tag for "latest") differs from what is
  # installed. Same pin-honored/skip-on-match shape as the semgrep step.
  RTK_CUR=$(rtk --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
  [ -z "$RTK_CUR" ] && RTK_CUR=$("$HOME/.cargo/bin/rtk" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)

  if [ -n "$RTK_VERSION" ] && [ "$RTK_VERSION" != "latest" ]; then
    if [ "${RTK_VERSION#v}" = "$RTK_CUR" ]; then
      ok "rtk already at pinned $RTK_CUR"
    else
      info "Pinned version: $RTK_VERSION (installed: ${RTK_CUR:-none})"
      info "Compiling from source — this may take a few minutes..."
      if cargo install --git https://github.com/rtk-ai/rtk --tag "$RTK_VERSION" --force; then
        ok "RTK updated to $RTK_VERSION"
      else
        warn "RTK update failed"
      fi
    fi
  else
    # "latest" = newest release TAG, resolved by name and installed BY TAG.
    # (A bare `cargo install --git` builds the default-branch HEAD, whose
    # Cargo.toml version can trail the newest tag — the guard would then
    # never converge and recompile on every run.)
    RTK_TIP_TAG=$(git ls-remote --tags https://github.com/rtk-ai/rtk 2>/dev/null \
      | sed -n 's|.*refs/tags/\(v\{0,1\}[0-9][0-9.]*\)$|\1|p' | sort -V | tail -1 || true)
    RTK_TIP="${RTK_TIP_TAG#v}"
    if [ -n "$RTK_TIP" ] && [ "$RTK_TIP" = "$RTK_CUR" ]; then
      ok "rtk already at latest tag ($RTK_CUR)"
    else
      info "No pin — latest tag: ${RTK_TIP_TAG:-unknown} (installed: ${RTK_CUR:-none})"
      info "Compiling from source — this may take a few minutes..."
      if [ -n "$RTK_TIP_TAG" ] && cargo install --git https://github.com/rtk-ai/rtk --tag "$RTK_TIP_TAG" --force; then
        ok "RTK updated to $RTK_TIP_TAG"
      elif [ -z "$RTK_TIP_TAG" ] && cargo install --git https://github.com/rtk-ai/rtk --force; then
        ok "RTK updated (latest HEAD — no tag resolvable)"
      else
        warn "RTK update failed"
      fi
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

# ── 6.2. Update Semgrep (pin-honored — BLOCKING security gate) ──
echo ""
echo "── Updating Semgrep..."
if command -v semgrep &>/dev/null; then
  SEMGREP_VER=""
  if [ -f "$REPO/plugins.lock.json" ] && command -v python3 &>/dev/null; then
    SEMGREP_VER=$(python3 -c "
import json
with open('$REPO/plugins.lock.json') as f:
    d = json.load(f)
print(d.get('semgrep',{}).get('version',''))
" 2>/dev/null || true)
  fi

  SEMGREP_CUR=$(semgrep --version 2>/dev/null | head -1)
  if [ -n "$SEMGREP_VER" ] && [ "$SEMGREP_VER" != "latest" ]; then
    if [ "$SEMGREP_CUR" = "$SEMGREP_VER" ]; then
      ok "semgrep already at pinned $SEMGREP_VER"
    else
      # Jump shown explicitly: semgrep is a BLOCKING gate — a version bump
      # can add rules that BLOCK unchanged code, so the jump must be a
      # visible, deliberate human decision (bump the pin, then update).
      info "semgrep ${SEMGREP_CUR:-?} → ${SEMGREP_VER} (pinned in plugins.lock.json)"
      if pipx install --force "semgrep==${SEMGREP_VER}" 2>/dev/null; then
        ok "semgrep updated to $SEMGREP_VER"
      else
        warn "semgrep update failed — try: pipx install --force semgrep==${SEMGREP_VER}"
      fi
    fi
  else
    info "No pinned version — upgrading to latest"
    if pipx upgrade semgrep 2>/dev/null; then
      ok "semgrep updated ($(semgrep --version 2>/dev/null | head -1))"
    else
      warn "semgrep update failed — try: pipx upgrade semgrep"
    fi
  fi
else
  info "semgrep not installed — skipping (run: make plugin)"
fi

# ── 6.5. Update bun ──
echo ""
echo "── Updating bun..."
if command -v bun &>/dev/null; then
  if bun upgrade >/dev/null 2>&1; then
    ok "bun $(bun --version 2>/dev/null || echo '?') (self-upgrade)"
  else
    warn "bun upgrade failed — try manually: bun upgrade"
  fi
else
  info "bun not installed — skipping"
fi
# NOT updated here, deliberately (audit 2026-07-02):
# - magic MCP: registered as `npx -y @21st-dev/magic@latest` — npx resolves
#   the latest release at every invocation, nothing to upgrade.
# - graphify Claude integration (`graphify claude install`): rewrites curated
#   CLAUDE.md / .claude/settings.json (BDR-028 guard territory) — re-run
#   MANUALLY only if a graphify upgrade changes its hook format.
# - gsd: pinned in plugins.lock.json — Step 4 reinstalls the PIN, it does not
#   advance it. Bump the lock deliberately, then re-run.

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

# ── Impeccable (design anti-pattern detector + skill) ──
echo ""
echo "── Updating impeccable..."
IMP_DIR="$REPO/skills-external/impeccable"
if [ ! -f "$IMP_DIR/SKILL.md" ]; then
  info "impeccable not installed — skipping (run: make plugin)"
else
  IMP_VER=""
  if [ -f "$REPO/plugins.lock.json" ] && command -v python3 &>/dev/null; then
    IMP_VER=$(python3 -c "
import json
with open('$REPO/plugins.lock.json') as f:
    d = json.load(f)
print(d.get('impeccable',{}).get('version','latest'))
" 2>/dev/null || true)
  fi
  IMP_NODE=$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1)
  if [ -z "${IMP_NODE:-}" ] || [ "$IMP_NODE" -lt 24 ]; then
    info "impeccable update skipped — needs Node >= 24 (found ${IMP_NODE:-none}); existing dist kept"
  else
    IMP_PKG="impeccable"
    # Pin honored (LRN-077 class: a silent rules update changes audit
    # output on unchanged code) — bump the pin deliberately, then update.
    [ -n "$IMP_VER" ] && [ "$IMP_VER" != "latest" ] && IMP_PKG="impeccable@${IMP_VER}"
    IMP_STAGE=$(mktemp -d)
    if (cd "$IMP_STAGE" && npx -y "$IMP_PKG" skills install -y --providers=claude --scope=project --no-hooks >/dev/null 2>&1); then
      IMP_SRC=$(find "$IMP_STAGE" -type d -name impeccable -path "*skills*" 2>/dev/null | head -1)
      if [ -n "$IMP_SRC" ] && [ -f "$IMP_SRC/SKILL.md" ]; then
        rm -rf "$IMP_DIR"
        mv "$IMP_SRC" "$IMP_DIR"
        ok "impeccable refreshed (CLI ${IMP_VER:-latest})"
      else
        warn "impeccable: installer produced no dist — existing kept"
      fi
    else
      warn "impeccable refresh failed — existing dist kept"
    fi
    rm -rf "$IMP_STAGE"
  fi
fi

# ── 7.5. Update external skills (npx skills) ──
echo ""
echo "── Updating external skills (npx skills)..."
if command -v npx &>/dev/null; then
  NPX_SKILLS=(
    "alchaincyf/darwin-skill"
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
