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

echo "── crux (mock) ──"
CRUX_OK="$(SEO_DATA_MOCK_DIR="$REPO/lib/seo-data/fixtures" \
  python3 "$SD/google_seo.py" crux --url https://ex.com --strategy mobile)"
has "crux status ok"        "$CRUX_OK" '"status": "ok"'
has "crux lcp p75 mapped"   "$CRUX_OK" '"lcp_p75_ms": 2100'
has "crux inp p75 mapped"   "$CRUX_OK" '"inp_p75_ms": 180'
has "crux cls p75 mapped"   "$CRUX_OK" '"cls_p75": 0.08'
CRUX_DEG="$(env -u CRUX_API_KEY -u SEO_DATA_MOCK_DIR \
  python3 "$SD/google_seo.py" crux --url https://ex.com)"
has "crux degrades w/o key" "$CRUX_DEG" '"status": "degraded"'
has "crux degrade reason"   "$CRUX_DEG" 'no_crux_key'
ORIG="$(python3 -c "import sys; sys.path.insert(0,'$SD'); import google_seo; print(google_seo._origin('https://example.com/blog/post'))")"
has   "origin strips to host" "$ORIG" 'https://example.com'
hasnt "origin drops the path" "$ORIG" 'blog'

echo "── gsc (mock) ──"
MOCK="$REPO/lib/seo-data/fixtures"
TMP2="$(mktemp -d)"; S2="$TMP2/tokens.json"
python3 "$SD/tokenstore.py" set --file "$S2" --label client-a --refresh-token RT \
  --scopes https://www.googleapis.com/auth/webmasters.readonly --properties sc-domain:ex.com >/dev/null
Q="$(SEO_DATA_MOCK_DIR="$MOCK" python3 "$SD/google_seo.py" queries \
  --store "$S2" --account client-a --property sc-domain:ex.com --days 90)"
has "queries ok"                 "$Q" '"status": "ok"'
has "queries row key"            "$Q" 'plombier paris'
has "queries position field"     "$Q" '"position": 6.3'
I="$(SEO_DATA_MOCK_DIR="$MOCK" python3 "$SD/google_seo.py" inspect \
  --store "$S2" --account client-a --property sc-domain:ex.com --url https://ex.com/x)"
has "inspect indexed true"       "$I" '"indexed": true'
DEG="$(env -u SEO_DATA_MOCK_DIR python3 "$SD/google_seo.py" queries \
  --store "$TMP2/none.json" --account nobody --property sc-domain:ex.com)"
has "gsc degrades w/o creds"     "$DEG" '"status": "degraded"'
has "gsc degrade reason"         "$DEG" 'no_credentials'
rm -rf "$TMP2"

echo "── fetch.sh ──"
FETCH="$SD/fetch.sh"
# SEO_DATA_ENV_FILE=/dev/null: tests must NEVER source the real ~/.claude/.env —
# on a machine with a live CRUX_API_KEY the degrade tests would hit the network.
NOENV=/dev/null
ACC="$(SEO_DATA_ENV_FILE=$NOENV SEO_DATA_STORE=/nonexistent/tokens.json bash "$FETCH" accounts)"
has "accounts empty is ok json" "$ACC" '"accounts": []'
CR="$(SEO_DATA_ENV_FILE=$NOENV SEO_DATA_MOCK_DIR="$MOCK" bash "$FETCH" crux --url https://ex.com)"
has "fetch crux ok"             "$CR" '"status": "ok"'
SEO_DATA_ENV_FILE=$NOENV bash "$FETCH" bogus-subcmd >/dev/null 2>&1; RC=$?
[ "$RC" = "2" ] && ok "bad subcmd exit 2" || no "bad subcmd exit 2" "got $RC"
DG="$(SEO_DATA_ENV_FILE=$NOENV env -u SEO_DATA_MOCK_DIR -u CRUX_API_KEY bash "$FETCH" crux --url https://ex.com)"; RC=$?
has "degrade json"              "$DG" '"status": "degraded"'
[ "$RC" = "0" ] && ok "degrade exit 0" || no "degrade exit 0" "got $RC"
# redaction through the real fetch.sh dispatch layer
TMP4="$(mktemp -d)"; RSTORE="$TMP4/rt.json"
python3 "$SD/tokenstore.py" set --file "$RSTORE" --label leaky --refresh-token RT_SECRET_XYZ \
  --scopes https://www.googleapis.com/auth/webmasters.readonly --properties sc-domain:z.com >/dev/null
ACCJSON="$(SEO_DATA_ENV_FILE=$NOENV SEO_DATA_STORE="$RSTORE" bash "$FETCH" accounts)"
has   "accounts lists label"  "$ACCJSON" 'leaky'
hasnt "accounts hides token"  "$ACCJSON" 'RT_SECRET_XYZ'
rm -rf "$TMP4"
# corrupted store must degrade with JSON + exit 0 (Fix 1)
TMP5="$(mktemp -d)"; CSTORE="$TMP5/corrupt.json"; printf 'not json {{' > "$CSTORE"
CJ="$(SEO_DATA_ENV_FILE=$NOENV SEO_DATA_STORE="$CSTORE" bash "$FETCH" accounts)"; CRC=$?
has "corrupt store degrades" "$CJ" '"status"'
[ "$CRC" = "0" ] && ok "corrupt store exit 0" || no "corrupt store exit 0" "got $CRC"
rm -rf "$TMP5"
# bad usage (known subcmd, missing flag) must still emit JSON + exit 2 (Fix 2)
BU="$(SEO_DATA_ENV_FILE=$NOENV bash "$FETCH" crux)"; BURC=$?
has "bad usage emits json" "$BU" '"status"'
[ "$BURC" = "2" ] && ok "bad usage exit 2" || no "bad usage exit 2" "got $BURC"

echo "── connect (persist, offline) ──"
TMP3="$(mktemp -d)"; S3="$TMP3/tokens.json"
python3 -c "import sys; sys.path.insert(0,'$SD'); import connect; \
connect.persist('$S3','client-x','RT_X',['https://www.googleapis.com/auth/webmasters.readonly'],['sc-domain:x.com'])"
L3="$(python3 "$SD/tokenstore.py" list --file "$S3")"
has "connect.persist wrote label" "$L3" '"client-x"'
has "connect.persist wrote prop"  "$L3" 'sc-domain:x.com'
hasnt "connect.persist redacts"   "$L3" 'RT_X'
rm -rf "$TMP3"

echo "── wiring locks ──"
tf() { if grep -qF -- "$3" "$2" 2>/dev/null; then ok "$1"; else no "$1" "missing: $3"; fi; }
tf "env.example client id"    "$REPO/.env.example"    "GOOGLE_OAUTH_CLIENT_ID="
tf "env.example crux key"     "$REPO/.env.example"    "CRUX_API_KEY="
tf "makefile seo-connect"     "$REPO/Makefile"        "seo-connect:"
tf "seo-connect sources env"  "$REPO/Makefile"        ".claude/.env"
tf "makefile discovers test"  "$REPO/Makefile"        "lib/seo-data/*.test.sh"
tf "install prompts connect"  "$REPO/install.sh"      "make seo-connect"
tf "doctor checks seo-data"   "$REPO/doctor.sh"       "seo-data"
tf "gitleaks allowlist store" "$REPO/.gitleaks.toml"  "seo-data/tokens"
tf "gitignore venv"           "$REPO/.gitignore"      ".venv-seo-data"

echo "── integration locks ──"
tf "skill step0 account select" "$REPO/skills/seo/SKILL.md"      "COMPTE GOOGLE"
tf "analyzer calls fetch crux"  "$REPO/agents/seo-analyzer.md"   "fetch.sh crux"
tf "analyzer calls fetch queries" "$REPO/agents/seo-analyzer.md" "fetch.sh queries"
tf "analyzer gsc subsection"    "$REPO/agents/seo-analyzer.md"   "Performance GSC"
tf "catalog gsc oauth entry"    "$REPO/agents/resources/automation-catalog.md" "make seo-connect"

echo "── readme lock ──"
tf "readme documents fetch.sh" "$REPO/lib/seo-data/README.md" "fetch.sh"
tf "readme documents seo-connect" "$REPO/lib/seo-data/README.md" "make seo-connect"

echo ""
echo "seo-data engine: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
