#!/usr/bin/env bash
# Symlink this repo into ~/.claude/
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="$HOME/.claude"
CHANGED=0

mkdir -p "$CLAUDE"

link_file() {
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    return  # already correct
  fi
  ln -sf "$src" "$dst"
  CHANGED=$((CHANGED + 1))
}

link_file "$REPO/CLAUDE.md"     "$CLAUDE/CLAUDE.md"
link_file "$REPO/settings.json" "$CLAUDE/settings.json"

for item in hooks agents skills lib templates; do
  target="$CLAUDE/$item"
  if [ -L "$target" ]; then
    if [ "$(readlink "$target")" = "$REPO/$item" ]; then
      continue  # already correct
    fi
    rm -f "$target"
  elif [ -d "$target" ]; then
    echo "⚠️  ~/.claude/$item is a real directory. Rename or remove it, then re-run link.sh."
    continue
  fi
  ln -sf "$REPO/$item" "$target"
  CHANGED=$((CHANGED + 1))
done

if [ -d "$REPO/skills-external/gstack" ]; then
  if [ -L "$CLAUDE/skills/gstack" ] && [ "$(readlink "$CLAUDE/skills/gstack")" = "$REPO/skills-external/gstack" ]; then
    : # already correct
  else
    ln -sf "$REPO/skills-external/gstack" "$CLAUDE/skills/gstack"
    CHANGED=$((CHANGED + 1))
  fi
else
  echo "⚠️  GStack submodule not found — run: git submodule update --init"
fi

if [ "$CHANGED" -eq 0 ]; then
  echo "✅ All symlinks already up to date."
else
  echo "✅ $CHANGED symlink(s) updated in ~/.claude/"
fi
echo "   Next: bash install-plugins.sh"
