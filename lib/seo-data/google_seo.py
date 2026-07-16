#!/usr/bin/env python3
"""CrUX + GSC fetch → normalized JSON. Third-party imports are LAZY so mock and
degraded paths run stdlib-only (no venv, no network)."""
import argparse, json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

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
    out = {"status": "ok", "source": "crux"}
    lcp = p75("largest_contentful_paint")
    inp = p75("interaction_to_next_paint")
    cls = p75("cumulative_layout_shift")
    # Low-traffic origins often miss a metric (INP notably) — omit, don't crash.
    if lcp is not None:
        out["lcp_p75_ms"] = int(lcp)
    if inp is not None:
        out["inp_p75_ms"] = int(inp)
    if cls is not None:
        out["cls_p75"] = float(cls)
    if len(out) == 2:  # no metric at all
        return {"status": "degraded", "reason": "no_field_data"}
    return out

def _crux_query(key, body):
    import requests  # lazy
    return requests.post(
        "https://chromeuxreport.googleapis.com/v1/records:queryRecord?key=" + key,
        json=body, timeout=20)

def _origin(url):
    from urllib.parse import urlparse  # stdlib
    p = urlparse(url)
    return "%s://%s" % (p.scheme, p.netloc)  # strip path — CrUX origin = scheme+host only

def crux(url, strategy="mobile"):
    raw = _mock("crux_%s.json" % strategy)
    if raw is None:
        key = os.environ.get("CRUX_API_KEY")
        if not key:
            return {"status": "degraded", "reason": "no_crux_key"}
        ff = "PHONE" if strategy == "mobile" else "DESKTOP"
        r = _crux_query(key, {"url": url, "formFactor": ff})
        if r.status_code == 404:  # no page-level data → try origin-level
            r = _crux_query(key, {"origin": _origin(url), "formFactor": ff})
        if r.status_code == 404:
            return {"status": "degraded", "reason": "no_field_data"}
        if r.status_code == 429:
            return {"status": "degraded", "reason": "rate_limited"}
        r.raise_for_status()
        raw = r.json()
    return _norm_crux(raw)

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
    except Exception as e:
        # Only a real RefreshError means re-consent; a network blip must NOT
        # send the user back through OAuth.
        from google.auth.exceptions import RefreshError  # lazy
        reason = "token_revoked" if isinstance(e, RefreshError) else "network_error"
        return {"status": "degraded", "reason": reason}
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

def _cli():
    try:
        p = argparse.ArgumentParser()
        sub = p.add_subparsers(dest="cmd", required=True)
        pc = sub.add_parser("crux")
        pc.add_argument("--url", required=True)
        pc.add_argument("--strategy", default="mobile", choices=["mobile", "desktop"])
        pc.add_argument("--store", default=None)  # accepted+ignored: uniform fetch.sh dispatch
        pq = sub.add_parser("queries")
        pq.add_argument("--store", required=True)
        pq.add_argument("--account", required=True)
        pq.add_argument("--property", required=True)
        pq.add_argument("--days", type=int, default=90)
        pq.add_argument("--dim", default="query")
        pi = sub.add_parser("inspect")
        pi.add_argument("--store", required=True)
        pi.add_argument("--account", required=True)
        pi.add_argument("--property", required=True)
        pi.add_argument("--url", required=True)
        args = p.parse_args()
        if args.cmd == "crux":
            print(json.dumps(crux(args.url, args.strategy), indent=2))
        elif args.cmd == "queries":
            print(json.dumps(queries(args.store, args.account, args.property,
                                      args.days, args.dim), indent=2))
        elif args.cmd == "inspect":
            print(json.dumps(inspect(args.store, args.account, args.property,
                                      args.url), indent=2))
    except SystemExit as e:                       # argparse usage error
        if e.code not in (0, None):
            print(json.dumps({"status": "error", "reason": "bad_usage"}))
        raise                                     # preserve argparse's exit code
    except Exception:
        # Fail-open data contract: ANY unexpected error (HTTP 403/5xx, DNS,
        # timeout) degrades with exit 0 — never a traceback, never empty stdout.
        print(json.dumps({"status": "degraded", "reason": "unexpected_error"}))

if __name__ == "__main__":
    _cli()
