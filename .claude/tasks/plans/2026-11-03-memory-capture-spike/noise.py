"""Offline noise measurement of the memory mod capture rule.

1:1 port of failureLine / normalize / redact of
mods/memory/hooks/register.ts. Read-only, stdout only.
Run: python3 -I noise.py [--dir D] [--days 14] [--samples 30] [--seed N]
"""
import argparse
import json
import os
import random
import re
import time
from collections import namedtuple

DEFAULT_DIR = os.path.expanduser(
    "~/.claude/projects/-home-bchanot-Documents-claude")
MAX_REGEX_INPUT = 65536
MAX_LINE = 300
MAX_COMMAND = 300
LINE_WINDOW = 1000
A = re.ASCII  # JS \w \d \b are ASCII-only

# Secret-shaped sources are assembled from parts on purpose.
PEM = "-----"
PEM_KIND = "(?:[A-Z]+ )?PRIVATE KEY"
REDACTIONS = [
    (re.compile(r"\b([A-Za-z_]{0,60}(?:TOKEN|API_KEY|SECRET|PASSWORD|"
                r"PASSWD)[A-Za-z_]{0,60})=\S+", re.I | A), r"\1=<redacted>"),
    (re.compile("sk_" + "live_[0-9A-Za-z]{10,}"), "<redacted:stripe>"),
    (re.compile("AK" + "IA[0-9A-Z]{16}"), "<redacted:aws>"),
    (re.compile("gh[pousr]" + "_[A-Za-z0-9]{30,}"), "<redacted:github>"),
    (re.compile("xox" + "[abprs]-[A-Za-z0-9-]{10,}"), "<redacted:slack>"),
    (re.compile(r"SG\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}"),
     "<redacted:sendgrid>"),
    (re.compile("sb_" + "secret_[A-Za-z0-9_-]{10,}"), "<redacted:supabase>"),
    (re.compile(f"{PEM}BEGIN {PEM_KIND}{PEM}.*?(?:{PEM}END {PEM_KIND}{PEM}"
                r"|\Z)", re.S), "<redacted:private-key>"),
    (re.compile(r"\bBearer\s+[A-Za-z0-9._~+/=-]{8,}", A),
     "Bearer <redacted>"),
    (re.compile(r"([a-z][a-z0-9+.-]{0,30}://)[^\s/@:]+:[^\s/@]+@", re.I),
     r"\1<redacted>@"),
]
HEX_RUN = re.compile(r"\b[0-9a-f]{7,}\b", A)
PATH = re.compile(r"(?:\.{0,2}/)?[\w.-]{1,200}(?:/[\w.-]{1,200}){1,30}", A)
EXIT_CODE = re.compile(r"^Exit code \d+", A)
RTK_TRAILER = re.compile(
    r"\s*\[(?:\+\d+ hidden|full output): rtk recall [0-9a-f]+\]\Z")

Entry = namedtuple("Entry", "key line command agent code tool")
Pair = namedtuple("Pair", "command text is_error")


def redact(text):
    out = text[:MAX_REGEX_INPUT]
    for pattern, mask in REDACTIONS:
        out = pattern.sub(mask, out)
    return out


def normalize(line):
    out = HEX_RUN.sub("<hex>", line.lower())
    out = PATH.sub("<path>", out)
    out = re.sub(r"\d+", "#", out, flags=A)
    return re.sub(r"\s+", " ", out).strip()


def has_letter(line):
    letters = re.sub(r"<path>|<hex>|#", "", normalize(line))
    return any(c.isalpha() for c in letters)


def clean_lines(text, strip_trailer):
    lines = []
    for raw in text.split("\n"):
        line = raw[-LINE_WINDOW:]
        if strip_trailer:
            line = RTK_TRAILER.sub("", line)
        line = line.strip()
        if line != "":
            lines.append(line)
    return lines


def count_trailer_pick(text, stats):
    """Counts a pick that, without stripping, would be a trailer line."""
    raw = clean_lines(text, False)
    if len(raw) >= 2 and RTK_TRAILER.search(raw[-1]) and has_letter(raw[-1]):
        stats["rtk_would_pick"] += 1


def failure_line(text, stats):
    """The distinctive line, or None; stats counts the two drops."""
    if not EXIT_CODE.match(text):
        return None
    count_trailer_pick(text, stats)
    lines = clean_lines(text, True)
    if len(lines) < 2:
        return None
    line = lines[-1][:MAX_LINE]
    if not has_letter(line):
        stats["letterless"] += 1
        return None
    return line


PROBES = {"grep", "egrep", "fgrep", "rg", "test", "diff", "cmp", "[", "[["}
SEGMENT_SPLIT = re.compile(r";|&&|\|\||\||\n")
ERRORISH = re.compile(
    r"error|fatal|cannot|can't|no such|not found|denied|failed|failure|"
    r"unexpected|invalid|exception|traceback|panic|usage:|SC\d{4}|> \d+|"
    r"assert", re.I)
TIGHTEN_RULES = ("probe", "errorish")


def last_word(command):
    """First word of the last segment, env prefixes and bin dir dropped."""
    parts = [p.strip() for p in SEGMENT_SPLIT.split(command) if p.strip()]
    words = parts[-1].split() if parts else []
    while words and re.match(r"[A-Za-z_]\w*=", words[0]):
        words.pop(0)
    if not words:
        return ""
    return re.sub(r"^/(?:usr/)?bin/", "", words[0])


def survives(entry, rules):
    if "probe" in rules and entry.code == 1 and entry.tool in PROBES:
        return False
    return "errorish" not in rules or ERRORISH.search(entry.line) is not None


def build_entry(pair, agent, stats):
    red = redact(pair.text[-MAX_REGEX_INPUT:])
    line = failure_line(red, stats)
    if line is None:
        return None
    full = redact(pair.command[:MAX_REGEX_INPUT])
    code = int(EXIT_CODE.match(red).group(0).split()[2])
    return Entry(normalize(line), line, full[:MAX_COMMAND], agent, code,
                 last_word(full))


def result_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "".join(b.get("text", "") for b in content
                       if isinstance(b, dict) and b.get("type") == "text")
    return ""


def blocks_of(record):
    content = (record.get("message") or {}).get("content")
    if not isinstance(content, list):
        return []
    return [b for b in content if isinstance(b, dict)]


def pairs_of(path):
    """Bash tool_use paired with its tool_result by tool_use_id."""
    calls, pairs = {}, []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            try:
                record = json.loads(raw)
            except ValueError:
                continue
            for b in blocks_of(record):
                if b.get("type") == "tool_use" and b.get("name") == "Bash":
                    cmd = (b.get("input") or {}).get("command")
                    calls[b.get("id")] = str(cmd or "")
                elif b.get("type") == "tool_result":
                    cid = b.get("tool_use_id")
                    if cid in calls:
                        pairs.append(Pair(calls[cid],
                                          result_text(b.get("content")),
                                          b.get("is_error") is True))
    return pairs


def recent(path, cutoff):
    return os.path.getmtime(path) >= cutoff


def find_files(root, days):
    """(session id, is_agent, path) of main and sub-agent transcripts."""
    cutoff = time.time() - days * 86400
    found = []
    for name in sorted(os.listdir(root)):
        full = os.path.join(root, name)
        if name.endswith(".jsonl") and recent(full, cutoff):
            found.append((name[:-6], False, full))
        sub = os.path.join(full, "subagents")
        if os.path.isdir(sub):
            for f in sorted(os.listdir(sub)):
                p = os.path.join(sub, f)
                if f.endswith(".jsonl") and recent(p, cutoff):
                    found.append((name, True, p))
    return found


def new_session():
    return {"before": {False: 0, True: 0}, "after": {False: 0, True: 0},
            "seen": set(), "kept": []}


def measure(files, stats, rules=()):
    """Per session counts; dedupe by key pooled over main and sub-agents."""
    sessions = {}
    for sid, agent, path in sorted(files, key=lambda f: f[1]):
        s = sessions.setdefault(sid, new_session())
        for pair in pairs_of(path):
            if not pair.is_error:
                continue
            entry = build_entry(pair, agent, stats)
            if entry is None or not survives(entry, rules):
                continue
            s["before"][agent] += 1
            if entry.key not in s["seen"]:
                s["seen"].add(entry.key)
                s["after"][agent] += 1
                s["kept"].append(entry)
    return sessions


def print_counts(sessions, stats):
    tot = {k: {False: 0, True: 0} for k in ("before", "after")}
    print("session   main(before/after)  sub(before/after)")
    for sid, s in sorted(sessions.items()):
        print(f"{sid[:8]}  {s['before'][False]:>6}/{s['after'][False]:<6}"
              f"  {s['before'][True]:>6}/{s['after'][True]:<6}")
        for k in tot:
            for agent in (False, True):
                tot[k][agent] += s[k][agent]
    for agent, label in ((False, "main loop"), (True, "sub-agents")):
        print(f"TOTAL {label}: before dedupe {tot['before'][agent]}, "
              f"after dedupe {tot['after'][agent]}")
    print(f"rtk-trailer picks without stripping: {stats['rtk_would_pick']}")
    print("rtk-trailer picks after stripping: 0 (trailer removed per line)")
    print(f"letterless dropped: {stats['letterless']}")


def print_samples(sessions, count, seed):
    kept = [e for s in sessions.values() for e in s["kept"]]
    rng = random.Random(seed)
    picked = rng.sample(kept, min(count, len(kept)))
    print(f"\n{len(picked)} samples of {len(kept)} captured entries")
    for e in picked:
        cmd = redact(e.command)[:200].replace("\n", " ")
        who = "sub" if e.agent else "main"
        print(f"- [{who}] key: {redact(e.key)}\n  line: {redact(e.line)}"
              f"\n  cmd: {cmd}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=DEFAULT_DIR)
    ap.add_argument("--days", type=int, default=14)
    ap.add_argument("--samples", type=int, default=30)
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--tighten", action="append", default=[],
                    choices=TIGHTEN_RULES)
    args = ap.parse_args()
    stats = {"letterless": 0, "rtk_would_pick": 0}
    files = find_files(args.dir, args.days)
    print(f"files: {len(files)} ({sum(1 for f in files if f[1])} sub-agent)")
    sessions = measure(files, stats, args.tighten)
    print_counts(sessions, stats)
    print_samples(sessions, args.samples, args.seed)


if __name__ == "__main__":
    main()
