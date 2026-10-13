# CONTRACT — router-downgrade-cap
- date: 2026-10-13 | flow: feat | branch: feature/router-downgrade-cap (to start off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
User (2026-10-13, after the explanation of why `mainModelSwitch` is off):
"on va partir sur 2 on va fiare un feat maintenant comme ca c'est bon. JE te laisse juger le seuil de token a metre en place, sachant que capourrait switcher plusieurs fois dnas la meme conversation. Dison que si je suis sur fable et que l'interprete du prompt estime que c'est un autre model il switch de model tot. Et si il y a de nouveau de la reflexion alors on switch plus haut genre fable sans forcemnt re down si on ateint la limite de token. bref je te laisse faire ca"

Option 2 as proposed by Claude: "Un `/feat` qui ajoute `downgradeMaxTokens` au mod et passe le switch à on par défaut sous ce plafond."

/feat arguments: model-router: downgrade cap. Add `downgradeMaxTokens` to the mod (symmetric to `upgradeMaxTokens`): a main-loop downgrade is allowed only while the context is under the cap; above it main keeps its model (no re-down once the limit is reached, upgrades to best still allowed). Flip `mainModelSwitch` default to on under that cap. User also wants the prompt classifier to be allowed to move the main model down (today effort-only by design, W4-B), with the cap as the guard. Threshold value left to Claude's judgment (several switches per conversation expected).

## CLARIFICATIONS
Q: default value of `downgradeMaxTokens` / A: delegated — 120000 tokens of COLD READ (LRN-204; r2: measured against the target model's warm prefix, not the context size); per-machine override in `~/.claude/model-router.json`
Q: does a return to the engine's own model obey the upgrade cap? / A: delegated — r1 said "bypass"; r2 (challenge, correctness #1): no bypass, both caps measure the COLD READ of the target (LRN-204), so a warm return passes by itself and a cold one is capped like any switch
Q: does the classifier also move main UP (design/analysis → best tier)? / A: delegated — no, downgrades only; prompt rules keep upgrading as today [r2, correctness #2]
Q: does a user `/model` suspend the classifier's model axis? / A: delegated — no; the baseline moves and the guess routes from it; `/route classify off` or `/route off` pins [r2, correctness #3, trade-off to the BDR]
Q: when a user `/effort` beats the classifier's effort guess (`userMovedEffort`), does the model guess still apply? / A: delegated — no: the whole classifier route yields for that step, both axes
Q: status line display once the switch defaults to on / A: [gated 2026-10-13] show ` · switch off` only when the switch is off; the ` · switch on` fragment is dropped (on is the norm)

## ACCEPTANCE CRITERIA
1. `Config` carries `downgradeMaxTokens` (positive number, default 120000), merged like `upgradeMaxTokens` (`pickPositive`, user override wins, invalid value logged and ignored).
   CHECK: cd mods/model-router && grep -q "downgradeMaxTokens: 120000" hooks/register.ts && grep -q "user.downgradeMaxTokens, base.downgradeMaxTokens, 'downgradeMaxTokens'" hooks/register.ts && echo CRIT1-OK
   EXPECT: CRIT1-OK
   EVIDENCE: MET exit=0 marker-found :: CRIT1-OK
2. `mainModelSwitch` defaults to `true` in `DEFAULT_CONFIG` and is merged FAIL-CLOSED (a non-boolean override is logged and reads as `false`; it never enables anything).
   CHECK: cd mods/model-router && grep -q "mainModelSwitch: true," hooks/register.ts && grep -q 'config "mainModelSwitch" is not a boolean' hooks/register.ts && echo CRIT2-OK
   EXPECT: CRIT2-OK
   EVIDENCE: MET exit=0 marker-found :: CRIT2-OK
3. Both caps measure the COLD READ of the target model (context tokens minus the tokens at that model's last main step when it served within `CACHE_TTL_MS` = 1 h; the whole context when never served, expired, or when the context is SMALLER than the record (compaction: entry dropped); unknown size = blocked): `upgradeCall` and `leaveDown` against `upgradeMaxTokens`, `downgradeCall` against `downgradeMaxTokens`, through ONE helper (`coldBlock`). The served record is written on EVERY main step (routed or not), kept across turn ends, NOT kept across `/clear`, reset by `/route reload`. A downgrade refusal keeps `switch off` first, then logs `downgrade skipped: cold read N tokens over M` / `downgrade skipped: context size unknown` once per cap crossing (until a downgrade next succeeds). No "return bypass" exists.
4. In `decideMain`, main routed onto a model whose known window (`windows`) the context has outgrown returns to the session model (once-log) when the size is known and the session model is a known, ranked, not-down, non-haiku id; otherwise the normal decision runs. `moveTo` carries `[1m]` when `cur` OR the session model has it (haiku excepted).
5. The prompt classifier writes the full phase route (`tier` + `effort`); the model name comes from the first slot carrying one, and when that slot is the classifier's: a floor with a model wins over it, and a wanted that ranks above the SESSION model is dropped (a guess never moves main above the user's baseline; a breaker fallback from a guessed sonnet reaches opus, never haiku). So `coding`/`bookkeeping` move main down under the switch and the cold-read cap while `design`/`analysis` only set effort; `chat`/unknown route nothing. `userMovedEffort` compares this turn's first engine effort with the previous turn's; when true, `mainPlan` drops a classifier route for THIS turn only (both axes, `turnModel` untouched, texts agree); the next classified turn routes again. A user `/model` is NOT a guard (baseline moves). In-file comments at the classifier (~l.3438-3441, 3535, 3546) state the new rule.
6. A model-loaded (not typed) skill row whose resolved model ranks below the run slot's resolved model moves effort only while `runMain` is set; typed skills and best-tier rows unchanged.
7. `/route show` prints `switch: on (downgrade, cap 120000 tokens cold)` / `switch: off (downgrade)`; the status line shows ` · switch off` only when the switch is off [gated 2026-10-13]; the toast hint names a cap hold (`, held: <why>`) as well as the switch.
8. Tests in `hooks/register.test.ts`: (a) downgrade under the cold-read cap by default; (b) above the cap keeps main, one log; (c) unknown usage blocks; (d) warm model cheap to return to, with a control (cold opus blocked at the same size); (e) classifier coding → sonnet/medium; (f) classifier coding above the cap → fable/medium; (g) `switch off` restores today's behavior; (h) user `/effort` drops the model guess, `/route show` agrees; (i) design guess never moves a sonnet session up; (j) model-loaded helper skill in a run moves effort only; (k) haiku outgrown returns to the session model; (l) quoted "false" switch reads as off with a warning; (m) cap hold toast hint; (n) TTL expiry; (o) reload forgets the record + skip line once per cap crossing across turns; (p) smaller context than the record is cold; (q) mid-turn ultrathink floor beats a guess; (r) guessed sonnet rate-limited falls to opus never haiku; (s) a user /effort drops the guess for one turn only. The tests the default flip invalidates (plan § Tests list, incl. l.305-315, 605-614, 747, 754, 951-958, 1665-1672, 2934-2943, 4576, 4783-4799, status-line `switch on` assertions) are re-expressed with an explicit `switch off`, never weakened or deleted; a mutable-usage rig uses ONE bottom `session.usage` hook.
9. The whole mod test suite passes.
   CHECK: make test suite=lib/tests/mods.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
10. `lib/effort-shift.md` Limits bullet about the classifier says the guess may move the model DOWN under `mainModelSwitch` and `downgradeMaxTokens`, never up, and that a user `/model` moves the baseline; no longer "effort only".
   CHECK: ! grep -q "classifier (effort only;" lib/effort-shift.md && grep -q "downgradeMaxTokens" lib/effort-shift.md && echo CRIT10-OK
   EXPECT: CRIT10-OK
   EVIDENCE: MET exit=0 marker-found :: CRIT10-OK

## FILE SCOPE
- mods/model-router/hooks/register.ts
- mods/model-router/hooks/register.test.ts
- lib/effort-shift.md
(README.md l.144/146 and USAGE.md l.190 handled by STEP 6 doc-sync, out of the executor's scope)
