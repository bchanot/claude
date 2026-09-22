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

link_file "$REPO/CLAUDE.global.md" "$CLAUDE/CLAUDE.md"
link_file "$REPO/settings.json" "$CLAUDE/settings.json"

# Global git hooks (BDR-095): githooks/ is generated from lib/gitflow.sh so it
# never drifts from the per-repo .githooks/ the lib writes, and git's GLOBAL
# core.hooksPath points at ~/.claude/githooks → every repo on this machine is
# protected and auto-pushed, even one that never ran gitflow init. A repo's
# own local core.hooksPath still wins (git precedence), which is what the
# session-start reconcile is for.
# The tilde is stored literally on purpose: git expands `~` in core.hooksPath
# itself, so the setting stays valid on any machine and for any HOME.
# shellcheck disable=SC2088
_gh_before=$(git config --global core.hooksPath 2>/dev/null || true)
# shellcheck disable=SC2088
bash "$REPO/lib/gitflow.sh" global-hooks "$REPO/githooks" '~/.claude/githooks'
# shellcheck disable=SC2088
if [ "$_gh_before" != '~/.claude/githooks' ]; then
  echo "🪝 git config --global core.hooksPath ~/.claude/githooks (was: ${_gh_before:-unset})"
  CHANGED=$((CHANGED + 1))
fi
unset _gh_before

for item in hooks githooks agents skills lib templates rules; do
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

# GStack is exposed via per-skill symlinks under skills/ (browse,
# canary, autoplan, design-review, …) created by gstack's own
# `./setup`. A global `skills/gstack -> skills-external/gstack/`
# symlink duplicated the top-level gstack SKILL.md alongside those
# individual skills, producing two entries with the same description
# ("Fast headless browser for QA testing…"). Remove any stale global
# link — only per-skill entries remain.
if [ -L "$REPO/skills/gstack" ] || [ -L "$CLAUDE/skills/gstack" ]; then
  rm -f "$REPO/skills/gstack" "$CLAUDE/skills/gstack"
  CHANGED=$((CHANGED + 1))
fi
if [ ! -d "$REPO/skills-external/gstack" ]; then
  echo "⚠️  GStack submodule not found — run: git submodule update --init"
fi

# GStack shared infrastructure: bin/ (CLI tools, config, analytics) and
# browse/dist/ (compiled browse binary). Per-skill SKILL.md symlinks don't
# expose these, but multiple skills hardcode ~/.claude/skills/gstack/bin/
# and ~/.claude/skills/gstack/browse/dist/. Create targeted symlinks.
GSTACK_SRC="$REPO/skills-external/gstack"
GSTACK_DST="$CLAUDE/skills/gstack"
if [ -d "$GSTACK_SRC/bin" ]; then
  mkdir -p "$GSTACK_DST"
  if [ ! -L "$GSTACK_DST/bin" ]; then
    ln -sf "$GSTACK_SRC/bin" "$GSTACK_DST/bin"
    CHANGED=$((CHANGED + 1))
  fi
fi
if [ -d "$GSTACK_SRC/browse/dist" ]; then
  mkdir -p "$GSTACK_DST/browse"
  if [ ! -L "$GSTACK_DST/browse/dist" ]; then
    ln -sf "$GSTACK_SRC/browse/dist" "$GSTACK_DST/browse/dist"
    CHANGED=$((CHANGED + 1))
  fi
fi

# impeccable is NOT here: its installer writes the skill straight into
# skills/ (and its agents into agents/) at --scope=global, so there is no
# skills-external/ copy to symlink. See install-plugins.sh Step 8d.
EXTERNAL_SKILLS=(emil-design-eng frontend-design design-motion-principles)
for _ext_skill in "${EXTERNAL_SKILLS[@]}"; do
  if [ -d "$REPO/skills-external/$_ext_skill" ]; then
    if [ -L "$CLAUDE/skills/$_ext_skill" ] && [ "$(readlink "$CLAUDE/skills/$_ext_skill")" = "$REPO/skills-external/$_ext_skill" ]; then
      : # already correct
    else
      ln -sf "$REPO/skills-external/$_ext_skill" "$CLAUDE/skills/$_ext_skill"
      CHANGED=$((CHANGED + 1))
    fi
  else
    echo "⚠️  $_ext_skill not found — run: make plugin"
  fi
done

# External skills installed via `npx skills add` live under
# $HOME/.agents/skills/. We symlink them into $REPO/skills/ with
# absolute paths so the link stays valid regardless of where the
# repo is cloned (relative ../../ paths broke on repos deeper than
# one level below $HOME).
NPX_EXTERNAL_SKILLS=(darwin-skill)
for _ext in "${NPX_EXTERNAL_SKILLS[@]}"; do
  _target="$HOME/.agents/skills/$_ext"
  _link="$REPO/skills/$_ext"
  if [ ! -d "$_target" ]; then
    echo "⚠️  $_ext not installed at $_target — run: make plugin"
    continue
  fi
  if [ -L "$_link" ] && [ "$(readlink "$_link")" = "$_target" ]; then
    continue
  fi
  rm -f "$_link"
  ln -sf "$_target" "$_link"
  CHANGED=$((CHANGED + 1))
done

# ── Local secrets: repo/.env -> ~/.claude/.env ──────────────
# Real key lives in ~/.claude/.env (source of truth, outside the repo so the
# secret never enters the git tree). The repo reaches it via a symlink that
# `source "$REPO/.env"` follows transparently. Never creates/copies/prints it.
link_env() {
  local home_env="$CLAUDE/.env" repo_env="$REPO/.env"
  if [ ! -f "$home_env" ]; then
    echo "⚠️  $home_env missing — create it (the repo never stores the secret):"
    echo "       cp \"$REPO/.env.example\" \"$home_env\" && \"\${EDITOR:-nano}\" \"$home_env\""
    return
  fi
  if [ -L "$repo_env" ]; then
    [ "$(readlink "$repo_env")" = "$home_env" ] && return
    ln -sf "$home_env" "$repo_env"; CHANGED=$((CHANGED + 1))
  elif [ ! -e "$repo_env" ]; then
    ln -sf "$home_env" "$repo_env"; CHANGED=$((CHANGED + 1))
  else
    echo "⚠️  $repo_env is a real file, not a symlink."
    echo "    If it holds your secret:  mv \"$repo_env\" \"$home_env\"  then re-run link.sh"
    echo "    Otherwise remove it so link.sh can link to $home_env."
  fi
}
link_env

if [ "$CHANGED" -eq 0 ]; then
  echo "✅ All symlinks already up to date."
else
  echo "✅ $CHANGED symlink(s) updated in ~/.claude/"
fi
echo "   Next: bash install-plugins.sh"
