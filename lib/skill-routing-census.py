#!/usr/bin/env python3
"""Deterministic census of skill-description collisions (TF-IDF cosine).

Adapted from addyosmani/agent-skills evals Tier 2. Reads every SKILL.md
under the live catalog — `~/.claude/skills/*/` plus plugin skills under
`~/.claude/plugins/cache/*/*/*/skills/*/` and the nested
`.../.claude/skills/*/` layout (override with SKILL_ROUTING_ROOTS,
colon-separated dirs, for fixtures) — extracts the `description`
frontmatter field (scalar or `|`/`>` block), tokenizes it, and scores
every pair by TF-IDF cosine. Two skills with near-identical descriptions
route the same prompt to both: a routing collision, not a naming clash.

Report: `skills with description: N`, the top 10 pairs, then a WARN line
per pair >= SKILL_ROUTING_WARN (default 0.50) and a FAIL line per pair
>= SKILL_ROUTING_FAIL (default 0.75). Exit 1 iff any pair reached FAIL.
"""
import collections
import glob
import itertools
import math
import os
import re
import sys

DEFAULT_ROOTS = ["~/.claude/skills", "~/.claude/plugins/cache"]
ROOT_SUFFIXES = [
    "*/SKILL.md",
    "*/*/*/skills/*/SKILL.md",
    "*/*/*/.claude/skills/*/SKILL.md",
]
STOPWORDS = set(
    "a an the and or of to in on for with use when you your this that is are "
    "be it as by from at into not no if then use using used uses skill "
    "skills user users project projects file files code work".split()
)
BLOCK_MARKERS = ("|", ">", "|-", ">-", "|+", ">+")
WARN_DEFAULT = 0.50
FAIL_DEFAULT = 0.75


def resolve_roots():
    """Root dirs: SKILL_ROUTING_ROOTS override, else the live catalog."""
    override = os.environ.get("SKILL_ROUTING_ROOTS")
    return override.split(":") if override else DEFAULT_ROOTS


def discover_paths(roots):
    """SKILL.md paths across all roots/suffixes, sorted for determinism."""
    paths = []
    for root in roots:
        expanded = os.path.expanduser(root)
        for suffix in ROOT_SUFFIXES:
            paths.extend(sorted(glob.glob(os.path.join(expanded, suffix))))
    return paths


def dedup_by_skill_name(paths):
    """name (skill dir) -> path; first path wins (symlinks pre-resolved)."""
    by_name = {}
    for path in paths:
        name = os.path.basename(os.path.dirname(path))
        by_name.setdefault(name, path)
    return by_name


def _frontmatter(text):
    """Raw text between the two leading `---` delimiters, or None."""
    match = re.search(r"^---\r?\n(.*?)\r?\n---", text, re.S)
    return match.group(1) if match else None


def _strip_quotes(value):
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
        return value[1:-1]
    return value


def _block_text(lines, start):
    """Join a YAML block-scalar's indented continuation lines.

    A blank line inside a block scalar does NOT end it (YAML compares
    indentation only against non-blank lines) — only a line back at the
    frontmatter's column-0 (the next key) does.
    """
    collected = []
    for line in lines[start:]:
        if line.strip() == "" or line.startswith((" ", "\t")):
            collected.append(line.strip())
        else:
            break
    return " ".join(part for part in collected if part)


def extract_description(path):
    """The `description:` frontmatter value (scalar or block), or None."""
    try:
        with open(path, encoding="utf-8", errors="ignore") as handle:
            text = handle.read()
    except OSError:
        return None
    fm = _frontmatter(text)
    if fm is None:
        return None
    lines = fm.split("\n")
    for i, line in enumerate(lines):
        match = re.match(r"^description:\s*(.*)$", line)
        if not match:
            continue
        value = match.group(1).strip()
        if value in BLOCK_MARKERS:
            return _block_text(lines, i + 1) or None
        return _strip_quotes(value) or None
    return None


def stem(word):
    """Strip a trailing s/es/ed/ing suffix from a long-enough word."""
    for suffix in ("ing", "ed", "es", "s"):
        if len(word) > 4 and word.endswith(suffix):
            return word[: -len(suffix)]
    return word


def tokenize(text):
    """Lowercase, keep [a-z][a-z0-9-]+ words, drop stopwords/short, stem."""
    words = re.findall(r"[a-z][a-z0-9-]+", text.lower())
    return [stem(w) for w in words if w not in STOPWORDS and len(w) > 2]


def build_docs(paths_by_name):
    """name -> Counter(tokens), for every skill with a non-empty description."""
    docs = {}
    for name, path in paths_by_name.items():
        desc = extract_description(path)
        if not desc:
            continue
        tokens = tokenize(desc)
        if tokens:
            docs[name] = collections.Counter(tokens)
    return docs


def _document_frequencies(docs):
    df = collections.Counter()
    for counter in docs.values():
        for token in counter:
            df[token] += 1
    return df


def _tfidf_vector(counter, doc_count, df):
    """(1 + log tf) * log(N/df), L2-normalized."""
    weights = {
        token: (1 + math.log(n)) * math.log(doc_count / df[token])
        for token, n in counter.items()
    }
    norm = math.sqrt(sum(w * w for w in weights.values())) or 1
    return {token: w / norm for token, w in weights.items()}


def tfidf_vectors(docs):
    """name -> {token: TF-IDF weight}, L2-normalized."""
    doc_count = len(docs)
    df = _document_frequencies(docs)
    return {name: _tfidf_vector(c, doc_count, df) for name, c in docs.items()}


def cosine(vec_a, vec_b):
    return sum(weight * vec_b.get(token, 0) for token, weight in vec_a.items())


def score_pairs(vectors):
    """[(score, a, b), ...] over every pair, sorted by score descending."""
    pairs = [
        (cosine(vectors[a], vectors[b]), a, b)
        for a, b in itertools.combinations(sorted(vectors), 2)
    ]
    pairs.sort(reverse=True)
    return pairs


def _thresholds():
    warn = float(os.environ.get("SKILL_ROUTING_WARN", WARN_DEFAULT))
    fail = float(os.environ.get("SKILL_ROUTING_FAIL", FAIL_DEFAULT))
    return warn, fail


def report(doc_count, pairs):
    """Print the census report; return True iff a pair reached FAIL."""
    warn, fail = _thresholds()
    print(f"skills with description: {doc_count}")
    for score, a, b in pairs[:10]:
        print(f"{score:.2f}  {a}  ~  {b}")
    failed = False
    for score, a, b in pairs:
        if score >= fail:
            print(f"FAIL {score:.2f}  {a}  ~  {b}")
            failed = True
        elif score >= warn:
            print(f"WARN {score:.2f}  {a}  ~  {b}")
    return failed


def main():
    by_name = dedup_by_skill_name(discover_paths(resolve_roots()))
    docs = build_docs(by_name)
    vectors = tfidf_vectors(docs)
    failed = report(len(docs), score_pairs(vectors))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
