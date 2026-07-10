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

cmd="${1:-}"; shift || true
case "$cmd" in
  accounts) exec "$PY" "$HERE/tokenstore.py" list --file "$STORE" ;;
  crux|queries|inspect)
    exec "$PY" "$HERE/google_seo.py" "$cmd" --store "$STORE" "$@" ;;
  *) echo '{"status":"error","reason":"usage: fetch.sh {accounts|crux|queries|inspect} [flags]"}'
     exit 2 ;;
esac
