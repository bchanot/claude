#!/usr/bin/env bash
# Stable entrypoint for the seo-data engine. JSON on stdout; exit 0 on ok/degrade,
# exit 2 on bad usage. Never prints secrets.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SEO_DATA_ENV_FILE:-${HOME}/.claude/.env}"  # canonical; tests override to /dev/null
STORE="${SEO_DATA_STORE:-${HOME}/.claude/seo-data/tokens.json}"
VENV_PY="${HOME}/.claude/.venv-seo-data/bin/python3"

# Library stderr must never leak a secret into agent context — suppress it
# globally unless explicitly debugging (SEO_DATA_DEBUG=1 restores it).
[ -n "${SEO_DATA_DEBUG:-}" ] || exec 2>/dev/null

# Load secrets quietly (sourced, never echoed).
if [ -f "$ENV_FILE" ]; then
  set -a; # shellcheck source=/dev/null
  . "$ENV_FILE"; set +a
fi
# Prefer the isolated venv (has google-auth); fall back to system python3 for
# stdlib-only paths (accounts / mock / degrade).
PY="python3"; [ -x "$VENV_PY" ] && PY="$VENV_PY"

# Whole-string label guard (shell-safe ASCII). POSIX `case` in a C-locale
# subshell — newline-proof and locale-independent, unlike a per-line grep.
_label_safe() ( LC_ALL=C; case "$1" in ''|[!A-Za-z0-9]*|*[!A-Za-z0-9._-]*) exit 1;; esac )

cmd="${1:-}"; shift || true
case "$cmd" in
  accounts) exec "$PY" "$HERE/tokenstore.py" list --file "$STORE" ;;
  crux|queries|inspect)
    exec "$PY" "$HERE/google_seo.py" "$cmd" --store "$STORE" "$@" ;;
  forget)
    # forget --label <label> → drop one account; forget --all → empty the store.
    # Local removal only — does NOT revoke the grant at Google's end.
    # Label charset guard: store keys stay shell-safe wherever an agent
    # interpolates them into a command line (defense-in-depth vs injection).
    if [ "${1:-}" = "--all" ]; then
      exec "$PY" "$HERE/tokenstore.py" clear --file "$STORE"
    elif [ "${1:-}" = "--label" ] && _label_safe "${2:-}"; then
      exec "$PY" "$HERE/tokenstore.py" remove --file "$STORE" --label "$2"
    fi
    echo '{"status":"error","reason":"usage: fetch.sh forget {--label <label>|--all} (label charset: A-Za-z0-9._-)"}'
    exit 2 ;;
  *) echo '{"status":"error","reason":"usage: fetch.sh {accounts|crux|queries|inspect|forget} [flags]"}'
     exit 2 ;;
esac
