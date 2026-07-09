#!/usr/bin/env bash
# Deterministic tests for the seo-data engine (no network, no venv).
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SD="$REPO/lib/seo-data"
PASS=0; FAIL=0
ok()   { echo "  PASS $1"; PASS=$((PASS+1)); }
no()   { echo "  FAIL $1 — $2"; FAIL=$((FAIL+1)); }
# assert stdout of a command contains / omits a fixed string
has()  { if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else no "$1" "missing: $3"; fi; }
hasnt(){ if printf '%s' "$2" | grep -qF -- "$3"; then no "$1" "forbidden: $3"; else ok "$1"; fi; }

echo "── tokenstore ──"
TMP="$(mktemp -d)"; STORE="$TMP/tokens.json"
python3 "$SD/tokenstore.py" set --file "$STORE" --label client-a \
  --refresh-token RT_AAA --scopes https://www.googleapis.com/auth/webmasters.readonly \
  --properties sc-domain:a.com,https://www.a.com/ >/dev/null
python3 "$SD/tokenstore.py" set --file "$STORE" --label client-b \
  --refresh-token RT_BBB --scopes https://www.googleapis.com/auth/webmasters.readonly \
  --properties sc-domain:b.com >/dev/null
LIST="$(python3 "$SD/tokenstore.py" list --file "$STORE")"
has   "list shows client-a"            "$LIST" '"client-a"'
has   "list shows client-b"            "$LIST" '"client-b"'
has   "list shows a property"          "$LIST" 'sc-domain:a.com'
hasnt "list redacts refresh tokens"    "$LIST" 'RT_AAA'
PERM="$(stat -c '%a' "$STORE")"
[ "$PERM" = "600" ] && ok "store file is 0600" || no "store file 0600" "got $PERM"
DPERM="$(stat -c '%a' "$(dirname "$STORE")")"
[ "$DPERM" = "700" ] && ok "store dir is 0700" || no "store dir 0700" "got $DPERM"
rm -rf "$TMP"

echo ""
echo "seo-data engine: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
