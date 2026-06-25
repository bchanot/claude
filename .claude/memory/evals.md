---
type: evals_registry
entry_prefix: EVAL
schema:
  id: EVAL-XXX
  date: YYYY-MM-DD
  output: string (what was produced)
  method: string (how it was evaluated - manual read, test, benchmark, user feedback)
  anomalies: list of strings (what was wrong, missing, surprising)
  action: [keep | correct | deprecate]
rules:
  - Log an eval whenever you validate the quality of something Claude produced (report, audit, plan, generated code).
  - Action keep - the output is fit for purpose as-is.
  - Action correct - needs revision; capture what.
  - Action deprecate - the approach itself is flawed; link to the decision that replaces it.
---

# Evals registry (EVAL)

## Index

| ID | Date | Output | Action |
|----|------|--------|--------|
| EVAL-001 | 2026-04-23 | `.claude/` restructure plan (ship-feature STEP 2) | keep |
| EVAL-002 | 2026-06-02 | `profile gstack on/off` verb implementation | keep |
| EVAL-003 | 2026-06-11 | darwin optimization run on `audit-delta` skill | keep |
| EVAL-004 | 2026-06-11 | darwin eval 26 perso skills + 4-bug fix round | keep |
| EVAL-005 | 2026-06-23 | Obsolete `claude --effort max` alias missed across Step 9 edits | correct |
| EVAL-006 | 2026-06-25 | prune-memory v1.1 TDD — 6 guards (0a3e766), validated on real data | keep |

---

## EVAL-001 — `.claude/` restructure plan

- **Date**: 2026-04-23
- **Output**: 21-task plan migrate `tasks/` to `.claude/tasks/` + create `.claude/memory/` + `.claude/audits/` + integrate CAPITALIZE across 5 skills + add `/close` skill.
- **Method**: manual review of 5 impacted skills/agents; verified `rtk` path-agnostic; confirmed `~/.claude/CLAUDE.md` symlinks to project (single file edit). Radical-honesty check on session-close ritual: confirmed aspirational without skill integration → scope expanded to Option D.
- **Anomalies**: none blocking. Note: `tasks/LESSONS.md` empty (101B, header only) — migration to `learnings.md` symbolic.
- **Action**: keep — plan validated, ready for execution.

---

## EVAL-002 — `profile gstack on|off` verb implementation

- **Date**: 2026-06-02
- **Output**: `cmd_gstack()` + 3 extracted helpers in `lib/profile.sh`; `cmd_reset`/`cmd_set` refactored to reuse; `skills/profile/SKILL.md` doc updated.
- **Method**: shellcheck 0.10.0 (CLEAN) + `bash -n`; 6-case live test (help; bad-action exit 1; `off` with active=none → exit 1 zero-mutation; `on` restores 14 + label `full` preserved NOT cleared; `off` trim; `on` cycle) with saved manifest + final assertion final-state == original (PASS, live env untouched).
- **Anomalies**: (1) Initial flag "full.profile omits ios/spec = bug" WRONG — full curated by design, confirmed by BDR-017 caveat. Self-corrected BEFORE any edit, no bad change shipped. Lesson: verify profile INTENT vs source completeness before calling omission a bug. (2) Surfaced real source-only gap → BLK-007 (open).
- **Action**: keep — verb works, tested, documented; false bug-flag caught pre-edit.
---

## EVAL-003 — darwin optimization run on `audit-delta`

- **Date**: 2026-06-11
- **Output**: `audit-delta` SKILL.md 87.5 → 89.9 (9-dim rubric). 2 rounds kept, 0 reverts. R1 (0d2ece7): 2 unreachable-user branches (dangling marker → report-only + marker frozen; no axes → all four). R2 (9fc93fa): 3c marker-rule contradiction cross-ref + corrupted-JSON branch + fail-closed 3e revert. Merged ff to master, branch deleted.
- **Method**: 8 live subagent tests on synthetic git fixtures (/tmp, 14 commits, planted issues: hardcoded token, unguarded rm -rf, 27-line fn, dead fn, `|| true`, uncommitted password echo) + 4 counterbalanced blind judges (2/round, 4/4 high-conf consensus pro-new-version). All eval_mode=full_test. Behavior proofs: gate held under "fix everything + meeting" pressure (0 source edits); corrupted state file sha256-identical before/after.
- **Anomalies**: (1) baseline contamination — "no-skill" agents invoked globally installed skill anyway → LRN-028. (2) R1 edit introduced live contradiction, only judges caught → LRN-029. (3) darwin `screenshot.mjs` hardcodes author macOS playwright path — fallback `npx playwright screenshot` works (rtk prints parser noise, command succeeds).
- **Action**: keep — skill improved, validated, merged. Residuals logged (empty-delta marker phrasing, missing-axis-key) — not worth chasing past HL-4 stop.

---

## EVAL-004 — darwin eval 26 perso skills + 4-bug fix round

- **Date**: 2026-06-11
- **Output**: structure scorecard 25 skills (33.5–66.8/76, anchor audit-delta 68.9) + 5 full_tests + 4 confirmed bugs fixed (5 commits, ff-merged master): geo-analyzer headless→report-only + unreachable definition; init-project broken readme-updater ref → doc-syncer; analyzer.md memory-write vs read-only contradiction; onboard allowed-tools += Agent/Skill.
- **Method**: 5 parallel structure judges (shared rubric file, calibration anchor, lower-score-when-hesitating rule) + 5 behavior tests on fixtures (hotfix, geo, commit-change, status, analyze) + geo fix validated by re-test (0 source edits, `?? .claude/` only) + 2/2 counterbalanced blind judges (safety 3→9).
- **Anomalies**: (1) KEY: stub skills (analyze 33.5, hotfix 36.7…) score terribly on structure but execute excellently — substance lives in `agents/*.md`; rubric must judge SKILL.md+agent.md as system, else misleading. (2) geo confirmed live: 2 HTML source files edited unsupervised pre-fix. (3) Self-inflicted: overwrote 5 pre-existing test-prompts.json without existence check (darwin spec says reuse/ask) — restored via git checkout. (4) Both geo judges independently flagged undefined "headless" — fixed same round.
- **Action**: keep — bugs real, fixes verified. NOT recommended: rewriting stubs to inflate structure scores (pattern works, proven live).

---

## EVAL-005 — Obsolete `claude --effort max` alias missed across repeated Step 9 edits

- **Date**: 2026-06-23
- **Output checked**: install-plugins.sh Step 9 kept `alias claude='claude --effort max'` while `settings.json` sets `"effortLevel": "xhigh"` (the source of truth). I edited Step 9 ≥4× this session (playwright override, config guard, no-sandbox env) and never flagged it — the user caught it.
- **Method / why missed**: I treated the pre-existing `CLAUDE_LINES` as established and only touched the lines I was adding/removing. Spotting the redundancy needs cross-referencing TWO config layers (shell alias vs settings.json) — a semantic check I never ran. Masked further: the user's `.bashrc` is hand-managed and the alias line wasn't even present, so it looked inert.
- **Anomaly**: not just dead config — a CLI flag (`--effort max`) silently OVERRIDES the settings.json value (`xhigh`). Real correctness bug.
- **Action**: when editing installer shell-config, audit EACH existing line against the current settings.json / CLAUDE.md source of truth, not only the lines being changed. Removed the alias + added cleanup. General rule: reconcile config to ONE source of truth across env/alias/settings layers.

---

## EVAL-006 — prune-memory v1.1: 6 dangers TDD-closed, validated on real data

- **Date**: 2026-06-25
- **Output**: prune-memory (only DESTRUCTIVE skill, never tested before) TDD'd end-to-end. 6 dangers, each proven by a failing RED then closed by a DETERMINISTIC guard: RED-1 false "verified" claim removed; RED-2 dirty tree → real `exit 1` (was prose-only STOP); RED-3 negation-sentence verbatim guard (no silent inversion); RED-4 collapse safety-critical exception (NEVER/ALWAYS/PERMANENT entry INTOUCHABLE); RED-5 STEP-4 fidelity census (count-based, per-entry × per-category); RED-6 trailing-space false-ORPHAN fix. Guards committed in **0a3e766**; tests: `tests/run-deterministic.sh` + `run-behavioral.md` + fixtures + BACKLOG.
- **Method**: run-deterministic all-green (RED-1/2/5/6); RED-3/4 by single faithful subagent runs on throwaway fixtures (deterministic oracles — byte-identical + layer-(a) substring; N=6 tolerance-zero fleet documented in run-behavioral.md, NOT exhausted — 1 run sufficed to prove presence then closure); REAL-data re-test on live learnings.md (602 l): fidelity 0 false-positive vs old line-grep 13, census PROVEN counting both sides (HEAD/WORK not=107/114, no=64/71, never=34/34 — no category dropped). Scope held (only learnings.md), reverted after (measurement, not a kept prune). Clean tree verified first; git + cp backup.
- **Anomalies**: (1) SAFE ≠ USEFUL — compression (pass C) marginal on already-caveman dense content (~3.6% trim, registry GREW); real value = index-drift (D found 19 missing Index rows on the real learnings.md, measured then reverted) + merge (B), not C on dense. (2) RED-8 OPEN — fidelity proves "no negation DELETED", not "none ADDED wrongly"; visible empirically (not/no +7 in the measurement, passed under the drop-radar); remote (compression subtracts) but real. (3) RED-7 OPEN — merge LRN-014+016 maybe PRIMED by the SKILL.md example, not real overlap; verify. (4) two guard bugs caught by VALIDATION not logic: awk `\<` unsupported (mawk) → not/no counted 0; `NR==FNR` blind when working census empty = the deletion case → both fixed + re-validated. (5) REAL ANCHOR FOR PASS D — this very evals.md had EVAL-005's Index row MISSING (pre-existing drift), exactly what the skill's D pass auto-corrects; hand-backfilled in a separate `fix(memory)` commit. learnings.md likewise carries 19 missing Index rows (deferred to an intentional prune). D is NOT theoretical.
- **Action**: keep — safe, useful for B/D, compression marginal on dense (documented limit). `Fixed in v1.1 (TDD found it)` WAS the RED-1 defect (claim of a verify never run); TDD note now TRUE (real suite passes). Patterns → LRN-046/047/048; open items → tests/BACKLOG.md (RED-7/RED-8).
