#!/usr/bin/env bash
# Claude Code statusline — model, folder, branch, profile, effort, context bar, session start
# Receives JSON on stdin from Claude Code.

INPUT=$(cat)

MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "?"')
DIR=$(echo "$INPUT" | jq -r '.cwd // "?"')
PROJ=$(echo "$INPUT" | jq -r '.workspace.project_dir // .cwd // "."' 2>/dev/null)
FOLDER="${DIR##*/}"
PCT=$(echo "$INPUT" | jq -r \
  '.context_window.used_percentage // 0' \
  | cut -d. -f1)

# Git branch (fast, no network)
BRANCH=""
if [ -d "$DIR" ]; then
  BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
fi
BRANCH_STR="${BRANCH:+ ($BRANCH)}"

REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Profile of this project and conversation: `profile.sh current --plain`
# (two jq calls) on the session's project dir. `(conv)` = a --settings
# conversation. Any failure -> "?".
_plain="$(bash "$REPO/lib/profile.sh" -C "$PROJ" current --plain 2>/dev/null)" || _plain=""
PROFILE="$(sed -n 's/^profile=//p' <<<"$_plain" | head -1)"
[ -n "$PROFILE" ] || PROFILE="?"
[ "$(sed -n 's/^source=//p' <<<"$_plain" | head -1)" = flag ] && PROFILE="$PROFILE (conv)"

# Effort level: the live value when the harness exports it (skill/agent
# `effort:` shifts included, BDR-107), else the persisted settings.json key
# (.effortLevel — set by /effort or manual edit; symlinked into ~/.claude).
EFFORT="${CLAUDE_EFFORT:-}"
if [ -z "$EFFORT" ] && [ -f "$REPO/settings.json" ]; then
  EFFORT=$(jq -r '.effortLevel // "?"' "$REPO/settings.json" 2>/dev/null)
fi
[ -z "$EFFORT" ] && EFFORT="?"

# Session duration (from total_duration_ms)
DURATION_MS=$(echo "$INPUT" | jq -r \
  '.cost.total_duration_ms // 0' | cut -d. -f1)
DURATION_S=$((DURATION_MS / 1000))
if [ "$DURATION_S" -ge 3600 ]; then
  DURATION="$((DURATION_S / 3600))h$((DURATION_S % 3600 / 60))m"
elif [ "$DURATION_S" -ge 60 ]; then
  DURATION="$((DURATION_S / 60))m"
else
  DURATION="<1m"
fi

# Progress bar (20 chars wide)
WIDTH=20
FILLED=$((PCT * WIDTH / 100))
EMPTY=$((WIDTH - FILLED))
if [ "$FILLED" -gt 0 ]; then
  printf -v FILL "%${FILLED}s"
else
  FILL=""
fi
if [ "$EMPTY" -gt 0 ]; then
  printf -v PAD "%${EMPTY}s"
else
  PAD=""
fi
BAR="${FILL// /█}${PAD// /░}"

# Color: green <50%, yellow 50-79%, red >=80%
if [ "$PCT" -ge 80 ]; then
  COLOR="\033[31m"
elif [ "$PCT" -ge 50 ]; then
  COLOR="\033[33m"
else
  COLOR="\033[32m"
fi
RESET="\033[0m"

# Output: single line
echo -e "$MODEL | $FOLDER${BRANCH_STR} | profile: ${PROFILE} | effort: ${EFFORT} | ${COLOR}${BAR}${RESET} ${PCT}% | ${DURATION}"
