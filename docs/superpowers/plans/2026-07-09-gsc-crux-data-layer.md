# GSC + CrUX Data Layer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `/seo` (+`/geo`) FULL audits real Google data — Search Console queries/positions/indexation + CrUX field Core Web Vitals — via an isolated, secure, multi-account data engine.

**Architecture:** A self-contained engine under `lib/seo-data/` (bash entrypoint `fetch.sh` → Python helpers in an isolated venv) fetches GSC + CrUX and emits normalized JSON on stdout. The existing `seo-analyzer` agent consumes that JSON during FULL audits; the `/seo` dispatcher selects account+property in STEP 0. Secrets live in the `~/.claude/.env` vault (OAuth app + CrUX key) plus a label-keyed token store `~/.claude/seo-data/tokens.json`.

**Tech Stack:** Bash (entrypoint, tests), Python 3.14 (`google-auth`, `google-auth-oauthlib`, `requests` — pinned, in a dedicated venv), GSC Search Console API v3 + URL Inspection, CrUX API.

**Spec:** `docs/superpowers/specs/2026-07-09-gsc-crux-data-layer-design.md` (transient — delete after ship+doc+capitalize).

## Global Constraints

Every task's requirements implicitly include these (verbatim from the spec):

- **Security first.** Secrets never in git, files `0600` / dirs `0700`, OAuth scope **exactly** `https://www.googleapis.com/auth/webmasters.readonly`, no secret ever printed to stdout/stderr/report.
- **Offline-testable.** Third-party imports (`google.*`, `requests`) are **lazy** — imported only inside real OAuth/HTTP code paths. The `accounts`, mock (`SEO_DATA_MOCK_DIR` set), and degraded paths run on **stdlib only**, no venv, no network. `make test` never hits the network.
- **Graceful degradation (fail-open audit).** Missing creds / missing venv / revoked token / HTTP 429 → JSON `{"status":"degraded","reason":"…"}` on stdout with **exit 0**. Bad CLI usage → exit 2.
- **Multi-account, no shared state.** Account + property are **explicit arguments** on every `fetch.sh` call. No "current account" global. Store writes only happen during `connect` (atomic `tmp`→`fsync`→`rename` under `fcntl` lock); audits are read-only.
- **Store keyed by user label**, not email (keeps scope minimal). Properties discovered via `sites.list` (already in scope).
- **Canonical env path.** Read secrets from `~/.claude/.env` (canonical), never `$REPO/.env` (symlink may be absent on a fresh machine).
- **Repo test convention.** Bash tests in `lib/tests/*.test.sh`, helpers `tf`/`tr_`/`tn` + `PASS`/`FAIL` counters, final line `[ "$FAIL" -eq 0 ]`, discovered by `make test`.
- **No commit attribution trailers** (no `Co-Authored-By`, no `Claude-Session`).
- **Branch:** all commits on `feature/gsc-crux-data-layer` (already created).

---

## File Structure

**Engine (created):**
- `lib/seo-data/tokenstore.py` — label-keyed token store I/O (atomic + locked). Stdlib only.
- `lib/seo-data/google_seo.py` — CrUX + GSC calls, OAuth refresh (lazy), mock mode, normalization → JSON.
- `lib/seo-data/connect.py` — one-time OAuth consent + `sites.list` discovery + persist to store.
- `lib/seo-data/fetch.sh` — bash entrypoint: source env, pick python, dispatch, degrade, redact.
- `lib/seo-data/requirements.txt` — pinned deps.
- `lib/seo-data/README.md` — usage contract.

**Tests (created):**
- `lib/tests/seo-data.test.sh` — deterministic bash test (drives CLIs against fixtures, checks locks).
- `lib/tests/fixtures/seo-data/*.json` — synthetic API responses (no real secret/PII).

**Wiring (modified):**
- `.env.example`, `install.sh`, `Makefile`, `doctor.sh`, `.gitleaks.toml`, `.gitignore`.

**Integration (modified):**
- `agents/seo-analyzer.md`, `skills/seo/SKILL.md`, `agents/resources/automation-catalog.md`.

**Interface contract (used across tasks):**
```
tokenstore.py  (module + CLI: python3 tokenstore.py {list|set} --file PATH …)
  load(path) -> dict
  list_accounts(path) -> list[dict]      # [{label, properties, granted_at}]  NO refresh_token
  get_refresh_token(path, label) -> str | None
  save_account(path, label, refresh_token, scopes: list[str], properties: list[str]) -> None

google_seo.py  (module + CLI: python3 google_seo.py {crux|queries|inspect} …)
  crux(url, strategy='mobile') -> dict
  queries(store_path, account, property, days=90, dim='query') -> dict
  inspect(store_path, account, property, url) -> dict
    # all return {"status":"ok"|"degraded", ...}

fetch.sh {accounts|crux|queries|inspect} [flags]  -> JSON on stdout

connect.py  (CLI: python3 connect.py --label LABEL)
  run_consent(client_id, client_secret, scopes) -> str          # refresh_token
  discover_properties(refresh_token, client_id, client_secret) -> list[str]
  persist(store_path, label, refresh_token, scopes, properties) -> None
```

---

## Task 1: Token store (`tokenstore.py`)

Label-keyed, atomic, locked store. Foundation for everything; stdlib only so it tests without a venv.

**Files:**
- Create: `lib/seo-data/tokenstore.py`
- Create: `lib/tests/seo-data.test.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `load`, `list_accounts`, `get_refresh_token`, `save_account` (signatures in File Structure) + CLI `list`/`set`.

- [ ] **Step 1: Write the failing test** — create `lib/tests/seo-data.test.sh`:

```bash
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
rm -rf "$TMP"

echo ""
echo "seo-data engine: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run it, verify red**

Run: `bash lib/tests/seo-data.test.sh`
Expected: FAIL — `tokenstore.py` does not exist (`python3: can't open file`).

- [ ] **Step 3: Implement `lib/seo-data/tokenstore.py`** (stdlib only):

```python
#!/usr/bin/env python3
"""Label-keyed OAuth refresh-token store. Atomic writes under an fcntl lock.
No third-party deps — must run without the venv (used by the offline test path)."""
import argparse, fcntl, json, os, sys, tempfile
from datetime import datetime, timezone

def load(path):
    if not os.path.exists(path):
        return {"version": 1, "accounts": {}}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def list_accounts(path):
    data = load(path)
    return [
        {"label": lbl, "properties": a.get("properties", []),
         "granted_at": a.get("granted_at")}
        for lbl, a in data.get("accounts", {}).items()
    ]  # refresh_token intentionally omitted (redaction)

def get_refresh_token(path, label):
    return load(path).get("accounts", {}).get(label, {}).get("refresh_token")

def save_account(path, label, refresh_token, scopes, properties):
    os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
    lock_path = path + ".lock"
    with open(lock_path, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)          # serialize concurrent connects
        data = load(path)
        data.setdefault("version", 1)
        data.setdefault("accounts", {})
        data["accounts"][label] = {
            "refresh_token": refresh_token,
            "scopes": scopes,
            "granted_at": datetime.now(timezone.utc).isoformat(),
            "properties": properties,
        }
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), suffix=".tmp")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
                f.flush(); os.fsync(f.fileno())
            os.chmod(tmp, 0o600)
            os.replace(tmp, path)                 # atomic
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)

def _cli():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    pl = sub.add_parser("list"); pl.add_argument("--file", required=True)
    ps = sub.add_parser("set")
    for flag in ("--file", "--label", "--refresh-token"):
        ps.add_argument(flag, required=True)
    ps.add_argument("--scopes", default="")
    ps.add_argument("--properties", default="")
    args = p.parse_args()
    if args.cmd == "list":
        print(json.dumps({"status": "ok", "accounts": list_accounts(args.file)}))
    else:
        save_account(args.file, args.label, getattr(args, "refresh_token"),
                     [s for s in args.scopes.split(",") if s],
                     [x for x in args.properties.split(",") if x])
        print(json.dumps({"status": "ok"}))

if __name__ == "__main__":
    _cli()
```

- [ ] **Step 4: Run it, verify green**

Run: `bash lib/tests/seo-data.test.sh`
Expected: PASS (5 tokenstore checks pass).

- [ ] **Step 5: Commit**

```bash
git add lib/seo-data/tokenstore.py lib/tests/seo-data.test.sh
git commit -m "feat(seo-data): label-keyed atomic OAuth token store"
```

---

## Task 2: CrUX fetch (`google_seo.py` — CrUX path)

Simplest data path (API key, no OAuth). Establishes the mock-mode + degrade + normalization pattern.

**Files:**
- Create: `lib/seo-data/google_seo.py`
- Create: `lib/tests/fixtures/seo-data/crux_mobile.json`
- Modify: `lib/tests/seo-data.test.sh` (append CrUX section)

**Interfaces:**
- Consumes: env `CRUX_API_KEY`, env `SEO_DATA_MOCK_DIR`.
- Produces: `crux(url, strategy='mobile') -> dict`; CLI `python3 google_seo.py crux --url … [--strategy …]`.

- [ ] **Step 1: Write the fixture** — `lib/tests/fixtures/seo-data/crux_mobile.json` (shape of the CrUX API `record.metrics`):

```json
{"record":{"key":{"formFactor":"PHONE"},"metrics":{
  "largest_contentful_paint":{"percentiles":{"p75":2100}},
  "interaction_to_next_paint":{"percentiles":{"p75":180}},
  "cumulative_layout_shift":{"percentiles":{"p75":"0.08"}}}}}
```

- [ ] **Step 2: Write the failing test** — append to `lib/tests/seo-data.test.sh` before the final summary:

```bash
echo "── crux (mock) ──"
CRUX_OK="$(SEO_DATA_MOCK_DIR="$REPO/lib/tests/fixtures/seo-data" \
  python3 "$SD/google_seo.py" crux --url https://ex.com --strategy mobile)"
has "crux status ok"        "$CRUX_OK" '"status": "ok"'
has "crux lcp p75 mapped"   "$CRUX_OK" '"lcp_p75_ms": 2100'
has "crux inp p75 mapped"   "$CRUX_OK" '"inp_p75_ms": 180'
has "crux cls p75 mapped"   "$CRUX_OK" '"cls_p75": 0.08'
CRUX_DEG="$(env -u CRUX_API_KEY -u SEO_DATA_MOCK_DIR \
  python3 "$SD/google_seo.py" crux --url https://ex.com)"
has "crux degrades w/o key" "$CRUX_DEG" '"status": "degraded"'
has "crux degrade reason"   "$CRUX_DEG" 'no_crux_key'
```

- [ ] **Step 3: Run it, verify red**

Run: `bash lib/tests/seo-data.test.sh`
Expected: FAIL — `google_seo.py` missing.

- [ ] **Step 4: Implement the CrUX path** — create `lib/seo-data/google_seo.py` (lazy `requests` import; mock reads the fixture and runs the REAL normalizer):

```python
#!/usr/bin/env python3
"""CrUX + GSC fetch → normalized JSON. Third-party imports are LAZY so mock and
degraded paths run stdlib-only (no venv, no network)."""
import argparse, json, os, sys

def _mock(name):
    d = os.environ.get("SEO_DATA_MOCK_DIR")
    if not d:
        return None
    path = os.path.join(d, name)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def _norm_crux(raw):
    m = raw["record"]["metrics"]
    def p75(metric):
        return m.get(metric, {}).get("percentiles", {}).get("p75")
    return {
        "status": "ok", "source": "crux",
        "lcp_p75_ms": int(p75("largest_contentful_paint")),
        "inp_p75_ms": int(p75("interaction_to_next_paint")),
        "cls_p75": float(p75("cumulative_layout_shift")),
    }

def crux(url, strategy="mobile"):
    raw = _mock("crux_%s.json" % strategy)
    if raw is None:
        key = os.environ.get("CRUX_API_KEY")
        if not key:
            return {"status": "degraded", "reason": "no_crux_key"}
        import requests  # lazy
        ff = "PHONE" if strategy == "mobile" else "DESKTOP"
        r = requests.post(
            "https://chromeuxreport.googleapis.com/v1/records:queryRecord?key=" + key,
            json={"url": url, "formFactor": ff}, timeout=20)
        if r.status_code == 404:
            return {"status": "degraded", "reason": "no_field_data"}
        if r.status_code == 429:
            return {"status": "degraded", "reason": "rate_limited"}
        r.raise_for_status()
        raw = r.json()
    return _norm_crux(raw)

def _cli():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    pc = sub.add_parser("crux")
    pc.add_argument("--url", required=True)
    pc.add_argument("--strategy", default="mobile", choices=["mobile", "desktop"])
    args = p.parse_args()
    if args.cmd == "crux":
        print(json.dumps(crux(args.url, args.strategy), indent=2))

if __name__ == "__main__":
    _cli()
```

- [ ] **Step 5: Run it, verify green**

Run: `bash lib/tests/seo-data.test.sh`
Expected: PASS (tokenstore + 6 CrUX checks).

- [ ] **Step 6: Commit**

```bash
git add lib/seo-data/google_seo.py lib/tests/fixtures/seo-data/crux_mobile.json lib/tests/seo-data.test.sh
git commit -m "feat(seo-data): CrUX field-data fetch with mock mode and graceful degrade"
```

---

## Task 3: GSC fetch (`google_seo.py` — queries + inspect)

Adds Search Analytics + URL Inspection with OAuth refresh (lazy) reusing `tokenstore`.

**Files:**
- Modify: `lib/seo-data/google_seo.py` (add `queries`, `inspect`, `_gsc_session`, extend CLI)
- Create: `lib/tests/fixtures/seo-data/gsc_queries.json`, `lib/tests/fixtures/seo-data/gsc_inspect.json`
- Modify: `lib/tests/seo-data.test.sh` (append GSC section)

**Interfaces:**
- Consumes: `tokenstore.get_refresh_token`, env `GOOGLE_OAUTH_CLIENT_ID/SECRET`, `SEO_DATA_MOCK_DIR`.
- Produces: `queries(store_path, account, property, days=90, dim='query')`, `inspect(store_path, account, property, url)`; CLI `queries`/`inspect`.

- [ ] **Step 1: Write fixtures**

`lib/tests/fixtures/seo-data/gsc_queries.json` (Search Analytics `rows` shape):
```json
{"rows":[
  {"keys":["plombier paris"],"clicks":40,"impressions":900,"ctr":0.044,"position":6.3},
  {"keys":["urgence fuite"],"clicks":5,"impressions":1200,"ctr":0.004,"position":8.9}]}
```
`lib/tests/fixtures/seo-data/gsc_inspect.json` (URL Inspection shape):
```json
{"inspectionResult":{"indexStatusResult":{
  "verdict":"PASS","coverageState":"Submitted and indexed","lastCrawlTime":"2026-07-01T10:00:00Z"}}}
```

- [ ] **Step 2: Write the failing test** — append before the summary:

```bash
echo "── gsc (mock) ──"
MOCK="$REPO/lib/tests/fixtures/seo-data"
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
```

- [ ] **Step 3: Run it, verify red**

Run: `bash lib/tests/seo-data.test.sh`
Expected: FAIL — `queries`/`inspect` not implemented (argparse error / AttributeError).

- [ ] **Step 4: Implement** — add to `google_seo.py`:

```python
def _gsc_session(store_path, account):
    """Return an authorized requests.Session or a degrade dict. Lazy imports."""
    rt = None
    if store_path and account:
        import tokenstore  # local module, stdlib
        rt = tokenstore.get_refresh_token(store_path, account)
    cid = os.environ.get("GOOGLE_OAUTH_CLIENT_ID")
    csec = os.environ.get("GOOGLE_OAUTH_CLIENT_SECRET")
    if not (rt and cid and csec):
        return {"status": "degraded", "reason": "no_credentials"}
    from google.oauth2.credentials import Credentials       # lazy
    from google.auth.transport.requests import AuthorizedSession, Request
    creds = Credentials(None, refresh_token=rt, client_id=cid, client_secret=csec,
                        token_uri="https://oauth2.googleapis.com/token",
                        scopes=["https://www.googleapis.com/auth/webmasters.readonly"])
    try:
        creds.refresh(Request())
    except Exception:
        return {"status": "degraded", "reason": "token_revoked"}
    return AuthorizedSession(creds)

def _norm_queries(raw, dim):
    return {"status": "ok", "source": "gsc", "dimension": dim, "rows": [
        {"key": r["keys"][0], "clicks": r.get("clicks", 0),
         "impressions": r.get("impressions", 0), "ctr": r.get("ctr", 0),
         "position": r.get("position")}
        for r in raw.get("rows", [])]}

def queries(store_path, account, property, days=90, dim="query"):
    raw = _mock("gsc_queries.json")
    if raw is None:
        sess = _gsc_session(store_path, account)
        if isinstance(sess, dict):
            return sess
        import datetime as _dt
        end = _dt.date.today(); start = end - _dt.timedelta(days=days)
        import urllib.parse
        url = ("https://searchconsole.googleapis.com/webmasters/v3/sites/"
               + urllib.parse.quote(property, safe="") + "/searchAnalytics/query")
        r = sess.post(url, json={"startDate": start.isoformat(), "endDate": end.isoformat(),
                                 "dimensions": [dim], "rowLimit": 100}, timeout=30)
        if r.status_code == 429:
            return {"status": "degraded", "reason": "rate_limited"}
        r.raise_for_status()
        raw = r.json()
    return _norm_queries(raw, dim)

def inspect(store_path, account, property, url):
    raw = _mock("gsc_inspect.json")
    if raw is None:
        sess = _gsc_session(store_path, account)
        if isinstance(sess, dict):
            return sess
        r = sess.post("https://searchconsole.googleapis.com/v1/urlInspection/index:inspect",
                      json={"inspectionUrl": url, "siteUrl": property}, timeout=30)
        if r.status_code == 429:
            return {"status": "degraded", "reason": "rate_limited"}
        r.raise_for_status()
        raw = r.json()
    isr = raw["inspectionResult"]["indexStatusResult"]
    return {"status": "ok", "source": "gsc",
            "indexed": isr.get("verdict") == "PASS",
            "coverage": isr.get("coverageState"),
            "last_crawl": isr.get("lastCrawlTime")}
```
Extend `_cli()` (add subparsers `queries` and `inspect`, each with `--store --account --property`, plus `--days`/`--dim` for queries and `--url` for inspect; dispatch to the functions and `print(json.dumps(..., indent=2))`). Ensure the script's dir is importable for `import tokenstore` (add `sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))` at top).

- [ ] **Step 5: Run it, verify green**

Run: `bash lib/tests/seo-data.test.sh`
Expected: PASS (tokenstore + CrUX + 7 GSC checks).

- [ ] **Step 6: Commit**

```bash
git add lib/seo-data/google_seo.py lib/tests/fixtures/seo-data/gsc_queries.json lib/tests/fixtures/seo-data/gsc_inspect.json lib/tests/seo-data.test.sh
git commit -m "feat(seo-data): GSC Search Analytics + URL Inspection with lazy OAuth refresh"
```

---

## Task 4: Bash entrypoint (`fetch.sh`)

The stable CLI the analyzers call. Sources env, picks python (venv else system), dispatches, guarantees degrade-exit-0 and redaction.

**Files:**
- Create: `lib/seo-data/fetch.sh`
- Modify: `lib/tests/seo-data.test.sh` (append fetch.sh section)

**Interfaces:**
- Consumes: `~/.claude/.env` (canonical), `google_seo.py`, `tokenstore.py`, optional `~/.claude/.venv-seo-data/`.
- Produces: `fetch.sh {accounts|crux|queries|inspect} [flags]` → JSON stdout, exit 0 on ok/degrade, exit 2 on bad usage.

- [ ] **Step 1: Write the failing test** — append before the summary:

```bash
echo "── fetch.sh ──"
FETCH="$SD/fetch.sh"
ACC="$(SEO_DATA_STORE="$STORE_MISSING" bash "$FETCH" accounts 2>/dev/null)"; STORE_MISSING="/nonexistent/tokens.json"
ACC="$(SEO_DATA_STORE=/nonexistent/tokens.json bash "$FETCH" accounts)"
has "accounts empty is ok json" "$ACC" '"status"'
CR="$(SEO_DATA_MOCK_DIR="$MOCK" bash "$FETCH" crux --url https://ex.com)"
has "fetch crux ok"             "$CR" '"status": "ok"'
bash "$FETCH" bogus-subcmd >/dev/null 2>&1; [ "$?" = "2" ] && ok "bad subcmd exit 2" || no "bad subcmd exit 2" "wrong code"
DG="$(env -u SEO_DATA_MOCK_DIR -u CRUX_API_KEY bash "$FETCH" crux --url https://ex.com)"; RC=$?
has "degrade json"              "$DG" '"status": "degraded"'
[ "$RC" = "0" ] && ok "degrade exit 0" || no "degrade exit 0" "got $RC"
hasnt "no secret echoed"        "$DG" 'RT_'
```

- [ ] **Step 2: Run it, verify red**

Run: `bash lib/tests/seo-data.test.sh`
Expected: FAIL — `fetch.sh` missing.

- [ ] **Step 3: Implement `lib/seo-data/fetch.sh`:**

```bash
#!/usr/bin/env bash
# Stable entrypoint for the seo-data engine. JSON on stdout; exit 0 on ok/degrade,
# exit 2 on bad usage. Never prints secrets.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${HOME}/.claude/.env"                       # canonical, not $REPO/.env
STORE="${SEO_DATA_STORE:-${HOME}/.claude/seo-data/tokens.json}"
VENV_PY="${HOME}/.claude/.venv-seo-data/bin/python3"

# Load secrets quietly (no echo). Only the keys we need are exported.
if [ -f "$ENV_FILE" ]; then
  set -a; # shellcheck source=/dev/null
  . "$ENV_FILE" >/dev/null 2>&1; set +a
fi
# Prefer the isolated venv (has google-auth); fall back to system python3 for
# stdlib-only paths (accounts / mock / degrade).
PY="python3"; [ -x "$VENV_PY" ] && PY="$VENV_PY"

cmd="${1:-}"; shift || true
case "$cmd" in
  accounts) exec "$PY" "$HERE/tokenstore.py" list --file "$STORE" ;;
  crux|queries|inspect)
    # queries/inspect need the store path; pass it through.
    exec "$PY" "$HERE/google_seo.py" "$cmd" --store "$STORE" "$@" 2>/dev/null ;;
  *) echo '{"status":"error","reason":"usage: fetch.sh {accounts|crux|queries|inspect} [flags]"}' >&2
     exit 2 ;;
esac
```
Note: `crux` ignores `--store` — `google_seo.py`'s `crux` subparser must accept and ignore an optional `--store` (add `pc.add_argument("--store", default=None)`), so `fetch.sh` can pass it uniformly. `2>/dev/null` on the data path guarantees no stray library stderr leaks a token; degrade/ok JSON always comes on stdout.

- [ ] **Step 4: Run it, verify green**

Run: `bash lib/tests/seo-data.test.sh`
Expected: PASS (all prior + 6 fetch.sh checks). Fix the stray `STORE_MISSING` ordering in the test (define it before use) if it warns.

- [ ] **Step 5: Commit**

```bash
git add lib/seo-data/fetch.sh lib/seo-data/google_seo.py lib/tests/seo-data.test.sh
git commit -m "feat(seo-data): fetch.sh entrypoint with venv/system fallback and redaction"
```

---

## Task 5: OAuth consent (`connect.py`) + pinned deps

One-time interactive consent + `sites.list` discovery + persist. Browser flow is manually verified; the persist + label logic is unit-tested.

**Files:**
- Create: `lib/seo-data/connect.py`
- Create: `lib/seo-data/requirements.txt`
- Modify: `lib/tests/seo-data.test.sh` (append persist test)

**Interfaces:**
- Consumes: env `GOOGLE_OAUTH_CLIENT_ID/SECRET`, `tokenstore.save_account`.
- Produces: `run_consent`, `discover_properties`, `persist`; CLI `python3 connect.py --label LABEL`.

- [ ] **Step 1: Write `requirements.txt`** (pinned; versions current as of 2026-07 — the implementer verifies latest patch at execution):

```
google-auth==2.40.0
google-auth-oauthlib==1.2.2
requests==2.32.4
```

- [ ] **Step 2: Write the failing test** — append before the summary (tests only the offline-safe `persist`, via the tokenstore it wraps):

```bash
echo "── connect (persist, offline) ──"
TMP3="$(mktemp -d)"; S3="$TMP3/tokens.json"
python3 -c "import sys; sys.path.insert(0,'$SD'); import connect; \
connect.persist('$S3','client-x','RT_X',['https://www.googleapis.com/auth/webmasters.readonly'],['sc-domain:x.com'])"
L3="$(python3 "$SD/tokenstore.py" list --file "$S3")"
has "connect.persist wrote label" "$L3" '"client-x"'
has "connect.persist wrote prop"  "$L3" 'sc-domain:x.com'
hasnt "connect.persist redacts"   "$L3" 'RT_X'
rm -rf "$TMP3"
```

- [ ] **Step 3: Run it, verify red**

Run: `bash lib/tests/seo-data.test.sh`
Expected: FAIL — `connect` module / `persist` missing.

- [ ] **Step 4: Implement `lib/seo-data/connect.py`:**

```python
#!/usr/bin/env python3
"""One-time OAuth consent + GSC property discovery + persist. Third-party imports
are lazy so `persist` is testable stdlib-only."""
import argparse, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tokenstore

SCOPES = ["https://www.googleapis.com/auth/webmasters.readonly"]

def run_consent(client_id, client_secret):
    from google_auth_oauthlib.flow import InstalledAppFlow   # lazy
    cfg = {"installed": {"client_id": client_id, "client_secret": client_secret,
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "redirect_uris": ["http://localhost"]}}
    flow = InstalledAppFlow.from_client_config(cfg, scopes=SCOPES)
    creds = flow.run_local_server(port=0)     # opens browser, one-time consent
    if not creds.refresh_token:
        raise SystemExit("No refresh token returned. Revoke prior grant and retry.")
    return creds.refresh_token

def discover_properties(refresh_token, client_id, client_secret):
    from google.oauth2.credentials import Credentials
    from google.auth.transport.requests import AuthorizedSession, Request
    creds = Credentials(None, refresh_token=refresh_token, client_id=client_id,
                        client_secret=client_secret,
                        token_uri="https://oauth2.googleapis.com/token", scopes=SCOPES)
    creds.refresh(Request())
    r = AuthorizedSession(creds).get(
        "https://searchconsole.googleapis.com/webmasters/v3/sites", timeout=30)
    r.raise_for_status()
    return [e["siteUrl"] for e in r.json().get("siteEntry", [])]

def persist(store_path, label, refresh_token, scopes, properties):
    tokenstore.save_account(store_path, label, refresh_token, scopes, properties)

def _cli():
    p = argparse.ArgumentParser()
    p.add_argument("--label", required=True)
    p.add_argument("--store", default=os.path.expanduser("~/.claude/seo-data/tokens.json"))
    args = p.parse_args()
    cid = os.environ.get("GOOGLE_OAUTH_CLIENT_ID")
    csec = os.environ.get("GOOGLE_OAUTH_CLIENT_SECRET")
    if not (cid and csec):
        raise SystemExit("Set GOOGLE_OAUTH_CLIENT_ID/SECRET in ~/.claude/.env first.")
    existing = {a["label"] for a in tokenstore.list_accounts(args.store)}
    if args.label in existing:
        ans = input("Label '%s' exists. Overwrite? [y/N] " % args.label).strip().lower()
        if ans != "y":
            raise SystemExit("Aborted.")
    rt = run_consent(cid, csec)
    props = discover_properties(rt, cid, csec)
    persist(args.store, args.label, rt, SCOPES, props)
    print("Connected '%s'. Properties: %s" % (args.label, ", ".join(props) or "(none)"))

if __name__ == "__main__":
    _cli()
```

- [ ] **Step 5: Run it, verify green**

Run: `bash lib/tests/seo-data.test.sh`
Expected: PASS (all prior + 3 persist checks).

- [ ] **Step 6: Manual verification (documented, not automated)** — after Task 6 wires `make seo-connect`: run it once against a real GCP OAuth client, confirm the browser consent completes, the store gains the label with discovered properties, and a second `fetch.sh queries` runs non-interactively.

- [ ] **Step 7: Commit**

```bash
git add lib/seo-data/connect.py lib/seo-data/requirements.txt lib/tests/seo-data.test.sh
git commit -m "feat(seo-data): OAuth consent + property discovery + pinned deps"
```

---

## Task 6: Install / deploy wiring

`.env.example`, `Makefile seo-connect`, `install.sh` step, `doctor.sh` check, gitleaks allowlist, gitignore. All content-locked by the bash test.

**Files:**
- Modify: `.env.example`, `Makefile`, `install.sh`, `doctor.sh`, `.gitleaks.toml`, `.gitignore`
- Modify: `lib/tests/seo-data.test.sh` (append wiring locks)

**Interfaces:**
- Consumes: `lib/seo-data/{connect.py,requirements.txt}`.
- Produces: `make seo-connect`; doctor check; allowlisted store path.

- [ ] **Step 1: Write the failing test** — append before the summary:

```bash
echo "── wiring locks ──"
tf() { if grep -qF -- "$3" "$2" 2>/dev/null; then ok "$1"; else no "$1" "missing: $3"; fi; }
tf "env.example client id"   "$REPO/.env.example"    "GOOGLE_OAUTH_CLIENT_ID="
tf "env.example crux key"    "$REPO/.env.example"    "CRUX_API_KEY="
tf "makefile seo-connect"    "$REPO/Makefile"        "seo-connect:"
tf "install prompts connect" "$REPO/install.sh"      "make seo-connect"
tf "doctor checks seo-data"  "$REPO/doctor.sh"       "seo-data"
tf "gitleaks allowlist store" "$REPO/.gitleaks.toml" "seo-data/tokens.json"
tf "gitignore venv"          "$REPO/.gitignore"      ".venv-seo-data"
```

- [ ] **Step 2: Run it, verify red**

Run: `bash lib/tests/seo-data.test.sh`
Expected: FAIL — none of the 7 locks present yet.

- [ ] **Step 3: Apply the wiring edits**

`.env.example` — append:
```
# ── Google SEO data layer (lib/seo-data) — used by /seo FULL ──
# OAuth Desktop client: GCP console → APIs & Services → Credentials → OAuth client (Desktop).
# Scope requested at consent: webmasters.readonly. One-time setup: make seo-connect
GOOGLE_OAUTH_CLIENT_ID=<your-client-id.apps.googleusercontent.com>
GOOGLE_OAUTH_CLIENT_SECRET=<your-client-secret>
# CrUX + PageSpeed API key (GCP console → Credentials → API key, restricted to those APIs).
# Get it: https://developer.chrome.com/docs/crux/api
CRUX_API_KEY=<your-crux-api-key>
```

`Makefile` — add target + `.PHONY`:
```make
seo-connect: ## Connect a Google account for /seo FULL (creates venv, OAuth consent)
	@python3 -m venv "$$HOME/.claude/.venv-seo-data"
	@"$$HOME/.claude/.venv-seo-data/bin/pip" install -q -r lib/seo-data/requirements.txt
	@read -r -p "Label for this account (e.g. client-a): " label; \
	 "$$HOME/.claude/.venv-seo-data/bin/python3" lib/seo-data/connect.py --label "$$label"
```
(Add `seo-connect` to the `.PHONY:` line at the top of the Makefile.)

`install.sh` — after the `bash "$REPO/link.sh"` block (§5, ~line 107), before plugins:
```bash
# ── 5b. Optional: connect a Google account for /seo FULL ──
echo ""
if [ -f "$HOME/.claude/seo-data/tokens.json" ]; then
  ok "seo-data: a Google account is already connected"
else
  info "SEO data layer (GSC + CrUX) is optional. To enable real Search Console"
  info "data in /seo FULL, add GOOGLE_OAUTH_* + CRUX_API_KEY to ~/.claude/.env,"
  info "then run:  make seo-connect"
fi
```

`doctor.sh` — add a check block (non-fatal, canonical env, mirrors existing WARN style):
```bash
echo "── seo-data (GSC/CrUX) ──"
if grep -qE '^[[:space:]]*(export[[:space:]]+)?CRUX_API_KEY=.' "$HOME/.claude/.env" 2>/dev/null; then
  ok "CRUX_API_KEY present"
else
  warn "CRUX_API_KEY absent in ~/.claude/.env — /seo FULL falls back to lab PageSpeed"
fi
if [ -f "$HOME/.claude/seo-data/tokens.json" ]; then
  ok "seo-data: $(python3 "$REPO/lib/seo-data/tokenstore.py" list --file "$HOME/.claude/seo-data/tokens.json" | grep -o '"label"' | wc -l) account(s) connected"
else
  warn "seo-data: no Google account connected (run: make seo-connect) — GSC data disabled"
fi
```
(Use the same `ok`/`warn` helpers doctor.sh already defines; if they differ, match its local names.)

`.gitleaks.toml` — add to `[allowlist].paths` (after the `.env` entry):
```toml
  # seo-data OAuth token store — legitimate local secret (like ~/.claude/.env),
  # 0600, outside git. Allowlisted so `make scan-secrets` doesn't flag the vault.
  '''(^|/)\.claude/seo-data/tokens\.json$''',
```

`.gitignore` — after the `.env*` block (~line 114):
```
# seo-data engine local artifacts (live under ~/.claude, never committed)
.venv-seo-data/
seo-data/tokens.json
```

- [ ] **Step 4: Run it, verify green**

Run: `bash lib/tests/seo-data.test.sh`
Expected: PASS (all prior + 7 wiring locks). Then `make test` — the whole suite still green.

- [ ] **Step 5: Commit**

```bash
git add .env.example Makefile install.sh doctor.sh .gitleaks.toml .gitignore lib/tests/seo-data.test.sh
git commit -m "chore(seo-data): install/make/doctor wiring + gitleaks allowlist for token store"
```

---

## Task 7: Analyzer + skill integration

Make `/seo` FULL actually consume the engine: account selection in STEP 0, CrUX field data + a GSC performance subsection in the analyzer, automation-catalog entry.

**Files:**
- Modify: `skills/seo/SKILL.md` (STEP 0 — account/property selection, FULL only)
- Modify: `agents/seo-analyzer.md` (STEP 4 CWV terrain via `fetch.sh crux`; new "Performance GSC" subsection via `fetch.sh queries`/`inspect`; STEP 9 Technical axis note)
- Modify: `agents/resources/automation-catalog.md` (GSC OAuth connection entry)
- Modify: `lib/tests/seo-data.test.sh` (append integration locks)

**Interfaces:**
- Consumes: `lib/seo-data/fetch.sh` CLI contract.
- Produces: analyzer output enriched with real GSC/CrUX; passes `(account, property)` explicitly.

- [ ] **Step 1: Write the failing test** — append before the summary:

```bash
echo "── integration locks ──"
tf "skill step0 account select" "$REPO/skills/seo/SKILL.md"      "COMPTE GOOGLE"
tf "analyzer calls fetch crux"  "$REPO/agents/seo-analyzer.md"   "fetch.sh crux"
tf "analyzer calls fetch queries" "$REPO/agents/seo-analyzer.md" "fetch.sh queries"
tf "analyzer gsc subsection"    "$REPO/agents/seo-analyzer.md"   "Performance GSC"
tf "catalog gsc oauth entry"    "$REPO/agents/resources/automation-catalog.md" "make seo-connect"
```

- [ ] **Step 2: Run it, verify red**

Run: `bash lib/tests/seo-data.test.sh`
Expected: FAIL — 5 integration locks absent.

- [ ] **Step 3: Apply the integration edits** (concrete anchors from the /analyze report):

`skills/seo/SKILL.md` — in **STEP 0**, after the "Audit depth" block, add a FULL-only account-selection block (main loop, interactive) exactly as specified in spec §6, opening with the line `COMPTE GOOGLE pour cet audit FULL :`, listing connected accounts from `bash lib/seo-data/fetch.sh accounts`, an option to run `make seo-connect`, and an "Ignore" option. Record the chosen `(account, property)` in the shared context block and pass it into **both** analyzer dispatch prompts (STEP 1) under `BUSINESS CONTEXT` as `GSC account: <label>` / `GSC property: <property>`.

`agents/seo-analyzer.md` — in **STEP 4 → Core Web Vitals** (currently the anonymous PageSpeed curl, ~lines 238-259), add before the PageSpeed call:
```
When a GSC account+property were passed in context, fetch CrUX field data first:
  bash ~/.claude/lib/seo-data/fetch.sh crux --url "https://$DOMAIN" --strategy mobile
  bash ~/.claude/lib/seo-data/fetch.sh crux --url "https://$DOMAIN" --strategy desktop
If status=ok, use lcp_p75_ms / inp_p75_ms / cls_p75 as the PRIMARY CWV figures
(75th pct, real users). Keep the PageSpeed lab run as a SECONDARY diagnostic.
If status=degraded, fall back to PageSpeed lab only (current behavior).
```
Then add a new subsection **"Performance GSC (90 j)"** in STEP 4 (FULL only, when account+property present):
```
  bash ~/.claude/lib/seo-data/fetch.sh queries --account "$GSC_ACCOUNT" --property "$GSC_PROPERTY" --days 90 --dim query
  bash ~/.claude/lib/seo-data/fetch.sh inspect --account "$GSC_ACCOUNT" --property "$GSC_PROPERTY" --url "https://$DOMAIN/"
Report: top queries; flag QUICK WINS = rows with position between 4 and 10 AND
high impressions (candidates to push onto page 1). Report index coverage from inspect.
All emitted into SEO.md §2 and §8. If status=degraded → note it and emit the §11
user action "Connecter GSC: make seo-connect".
```
In **STEP 9** scoring, add a note on the Technical axis: "CWV scored on CrUX field data when available; else lab PageSpeed." In **STEP 3 (plugin check)**, add the graceful-degradation line for GSC/CrUX creds (READY | DEGRADED).

`agents/resources/automation-catalog.md` — under the existing Google Search Console entry (~line 69), add:
```
- **Connexion GSC pour /seo (données réelles)** — `make seo-connect` (une fois par
  compte) : consentement OAuth lecture seule (webmasters.readonly), stocke un refresh
  token local (0600). Ensuite /seo FULL lit requêtes/positions/indexation sans réinvite.
```

- [ ] **Step 4: Run it, verify green**

Run: `bash lib/tests/seo-data.test.sh`
Expected: PASS (all prior + 5 integration locks). Run `make test` — full suite green.

- [ ] **Step 5: Commit**

```bash
git add skills/seo/SKILL.md agents/seo-analyzer.md agents/resources/automation-catalog.md lib/tests/seo-data.test.sh
git commit -m "feat(seo): wire GSC+CrUX data into /seo FULL (STEP 0 account select, CWV field, GSC perf)"
```

---

## Task 8: Engine README

Document the engine's contract so future maintainers (and the analyzer) have a single reference.

**Files:**
- Create: `lib/seo-data/README.md`
- Modify: `lib/tests/seo-data.test.sh` (append doc lock)

**Interfaces:**
- Consumes: nothing.
- Produces: `lib/seo-data/README.md`.

- [ ] **Step 1: Write the failing test** — append before the summary:

```bash
echo "── readme lock ──"
tf "readme documents fetch.sh" "$REPO/lib/seo-data/README.md" "fetch.sh"
tf "readme documents seo-connect" "$REPO/lib/seo-data/README.md" "make seo-connect"
```

- [ ] **Step 2: Run it, verify red** — Run: `bash lib/tests/seo-data.test.sh` — Expected: FAIL (README missing).

- [ ] **Step 3: Write `lib/seo-data/README.md`** — cover: purpose (real GSC+CrUX for /seo FULL), setup (`make seo-connect` + the 3 `.env` keys), the `fetch.sh` subcommand contract (copy §9 of the spec), the token store location + security notes (0600, gitleaks allowlist, scope webmasters.readonly), graceful-degradation behavior, and how to run the test (`make test`). Concrete, no placeholders.

- [ ] **Step 4: Run it, verify green** — Run: `bash lib/tests/seo-data.test.sh` — Expected: PASS (all locks).

- [ ] **Step 5: Commit**

```bash
git add lib/seo-data/README.md lib/tests/seo-data.test.sh
git commit -m "docs(seo-data): engine usage + security contract README"
```

---

## Self-Review

**1. Spec coverage** — every spec section maps to a task:
- §4 architecture → Tasks 1-5 (engine files) + 7 (consumers).
- §5 auth/secrets (OAuth, .env vault, keyed store, gitleaks) → Task 1 (store), 5 (OAuth), 6 (.env.example + gitleaks + gitignore).
- §6 account selection STEP 0 → Task 7.
- §7 concurrency (explicit args, read-only audits, atomic locked writes) → Task 1 (atomic/lock), 4 (explicit args), 7 (pass-through).
- §8 data mapping (CrUX field, GSC queries/inspect, position 4-10) → Tasks 2, 3, 7.
- §9 fetch.sh contract → Task 4.
- §10 degradation/redaction → Tasks 2, 3, 4 (degrade+exit0+redaction tests).
- §11 install (env.example, install.sh, Makefile, doctor, gitleaks, gitignore) → Task 6.
- §12 tests → woven through every task (bash, fixtures, no network).
- §14 file touch-list → matches Tasks 1-8 exactly.
- §13 YAGNI (no GA4/Ads/Indexing, geo-analyzer untouched, one property/audit) → respected (no such tasks).

**2. Placeholder scan** — no "TBD/TODO". Tasks 3, 7, 8 use precise prose for markdown edits with exact anchor strings + verbatim content to insert (not "add error handling"). All code steps show code. `requirements.txt` versions flagged "verify latest patch at execution" (a real instruction, not a placeholder).

**3. Type consistency** — signatures identical across tasks: `save_account(path,label,refresh_token,scopes,properties)`, `get_refresh_token(path,label)`, `list_accounts(path)`, `crux(url,strategy)`, `queries(store_path,account,property,days,dim)`, `inspect(store_path,account,property,url)`, `persist(...)` delegates to `save_account`. `fetch.sh` passes `--store` uniformly (crux ignores it — noted in Task 4). `SEO_DATA_MOCK_DIR` / `SEO_DATA_STORE` env names consistent.

**Known execution caveats (not gaps):** the OAuth browser consent (Task 5) and live API calls can't be unit-tested — covered by the Task 5 manual-verification step. The `.test.sh` accumulates sections across tasks; each task appends before the final summary block.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-09-gsc-crux-data-layer.md`. Two execution options:

**1. Subagent-Driven (recommended)** — a fresh subagent per task, review between tasks, fast iteration.
**2. Inline Execution** — execute tasks in this session with checkpoints for review.

Which approach?
