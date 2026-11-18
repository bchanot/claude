#!/usr/bin/env python3
"""Apply run B3 blocks to a repo root.

Usage: apply.py <plan.md> <repo root> <skills|lib|all|review1>
Blocks are read from the plan (### Block <name> + fenced body). Every anchor
must occur exactly once in its file; any miss aborts before writing anything.
"""
import pathlib
import re
import sys

CALLERS = [
    "skills/feat/SKILL.md", "skills/bugfix/SKILL.md", "skills/hotfix/SKILL.md",
    "skills/ship-feature/SKILL.md", "skills/init-project/SKILL.md",
    "skills/audit-delta/SKILL.md", "skills/code-clean/SKILL.md",
    "skills/onboard/SKILL.md", "skills/harden/SKILL.md",
    "skills/pack-seo/skills/seo/SKILL.md",
    "skills/pack-seo/skills/geo/SKILL.md",
    "skills/pack-web-validate/skills/web-validate/SKILL.md",
]
# block-form callers: (file, indent, noun of its BLOCKERs addressed row)
BLOCKS = [
    ("skills/ship-feature/SKILL.md", 2, "plan"),
    ("skills/init-project/SKILL.md", 2, "plan"),
    ("skills/audit-delta/SKILL.md", 2, "finding-set"),
    ("skills/code-clean/SKILL.md", 2, "scope"),
    ("skills/onboard/SKILL.md", 2, "proposals"),
    ("skills/harden/SKILL.md", 5, "bundle"),
    ("skills/pack-seo/skills/seo/SKILL.md", 2, "bundle"),
    ("skills/pack-seo/skills/geo/SKILL.md", 2, "bundle"),
    ("skills/pack-web-validate/skills/web-validate/SKILL.md", 2, "bundle"),
]
ROUTE_OLD = "send it with the challenger dispatch)."
LENSES = ("Lenses returned    : correctness / robustness / simplicity "
          "(NAME any that failed to return)\n")
FEAT_SUM = ("(BLOCKERs addressed / deferred / lenses returned), surfacing any "
            "deferred BLOCKER in\nthe STEP 1 pass B batch.\n")
BUG_SUM = ("(BLOCKERs addressed / deferred / lenses returned), folding any "
           "deferred BLOCKER into\nthe STEP 3 approval gate.\n")
HOT_SUM = ("CHALLENGE SUMMARY (BLOCKERs addressed / deferred / lenses "
           "returned). A BLOCKER\nthat shows the fix is wrong or incomplete "
           "means this was never\n")
END_OLD = (
    "Before the summary, the main loop prints the run's diff stat, then "
    "makes its\nend-of-run advisor call (`lib/effort-shift.md` § Advisor);"
    " its answer\ngoes into the summary as an `Advisor:` line, and a fix it "
    "drives goes\nback through the gates.\n")
FEAT_VERIFIED = "VERIFIED : <what was checked>\n"
BUG_REGRESSION = "   REGRESSION : <checked areas>\n"
ITEM3_OLD = (
    "3. Before proposing a merge (`gitflow finish`) or calling a long task\n"
    "   done. Wired at the end step of feat, bugfix, ship-feature,\n"
    "   init-project, a11y, guardrails, audit-delta and tour, and at the\n"
    "   release gate of release-candidate: one end-of-run call per skill\n"
    "   run, never skipped for an earlier plan or stuck call; audit-delta\n"
    "   and tour skip it when the run applied no fix. In the six flows that\n"
    "   run the gates, the main loop first prints the run's diff stat, a fix\n"
    "   the answer drives goes back through the gates, and a later proposal\n"
    "   reuses the answer and says it predates the newer commits. Elsewhere\n"
    "   the answer is reported only and a fix it calls for is a new run.\n")
CL_FILES = ("skills/{feat,bugfix,ship-feature,init-project,a11y,guardrails,"
            "audit-delta,tour,release-candidate}/SKILL.md")
CL_ROW = "and the CHALLENGE SUMMARY gains an `Advisor:` row;"
CL_SKIP = ("never skipped for an earlier plan or stuck call. It sits at the "
           "end step of feat, bugfix, ship-feature, init-project, a11y and "
           "guardrails:")
CL_REUSE = ("and a later proposal reuses the answer and says it predates the "
            "newer commits.")
CL_ANSWER = ("the answer goes into the reply, summary or finish proposal as an "
             "`Advisor:` line,")


def read_blocks(plan):
    text = pathlib.Path(plan).read_text(encoding="utf-8")
    pattern = r"^### Block (\S+)\n```\n(.*?)```\n"
    return dict(re.findall(pattern, text, re.S | re.M))


def inline(block):
    return block.rstrip("\n")


def indent(block, width):
    pad = " " * width
    return "".join(pad + line if line.strip() else line
                   for line in block.splitlines(True))


def skills_edits(b):
    edits = [(f, ROUTE_OLD, inline(b["route-new"])) for f in CALLERS]
    for rel, width, noun in BLOCKS:
        old = "\n" + " " * width + LENSES
        row = inline(b["row"]).replace("{noun}", noun) + "\n"
        edits.append((rel, old, old + " " * width + row))
    edits += [
        ("skills/feat/SKILL.md", FEAT_SUM, b["feat-summary"]),
        ("skills/bugfix/SKILL.md", BUG_SUM, b["bugfix-summary"]),
        ("skills/hotfix/SKILL.md", HOT_SUM, b["hotfix-summary"]),
        ("skills/feat/SKILL.md", END_OLD, b["end-report"]),
        ("skills/bugfix/SKILL.md", indent(END_OLD, 3),
         indent(b["end-report"], 3)),
        ("skills/feat/SKILL.md", FEAT_VERIFIED,
         FEAT_VERIFIED + b["feat-field"]),
        ("skills/bugfix/SKILL.md", BUG_REGRESSION,
         BUG_REGRESSION + indent(b["bugfix-field"], 3)),
    ]
    return edits


def lib_edits(b):
    return [
        ("lib/effort-shift.md", ITEM3_OLD, b["item3"]),
        ("CHANGELOG.md", CL_FILES, inline(b["cl-files"])),
        ("CHANGELOG.md", CL_ROW, inline(b["cl-row"])),
        ("CHANGELOG.md", CL_SKIP, inline(b["cl-skip"])),
        ("CHANGELOG.md", CL_REUSE, inline(b["cl-reuse"])),
        ("CHANGELOG.md", CL_ANSWER, inline(b["cl-answer"])),
    ]


def review1_edits(b):
    """STEP 6 review fix, applied on top of 55edd0a."""
    old, new = b["end-tail-old"], b["end-tail-new"]
    return [
        ("skills/feat/SKILL.md", old, new),
        ("skills/bugfix/SKILL.md", indent(old, 3), indent(new, 3)),
        ("CHANGELOG.md", "except that feat and bugfix skip it when",
         inline(b["cl-skips"])),
    ]


def all_edits(b):
    return skills_edits(b) + lib_edits(b)


GROUPS = {"skills": skills_edits, "lib": lib_edits, "all": all_edits,
          "review1": review1_edits}


def main():
    plan, root, group = sys.argv[1], pathlib.Path(sys.argv[2]), sys.argv[3]
    edits = GROUPS[group](read_blocks(plan))
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
