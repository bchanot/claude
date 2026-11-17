#!/usr/bin/env python3
"""Apply run B2 blocks to a repo root.

Usage: apply.py <plan.md> <repo root> <skills|agents>
Blocks are read from the plan (### Block <name> + fenced body). Every anchor
must occur exactly once in its file; any miss aborts before writing anything.
"""
import pathlib
import re
import sys

ARROW = "→"
DASH = "—"


def read_blocks(plan):
    text = pathlib.Path(plan).read_text(encoding="utf-8")
    pattern = r"^### Block (\S+)\n```\n(.*?)```\n"
    return dict(re.findall(pattern, text, re.S | re.M))


def indent(block, width):
    pad = " " * width
    return "".join(pad + line if line.strip() else line
                   for line in block.splitlines(True))


def gate_edits(b):
    s0, s3 = b["stuck"], indent(b["stuck"], 3)
    loop_feat = "Loop decisions stay HERE, in the main loop (LRN-083). Nominal (clear\n"
    loop_bug = "   Loop decisions stay HERE, in the main loop (LRN-083). Nominal = one\n"
    ship = f"other ([[LRN-095]]).\n\n## STEP 6 {DASH} CODE REVIEW"
    init = f"([[LRN-095]]) {DASH} both run.\n\n## STEP 10 {DASH} CODE REVIEW"
    item6 = "   the include's; loop decisions stay in this main loop.\n"
    return [
        ("skills/feat/SKILL.md", loop_feat, s0 + "\n" + loop_feat),
        ("skills/bugfix/SKILL.md", loop_bug, s3 + "\n" + loop_bug),
        ("skills/ship-feature/SKILL.md", ship,
         ship.replace("\n\n## ", "\n\n" + s0 + "\n## ")),
        ("skills/init-project/SKILL.md", init,
         init.replace("\n\n## ", "\n\n" + s0 + "\n## ")),
        ("skills/a11y/SKILL.md", item6, item6 + s3),
        ("skills/guardrails/SKILL.md", item6, item6 + s3),
    ]


def end_edits(b):
    feat = "\nPrint summary:\n```\nFEAT COMPLETE"
    bug = "   two sentences of body).\n4. Print summary:"
    item1 = ("   commit, project convention else 50 words at most.\n"
             "2. `mcp__model-router__route")
    ho = indent(b["end-handover"], 3)
    step9 = f"## STEP 9 {DASH} FINISH\n"
    step11 = f"## STEP 11 {DASH} FINISH\n"
    audit = f"## STEP 4 {DASH} FINAL SUMMARY\n\n"
    tour = "Global summary inline, one line per project (append"
    tour_list = "2. Prints the global summary (STEP 3 format) once ALL runners returned.\n"
    tour_runner = (f"    Skip STEP 0/0b (routing) and the global summary {DASH} the dispatcher owns\n"
                   "    them. Every rule of the skill applies unchanged: max 3 iterations,\n")
    rc = f"### STEP 4 {DASH} HUMAN GATE: when to release\n"
    return [
        ("skills/feat/SKILL.md", feat, "\n" + b["end-report"] + feat),
        ("skills/bugfix/SKILL.md", bug,
         bug.replace("\n4. ", "\n" + indent(b["end-report"], 3) + "4. ")),
        ("skills/ship-feature/SKILL.md", step9, step9 + b["end-finish"] + "\n"),
        ("skills/init-project/SKILL.md", step11, step11 + b["end-finish"] + "\n"),
        ("skills/a11y/SKILL.md", item1, item1.replace("\n2. ", "\n" + ho + "2. ")),
        ("skills/guardrails/SKILL.md", item1,
         item1.replace("\n2. ", "\n" + ho + "2. ")),
        ("skills/audit-delta/SKILL.md", audit, audit + b["end-audit"] + "\n"),
        ("skills/tour/SKILL.md", tour, b["end-tour"] + "\n" + tour),
        ("skills/tour/SKILL.md", tour_list, b["tour-dispatch"]),
        ("skills/tour/SKILL.md", tour_runner, b["tour-runner"]),
        ("skills/release-candidate/SKILL.md", rc, rc + b["end-release"] + "\n"),
    ]


def skills_edits(b):
    return gate_edits(b) + end_edits(b)


def agents_edits(b):
    ver_old = ("- Advisor (when listed): at most one call, after STEP 4 and before\n"
               "  STEP 5, whatever the harness prompt schedules; absent or\n"
               f"  erroring {ARROW} proceed. Advice may send you back to a criterion: a\n")
    sa_old = (
        "- Advisor (when listed): at most one call, after STEP 4 and before\n"
        "  STEP 5 and any REPORT write, whatever the harness prompt schedules;\n"
        f"  absent or erroring {ARROW} proceed. Advice may add a finding or raise a\n"
        "  severity, cited at a file:line you read. An added finding's rule/check\n"
        "  is `advisor:<STEP 3 class>`; a raised one keeps its own line, its\n"
        "  rule/check becoming `<rule>+advisor`, so it counts once. The severity\n"
        "  is that STEP 3 class's, which overrides the STEP 2 mapping for that\n"
        "  finding only; an added finding matching no class is REPORTED as LOW,\n"
        "  and a raise matching no class changes nothing. It enters STEP 5's\n"
        "  dedup and BLOCK(n) like any other, and PROOF ends with `; advisor <n>\n"
        "  added/raised`. It never removes, lowers or waives a finding from\n"
        "  semgrep, the checklist or STEP 4.\n")
    pc_old = (
        "- Advisor (when listed): at most one call, after drafting your findings\n"
        "  and before the verdict, whatever the harness prompt schedules; absent\n"
        f"  or erroring {ARROW} proceed. Advice may add or sharpen a finding. Advice\n"
        "  alone never drops or lowers one: a change rests on your own re-read,\n"
        "  cited at file:line.\n")
    dispatch = "- Dispatch THREE fresh challengers IN PARALLEL, one per lens\n"
    advisory_old = (
        "- ADVISORY: the revised plan + a challenge summary (raised / addressed /\n"
        "  deferred / any lens that failed to return) feed the orchestrator's existing\n"
        f"  human gate. The human decides {DASH} this is not a hard block.\n")
    item3_old = ("3. Before proposing a merge (`gitflow finish`) or calling a long task\n"
                 "   done.\n")
    return [
        ("agents/verifier.md", ver_old, b["verifier-head"]),
        ("agents/security-auditor.md", sa_old, b["auditor"]),
        ("agents/plan-challenger.md", pc_old, b["challenger"]),
        ("agents/plan-challenger.md", dispatch, b["protocol-first"] + dispatch),
        ("agents/plan-challenger.md", advisory_old, b["protocol-advisory"]),
        ("lib/effort-shift.md", item3_old, b["item3"]),
    ]


GROUPS = {"skills": skills_edits, "agents": agents_edits}


def main():
    plan, root, group = sys.argv[1], pathlib.Path(sys.argv[2]), sys.argv[3]
    blocks = read_blocks(plan)
    edits = GROUPS[group](blocks)
    texts = {}
    for rel, old, new in edits:
        text = texts.get(rel)
        if text is None:
            text = (root / rel).read_text(encoding="utf-8")
        count = text.count(old)
        if count != 1:
            sys.exit(f"ABORT {rel}: anchor count {count} != 1: {old[:60]!r}")
        texts[rel] = text.replace(old, new, 1)
    for rel, text in texts.items():
        (root / rel).write_text(text, encoding="utf-8")
    print(f"applied {len(edits)} edits ({group})")


if __name__ == "__main__":
    main()
