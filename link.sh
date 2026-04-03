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
ln -sf "$REPO/agents"    "$CLAUDE/agents"
ln -sf "$REPO/skills"    "$CLAUDE/skills"

# Hooks
mkdir -p "$CLAUDE/hooks"
ln -sf "$REPO/hooks/session-start.sh" "$CLAUDE/hooks/session-start.sh"

echo "✅ Symlinks created in ~/.claude/"
echo "   Run: bash install-plugins.sh"
