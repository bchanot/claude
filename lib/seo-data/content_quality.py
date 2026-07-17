#!/usr/bin/env python3
"""Deterministic filler / AI-slop content-quality scorer. Stdlib only.

Adapted from claude-seo (github.com/AgriciDaniel/claude-seo, MIT),
content_quality.py — rewritten to the lib/seo-data fail-open contract.

Scores a block of text against three regex/word-list heuristics: padding
"filler" phrases (QRG §4.6), LLM-typical phrasings ("AI-pattern" list),
and a measured information density (entities + numbers per token). 100%
deterministic — no LLM call, no network.

ADVISORY, NOT A VERDICT. This never claims "this text is AI-written" —
modern generative tools can pass every heuristic here, and human writers
use some of these phrases too. A low overall_quality or a filler/
ai-patterns flag is a candidate for human review, nothing more. In
geo-analyzer's STEP 8 (Content Shape for AI) it is ONE measured input
that INFORMS the axis, which stays an LLM judgement (30/70, Definition
Lead) — never a replacement for it, and never auto-filed as a finding on
its own.

Attribution: the AI-pattern list draws from the Wikipedia "AI Cleanup"
project's catalogue of LLM-typical phrasings (CC BY-SA 4.0), the same
list claude-seo cites.

Envelope (see `_cli`)::

    {"status": "ok", "source": "content_quality",
     "filler_score": 0..100,        # higher = more filler-like
     "ai_pattern_score": 0..100,    # higher = more AI-pattern hits
     "information_density": 0.0..1.0,
     "overall_quality": 0..100,     # composite, higher is better
     "flags": ["filler", "ai-patterns", "low-density", "repetitive"],
     "matches": {"filler": [...], "ai_patterns": [...]}}
    {"status": "degraded", "reason": "empty_input" | "<why>"}
"""
import argparse, json, re, sys
from collections import Counter
from typing import Iterable

# Padding / filler phrases QRG §4.6 flags as "little-to-no value". The
# lists are the value of this module — kept intact from the source, not
# trimmed.
_FILLER_PHRASES = (
    "it's important to note that",
    "in this article, we'll explore",
    "in this article we will explore",
    "in today's fast-paced world",
    "in today's digital age",
    "in today's competitive landscape",
    "needless to say",
    "at the end of the day",
    "when it comes to",
    "when all is said and done",
    "in the realm of",
    "in the world of",
    "the bottom line is",
    "without further ado",
    "first and foremost",
    "last but not least",
    "for what it's worth",
    "it goes without saying",
    "as we all know",
    "the truth is that",
    "the fact of the matter is",
    "more often than not",
    "let's dive in",
    "let's dive into",
    "let's take a closer look",
    "let's take a deeper look",
)

# LLM-typical phrasings (Wikipedia AI Cleanup catalogue, CC BY-SA 4.0;
# also used by claude-seo, MIT). Conservative: only phrases that
# disproportionately appear in LLM output. Adding to this list should
# require corpus evidence, not intuition.
_AI_PATTERNS = (
    "delve into",
    "delve deeper into",
    "in the ever-evolving",
    "ever-evolving landscape",
    "ever-changing landscape",
    "in the dynamic landscape",
    "navigating the",
    "navigate the complexities",
    "tapestry of",
    "rich tapestry",
    "intricate tapestry",
    "embark on a journey",
    "embarking on this",
    "a testament to",
    "a beacon of",
    "the cornerstone of",
    "a cornerstone of",
    "at the heart of",
    "at its core",
    "in essence,",
    "in conclusion,",
    "ultimately,",
    "moreover,",
    "furthermore,",
    "however, it's worth noting",
    "it's worth noting that",
    "by leveraging",
    "leverage the power of",
    "leveraging the power of",
    "harness the power of",
    "unlock the potential",
    "unlock the full potential",
    "the realm of possibilities",
    "open up a world of",
    "a world of possibilities",
    "elevate your",
    "transform your",
    "revolutionize the way",
    "game-changer",
    "game-changing",
    "cutting-edge",
    "state-of-the-art",
    "in summary,",
    "to summarize,",
    "to put it simply,",
    "in a nutshell,",
)

_TOKEN_RE = re.compile(r"[A-Za-z][A-Za-z'\-]*")
_NUMBER_RE = re.compile(r"\b\d+(?:[.,]\d+)?(?:%|st|nd|rd|th)?\b")
# Capitalised multi-word names: rough proper-noun heuristic. Two or more
# capitalised tokens in a row count as one entity.
_ENTITY_RE = re.compile(r"\b(?:[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)\b")


def _count_phrase_hits(text: str, patterns: Iterable[str]) -> list:
    """Patterns that appear at least once in text (case-insensitive)."""
    lowered = text.lower()
    return [p for p in patterns if p in lowered]


def _repetition_score(tokens):
    """Bigram repetition: fraction of bigrams that recur more than once."""
    if len(tokens) < 4:
        return 0.0
    bigrams = [tokens[i] + " " + tokens[i + 1] for i in range(len(tokens) - 1)]
    counts = Counter(bigrams)
    repeated = sum(1 for v in counts.values() if v > 1)
    return repeated / max(1, len(counts))


def analyse(text):
    """Score text against the filler / AI-pattern / density / repetition
    heuristics. Advisory only — see module docstring."""
    tokens = [t.lower() for t in _TOKEN_RE.findall(text)]
    n_tokens = len(tokens)

    filler_hits = _count_phrase_hits(text, _FILLER_PHRASES)
    ai_hits = _count_phrase_hits(text, _AI_PATTERNS)

    # Density: entities + numbers per 100 tokens. A high-density article
    # (case studies, data journalism) lands at ~5+; generic filler <2.
    entities = len(_ENTITY_RE.findall(text))
    numbers = len(_NUMBER_RE.findall(text))
    density_per_100 = (entities + numbers) * 100.0 / max(1, n_tokens)
    information_density = min(1.0, density_per_100 / 10.0)

    rep_score = int(round(_repetition_score(tokens) * 100))

    # Scale to per-1000 tokens so the score is comparable across lengths.
    scale = max(1.0, n_tokens / 1000.0)
    filler_score = min(100, int(round(len(filler_hits) / scale * 25)))
    ai_pattern_score = min(100, int(round(len(ai_hits) / scale * 15)))

    flags = []
    if filler_score >= 50:
        flags.append("filler")
    if ai_pattern_score >= 40:
        flags.append("ai-patterns")
    if information_density < 0.20:
        flags.append("low-density")
    if rep_score >= 30:
        flags.append("repetitive")

    # Composite: invert penalty signals, weight by impact. Same weights
    # as the source — the length bonus caps at 1000 tokens.
    overall = (
        (100 - filler_score) * 0.25
        + (100 - ai_pattern_score) * 0.25
        + information_density * 100 * 0.25
        + (100 - rep_score) * 0.15
        + min(100, n_tokens / 10.0) * 0.10
    )

    return {
        "filler_score": filler_score,
        "ai_pattern_score": ai_pattern_score,
        "information_density": round(information_density, 3),
        "overall_quality": int(round(overall)),
        "flags": flags,
        "matches": {"filler": filler_hits, "ai_patterns": ai_hits},
    }


def _build_parser():
    p = argparse.ArgumentParser(
        description="Deterministic filler / AI-slop content-quality scorer."
    )
    p.add_argument("--store", default=None)   # accepted+ignored (dispatch)
    p.add_argument(
        "--file", default="-",
        help="Path to a text file, or - for stdin (default -).",
    )
    return p


def _read_input(path):
    """Read the analysis target from stdin ('-'/omitted) or a plain file.
    Plain `open()` only — no pathlib, to stay stdlib-minimal per contract."""
    if path in (None, "-"):
        return sys.stdin.read()
    return open(path, encoding="utf-8", errors="replace").read()


def _cli():
    try:
        args = _build_parser().parse_args()
        text = _read_input(args.file)
        if not text or not text.strip():
            print(json.dumps({"status": "degraded", "reason": "empty_input"}))
            return
        envelope = {"status": "ok", "source": "content_quality"}
        envelope.update(analyse(text))
        print(json.dumps(envelope, indent=2))
    except SystemExit as e:
        if e.code not in (0, None):
            print(json.dumps({"status": "error", "reason": "bad_usage"}))
        raise
    except Exception as e:
        # Fail-open: a missing --file, an unreadable/binary file, or any
        # other unexpected error degrades rather than crashing the caller.
        print(json.dumps({"status": "degraded", "reason": str(e)}))


if __name__ == "__main__":
    _cli()
