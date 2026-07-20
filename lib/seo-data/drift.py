#!/usr/bin/env python3
"""On-page drift between audits. Stdlib only.

seo-analyzer.md:1365 says "on re-run, move current content to Historique
(summary: date + score + key changes)". That is prose the LLM writes about its
own previous prose: lossy, unreproducible, and machine-uncomparable. So "the
redesign silently dropped 40 canonicals" is invisible unless someone happens
to notice.

This snapshots the machine-readable signals per URL and diffs them.

NOT rank tracking — a common misread of the same feature elsewhere. Positions
come from GSC (`queries`). This is on-page regression detection: what the site
said last time vs now.

Runs over the WHOLE sitemap, never a sample: a drift over a sample that
changes between runs compares nothing.
"""
import argparse, json, os, re, time
from html.parser import HTMLParser

import sitemap as sm

STORE_DIR = os.path.expanduser("~/.claude/seo-data/drift")
MAX_PAGES = 500
# Losing a signal is a regression. Changing one may be intentional — the agent
# judges that, we only report which kind it is.
TRACKED = ("title", "description", "canonical", "robots", "h1_count", "jsonld_types")

class _Signals(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.title, self.description, self.canonical, self.robots = None, None, None, None
        self.h1_count, self.jsonld_types = 0, []
        self._in_title, self._in_ld = False, False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "title":
            self._in_title = True
        elif tag == "h1":
            self.h1_count += 1
        elif tag == "meta":
            n = (a.get("name") or "").lower()
            if n == "description":
                self.description = (a.get("content") or "").strip() or None
            elif n == "robots":
                self.robots = (a.get("content") or "").strip() or None
        elif tag == "link" and "canonical" in (a.get("rel") or "").lower():
            self.canonical = (a.get("href") or "").strip() or None
        elif tag == "script" and a.get("type") == "application/ld+json":
            self._in_ld = True

    def handle_endtag(self, tag):
        if tag == "title":
            self._in_title = False
        elif tag == "script":
            self._in_ld = False

    def handle_data(self, data):
        if self._in_title and data.strip():
            self.title = re.sub(r"\s+", " ", data.strip())
        elif self._in_ld:
            self.jsonld_types.extend(re.findall(r'"@type"\s*:\s*"([^"]+)"', data))

def _signals(html):
    p = _Signals()
    try:
        p.feed(html)
    except Exception:
        pass
    return {"title": p.title, "description": p.description,
            "canonical": p.canonical, "robots": p.robots,
            "h1_count": p.h1_count, "jsonld_types": sorted(set(p.jsonld_types))}

def _mock_pages():
    """{url: html}, same convention as linkgraph: a single page.html fixture
    cannot express a multi-page snapshot — every URL would look identical."""
    raw = sm._mock("pages.json")
    return json.loads(raw.decode("utf-8")) if raw else None

def _capture(urls):
    pages = _mock_pages()
    snap, failed = {}, 0
    for u in urls:
        if pages is not None:
            html = pages.get(u)
            if html is None:
                failed += 1
                continue
        else:
            try:
                html = sm._fetch(u).decode("utf-8", "replace")
            except Exception:
                failed += 1
                continue
        snap[u] = _signals(html)
    return snap, failed

def _store_path(sitemap_url):
    from urllib.parse import urlparse
    host = urlparse(sitemap_url).netloc.lower()
    safe = re.sub(r"[^a-z0-9.-]", "_", host) or "unknown"
    return os.path.join(STORE_DIR, safe + ".json")

def _load(path):
    if not os.path.exists(path):
        return None
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None                        # corrupt store -> treat as first run

def _save(path, snap, stamp):
    os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump({"captured": stamp, "pages": snap}, f)
    os.replace(tmp, path)                  # atomic: never a half-written baseline

def _classify(old, new):
    """LOST a signal = regression. Changed it = change. Only the first is
    unambiguous; the agent judges the rest."""
    regressions, changes = [], []
    for f in TRACKED:
        o, n = old.get(f), new.get(f)
        if o == n:
            continue
        row = {"field": f, "was": o, "now": n}
        # Covers every tracked field uniformly: "Titre" -> None, 1 -> 0,
        # ["Article"] -> []. Had the value, lost the value.
        (regressions if (o and not n) else changes).append(row)
    return regressions, changes

def drift(sitemap_url, max_pages=MAX_PAGES):
    sm_res = sm.sitemap(sitemap_url)
    if sm_res.get("status") != "ok":
        return sm_res
    urls = sm_res["urls"][:max_pages]
    snap, failed = _capture(urls)
    if not snap:
        return {"status": "degraded", "reason": "no_pages_fetched"}
    stamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    path = _store_path(sitemap_url)
    prev = _load(path)
    _save(path, snap, stamp)
    if prev is None:
        return {"status": "ok", "baseline": True, "captured": stamp,
                "pages": len(snap), "pages_failed": failed, "store": path}
    old = prev.get("pages", {})
    regressions, changes = [], []
    for u, new in snap.items():
        if u not in old:
            continue
        r, c = _classify(old[u], new)
        for row in r:
            regressions.append(dict(row, url=u))
        for row in c:
            changes.append(dict(row, url=u))
    return {"status": "ok", "baseline": False,
            "since": prev.get("captured"), "captured": stamp,
            "pages": len(snap), "pages_failed": failed,
            "gone": sorted(set(old) - set(snap)),
            "new": sorted(set(snap) - set(old)),
            "regressions": regressions, "changes": changes, "store": path}

def _cli():
    try:
        p = argparse.ArgumentParser()
        p.add_argument("--url", required=True, help="sitemap URL")
        p.add_argument("--max", type=int, default=MAX_PAGES)
        p.add_argument("--store", default=None)   # accepted+ignored
        args = p.parse_args()
        print(json.dumps(drift(args.url, args.max), indent=2))
    except SystemExit as e:
        if e.code not in (0, None):
            print(json.dumps({"status": "error", "reason": "bad_usage"}))
        raise
    except Exception:
        print(json.dumps({"status": "degraded", "reason": "unexpected_error"}))

if __name__ == "__main__":
    _cli()
