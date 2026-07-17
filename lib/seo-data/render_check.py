#!/usr/bin/env python3
"""Is the content in the served HTML, or painted by JS? Stdlib only.

seo-analyzer records `RENDERING: SSR/SSG/SPA/hybrid` and then does nothing
with it. That is the gap this closes. On a client-rendered site `curl` returns
an empty shell, so every meta/H1/JSON-LD check reports "missing" and the audit
emits a page of false findings against a site that may be perfectly fine.

The verdict is taken from what the server actually sent — not from guessing at
package.json, where a React SPA and a Next.js SSR app look identical.

R2, not R1: this REPORTS blindness so the agent can refuse to score. It does
not render JS. No Playwright, no Chromium, no venv.
"""
import argparse, json, re
from html.parser import HTMLParser

import sitemap as sm                       # sibling: _fetch / _mock

# A shell can still carry a title + a couple of nav words. These thresholds
# separate "shell" from "page" on the two real sites measured 2026-07-17
# (server-rendered: 1 h1, thousands of body chars) and on a hydration stub.
MIN_TEXT = 400
MIN_H1 = 1

class _Doc(HTMLParser):
    """Collect body text and the tags an SEO audit reads. Script/style content
    is NOT text: a 200 KB React bundle would otherwise look like a rich page."""
    SKIP = ("script", "style", "noscript", "template", "svg")

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.text, self.h1, self.jsonld, self.meta_desc = [], 0, 0, False
        self._skip = 0
        self._ld = False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag in self.SKIP:
            self._skip += 1
            self._ld = tag == "script" and a.get("type") == "application/ld+json"
        elif tag == "h1":
            self.h1 += 1
        elif tag == "meta" and a.get("name", "").lower() == "description":
            self.meta_desc = bool((a.get("content") or "").strip())

    def handle_endtag(self, tag):
        if tag in self.SKIP and self._skip:
            self._skip -= 1
            self._ld = False

    def handle_data(self, data):
        if self._ld:
            self.jsonld += 1
        elif not self._skip:
            s = data.strip()
            if s:
                self.text.append(s)

def _verdict(text_chars, h1, jsonld):
    if text_chars >= MIN_TEXT and h1 >= MIN_H1:
        return "server-rendered"
    if text_chars < MIN_TEXT and h1 == 0 and jsonld == 0:
        return "client-rendered"
    return "partial"                       # shell + some SSR'd head, or thin page

def render_check(url):
    raw = sm._mock("page.html")
    if raw is None:
        try:
            raw = sm._fetch(url)
        except Exception:
            return {"status": "degraded", "reason": "fetch_failed"}
    html = raw.decode("utf-8", "replace")
    d = _Doc()
    try:
        d.feed(html)
    except Exception:
        pass                               # tolerate malformed markup
    text = re.sub(r"\s+", " ", " ".join(d.text)).strip()
    verdict = _verdict(len(text), d.h1, d.jsonld)
    out = {"status": "ok", "source": "render_check", "verdict": verdict,
           "body_text_chars": len(text), "h1_in_html": d.h1,
           "jsonld_in_html": d.jsonld, "meta_description_in_html": d.meta_desc,
           "html_bytes": len(raw)}
    if verdict != "server-rendered":
        out["warning"] = ("content is not in the served HTML — curl-based "
                          "on-page checks will report false 'missing' findings")
    return out

def _cli():
    try:
        p = argparse.ArgumentParser()
        p.add_argument("--url", required=True)
        p.add_argument("--store", default=None)   # accepted+ignored
        args = p.parse_args()
        print(json.dumps(render_check(args.url), indent=2))
    except SystemExit as e:
        if e.code not in (0, None):
            print(json.dumps({"status": "error", "reason": "bad_usage"}))
        raise
    except Exception:
        print(json.dumps({"status": "degraded", "reason": "unexpected_error"}))

if __name__ == "__main__":
    _cli()
