#!/usr/bin/env python3
"""Sitemap discovery -> normalized JSON. Stdlib only: no venv, no requests, no
auth. Gives STEP 9 COVERAGE the denominator it was told to report and never
had, and STEP 5 a real sampling frame instead of "5-15 key pages" chosen by
eye.

Deliberately NOT a security boundary. urllib fetches these URLs, so nothing
here reaches a shell and there is no injection surface to guard. The consumer
is different: seo-analyzer interpolates URLs into curl, so IT must run
lib/url-guard.sh at the point of use (same pattern as the sameAs check).
Duplicating the guard here would just add a second copy to drift. `_sane`
below is a cheap garbage filter, not that guard.
"""
import argparse, gzip, json, os
from urllib.parse import urlparse

MAX_URLS = 50000      # sitemaps.org caps one file at 50k
MAX_CHILDREN = 50     # sitemapindex fan-out cap: bound the work, report the cut
TIMEOUT = 20

def _mock(name):
    d = os.environ.get("SEO_DATA_MOCK_DIR")
    if not d:
        return None
    path = os.path.join(d, name)
    if not os.path.exists(path):
        return None
    with open(path, "rb") as f:
        return f.read()

def _fetch(url):
    from urllib.request import urlopen, Request      # stdlib, lazy
    req = Request(url, headers={"User-Agent": "claude-seo-data/1.0"})
    with urlopen(req, timeout=TIMEOUT) as r:         # nosec: audited target
        raw = r.read(20 * 1024 * 1024)               # 20 MB ceiling
    if raw[:2] == b"\x1f\x8b":                       # sitemap.xml.gz is common
        raw = gzip.decompress(raw)
    return raw

class UnsafeXML(Exception):
    """A DTD reached the parser. Refused before parsing, not mitigated after."""

def _refuse_dtd(raw):
    """A sitemap NEVER has a DTD: sitemaps.org is <?xml?> then <urlset xmlns=>.
    So refuse any doctype/entity outright, at the door.

    This is the reason we do not pull in defusedxml. The stdlib parser is not
    the problem for XXE — xml.etree.ElementTree does not expand external
    entities, it raises on them — but it IS vulnerable to billion-laughs, where
    a 1 KB document expands to gigabytes in RAM. The 20 MB read ceiling bounds
    the input, not the expansion. Rejecting the construct beats depending on
    the parser's internals, and keeps this module stdlib-only: no venv, same as
    google_seo.py's mock/degrade paths. A sitemap with a DTD is not a sitemap
    we want anyway.
    """
    head = raw[:4096].lstrip()[:2048].upper()
    if b"<!DOCTYPE" in head or b"<!ENTITY" in head:
        raise UnsafeXML("DTD in sitemap")

def _locs(raw):
    """(<loc> texts, is_sitemapindex). Namespace-agnostic: real sitemaps carry
    the sitemaps.org xmlns and often xhtml too."""
    import xml.etree.ElementTree as ET               # stdlib, lazy
    _refuse_dtd(raw)
    root = ET.fromstring(raw)
    is_index = root.tag.endswith("sitemapindex")
    out = []
    for el in root.iter():
        if el.tag.endswith("}loc") or el.tag == "loc":
            text = (el.text or "").strip()
            if text:
                out.append(text)
    return out, is_index

def _sane(u):
    """Cheap garbage filter — NOT lib/url-guard.sh. Drops what could never be a
    real page URL; the consumer still guards before curling."""
    if not u or len(u) > 2048:
        return False
    if any(c in u for c in '\n\r\t "\'\\`$<>{}|^'):
        return False
    return urlparse(u).scheme in ("http", "https")

def _expand(children):
    """Fetch each child sitemap of an index. A child that fails is skipped and
    counted, never fatal: one dead child must not lose the other 49."""
    urls, ok, failed = [], 0, 0
    for c in children:
        raw = _mock("sitemap_child.xml")
        if raw is None:
            try:
                raw = _fetch(c)
            except Exception:
                failed += 1
                continue
        try:
            sub, _ = _locs(raw)
        except Exception:
            failed += 1
            continue
        urls.extend(sub)
        ok += 1
    return urls, ok, failed

def sitemap(url):
    raw = _mock("sitemap.xml")
    if raw is None:
        try:
            raw = _fetch(url)
        except Exception:
            return {"status": "degraded", "reason": "fetch_failed"}
    try:
        locs, is_index = _locs(raw)
    except UnsafeXML:
        # Distinct from parse_failed on purpose: this one is a finding, not a
        # glitch. A sitemap carrying a DTD is either broken tooling or someone
        # aiming a billion-laughs at the auditor.
        return {"status": "degraded", "reason": "unsafe_xml_dtd"}
    except Exception:
        return {"status": "degraded", "reason": "parse_failed"}
    out = {"status": "ok", "source": "sitemap", "index": is_index}
    if is_index:
        out["children_total"] = len(locs)
        kids, ok, failed = _expand(locs[:MAX_CHILDREN])
        out["children_read"], out["children_failed"] = ok, failed
        if len(locs) > MAX_CHILDREN:                 # say what was cut
            out["children_skipped"] = len(locs) - MAX_CHILDREN
        locs = kids
    seen, urls, dropped = set(), [], 0
    for u in locs:
        if not _sane(u):
            dropped += 1
            continue
        if u in seen:
            continue
        seen.add(u)
        urls.append(u)
    if len(urls) > MAX_URLS:
        out["truncated"] = len(urls) - MAX_URLS
        urls = urls[:MAX_URLS]
    out["count"], out["dropped"], out["urls"] = len(urls), dropped, urls
    if not urls:
        return {"status": "degraded", "reason": "no_urls"}
    return out

def _cli():
    try:
        p = argparse.ArgumentParser()
        p.add_argument("--url", required=True)
        p.add_argument("--store", default=None)   # accepted+ignored: uniform dispatch
        args = p.parse_args()
        print(json.dumps(sitemap(args.url), indent=2))
    except SystemExit as e:
        if e.code not in (0, None):
            print(json.dumps({"status": "error", "reason": "bad_usage"}))
        raise
    except Exception:
        # Same fail-open contract as google_seo.py: never a traceback, never
        # empty stdout, exit 0 so the audit degrades instead of dying.
        print(json.dumps({"status": "degraded", "reason": "unexpected_error"}))

if __name__ == "__main__":
    _cli()
