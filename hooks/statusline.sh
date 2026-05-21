#!/usr/bin/env bash
# Claude Code statusline — model, folder, branch, profile, effort, context bar, session start
# Receives JSON on stdin from Claude Code.

INPUT=$(cat)

MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "?"')
DIR=$(echo "$INPUT" | jq -r '.cwd // "?"')
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

# Active profile (written by lib/profile.sh set|apply|reset to <repo>/.active-profile).
# Read directly — `profile.sh current` is 12s+ and unusable in a statusline.
PROFILE="?"
if [ -f "$REPO/.active-profile" ]; then
  PROFILE=$(head -n1 "$REPO/.active-profile" | tr -d '[:space:]')
  [ -z "$PROFILE" ] && PROFILE="?"
fi

# Effort level from settings.json (.effortLevel — set by /effort or manual edit).
# settings.json is the source-of-truth, symlinked into ~/.claude/settings.json.
EFFORT="?"
if [ -f "$REPO/settings.json" ]; then
  EFFORT=$(jq -r '.effortLevel // "?"' "$REPO/settings.json" 2>/dev/null)
  [ -z "$EFFORT" ] && EFFORT="?"
fi

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
