#!/usr/bin/env bash
# ============================================================
# Claude Code — Plugin installer
# Run this after a fresh clone to reinstall all plugins
# ============================================================
set -euo pipefail

echo "=== Claude Code Plugin Installer ==="
echo ""

# ---- Marketplace officielle (already registered by default) ----
echo ">> Installing official Anthropic plugins..."
claude plugin install security-guidance@claude-plugins-official
claude plugin install frontend-design@claude-plugins-official
claude plugin install skill-creator@claude-plugins-official
claude plugin install pr-review-toolkit@claude-plugins-official

# ---- Superpowers ----
echo ""
echo ">> Installing Superpowers..."
claude plugin marketplace add obra/superpowers-marketplace 2>/dev/null || true
claude plugin install superpowers@superpowers-marketplace

# ---- UI/UX Pro Max ----
echo ""
echo ">> Installing UI/UX Pro Max..."
claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill 2>/dev/null || true
claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill

# ---- GSD ----
echo ""
echo ">> Installing GSD (get-shit-done)..."
npx get-shit-done-cc --claude --global --auto

# ---- GStack ----
echo ""
echo ">> Installing GStack (Garry Tan)..."
if [ ! -d "$HOME/.claude/skills/gstack" ]; then
  git clone --single-branch --depth 1 \
    https://github.com/garrytan/gstack.git \
    "$HOME/.claude/skills/gstack"
fi
cd "$HOME/.claude/skills/gstack" && ./setup
cd -

# ---- RTK ----
echo ""
echo ">> Installing RTK (token compression)..."
if ! command -v rtk &>/dev/null; then
  cargo install --git https://github.com/rtk-ai/rtk
fi
rtk init -g --auto-patch

# ---- Context7 MCP ----
echo ""
echo ">> Context7 MCP — manual step required:"
echo "   Get a free API key at https://context7.com"
echo "   Then run:"
echo "   claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp --api-key YOUR_KEY"

# ---- Joey Barbier plugins ----
echo ""
echo ">> Installing Joey Barbier plugins..."
claude plugin marketplace add joey-barbier/ClaudeCode-Plugin 2>/dev/null || true
claude plugin install review@joey-barbier-plugins 2>/dev/null || \
  echo "   Warning: verify plugin name at github.com/joey-barbier/ClaudeCode-Plugin"
claude plugin install memory@joey-barbier-plugins 2>/dev/null || \
  echo "   Warning: verify plugin name at github.com/joey-barbier/ClaudeCode-Plugin"

echo ""
echo "=== Done! Restart Claude Code to activate all plugins. ==="
echo ""
echo "Plugins installed (marketplace-managed, not committed to git):"
echo "  - security-guidance    (Anthropic official)"
echo "  - frontend-design      (Anthropic official)"
echo "  - skill-creator        (Anthropic official)"
echo "  - pr-review-toolkit    (Anthropic official)"
echo "  - superpowers          (obra/superpowers)"
echo "  - ui-ux-pro-max        (nextlevelbuilder)"
echo "  - gsd                  (glittercowboy)"
echo "  - rtk                  (rtk-ai, system binary + hook)"
echo ""
echo "Skills committed to git (available without reinstall):"
echo "  ~/.claude/skills/gstack  (garrytan)"
