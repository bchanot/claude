#!/usr/bin/env bash
# One-time OAuth consent wrapper — runnable from ANY directory:
#   bash ~/.claude/lib/seo-data/connect.sh --label <label>
# Sources the env vault internally (never echoed), prefers the engine venv,
# then execs connect.py. Interactive by design: stdout carries the auth URL,
# stderr stays visible (unlike fetch.sh, there is no secret-leak surface to
# suppress — connect.py never prints tokens).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SEO_DATA_ENV_FILE:-${HOME}/.claude/.env}"  # canonical; tests override to /dev/null
VENV_PY="${HOME}/.claude/.venv-seo-data/bin/python3"

# Whole-string label guard (shell-safe ASCII: leading alnum then alnum/._-).
# POSIX `case` in a C-locale subshell: no per-line grep pitfall (a newline is
# a non-allowed byte caught by *[!...]*), no locale range surprise, no second
# grammar to differ from. Empty and non-alnum-leading are rejected too.
_label_safe() ( LC_ALL=C; case "$1" in ''|[!A-Za-z0-9]*|*[!A-Za-z0-9._-]*) exit 1;; esac )

# Strict argv grammar (parser-differential defense): accept ONLY the exact
# forms `--label <value>` / `--store <path>` — never `=`-joined or abbreviated
# forms — so the downstream argparse can never resolve a token this guard
# didn't see. Runs BEFORE any secret is loaded.
argv=("$@"); n=${#argv[@]}; i=0
while [ "$i" -lt "$n" ]; do
  case "${argv[$i]}" in
    --label)
      if ! _label_safe "${argv[$((i+1))]:-}"; then
        echo "connect.sh: unsafe label — must match ^[A-Za-z0-9][A-Za-z0-9._-]*\$" >&2
        exit 2
      fi
      i=$((i+2)) ;;
    --store) i=$((i+2)) ;;
    *)
      echo "connect.sh: unsupported argument '${argv[$i]}' — usage: connect.sh --label <label> [--store <path>]" >&2
      exit 2 ;;
  esac
done

# Load secrets quietly (sourced, never echoed).
if [ -f "$ENV_FILE" ]; then
  set -a; # shellcheck source=/dev/null
  . "$ENV_FILE"; set +a
fi
PY="python3"; [ -x "$VENV_PY" ] && PY="$VENV_PY"
exec "$PY" "$HERE/connect.py" "$@"
