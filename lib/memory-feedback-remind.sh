#!/usr/bin/env bash
# lib/memory-feedback-remind.sh — the phase 4d reminder line of the
# session-start banner (BDR-057: transcripts live 7 days). One line when
# /memory-feedback never ran, or ran REMIND_DAYS+ days ago and the memory
# store changed since. Silent once both gates are recorded ("closed":true),
# with "recall": false, or on any error; always rc 0. bash 3.2 safe,
# portable (find -mtime, no stat -c), no JSON parse.
REMIND_DAYS=5
state="$HOME/.claude/memory-feedback/state.json"

store=""
for f in "$HOME"/.claude/plugins/store/memory_skills-dir-*.json; do
  [ -f "$f" ] || continue
  if [ -z "$store" ] || [ "$f" -nt "$store" ]; then store=$f; fi
done
[ -n "$store" ] || exit 0
# recall off: no record can come (the 4b capture still writes the store)
grep -Eq '"recall"[[:space:]]*:[[:space:]]*false' \
  "$HOME/.claude/memory.json" 2>/dev/null && exit 0
if [ ! -f "$state" ]; then
  echo "memory feedback: never run → /memory-feedback"
  exit 0
fi
[ -r "$state" ] || exit 0
grep -q '"closed":true' "$state" 2>/dev/null && exit 0
[ "$store" -nt "$state" ] || exit 0
[ -n "$(find "$state" -mtime +$((REMIND_DAYS - 1)) 2>/dev/null)" ] || exit 0
echo "memory feedback: last run ${REMIND_DAYS}+ d ago," \
  "transcripts expire at 7 → /memory-feedback"
exit 0
