#!/usr/bin/env bash
# hooks/instructions-loaded.sh — InstructionsLoaded hook: one JSON line per
# instruction file the engine loads, into
# ~/.claude/logs/instructions-loaded.jsonl. The proof channel for
# path-scoped rules (BDR-125 phase 0): a rule that loaded shows
# `load_reason: path_glob_match`, the file that triggered it, and the
# session or sub-agent that loaded it. Never blocks, never prints to
# stdout (stdout reaches the model), exits 0 whatever happens. Rotates to
# <log>.1 above 5 MB. CLAUDE_INSTRUCTIONS_LOG overrides the path (tests).
log="${CLAUDE_INSTRUCTIONS_LOG:-$HOME/.claude/logs/instructions-loaded.jsonl}"
command -v jq >/dev/null 2>&1 || exit 0
mkdir -p "$(dirname "$log")" 2>/dev/null || exit 0
if [ -f "$log" ] && [ "$(wc -c < "$log")" -gt 5242880 ]; then
  mv -f "$log" "$log.1" 2>/dev/null
fi
jq -c --arg ts "$(date -u +%FT%TZ)" '{ts: $ts, session_id, agent_id,
  agent_type, cwd, file_path, memory_type, load_reason, globs,
  trigger_file_path}' >> "$log" 2>/dev/null
exit 0
