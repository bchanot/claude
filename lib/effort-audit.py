#!/usr/bin/env python3
"""Sum output/thinking/cache tokens per (scope, model, effort) over Claude Code
transcripts. scope = main (session jsonl) | sub (subagents/*.jsonl or
isSidechain records). Read-only. Usage: effort-audit.py [projects-root]"""
import collections
import glob
import json
import os
import sys

# Weights relative to input price.
WEIGHTS = {"in": 1.0, "cc": 1.25, "cr": 0.1, "out": 5.0}
FIELDS = ("in", "cc", "cr", "out", "think")


def usage_row(usage):
    """Map one API usage block to the five counted fields."""
    details = usage.get("output_tokens_details") or {}
    return {
        "in": usage.get("input_tokens", 0) or 0,
        "cc": usage.get("cache_creation_input_tokens", 0) or 0,
        "cr": usage.get("cache_read_input_tokens", 0) or 0,
        "out": usage.get("output_tokens", 0) or 0,
        "think": details.get("thinking_tokens", 0) or 0,
    }


def scan(path, scope, agg):
    """Add every assistant record of one transcript to agg, once per
    message id (the transcript writes one record per content block,
    all sharing the same id and usage)."""
    seen = set()
    with open(path, errors="ignore") as handle:
        for line in handle:
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            msg = rec.get("message") or {}
            if rec.get("type") != "assistant" or not msg.get("usage"):
                continue
            mid = msg.get("id")
            if mid in seen:
                continue
            seen.add(mid)
            sub = scope == "sub" or bool(rec.get("isSidechain"))
            key = ("sub" if sub else "main",
                   str(msg.get("model", "?")).replace("claude-", ""),
                   str(rec.get("effort") or "?"))
            row = usage_row(msg["usage"])
            agg[key]["msgs"] += 1
            for field in FIELDS:
                agg[key][field] += row[field]


def weighted(counter):
    return sum(counter[f] * WEIGHTS[f] for f in WEIGHTS)


def report(agg):
    """Print the per-key table, then the main/sub split and the thinking
    share."""
    total = collections.Counter()
    for counter in agg.values():
        total.update(counter)
    total_w = weighted(total) or 1
    print(f"{'scope':5} {'model':22} {'effort':7} {'msgs':>6} {'think/msg':>9} "
          f"{'think_tok':>10} {'out_tok':>10} {'cache_read':>12} {'%wcost':>7}")
    ranked = sorted(agg.items(), key=lambda kv: -weighted(kv[1]))
    for (scope, model, effort), c in ranked:
        per_msg = c["think"] / max(c["msgs"], 1)
        print(f"{scope:5} {model:22} {effort:7} {c['msgs']:6d} "
              f"{per_msg:9.0f} {c['think']:10d} {c['out']:10d} "
              f"{c['cr']:12d} {100 * weighted(c) / total_w:6.1f}%")
    by_scope = collections.defaultdict(collections.Counter)
    for (scope, _, _), c in agg.items():
        by_scope[scope].update(c)
    for scope, c in by_scope.items():
        print(f"  {scope:5} weighted-cost "
              f"{100 * weighted(c) / total_w:5.1f}%  thinking "
              f"{100 * c['think'] / max(total['think'], 1):5.1f}%  "
              f"requests {c['msgs']}")
    print(f"  thinking = "
          f"{100 * total['think'] * WEIGHTS['out'] / total_w:.1f}% "
          f"of weighted cost; cache reads = "
          f"{100 * total['cr'] * WEIGHTS['cr'] / total_w:.1f}%")


def main():
    root = os.path.expanduser(
        sys.argv[1] if len(sys.argv) > 1 else "~/.claude/projects")
    agg = collections.defaultdict(collections.Counter)
    for project in sorted(glob.glob(os.path.join(root, "*"))):
        if not os.path.isdir(project):
            continue
        for path in glob.glob(os.path.join(project, "*.jsonl")):
            scan(path, "main", agg)
        sub_glob = os.path.join(project, "*", "subagents", "*.jsonl")
        for path in glob.glob(sub_glob):
            scan(path, "sub", agg)
    report(agg)


if __name__ == "__main__":
    main()
