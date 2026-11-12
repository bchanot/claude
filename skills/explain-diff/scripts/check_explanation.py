#!/usr/bin/env python3
"""Deterministic floor for an explain-diff page.

Usage: check_explanation.py <file.html>
Prints one PASS / WARN / FAIL line per check. Exit 1 when any check fails,
2 on a usage or read error.
"""
import json
import re
import subprocess
import sys
from html.parser import HTMLParser
from pathlib import Path

SECTIONS = ("background", "intuition", "code", "quiz")
PRE_INLINE_TAGS = {"code", "span", "b", "strong", "em", "i", "mark", "a", "br"}
BOX_DRAWING = re.compile("[─-╿]")
ASCII_BOX = re.compile(r"\+-{3,}\+|\|\s{2,}\S.*\s{2,}\|")
NAME = re.compile(r"^\d{4}-\d{2}-\d{2}-[a-z0-9]+(-[a-z0-9]+)*\.html$")
REMOTE_TAG = re.compile(
    r"<(script|link|img|iframe|source|video|audio)\b[^>]*"
    r"\b(src|href)\s*=\s*[\"']?(https?:)?//", re.I)
REMOTE_CSS = re.compile(r"@import|url\(\s*[\"']?(https?:)?//", re.I)
EM_DASH = "—"


class Page(HTMLParser):
    """Collects, in one pass, what the checks below need."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids, self.toc_links, self.pre_bad_tags = set(), set(), set()
        self.lang, self.viewport, self.quiz_text = "", False, None
        self.pre_text, self.prose = [], []
        self._pre = self._code = self._skip = 0
        self._nav = self._quiz = False

    def handle_starttag(self, tag, attrs):
        attr = {k: v or "" for k, v in attrs}
        if attr.get("id"):
            self.ids.add(attr["id"])
        if self._pre and tag not in PRE_INLINE_TAGS:
            self.pre_bad_tags.add(tag)
        handler = getattr(self, "_open_" + tag, None)
        if handler:
            handler(attr)

    def handle_endtag(self, tag):
        if tag == "pre":
            self._pre = max(0, self._pre - 1)
        elif tag == "code":
            self._code = max(0, self._code - 1)
        elif tag in ("script", "style"):
            self._skip, self._quiz = max(0, self._skip - 1), False
        elif tag == "nav":
            self._nav = False

    def handle_data(self, data):
        if self._quiz:
            self.quiz_text = (self.quiz_text or "") + data
        elif self._skip:
            return
        elif self._pre:
            self.pre_text.append(data)
        elif not self._code:
            self.prose.append(data)

    def _open_html(self, attr):
        self.lang = attr.get("lang", "").strip()

    def _open_meta(self, attr):
        if attr.get("name", "").lower() == "viewport":
            self.viewport = True

    def _open_nav(self, _attr):
        self._nav = True

    def _open_a(self, attr):
        href = attr.get("href", "")
        if self._nav and href.startswith("#"):
            self.toc_links.add(href[1:])

    def _open_pre(self, _attr):
        self._pre += 1

    def _open_code(self, _attr):
        self._code += 1

    def _open_style(self, _attr):
        self._skip += 1

    def _open_script(self, attr):
        self._skip += 1
        self._quiz = attr.get("id") == "quiz-data"


def check_name(path):
    if NAME.match(path.name):
        return [("PASS", "name", path.name)]
    return [("FAIL", "name", f"{path.name} must be YYYY-MM-DD-<slug>.html")]


def check_location(path):
    try:
        out = subprocess.run(
            ["git", "-C", str(path.parent), "rev-parse",
             "--is-inside-work-tree"],
            capture_output=True, text=True, check=False).stdout.strip()
    except OSError:
        return [("WARN", "location", "git not found, location unchecked")]
    if out == "true":
        return [("FAIL", "location", "file sits inside a git work tree")]
    return [("PASS", "location", "outside any git work tree")]


def check_self_contained(src):
    hits = REMOTE_TAG.findall(src) + REMOTE_CSS.findall(src)
    if hits:
        return [("FAIL", "self-contained", f"{len(hits)} remote resource(s)")]
    return [("PASS", "self-contained", "no remote script, style or media")]


def check_head(page):
    out = []
    if not page.lang:
        out.append(("FAIL", "lang", "<html> has no lang attribute"))
    if not page.viewport:
        out.append(("FAIL", "viewport", "no viewport meta"))
    return out or [("PASS", "head", f"lang={page.lang}, viewport set")]


def check_sections(page):
    missing = [s for s in SECTIONS if s not in page.ids]
    if missing:
        return [("FAIL", "sections", "missing id(s): " + ", ".join(missing))]
    unlinked = [s for s in SECTIONS if s not in page.toc_links]
    if unlinked:
        return [("FAIL", "toc", "<nav> lacks link(s) to: "
                 + ", ".join(unlinked))]
    return [("PASS", "sections", "4 sections, all linked from the TOC")]


def question_problems(index, question):
    text = question.get("q", "") if isinstance(question, dict) else ""
    if not str(text).strip():
        return [f"Q{index} has no text"]
    options = question.get("options")
    if not isinstance(options, list) or len(options) < 3:
        return [f"Q{index} needs 3 options or more"]
    out = []
    right = [o for o in options
             if isinstance(o, dict) and o.get("correct") is True]
    if len(right) != 1:
        out.append(f"Q{index} needs exactly one correct option")
    for number, option in enumerate(options, 1):
        filled = isinstance(option, dict) and all(
            str(option.get(k, "")).strip() for k in ("text", "why"))
        if not filled:
            out.append(f"Q{index} option {number} lacks text or why")
    return out


def load_quiz(page):
    try:
        quiz = json.loads(page.quiz_text or "")
    except ValueError as err:
        return None, f"quiz-data is missing or not JSON ({err})"
    if not isinstance(quiz, list) or len(quiz) != 5:
        count = len(quiz) if isinstance(quiz, list) else "not a list"
        return None, f"want 5 questions, got {count}"
    return quiz, None


def check_quiz(page):
    quiz, error = load_quiz(page)
    if error:
        return [("FAIL", "quiz", error)]
    problems = [p for i, q in enumerate(quiz, 1)
                for p in question_problems(i, q)]
    if problems:
        return [("FAIL", "quiz", "; ".join(problems))]
    return [("PASS", "quiz", "5 questions, one right answer each, explained")]


def quiz_strings(page):
    quiz, error = load_quiz(page)
    if error:
        return []
    out = []
    for question in quiz:
        if isinstance(question, dict):
            out.append(str(question.get("q", "")))
            for option in question.get("options") or []:
                if isinstance(option, dict):
                    out += [str(option.get("text", "")),
                            str(option.get("why", ""))]
    return out


def check_code_blocks(page):
    out = []
    if page.pre_bad_tags:
        tags = ", ".join(sorted(page.pre_bad_tags))
        out.append(("FAIL", "escaping",
                    f"markup <{tags}> inside <pre>: code left unescaped?"))
    text = "".join(page.pre_text)
    if BOX_DRAWING.search(text):
        out.append(("FAIL", "ascii-art", "box-drawing characters in <pre>"))
    elif ASCII_BOX.search(text):
        out.append(("WARN", "ascii-art", "a <pre> looks like an ASCII box"))
    return out or [("PASS", "code", "code blocks escaped, no ASCII diagram")]


def check_prose(page, src):
    out = []
    text = "".join(page.prose) + " ".join(quiz_strings(page))
    dashes = text.count(EM_DASH)
    if dashes:
        out.append(("FAIL", "em-dash", f"{dashes} em-dash(es) in the prose"))
    if "{{" in src:
        out.append(("FAIL", "placeholders", "template placeholder left"))
    return out or [("PASS", "prose", "no em-dash, no placeholder left")]


def run_checks(path, src, page):
    return (check_name(path) + check_location(path)
            + check_self_contained(src) + check_head(page)
            + check_sections(page) + check_quiz(page)
            + check_code_blocks(page) + check_prose(page, src))


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip())
        return 2
    path = Path(argv[1]).expanduser().resolve()
    try:
        src = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as err:
        print(f"ERROR cannot read {path}: {err}")
        return 2
    page = Page()
    page.feed(src)
    page.close()
    results = run_checks(path, src, page)
    for level, name, detail in results:
        print(f"{level} {name}: {detail}")
    failed = sum(1 for level, _, _ in results if level == "FAIL")
    print(f"{'FAIL' if failed else 'OK'}: {failed} failing check(s)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
