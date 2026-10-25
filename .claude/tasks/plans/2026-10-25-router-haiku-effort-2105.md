# FIX PLAN — router-haiku-effort (bugfix)

## DIAGNOSIS
- BUG: on a haiku model the router never sends an effort: `mechanical` (cheap tier, effort low) runs status-reporter and the 8 mechanical skills (status, profile, plugin-check, skills-perso, using-git-worktrees, 21st-cli-use, 21st-registry, 21st-design-sync) at Haiku 5.5's engine default (medium); `/route show` prints `- (haiku takes none)`.
- ROOT CAUSE: the Haiku 4.5 rule "haiku takes no effort" is hard-coded in 4 places; the `haiku` alias now resolves to `claude-haiku-5-5` (2c39524, BLK-035), which takes effort low–max, default medium (claude-api skill model table, cached 2026-10-06).
- PRIOR: BLK-035 (this is its residual), LRN-230 (per-model facts rot with the alias).
- EVIDENCE: mods/model-router/hooks/register.ts:3948-3953 `planStep` strips `effort` when `step.plan.model.startsWith(HAIKU)` (main AND agent steps); :3833 `handoffOf` sets the spawned agent's effort to undefined on haiku; :4238 `loop.last = hand.to` also when `isHaiku` (the "effort known" case only because it was undefined); :1874-1875 `effortWord` prints `- (haiku takes none)`. Census lib/tests/effort-routing.test.sh:170 skips the agent effort floor check when the phase model is haiku; agents/status-reporter.md frontmatter has `model: haiku` and no `effort:`.
- OUT OF SCOPE (not effort): `moveTo` / `knownModel` / `variantNote` `[1m]` rule (l.1220, 2137, 2273), `windowReturn` refusing a haiku home (l.1373), `smallModelBusy` (l.4410).

## FIX PLAN (r2, after 3 lenses: correctness CONCERNS(1), robustness CONCERNS(2), simplicity SOLID; no BLOCKER)
The guard is KEPT and scoped to the version that takes no effort (C1/R1, LRN-230: name the model version), not deleted.
1. register.ts: new constant beside `HAIKU` (l.213): `const NO_EFFORT = 'claude-haiku-4' // Haiku 4.x takes no effort; 5.x does (low-max)`. New helper next to `isHaiku` (l.3678): `const takesNoEffort = (cfg: Config, id: string): boolean => canonical(cfg, id).startsWith(NO_EFFORT)`.
2. register.ts:3948-3953 `planStep`: the strip tests `takesNoEffort(st.cfg, step.plan.model)` instead of `startsWith(HAIKU)`; comment names Haiku 4.x.
3. register.ts:3833 `handoffOf`: `takesNoEffort(st.cfg, started.model) ? undefined : given ?? route?.effort`.
4. register.ts:4238: `hand.effortCause !== 'engine' || takesNoEffort(st.cfg, hand.to.model)`.
5. register.ts:1873-1875 `effortWord`: `takesNoEffort(st.cfg, v.call.model)` → `'- (haiku 4 takes none)'`; doc sentence names Haiku 4.x.
   `HAIKU` / `isHaiku` stay for the out-of-scope sites ([1m], windowReturn, smallModelBusy).
6. register.test.ts (S1/C3/R3): update the existing omission assertions to the phase effort and rename: l.~860 `expect(sent.effort).toBeUndefined()`, l.~3838 `mainWord(..., 'haiku/-', ...)` → `haiku/low`, l.~4038-4048 test "a haiku spawn shows no effort" → asserts `haiku/low` and a new name. New tests: (c) `/route show` main line on a haiku-5-5 session shows the effort, not `takes none`; (d) Haiku 4.x keeps the strip: `models.haiku` overridden to `claude-haiku-4-5-20251001` (home override fixture) → a routed step sends NO effort, `/route show` says `haiku 4 takes none`, a spawn hand-off shows `haiku/-`; (e) unrouted haiku-5-5 step passes the engine effort unchanged (C2); (f) haiku-5-5 session + `plan` keyword prompt → step effort xhigh (R2, the accepted edge reversal pinned by a test); (g) unrowed haiku-5-5 spawn (engine effort cause): hand-off `haiku/-`, first agent step logs nothing (R3).
7. lib/tests/effort-routing.test.sh:170: delete the haiku skip (status-reporter is the only haiku agent; its row `mechanical` = haiku/low).
8. agents/status-reporter.md: add `effort: low` to the frontmatter, placed like other agents' `effort:` line.
9. README.md:124 (S2): drop "(none on haiku, which rejects the parameter)" (now false for Haiku 5.5).

## RISK (r2)
Visible behaviour change on Haiku 5.x (user pick 2026-10-25: "like any model"): routed steps get the phase effort (`mechanical` low); effort-only routes go live on a haiku session (`plan`/`design`/`architecture` → xhigh, `ultrathink` → max, `why`/`review` → high, sticky `/route effort=`, derived orchestrate); an unrouted step passes the engine/session effort (high here) instead of the engine default medium. Reverses the 2026-10-23 accepted edge "haiku session → keywords no-op" → amendment at CAPITALIZE; also the effort-pin BDR line "none on status-reporter (haiku)" (decisions.md:~1350) → amendment. Haiku 4.x unchanged.
Live check (C4, user-run, not a gate): `/status` on a session with `verbose` → hand-off `status-reporter haiku/low`.
