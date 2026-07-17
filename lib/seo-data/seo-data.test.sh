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
# rich_results rides the same URL-Inspection response (no extra call/quota)
has "rich verdict surfaced"      "$I" '"verdict": "FAIL"'
has "rich type breadcrumbs"      "$I" '"type": "Breadcrumbs"'
has "rich type faq"              "$I" '"type": "FAQ"'
has "rich counts error severity" "$I" '"errors": 2'
has "rich counts warn severity"  "$I" '"warnings": 1'
has "rich keeps issue message"   "$I" "Missing field 'acceptedAnswer'"
# same issueMessage repeats across items — the rollup must collapse it to one
NMSG="$(printf '%s' "$I" | grep -cF "Missing field 'acceptedAnswer'")"
[ "$NMSG" = "1" ] && ok "rich dedupes issue messages" \
                  || no "rich dedupes issue messages" "got $NMSG occurrences"
# Google OMITS richResultsResult when it detects none — absence is data, and
# must not KeyError nor vanish into a missing key
NR="$(SEO_DATA_MOCK_DIR="$SD/fixtures-norich" python3 "$SD/google_seo.py" inspect \
  --store "$S2" --account client-a --property sc-domain:ex.com --url https://ex.com/x)"
has "no-rich → synthetic ABSENT" "$NR" '"verdict": "ABSENT"'
has "no-rich keeps index status" "$NR" '"indexed": true'
hasnt "no-rich emits no PARTIAL" "$NR" 'PARTIAL'
DEG="$(env -u SEO_DATA_MOCK_DIR python3 "$SD/google_seo.py" queries \
  --store "$TMP2/none.json" --account nobody --property sc-domain:ex.com)"
has "gsc degrades w/o creds"     "$DEG" '"status": "degraded"'
has "gsc degrade reason"         "$DEG" 'no_credentials'
rm -rf "$TMP2"

echo "── cannibalisation ──"
# `keys` is additive: the single-dim consumer that reads `key` must not break
has "queries keeps key (compat)"  "$Q" '"key": "plombier paris"'
has "queries adds keys list"      "$Q" '"keys"'
CAN="$(SEO_DATA_MOCK_DIR="$SD/fixtures-cannibal" python3 "$SD/google_seo.py" cannibal \
  --store "$S2" --account client-a --property sc-domain:ex.com)"
has "cannibal ok"                 "$CAN" '"status": "ok"'
# fixture: 3 pages on "urgence fuite", 2 on "plombier paris", 1 on "devis"
has "cannibal finds 2 conflicts"  "$CAN" '"conflict_count": 2'
has "cannibal counts pages"       "$CAN" '"pages": 3'
has "cannibal sums impressions"   "$CAN" '"total_impressions": 2400'
hasnt "single-page query is not a conflict" "$CAN" 'devis plomberie'
# biggest conflict first, and inside it the strongest page first
CAN_FIRST="$(printf '%s' "$CAN" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["conflicts"][0]["query"], d["conflicts"][0]["urls"][0]["url"])')"
check_first() { [ "$1" = "$2" ] && ok "$3" || no "$3" "got[$1]"; }
check_first "$CAN_FIRST" "urgence fuite https://ex.com/urgence" "cannibal ranks by impact"
has "cannibal reports the cap"    "$CAN" '"capped": false'

echo "── sitemap ──"
SM="$(SEO_DATA_MOCK_DIR="$MOCK" python3 "$SD/sitemap.py" --url https://ex.com/sitemap.xml)"
has "sitemap ok"                 "$SM" '"status": "ok"'
has "sitemap not an index"       "$SM" '"index": false'
# fixture holds 8 <loc>: 1 empty, blog twice, ftp:// and a quoted one to drop
has "sitemap dedupes"            "$SM" '"count": 4'
has "sitemap counts drops"       "$SM" '"dropped": 2'
has "sitemap strips whitespace"  "$SM" '"https://ex.com/spaced"'
hasnt "sitemap drops non-http"   "$SM" 'ftp://'
hasnt "sitemap drops shell-meta" "$SM" 'bad"quote'
# namespace-agnostic: real sitemaps carry sitemaps.org xmlns (+ xhtml here)
has "sitemap reads namespaced"   "$SM" '"https://ex.com/services"'
# REGRESSION: <image:loc> also ends with '}loc'. An endswith test counted image
# sitemap entries as pages — a real native site returned 27 for 24 <url>, and
# img/logo.png was about to be sampled and audited as a page.
hasnt "image:loc is not a page"  "$SM" '/img/logo.png'
hasnt "image:loc jpeg not a page" "$SM" '/img/hero.jpeg'
has "image ns does not inflate count" "$SM" '"count": 4'

IDX="$(SEO_DATA_MOCK_DIR="$SD/fixtures-sitemap-index" python3 "$SD/sitemap.py" \
  --url https://ex.com/sitemap.xml)"
has "sitemapindex detected"      "$IDX" '"index": true'
has "sitemapindex fans out"      "$IDX" '"children_read": 2'
has "sitemapindex no child fail" "$IDX" '"children_failed": 0'
has "sitemapindex yields urls"   "$IDX" '"https://ex.com/child-a"'

# A sitemap NEVER has a DTD. Refused at the door: xml.etree does not expand
# external entities but IS billion-laughs-vulnerable, and the 20MB read ceiling
# bounds the input, not the expansion. Refusing beats depending on the parser,
# and keeps this module stdlib-only (no defusedxml, no venv).
DTD="$(SEO_DATA_MOCK_DIR="$SD/fixtures-sitemap-dtd" python3 "$SD/sitemap.py" \
  --url https://ex.com/sitemap.xml)"
has "billion-laughs refused"     "$DTD" '"status": "degraded"'
has "dtd reason is distinct"     "$DTD" 'unsafe_xml_dtd'
hasnt "dtd never parsed"         "$DTD" '"count"'

echo "── render_check (R2) ──"
SPA="$(SEO_DATA_MOCK_DIR="$SD/fixtures-spa" python3 "$SD/render_check.py" \
  --url https://spa.example/)"
has "spa → client-rendered"      "$SPA" '"verdict": "client-rendered"'
has "spa has no h1 in html"      "$SPA" '"h1_in_html": 0'
has "spa warns about false negs" "$SPA" 'false'
# the shell carries a fat window.__INITIAL_STATE__ script: script text is NOT
# page text, or a 200KB React bundle would read as a rich page
has "script text is not content" "$SPA" '"body_text_chars": 7'
SSR="$(SEO_DATA_MOCK_DIR="$SD/fixtures-ssr" python3 "$SD/render_check.py" \
  --url https://ssr.example/)"
has "ssr → server-rendered"      "$SSR" '"verdict": "server-rendered"'
has "ssr counts jsonld"          "$SSR" '"jsonld_in_html": 1'
has "ssr sees meta description"  "$SSR" '"meta_description_in_html": true'
hasnt "ssr emits no warning"     "$SSR" 'warning'

echo "── linkgraph ──"
LG="$(SEO_DATA_MOCK_DIR="$SD/fixtures-linkgraph" python3 "$SD/linkgraph.py" \
  --url https://ex.com/sitemap.xml)"
has "linkgraph ok"               "$LG" '"status": "ok"'
has "linkgraph crawls all"       "$LG" '"pages_crawled": 7'
# THE test: a planted page nobody links to must be found. Two live sites both
# returned zero orphans; without this, "always returns []" looks identical.
has "finds the planted orphan"   "$LG" '"https://ex.com/orphan"'
has "orphan is also unreachable" "$LG" '"unreachable"'
has "depth chain measured"       "$LG" '"max_depth": 4'
has "flags >3 clicks"            "$LG" '"https://ex.com/deepest"'
# home links: /a and /b only. anchor, .css?v=, mailto:, tel:, external, .png
# are not page links — 9 total across the 7 pages.
has "filters non-page links"     "$LG" '"total_internal_links": 9'
hasnt "no external host"         "$LG" 'other.com'
hasnt "no asset link"            "$LG" 'main.css'
hasnt "no image link"            "$LG" 'logo.png'
# /b/ in the markup vs /b in the sitemap must be ONE node, not a phantom orphan
hasnt "trailing slash unified"   "$LG" '"https://ex.com/b/"'

# An orphan from a partial crawl is a false orphan: withhold, do not truncate.
CAP="$(SEO_DATA_MOCK_DIR="$SD/fixtures-linkgraph" python3 "$SD/linkgraph.py" \
  --url https://ex.com/sitemap.xml --max 3)"
has "cap is reported"            "$CAP" '"capped": true'
has "capped withholds orphans"   "$CAP" '"orphans_withheld": true'
hasnt "capped emits no orphans"  "$CAP" '"orphans":'

echo "── drift (H2) ──"
DH="$(mktemp -d)"
D1="$(HOME="$DH" SEO_DATA_MOCK_DIR="$SD/fixtures-drift-v1" python3 "$SD/drift.py" \
  --url https://ex.com/sitemap.xml)"
has "first run is a baseline"    "$D1" '"baseline": true'
has "baseline captures pages"    "$D1" '"pages": 3'
hasnt "baseline diffs nothing"   "$D1" '"regressions"'
# v2: canonical lost on /a, h1+jsonld lost on /, title reworded, /gone removed,
# /neuve added. Losses are regressions; a reworded title is not.
D2="$(HOME="$DH" SEO_DATA_MOCK_DIR="$SD/fixtures-drift-v2" python3 "$SD/drift.py" \
  --url https://ex.com/sitemap.xml)"
has "second run diffs"           "$D2" '"baseline": false'
has "detects removed url"        "$D2" '"https://ex.com/gone"'
has "detects added url"          "$D2" '"https://ex.com/neuve"'
has "lost canonical = regression" "$D2" '"canonical"'
has "lost h1 = regression"       "$D2" '"h1_count"'
has "lost jsonld = regression"   "$D2" '"jsonld_types"'
# the classification IS the feature: losing a signal != changing one
NREG="$(printf '%s' "$D2" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)["regressions"]))')"
NCHG="$(printf '%s' "$D2" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)["changes"]))')"
[ "$NREG" = "3" ] && ok "3 losses classed as regressions" \
                  || no "3 losses classed as regressions" "got $NREG"
[ "$NCHG" = "1" ] && ok "reworded title is a change, not a regression" \
                  || no "reworded title is a change, not a regression" "got $NCHG"
rm -rf "$DH"

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

echo "── forget (remove/clear) ──"
TMP6="$(mktemp -d)"; S6="$TMP6/tokens.json"
python3 "$SD/tokenstore.py" set --file "$S6" --label keep --refresh-token RT_KEEP \
  --scopes https://www.googleapis.com/auth/webmasters.readonly --properties sc-domain:k.com >/dev/null
python3 "$SD/tokenstore.py" set --file "$S6" --label drop --refresh-token RT_DROP \
  --scopes https://www.googleapis.com/auth/webmasters.readonly --properties sc-domain:d.com >/dev/null
RM="$(python3 "$SD/tokenstore.py" remove --file "$S6" --label drop)"
has   "remove reports ok"        "$RM" '"status": "ok"'
has   "remove reports removed"   "$RM" '"removed": true'
hasnt "remove prints no token"   "$RM" 'RT_DROP'
L6="$(python3 "$SD/tokenstore.py" list --file "$S6")"
has   "remove keeps others"      "$L6" '"keep"'
hasnt "removed label gone"       "$L6" '"drop"'
RM2="$(python3 "$SD/tokenstore.py" remove --file "$S6" --label ghost)"
has   "remove missing = false"   "$RM2" '"removed": false'
CL="$(python3 "$SD/tokenstore.py" clear --file "$S6")"
has   "clear reports ok"         "$CL" '"status": "ok"'
has   "clear reports count"      "$CL" '"cleared": 1'
L7="$(python3 "$SD/tokenstore.py" list --file "$S6")"
has   "clear empties store"      "$L7" '"accounts": []'
PERM6="$(stat -c '%a' "$S6")"
[ "$PERM6" = "600" ] && ok "store stays 0600 after clear" || no "store 0600 after clear" "got $PERM6"
# via the real fetch.sh dispatch layer
python3 "$SD/tokenstore.py" set --file "$S6" --label back --refresh-token RT_BACK \
  --scopes https://www.googleapis.com/auth/webmasters.readonly --properties sc-domain:b.com >/dev/null
FG="$(SEO_DATA_ENV_FILE=$NOENV SEO_DATA_STORE="$S6" bash "$FETCH" forget --label back)"; FRC=$?
has "fetch forget removes"       "$FG" '"removed": true'
[ "$FRC" = "0" ] && ok "fetch forget exit 0" || no "fetch forget exit 0" "got $FRC"
FB="$(SEO_DATA_ENV_FILE=$NOENV SEO_DATA_STORE="$S6" bash "$FETCH" forget)"; FRC2=$?
has "forget bad usage json"      "$FB" '"status"'
[ "$FRC2" = "2" ] && ok "forget bad usage exit 2" || no "forget bad usage exit 2" "got $FRC2"
FA="$(SEO_DATA_ENV_FILE=$NOENV SEO_DATA_STORE="$S6" bash "$FETCH" forget --all)"
has "fetch forget --all ok"      "$FA" '"status": "ok"'
FI="$(SEO_DATA_ENV_FILE=$NOENV SEO_DATA_STORE="$S6" bash "$FETCH" forget --label 'x;touch /tmp/pwn')"; FIRC=$?
has "forget unsafe label json"   "$FI" '"status":"error"'
[ "$FIRC" = "2" ] && ok "forget unsafe label exit 2" || no "forget unsafe label exit 2" "got $FIRC"
# embedded-newline label must NOT pass the per-line-grep pitfall
FN="$(SEO_DATA_ENV_FILE=$NOENV SEO_DATA_STORE="$S6" bash "$FETCH" forget --label "$(printf 'ok\nrm -rf x')")"; FNRC=$?
has "forget newline label json"  "$FN" '"status":"error"'
[ "$FNRC" = "2" ] && ok "forget newline label exit 2" || no "forget newline label exit 2" "got $FNRC"
rm -rf "$TMP6"

echo "── connect.sh (offline negative) ──"
CN="$(SEO_DATA_ENV_FILE=$NOENV env -u GOOGLE_OAUTH_CLIENT_ID -u GOOGLE_OAUTH_CLIENT_SECRET \
  bash "$SD/connect.sh" --label t 2>&1)"; CNRC=$?
[ "$CNRC" != "0" ] && ok "connect.sh no-creds nonzero" || no "connect.sh no-creds nonzero" "got 0"
has "connect.sh creds gate msg"  "$CN" 'GOOGLE_OAUTH_CLIENT_ID'
CU="$(SEO_DATA_ENV_FILE=$NOENV bash "$SD/connect.sh" --label 'x;y' 2>&1)"; CURC=$?
[ "$CURC" = "2" ] && ok "connect.sh unsafe label exit 2" || no "connect.sh unsafe label exit 2" "got $CURC"
has "connect.sh label guard msg" "$CU" 'unsafe label'
# parser-differential bypasses must be rejected too (=-joined, abbreviated)
SEO_DATA_ENV_FILE=$NOENV bash "$SD/connect.sh" --label='x;y' >/dev/null 2>&1; CJRC=$?
[ "$CJRC" = "2" ] && ok "connect.sh =-joined rejected" || no "connect.sh =-joined rejected" "got $CJRC"
SEO_DATA_ENV_FILE=$NOENV bash "$SD/connect.sh" --labe 'x;y' >/dev/null 2>&1; CBRC=$?
[ "$CBRC" = "2" ] && ok "connect.sh abbrev rejected" || no "connect.sh abbrev rejected" "got $CBRC"
SEO_DATA_ENV_FILE=$NOENV bash "$SD/connect.sh" --label "$(printf 'ok\nrm -rf x')" >/dev/null 2>&1; CWRC=$?
[ "$CWRC" = "2" ] && ok "connect.sh newline rejected" || no "connect.sh newline rejected" "got $CWRC"
# a VALID label must still reach the creds gate (guard is not over-tight)
CV="$(SEO_DATA_ENV_FILE=$NOENV env -u GOOGLE_OAUTH_CLIENT_ID -u GOOGLE_OAUTH_CLIENT_SECRET \
  bash "$SD/connect.sh" --label ok-1.2_3 2>&1)"; CVRC=$?
[ "$CVRC" = "1" ] && ok "connect.sh valid label reaches gate" || no "connect.sh valid label reaches gate" "got $CVRC"
has "connect.sh valid gate msg"  "$CV" 'GOOGLE_OAUTH_CLIENT_ID'

echo "── wiring locks ──"
tf() { if grep -qF -- "$3" "$2" 2>/dev/null; then ok "$1"; else no "$1" "missing: $3"; fi; }
tf "env.example client id"    "$REPO/.env.example"    "GOOGLE_OAUTH_CLIENT_ID="
tf "env.example crux key"     "$REPO/.env.example"    "CRUX_API_KEY="
tf "makefile seo-connect"     "$REPO/Makefile"        "seo-connect:"
tf "makefile delegates wrapper" "$REPO/Makefile"      "lib/seo-data/connect.sh"
tf "connect.sh sources vault" "$SD/connect.sh"        ".claude/.env"
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

echo "── account-mgmt locks ──"
tf "skill routes account verbs" "$REPO/skills/seo/SKILL.md" "forget --all"
tf "skill connect wrapper path" "$REPO/skills/seo/SKILL.md" "lib/seo-data/connect.sh"
tf "skill revocation notice"    "$REPO/skills/seo/SKILL.md" "myaccount.google.com/permissions"
tf "skill label charset rule"   "$REPO/skills/seo/SKILL.md" "A-Za-z0-9._-"

echo "── readme lock ──"
tf "readme documents fetch.sh" "$REPO/lib/seo-data/README.md" "fetch.sh"
tf "readme documents seo-connect" "$REPO/lib/seo-data/README.md" "make seo-connect"
tf "readme documents forget"   "$REPO/lib/seo-data/README.md" "forget --all"
tf "readme revocation note"    "$REPO/lib/seo-data/README.md" "myaccount.google.com/permissions"

echo ""
echo "seo-data engine: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
