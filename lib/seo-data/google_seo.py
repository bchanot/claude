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
    # `keys` is the list the API actually returns (one entry per requested
    # dimension); `key` stays as keys[0] so the single-dim consumer that reads
    # it keeps working. Additive — nothing to migrate.
    return {"status": "ok", "source": "gsc", "dimension": dim, "rows": [
        {"key": r["keys"][0], "keys": r["keys"], "clicks": r.get("clicks", 0),
         "impressions": r.get("impressions", 0), "ctr": r.get("ctr", 0),
         "position": r.get("position")}
        for r in raw.get("rows", [])]}

def queries(store_path, account, property, days=90, dim="query", rows=100):
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
        # dim accepts a comma-separated list: the API groups by several
        # dimensions at once ("no limit... but you cannot group by the same
        # dimension twice"), and query+page is what exposes cannibalisation.
        dims = [d.strip() for d in dim.split(",") if d.strip()]
        r = sess.post(url, json={"startDate": start.isoformat(), "endDate": end.isoformat(),
                                 "dimensions": dims, "rowLimit": rows}, timeout=30)
        if r.status_code == 429:
            return {"status": "degraded", "reason": "rate_limited"}
        r.raise_for_status()
        raw = r.json()
    return _norm_queries(raw, dim)

def _rollup_issues(items):
    """Count issue instances by severity; dedupe messages (they repeat per item)."""
    errors = warnings = 0
    msgs = []
    for item in items:
        for iss in item.get("issues", []):
            sev = iss.get("severity")
            if sev == "ERROR":
                errors += 1
            elif sev == "WARNING":
                warnings += 1
            msg = iss.get("issueMessage")
            if msg and msg not in msgs:
                msgs.append(msg)
    return errors, warnings, msgs

def _norm_rich(ir):
    """richResultsResult → verdict + per-type rollup. Google OMITS the key when
    it detects no rich results, so absence is data, not an error: surfaced as the
    synthetic verdict ABSENT (not a Google enum) rather than a missing key, which
    a caller cannot tell apart from a check that never ran. PARTIAL is never
    emitted — the API reserves it as unused."""
    rr = ir.get("richResultsResult")
    if rr is None:
        return {"verdict": "ABSENT", "types": []}
    types = []
    for det in rr.get("detectedItems", []):
        errors, warnings, msgs = _rollup_issues(det.get("items", []))
        types.append({"type": det.get("richResultType"),
                      "items": len(det.get("items", [])),
                      "errors": errors, "warnings": warnings, "issues": msgs})
    return {"verdict": rr.get("verdict"), "types": types}

def _group_by_query(rows):
    """query+page rows -> {query: [row, …]}. Deterministic aggregation, not
    judgement: the agent must not be asked to group 1000 rows by eye."""
    by_q = {}
    for r in rows:
        keys = r.get("keys") or []
        if len(keys) < 2:
            continue
        by_q.setdefault(keys[0], []).append(
            {"url": keys[1], "clicks": r["clicks"],
             "impressions": r["impressions"], "position": r["position"]})
    return by_q

def cannibal(store_path, account, property, days=90, rows=1000):
    """Queries where 2+ of our own pages compete for the same term.

    Google's own data says it; nothing in this system asked. Cannibalisation
    is a SERP fact, not a content-similarity guess — do not confuse it with
    the 30/70 duplication rule, which has no data source here."""
    res = queries(store_path, account, property, days, "query,page", rows)
    if res.get("status") != "ok":
        return res
    conflicts = []
    for q, pages in _group_by_query(res["rows"]).items():
        if len(pages) < 2:
            continue
        pages.sort(key=lambda p: p["impressions"], reverse=True)
        conflicts.append({"query": q, "pages": len(pages),
                          "total_impressions": sum(p["impressions"] for p in pages),
                          "urls": pages})
    conflicts.sort(key=lambda c: c["total_impressions"], reverse=True)
    return {"status": "ok", "source": "gsc", "days": days,
            "rows_scanned": len(res["rows"]),
            # rows_scanned == rows means the window was FULL: there may be more
            # conflicts past the cut. Reported, never silently truncated.
            "capped": len(res["rows"]) >= rows,
            "conflict_count": len(conflicts), "conflicts": conflicts}

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
    ir = raw["inspectionResult"]
    isr = ir["indexStatusResult"]
    # rich_results rides the SAME response — Google already sent it and this
    # function used to discard it. No extra call, no extra quota, no new scope.
    return {"status": "ok", "source": "gsc",
            "indexed": isr.get("verdict") == "PASS",
            "coverage": isr.get("coverageState"),
            "last_crawl": isr.get("lastCrawlTime"),
            "rich_results": _norm_rich(ir)}

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
        pq.add_argument("--dim", default="query",
                        help="one dimension, or a comma-separated list (query,page)")
        pq.add_argument("--rows", type=int, default=100)
        pn = sub.add_parser("cannibal")
        pn.add_argument("--store", required=True)
        pn.add_argument("--account", required=True)
        pn.add_argument("--property", required=True)
        pn.add_argument("--days", type=int, default=90)
        pn.add_argument("--rows", type=int, default=1000)
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
                                      args.days, args.dim, args.rows), indent=2))
        elif args.cmd == "cannibal":
            print(json.dumps(cannibal(args.store, args.account, args.property,
                                       args.days, args.rows), indent=2))
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
