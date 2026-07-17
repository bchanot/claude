#!/usr/bin/env python3
"""Deterministic /20 scoring from a findings list. Stdlib only.

/harden has a real scale (SKILL.md:435 — Critique -15, Haute -8, Moyenne -3,
Basse -1, clamp [0,100]). /seo has none: every axis is felt, not computed, so
two runs over identical code can produce different scores. That is a
credibility problem on its own, and /client-handover gates on 17/20 — a
wobbling number makes the gate arbitrary. H2 sharpens it further: now that
drift reports what actually changed, a score moving on its own is visibly
noise.

The split is the point. The LLM keeps the irreducible judgement — WHICH
findings exist and how severe each is. The arithmetic stops being judgement:
same findings in, same score out. Same principle as grouping cannibalisation
rows in the engine rather than asking a model to add up 1000 of them.

Scale is /harden's, /5 into /20, so the whole skill family speaks one
vocabulary.
"""
import argparse, json, sys

PENALTY = {"critique": 15, "haute": 8, "moyenne": 3, "basse": 1}

# STEP 9 weights. FULL = 7 axes, LOCAL = 4 (off-page/social/competitive are
# not audited at that depth).
WEIGHTS = {
    ("FULL", "local"):    {"technical": .20, "on-page": .20, "seo-local": .25,
                           "off-page": .10, "social": .10, "competitive": .05,
                           "legal": .10},
    ("FULL", "national"): {"technical": .30, "on-page": .30, "seo-local": .05,
                           "off-page": .15, "social": .05, "competitive": .10,
                           "legal": .05},
    ("LOCAL", "local"):   {"technical": .25, "on-page": .35, "seo-local": .20,
                           "legal": .20},
    ("LOCAL", "national"):{"technical": .35, "on-page": .45, "seo-local": .05,
                           "legal": .15},
}

def _axis_score(findings):
    """100 - Σ penalties, clamped, then /5 → /20. Prevalence shifts severity
    ONE step, never invents one: a finding on 1 of 12 sampled pages is not the
    same defect as one on 12 of 12, and pretending otherwise is what made the
    old scores unreproducible."""
    total = 0
    for f in findings:
        sev = str(f.get("severity", "")).lower()
        if sev not in PENALTY:
            raise ValueError("unknown severity: %r" % f.get("severity"))
        order = ["basse", "moyenne", "haute", "critique"]
        i = order.index(sev)
        aff, samp = f.get("affected"), f.get("sampled")
        if isinstance(aff, int) and isinstance(samp, int) and samp > 0:
            ratio = aff / samp
            if ratio >= 0.5:
                i = min(i + 1, len(order) - 1)      # widespread → escalate
            elif aff <= 1:
                i = max(i - 1, 0)                   # isolated → de-escalate
        total += PENALTY[order[i]]
    return round(max(0, 100 - total) / 5.0, 1)

def score(payload):
    depth = str(payload.get("depth", "FULL")).upper()
    profile = str(payload.get("profile", "local")).lower()
    key = (depth, profile)
    if key not in WEIGHTS:
        return {"status": "error", "reason": "unknown depth/profile: %s/%s"
                                             % (depth, profile)}
    weights, axes_in = WEIGHTS[key], payload.get("axes", {})
    scored, na = {}, []
    for axis, w in weights.items():
        a = axes_in.get(axis)
        if a is None or str(a.get("status", "")).lower() == "na":
            na.append(axis)                          # N/A is not a zero
            continue
        try:
            s = _axis_score(a.get("findings", []))
        except ValueError as e:
            return {"status": "error", "reason": str(e)}
        scored[axis] = {"score_20": s, "weight": w,
                        "findings": len(a.get("findings", []))}
    if not scored:
        return {"status": "degraded", "reason": "no_axis_scored"}
    # Renormalise over what was actually measured. R2 mandates this for a
    # client-rendered on-page axis and left it to the model to do by hand.
    live = sum(v["weight"] for v in scored.values())
    for v in scored.values():
        v["weight_renormalised"] = round(v["weight"] / live, 4)
    glob = sum(v["score_20"] * v["weight"] / live for v in scored.values())
    return {"status": "ok", "source": "score", "depth": depth,
            "profile": profile, "axes": scored, "na": sorted(na),
            "weights_renormalised": round(live, 4) != 1.0,
            "global_20": round(glob, 1)}

def _cli():
    try:
        p = argparse.ArgumentParser()
        p.add_argument("--findings", default="-", help="JSON path, or - for stdin")
        p.add_argument("--store", default=None)      # accepted+ignored
        args = p.parse_args()
        raw = sys.stdin.read() if args.findings == "-" else \
            open(args.findings, encoding="utf-8").read()
        print(json.dumps(score(json.loads(raw)), indent=2))
    except SystemExit as e:
        if e.code not in (0, None):
            print(json.dumps({"status": "error", "reason": "bad_usage"}))
        raise
    except Exception:
        # Unlike the fetch verbs this is pure arithmetic: a degrade here means
        # malformed input, never a network fact.
        print(json.dumps({"status": "error", "reason": "bad_findings_json"}))

if __name__ == "__main__":
    _cli()
