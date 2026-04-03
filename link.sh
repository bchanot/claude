#!/usr/bin/env bash
# Symlink this repo into ~/.claude/
# Run once after cloning on a new machine.

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="$HOME/.claude"

mkdir -p "$CLAUDE"

# Core config files
ln -sf "$REPO/CLAUDE.md"      "$CLAUDE/CLAUDE.md"
ln -sf "$REPO/settings.json"  "$CLAUDE/settings.json"

# Agents and skills
ln -sf "$REPO/agents"  "$CLAUDE/agents"
ln -sf "$REPO/skills"  "$CLAUDE/skills"

# Hooks
mkdir -p "$CLAUDE/hooks"
ln -sf "$REPO/hooks/session-start.sh" "$CLAUDE/hooks/session-start.sh"

# GStack (submodule) — symlink from skills-external/ into ~/.claude/skills/
# The submodule must be initialized first (done by install-plugins.sh)
mkdir -p "$CLAUDE/skills"
if [ -d "$REPO/skills-external/gstack" ]; then
  ln -sf "$REPO/skills-external/gstack" "$CLAUDE/skills/gstack"
  echo "✅ GStack symlinked from submodule"
else
  echo "⚠️  GStack submodule not found — run: git submodule update --init"
fi

echo "✅ Symlinks created in ~/.claude/"
echo "   Next: bash install-plugins.sh"
