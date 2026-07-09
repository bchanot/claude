#!/usr/bin/env python3
"""CrUX + GSC fetch → normalized JSON. Third-party imports are LAZY so mock and
degraded paths run stdlib-only (no venv, no network)."""
import argparse, json, os

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

def _cli():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    pc = sub.add_parser("crux")
    pc.add_argument("--url", required=True)
    pc.add_argument("--strategy", default="mobile", choices=["mobile", "desktop"])
    pc.add_argument("--store", default=None)  # accepted+ignored: uniform fetch.sh dispatch
    args = p.parse_args()
    try:
        if args.cmd == "crux":
            print(json.dumps(crux(args.url, args.strategy), indent=2))
    except Exception:
        # Fail-open data contract: ANY unexpected error (HTTP 403/5xx, DNS,
        # timeout) degrades with exit 0 — never a traceback, never empty stdout.
        print(json.dumps({"status": "degraded", "reason": "unexpected_error"}))

if __name__ == "__main__":
    _cli()
