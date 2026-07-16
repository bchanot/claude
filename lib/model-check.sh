#!/usr/bin/env bash
# lib/model-check.sh — classify the persisted session model: big | small | unknown
#
# Witness for lib/model-gate.md (reflection requires a big model). Reads the
# "model" key of the user-scope settings (the file /model rewrites — LRN-098).
# Override the source with MODEL_CHECK_SETTINGS (tests use fixtures).
#
# stdout : <class>:<raw>   (raw = value found, empty if none)
# exit   : 0 = big (fable/opus) · 2 = small (sonnet/haiku) · 3 = unknown
set -u

SETTINGS="${MODEL_CHECK_SETTINGS:-$HOME/.claude/settings.json}"

raw=""
if [ -f "$SETTINGS" ]; then
  raw="$(python3 - "$SETTINGS" 2>/dev/null <<'PY'
import json, sys
try:
    v = json.load(open(sys.argv[1])).get("model", "")
    print(v if isinstance(v, str) else "")
except Exception:
    print("")
PY
)"
fi

norm="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
case "$norm" in
  *opusplan*)       printf 'unknown:%s\n' "$raw"; exit 3 ;; # opus-for-plan, sonnet otherwise — ambiguous
  *fable*|*opus*)   printf 'big:%s\n'     "$raw"; exit 0 ;;
  *sonnet*|*haiku*) printf 'small:%s\n'   "$raw"; exit 2 ;;
  *)                printf 'unknown:%s\n' "$raw"; exit 3 ;;
esac
