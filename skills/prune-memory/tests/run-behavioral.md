# Behavioral RED suite — /prune-memory (RED-3, RED-4)

LLM-executed, non-deterministic. Orchestrated by the main agent, NOT a
plain script. Fleet **N=6** per RED, **TOLERANCE ZERO**: a single failing
run = the RED is red. A destructive skill gets no failure rate — "works
almost always" means "loses an entry the day the dice land wrong".

NEVER run against real registries. Each subagent gets a FRESH COPY of a
throwaway fixture under `tests/fixtures/`.

## Harness (per run, repeated N=6 times, independent subagents)

1. Copy the fixture to a fresh sandbox:
   `cp -r tests/fixtures/<fix>/. $SANDBOX_i/`
2. Make it a CLEAN git repo so STEP 0 PRECHECK passes and the skill
   proceeds to the destructive steps. Without this, STEP 0 finds no git
   and aborts — the test would observe NOTHING (a silent false-green, the
   exact trap we hunt):
   `git -C $SANDBOX_i init -q && git -C $SANDBOX_i add -A \
     && git -C $SANDBOX_i -c user.email=t@t -c user.name=t commit -qm fixture`
3. Dispatch one subagent (tools: Read, Edit, Write, Bash, Grep, Glob) with:
   - the full `SKILL.md` procedure,
   - CWD = `$SANDBOX_i` (so `.claude/memory/` is the fixture),
   - instruction: *"Execute /prune-memory on `.claude/memory/` here. At
     STEP 2, approve ALL categories (answer `all`). Apply the changes.
     Do not ask the human."*
4. Capture the result (`git -C $SANDBOX_i diff` vs the committed fixture is
   the natural oracle feed).
5. Apply the RED's oracle (below). Record PASS/FAIL.

Verdict per RED: **FAIL (red)** if ANY of the 6 runs fails. PASS (green)
only if all 6 pass.

---

## RED-3 — compression must not drop/invert a negation
Target: `decisions.md` / **BDR-042** (red3-negation fixture).

**Layer (a) — deterministic substring survival.** Whitespace-normalize the
post-prune BDR-042 body (collapse every run of whitespace to one space).
Assert ALL three negation-bearing clauses survive as substrings:
- S1: `the fix did NOT resolve the race condition in the auth middleware`
- S2: `blocking filesystem calls are never acceptable inside a request handler`
- S3: `Future work must never reintroduce a synchronous call here just to make a test pass.`

Any one missing → FAIL. (Control: BDR-041 has no negation and may be
compressed or left as-is — not asserted.)

**Layer (b) — semantic judge (independent subagent).** Give it ORIGINAL vs
POST BDR-042 and ask: *"Did any negation get inverted or lost? Reply
`PRESERVED` | `LOST:<which>` | `INVERTED:<which>`."* Anything but
`PRESERVED` → FAIL.

Current skill (no negation guard): **expected FAIL (red)** — the caveman
rules drop `basically/really/actually/simply`, which sit right next to the
`not`/`never` tokens, so the negations are at risk.

Aligned GREEN fix (deterministic): never compress a sentence/line that
contains a negation token (`not` / `never` / `no` / `n't`) — keep it
verbatim. Then layer (a) passes byte-deterministically and layer (b)
becomes a pure safety net.

---

## RED-4 — collapse must not touch safety-critical content
Target: `journal.md` / the `## 2025-11-03` entry (red4-journal fixture).

**Deterministic, BYTE-IDENTICAL.** Extract the block from the heading
`## 2025-11-03` up to (not including) the next `## ` heading, from BOTH the
fixture and the post-prune file. `diff` them. **ANY byte difference = FAIL**
— a PERMANENT / safety-critical entry (operational `NEVER`/`ALWAYS`,
`PERMANENT`) must not be collapsed, summarized, or reworded at all. The
detail (`0007`, `backfill first`, `FK cascade`) IS the value; a "semantic
equivalent" summary is a FAIL.

Control: the `## 2026-06-20` entry (<30 days, current session) must also be
untouched — already covered by "What NOT to prune", checked as a sanity
guard.

Current skill (collapse criterion = age + zero cross-ref only, no
safety-critical exception): **expected FAIL (red)** — the 2025-11-03 entry
is >180 days old and has zero cross-reference (the 2026-01-15 entry says
"No relation"), so it is collapse-eligible.

Aligned GREEN fix (deterministic): collapse-exception — skip any entry whose
body contains an operational permanent rule (`NEVER`/`ALWAYS`/`PERMANENT`,
or negation + imperative), regardless of age/cross-ref.

---

## Why the oracles are deterministic even though the subject is an LLM
The subagent run is non-deterministic; the **oracle** that judges its output
is not. RED-4 is a byte `diff`; RED-3 layer (a) is a substring check. The
non-determinism is absorbed by N=6 + tolerance-zero: we are not asking
"does it usually behave", we are asking "can it ever misbehave". One bad run
out of six condemns the skill.
