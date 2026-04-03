#!/usr/bin/env bash
# Symlink this repo into ~/.claude/
# Run once after cloning on a new machine.

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="$HOME/.claude"

mkdir -p "$CLAUDE"

# Core config files (plain files — ln -sf handles these correctly)
ln -sf "$REPO/CLAUDE.md"      "$CLAUDE/CLAUDE.md"
ln -sf "$REPO/settings.json"  "$CLAUDE/settings.json"

# Agents and skills — must handle the case where target exists
# as a real directory (ln -sf would create a link INSIDE the dir
# instead of replacing it)
for item in agents skills lib; do
  target="$CLAUDE/$item"
  if [ -L "$target" ]; then
    # Stale symlink from a previous run — remove before recreating
    rm -f "$target"
  elif [ -d "$target" ]; then
    echo "⚠️  ~/.claude/$item is a real directory (not a symlink)."
    echo "   Rename or remove it, then re-run link.sh."
    echo "   Skipping $item to avoid data loss."
    continue
  fi
  ln -sf "$REPO/$item" "$target"
done

# Hooks
mkdir -p "$CLAUDE/hooks"
ln -sf "$REPO/hooks/session-start.sh" "$CLAUDE/hooks/session-start.sh"

# GStack (submodule) — symlink into ~/.claude/skills/ (which points to repo/skills/)
# The submodule must be initialized first (done by install-plugins.sh)
if [ -d "$REPO/skills-external/gstack" ]; then
  ln -sf "$REPO/skills-external/gstack" "$CLAUDE/skills/gstack"
  echo "✅ GStack symlinked from submodule"
else
  echo "⚠️  GStack submodule not found — run: git submodule update --init"
fi

echo "✅ Symlinks created in ~/.claude/"
echo "   Next: bash install-plugins.sh"
