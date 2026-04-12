#!/usr/bin/env bash
# Claude Code statusline — folder, git branch, model, context %
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
echo -e "$MODEL | $FOLDER${BRANCH_STR} | ${COLOR}${BAR}${RESET} ${PCT}%"
