#!/usr/bin/env python3
"""Internal link graph -> orphans + click depth. Stdlib only.

seo-analyzer.md asks "Every important page reachable within 3 clicks?" (:613)
and "Orphan pages (no inbound internal links)?" (:616) and has never had a
command that answers either. This is that command.

EXHAUSTIVE OR NOTHING. You cannot sample orphans: proving a page has no
inbound link means having read every other page. A partial crawl invents
orphans, and "page X has no inbound links" when it does is the worst finding
this tool could emit — it sends a client fixing what is not broken. So when
the cap bites, orphans are WITHHELD, not truncated.

Does NOT render JS. On a client-side-rendered SPA the links are not in the
HTML, every page looks orphaned, and that is a catastrophic false positive —
so an empty link graph is REFUSED (no_links_in_html), never reported.
"""
import argparse, json
from html.parser import HTMLParser
from urllib.parse import urljoin, urlparse, urldefrag

import sitemap as sm                      # sibling module: fetch + parse

MAX_PAGES = 500
# Extensions that are assets, not pages. Seen live: /css/main.css?v=1778157313
ASSET_EXT = (".css", ".js", ".mjs", ".png", ".jpg", ".jpeg", ".gif", ".webp",
             ".avif", ".svg", ".ico", ".woff", ".woff2", ".ttf", ".eot",
             ".pdf", ".zip", ".mp4", ".webm", ".xml", ".json", ".txt", ".rss")

class _Links(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.hrefs = []
    def handle_starttag(self, tag, attrs):
        if tag != "a":
            return
        for k, v in attrs:
            if k == "href" and v:
                self.hrefs.append(v)

def _norm(u):
    """Canonical form for graph identity. Drops the fragment, keeps the query
    (?p=2 IS a different page), and unifies the trailing slash so /blog and
    /blog/ are one node rather than a phantom orphan pair."""
    u = urldefrag(u)[0]
    p = urlparse(u)
    path = p.path or "/"
    if len(path) > 1 and path.endswith("/"):
        path = path[:-1]
    out = "%s://%s%s" % (p.scheme, p.netloc.lower(), path)
    return out + ("?" + p.query if p.query else "")

def _page_links(base, html, host):
    """Internal page links from one document. Filters what a link graph must
    never contain: assets, #anchors, mailto:/tel:, and other hosts."""
    p = _Links()
    try:
        p.feed(html)
    except Exception:
        pass                               # tolerate malformed markup
    out = set()
    for h in p.hrefs:
        h = h.strip()
        if not h or h.startswith(("#", "mailto:", "tel:", "javascript:", "data:")):
            continue
        absu = urljoin(base, h)
        pr = urlparse(absu)
        if pr.scheme not in ("http", "https") or pr.netloc.lower() != host:
            continue
        if pr.path.lower().endswith(ASSET_EXT):
            continue
        out.add(_norm(absu))
    return out

def _mock_pages():
    """{url: html} for tests. A single page.html fixture cannot express a
    GRAPH — every node would carry identical links — so the mock is a map."""
    raw = sm._mock("pages.json")
    return json.loads(raw.decode("utf-8")) if raw else None

def _crawl(urls, host):
    """Fetch each page once; return {page: {links}} plus a failure count."""
    pages = _mock_pages()
    graph, failed = {}, 0
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
        graph[_norm(u)] = _page_links(u, html, host)
    return graph, failed

def _depths(graph, root):
    """BFS click-depth from the homepage. Absent = unreachable by links."""
    seen, frontier, d = {root: 0}, [root], 0
    while frontier:
        d += 1
        nxt = []
        for node in frontier:
            for tgt in graph.get(node, ()):
                if tgt not in seen:
                    seen[tgt] = d
                    nxt.append(tgt)
        frontier = nxt
    return seen

def linkgraph(sitemap_url, max_pages=MAX_PAGES):
    sm_res = sm.sitemap(sitemap_url)
    if sm_res.get("status") != "ok":
        return sm_res                      # propagate the sitemap's own degrade
    urls = sm_res["urls"]
    capped = len(urls) > max_pages
    host = urlparse(urls[0]).netloc.lower()
    graph, failed = _crawl(urls[:max_pages], host)
    if not graph:
        return {"status": "degraded", "reason": "no_pages_fetched"}
    total_links = sum(len(v) for v in graph.values())
    if total_links == 0:
        # Every page orphaned is never the truth — it is a JS-rendered site.
        return {"status": "degraded", "reason": "no_links_in_html",
                "pages_crawled": len(graph),
                "hint": "links absent from served HTML (SPA?) — see R1/R2"}
    inbound = {n: 0 for n in graph}
    for src, tgts in graph.items():
        for t in tgts:
            if t in inbound and t != src:
                inbound[t] += 1
    root = _norm("%s://%s/" % (urlparse(urls[0]).scheme, host))
    depth = _depths(graph, root)
    out = {"status": "ok", "source": "linkgraph",
           "pages_crawled": len(graph), "pages_failed": failed,
           "total_internal_links": total_links, "capped": capped,
           "max_depth": max(depth.values()) if depth else 0,
           "beyond_3_clicks": sorted(n for n, d in depth.items() if d > 3),
           "unreachable": sorted(n for n in graph if n not in depth)}
    if capped or failed:
        # A page can only be called orphaned if EVERY other page was read.
        out["orphans_withheld"] = True
        out["reason_withheld"] = ("crawl incomplete (capped=%s, failed=%d) — "
                                  "an orphan from a partial crawl is a false "
                                  "orphan" % (capped, failed))
    else:
        out["orphans"] = sorted(n for n, c in inbound.items()
                                if c == 0 and n != root)
    return out

def _cli():
    try:
        p = argparse.ArgumentParser()
        p.add_argument("--url", required=True, help="sitemap URL")
        p.add_argument("--max", type=int, default=MAX_PAGES)
        p.add_argument("--store", default=None)   # accepted+ignored
        args = p.parse_args()
        print(json.dumps(linkgraph(args.url, args.max), indent=2))
    except SystemExit as e:
        if e.code not in (0, None):
            print(json.dumps({"status": "error", "reason": "bad_usage"}))
        raise
    except Exception:
        print(json.dumps({"status": "degraded", "reason": "unexpected_error"}))

if __name__ == "__main__":
    _cli()
