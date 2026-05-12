# Darwin Skill Optimization — 2026-05-12

**Branch:** `auto-optimize/20260512-1319`
**Scope:** 28 dirs in `~/Documents/claude/skills/` (cwd = source of truth, ~/.claude/skills is runtime mirror)
**Eval mode:** structural dim 1-7 full / dim 8 `dry_run`
**Phase reached:** 2 (round 1 per skill — rounds 2-3 skipped for diminishing returns)
**Runtime:** ~30 min

---

## Baseline scorecard (23 scoreable + 5 excluded)

23 personal skills scored. 5 broken gstack symlinks excluded (not user-owned).

| Rank | Skill            | Baseline | Weakest |
|------|------------------|---------:|---------|
| 1    | status           | 45.3 | D3 |
| 2    | refactor         | 48.4 | D4 |
| 3    | plugin-check     | 59.2 | D4 |
| 4    | skills-perso     | 66.4 | D3 |
| 5    | commit-change    | 69.6 | D3 |
| 6    | hotfix           | 74.1 | D4 |
| 7    | code-clean       | 74.7 | D3 |
| 8    | feat             | 74.7 | D4 |
| 9    | doc              | 76.2 | D3 |
| 10   | analyze          | 76.4 | D4 |
| 11   | validate         | 76.4 | D4 |
| 12   | geo              | 76.5 | D4 |
| 13   | profile          | 78.3 | D3 |
| 14   | close            | 79.2 | D3 |
| 15   | bugfix           | 79.3 | D4 |
| 16   | seo              | 82.5 | D4 |
| 17   | onboard          | 83.5 | D8 |
| 18   | client-handover  | 83.9 | D8 |
| 19   | init-project     | 84.1 | D8 |
| 20   | ship-feature     | 84.3 | D8 |
| 21   | prune-memory     | 84.6 | D8 |
| 22   | harden           | 85.5 | D8 |
| *    | graphify         | 29.0 | D4 |

graphify scored on partial read (62KB SKILL.md exceeded token limit). Real fix likely a Phase 2.5 exploratory rewrite, not hill-climb — deferred.

**Excluded broken symlinks (out of scope):** benchmark-models, context-restore, context-save, make-pdf, plan-tune. All point to `skills-external/gstack/<name>/SKILL.md` which doesn't exist.

**Average across 23: 75.6 / 100.**

---

## Phase 2 — optimized skills (bottom 5)

User-confirmed queue: bottom 5 by baseline (graphify deferred).

| Skill          | Before | After | Δ      | Round | Status | Change                                       |
|----------------|-------:|------:|-------:|:-----:|:------:|----------------------------------------------|
| status         | 45.3   | 76.2  | +30.9  | 1     | keep   | D3 fallback + frontmatter triggers           |
| refactor       | 48.4   | 74.3  | +25.9  | 1     | keep   | D3 fallback + frontmatter triggers           |
| plugin-check   | 59.2   | 76.8  | +17.6  | 1     | keep   | D3 fallback + triggers + advisory note       |
| skills-perso   | 66.4   | 80.1  | +13.7  | 1     | keep   | D3 "Known limits of heuristic" section       |
| commit-change  | 69.6   | 83.5  | +13.9  | 1     | keep   | D3 fallback + pre-flight git checks (HEAD/identity) |

**Average:** 58.0 → 78.2 (+20.2 per skill).
**Kept:** 5/5. **Reverted:** 0.

### Per-skill commit

- `512df48` optimize status: round 1 — D3 fallback + triggers
- `079074d` optimize refactor: round 1 — D3 fallback + D1 triggers
- `d3dd31c` optimize plugin-check: round 1 — D3 fallback + D1 triggers + advisory clarification
- `134561d` optimize skills-perso + commit-change: round 1 — D3 edge cases

### Same pattern across the bottom 4 dispatchers

status, refactor, plugin-check, commit-change are all thin dispatchers (15-30 lines, body = "load and follow agents/<x>.md + $ARGUMENTS"). Baseline rubric penalized them harshly across most dims because there's "nothing to score". Round 1 fix is invariant:

1. Add fallback clause: "If agent file unreachable, emit `<X> agent missing.` and STOP."
2. Add explicit triggers in frontmatter description.
3. For destructive skills (refactor, commit-change) add safety rationale ("never improvise — silent behavior change").

skills-perso is the outlier — full implementation, not a dispatcher. Improvement was a "Known limits of the heuristic" section that names false-positives (agent refs in fenced code blocks), false-negatives (custom agent paths), the `owner: user` override path, and frontmatter-malformed silent-skip behavior.

---

## Methodology notes & caveats

1. **Eval math drift.** Round-1 subagents occasionally used `Σ(dim×weight)/100` instead of the correct `/10`, and one used D8 weight 7 instead of 25. Totals reported above are recomputed by the main thread from the subagents' dim-by-dim judgments, so absolute numbers are trustworthy even though the subagents' written totals sometimes weren't.

2. **Score recalibration at round 1.** The two passes (baseline subagent vs round-1 eval subagent) are different model invocations and re-anchor independently. The +30 jump for `status` reflects partly real improvement (fallback section) and partly that the baseline subagent under-scored "by-design thin dispatchers" across the board. Δ direction is reliable; absolute magnitudes are noisy.

3. **150% size cap is tight for thin dispatchers.** `status` (15 lines, 776B) and `refactor` (15 lines, 379B) had ~22-line / ~570B caps. Multiple trim cycles per skill to fit. Recommend the spec consider an absolute-byte floor (e.g., min cap = max(150%, 1000B)) for cases where the original was minimal.

4. **D8 (effect) untested.** Spec allows `dry_run`; all 5 logged as such. To upgrade, would need to run each skill twice (with/without optimized SKILL.md) and compare outputs. Saved for a follow-up pass.

5. **Rounds 2-3 skipped.** Round 1 Δ for all 5 was big (+13.7 to +30.9). Round 2 expected Δ is small (returns flatten near 80). Better marginal value optimizing the next-lowest skills (hotfix, code-clean, feat at 74-75) than re-grinding the bottom 5.

6. **Screenshot.mjs is macOS-only.** Script hardcodes `/Users/alchain/.npm-global/...`. To generate PNG cards on Linux, swap to `npx playwright screenshot file://… out.png --viewport-size=960,1280` or fix the script's `require()` path.

---

## Suggested next passes

| Priority | Action |
|----------|--------|
| P1 | Hill-climb rank 6-12 (hotfix, code-clean, feat, doc, analyze, validate, geo) — same dispatcher fallback pattern; expected +5 to +15 per skill |
| P1 | Phase 2.5 exploratory rewrite of `graphify` (62KB SKILL.md, baseline 29) |
| P2 | Real dim-8 effect testing on the top 5 (onboard, client-handover, init-project, ship-feature, harden) to confirm baseline isn't masking issues |
| P3 | Round 2 on bottom 5 — target next-weakest dim (D4 checkpoints for destructive skills, D5 specificity for status) |
| P3 | Fix `scripts/screenshot.mjs` for Linux + generate PNG cards |

---

## Files touched (committed on `auto-optimize/20260512-1319`)

```
skills/status/SKILL.md          (+9 -2)
skills/refactor/SKILL.md        (+3 -4)
skills/plugin-check/SKILL.md    (+5 -5)
skills/skills-perso/SKILL.md    (+18 -0)
skills/commit-change/SKILL.md   (+5 -3)
skills/close/test-prompts.json       (new)
skills/graphify/test-prompts.json    (new)
skills/harden/test-prompts.json      (new)
skills/profile/test-prompts.json     (new)
skills/prune-memory/test-prompts.json (new)
```

5 commits on branch. To merge:

```bash
git checkout master
git merge --no-ff auto-optimize/20260512-1319
```

Or review per-commit and cherry-pick. No master commits yet — branch is purely additive.

---

## results.tsv

Persisted to `~/.agents/skills/darwin-skill/results.tsv` (28 baseline rows + 5 round-1 rows = 33 total).
