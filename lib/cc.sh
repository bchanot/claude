#!/usr/bin/env bash
# ============================================================
# lib/cc.sh — `cc <name> [profile]`: a named dtach session running claude,
# optionally under a per-conversation profile.
#
# Sourced from ~/.bashrc (user step, MIGRATION.md), guarded so a checkout
# without the file does not break the shell:
#   [ -f "$HOME/.claude/lib/cc.sh" ] && . "$HOME/.claude/lib/cc.sh"
# The old `dtach_claude()` and `alias cc='dtach_claude'` must go (an alias
# wins over this function and drops the profile argument; doctor warns).
#
# With a profile, claude starts with `--settings lib/profiles/<profile>.json`
# and the session exports CLAUDE_PROFILE + CLAUDE_PROFILE_SETTINGS, which
# `profile.sh current` reads (source=flag). That conversation is frozen:
# `/reload-plugins` re-reads neither the flag file nor a local value the
# flag overrides; to change packs, start another `cc <name> <profile>`.
# Without a profile: manifest defaults + local settings, as before.
# TMPDIR goes to ~/.cache/claude-tmp either way (BLK-021).
# ============================================================

cc() {
  local name="${1:-claude-$(date +%H%M%S)}" profile="${2:-}"
  local lib="$HOME/.claude/lib" settings=""
  if [ -n "$profile" ]; then
    settings="$lib/profiles/$profile.json"
    if [ ! -f "$settings" ]; then
      echo "cc: unknown profile '$profile'. Known:" >&2
      bash "$lib/profile.sh" list >&2
      return 2
    fi
  fi
  mkdir -p "$HOME/.cache/claude-tmp" "$HOME/.dtach"
  # shellcheck disable=SC2016,SC1003  # the inner shell expands $HOME; '^\' is dtach's detach key
  CLAUDE_PROFILE="$profile" CLAUDE_PROFILE_SETTINGS="$settings" \
  TMPDIR="$HOME/.cache/claude-tmp" \
  systemd-run --user --quiet --collect --scope --slice=dev.slice \
    --unit="cc-${name}" \
    dtach -c "$HOME/.dtach/${name}" -e '^\' \
      bash -c 'set -a; [ -f "$HOME/.claude/.env" ] && . "$HOME/.claude/.env"
               set +a
               if [ -n "$CLAUDE_PROFILE_SETTINGS" ]; then
                 exec claude --settings "$CLAUDE_PROFILE_SETTINGS"
               fi
               exec claude'
}
