# CONTRACT — model-router-w3b-dialog
- date: 2026-10-11 | flow: feat | branch: feature/model-router-confirm (continues W3-A before its merge)
- status: active

## REQUEST (verbatim — IMMUTABLE)
j'aimerais qu'on vois pour que quand je le prompt de demande de confirmation ou changement pour un model et un effort, il faudrait qu'il soit un peu plus complet. par exemple expliquer brievement ce que fait ce pour quoi on demqnde de choisir plutot que juste le nom. car juste verifier en vrai ca peut etre pleins de chose, ou dire feature : auditor. car c'est pas tres clair on sait pas pour quoi on prend la decision. Surtout que lam auditor security je croism ca proposait sonnet alors que nonm un audit securite ca devrait etre le plus performant du model. bref metre un peu de contextm dire oui ca me vam ou changer et si on choisis de changerm proposer quel model puis quel effort, puis pour userscope et projet ca c'est bien, et l'enregistrer.

## CLARIFICATIONS
(pass A: none — outcome, scope and flow given in the request; W3-A contract and plan r4 give the base)
Q: public shape (orchestrator default after three lenses, user may veto): ASK1 options Later / Keep / Change; ASK2 model = the four aliases labelled with their tier role (`fable (best)`, `opus (big)`, `sonnet (work)`, `haiku (cheap)`; Other = Later); ASK3 effort = the efforts offered by the phases headed by that model (fable: medium high xhigh max; opus: xhigh, skipped; sonnet: low medium high xhigh; haiku: low, skipped); the pair maps to that phase (rows stay phase names; a pair no phase offers is added by hand as a new phase in routing.json); ASK4 scope as W3-A; T3 (main-loop phase) = Later / Keep with context, no edit (BDR-116) [stated 2026-10-11]

Q: live decisions during this run (plan-challenger judge → verify Everywhere; orchestrate phase Keep = the T3 live check) / A: user "Revenir à judge" → row reset, its confirmed/changed entries removed; orchestrate Keep kept [gated 2026-10-11]
Q: live W3-B dialog answered during the security scan: security-auditor → Change → opus → xhigh → Everywhere = row `judge` (the request's own example; the first T2 answer through the new dialog) / A: kept; my reset of `changed` had wiped its from/to entry (census red at 604a6c4) → restored in the follow-up data commit [gated 2026-10-11]
Q: GATE 1 ran 3 verifiers (ECARTS(2) coverage → ECARTS(1) one non-discriminating test → CONFORME), security PASS (4 LOW) [recorded 2026-10-11]

## ACCEPTANCE CRITERIA
1. ASK1 text carries context: for a skill row "`/<name>` — <description ≤ 140 chars from the SKILL.md frontmatter, five YAML forms, first sentence>. Routed to <phase> (<about>): <model id> at <effort>. OK?"; for an agent row "`<name>` — <description from agent.offer ≤ 140 chars>. Routed to …"; for a phase "Phase `<name>` — <about>; used by <n> rows [+ its non-row consumers]: <model id> at <effort>. OK?"; descriptions and `about` pass `clean()` (Cc/Cf stripped, newlines folded, code-point truncation with "…"); a missing or unreadable description, an unset HOME or a name outside `^[A-Za-z0-9][A-Za-z0-9._:-]*$` degrades to the name alone (never blocks, never reads outside `${HOME}/.claude/skills/<name>/SKILL.md`, stat kind `file`, size-capped). Options: Later / Keep / Change (T3: Later / Keep); Other at ASK1 = Later + toast. One kit test per clause.
2. Change flow (rows only): ASK2 model = four fixed labels (Other or unknown = Later + toast); ASK3 effort = the efforts of the phases headed by the chosen alias, sorted ascending by level (≤ 4 labels, one → skipped, zero → Later + toast; Other = Later); target phase = the row's current phase when it matches, else the first matching phase in `cfg.phases` order; same phase as now = Keep (no `changed` entry); ASK4 as W3-A ([Everywhere, This project only], or [Everywhere, Later] with no repo key); any non-matching answer = Later, nothing written; storage as W3-A (`changed` from/to strings, `confirmed` = to); the new route applies to the current decision at once; after a main-row change the toast reports the real decision and the `/route switch on` hint when the pick is a downgrade. T3 never changes anything. One kit test per clause.
3. Rows stay phase names in every layer; `ALTS`, the alt options and the free-text phase branch of the W3-A dialog are removed (no dead code); the W3-A dialog tests are migrated to the new answers and every existing test stays green.
   CHECK: ! grep -qE 'ALTS\b' mods/model-router/hooks/register.ts && echo W3B-NO-ALTS
   EXPECT: W3B-NO-ALTS
   EVIDENCE: MET exit=0 marker-found :: W3B-NO-ALTS
4. `routing.json` phases gain an `about` string (≤ 120 chars) for the 11 phases, loaded into a separate map (never on `Route`, never in `DEFAULT_CONFIG`), a non-string or overlong value dropped + logged once; descriptions never read from the project tree.
   CHECK: bash .claude/tasks/contracts/w3b-about.sh
   EXPECT: W3B-ABOUT
   EVIDENCE: MET exit=0 marker-found :: W3B-ABOUT
5. Census unchanged and green (rows are phases; the DEFAULT == file phase lock keeps matching with `about` present); `lib/effort-shift.md` dialog lines updated (≤ 4 lines changed, Later/Keep/Change and the model-then-effort flow named).
   CHECK: bash lib/tests/effort-routing.test.sh >/dev/null 2>&1 && grep -q 'Change' lib/effort-shift.md && [ "$(wc -l < lib/effort-shift.md)" -le 66 ] && echo W3B-CENSUS
   EXPECT: W3B-CENSUS
   EVIDENCE: MET exit=0 marker-found :: W3B-CENSUS
6. Kit suite, mods suite and validate green.
   CHECK: cd mods/model-router && out="$(claude plugin test . 2>&1)" && printf '%s\n' "$out" | grep -qE '[0-9]+ pass' && ! printf '%s\n' "$out" | grep -qE '[1-9][0-9]* fail' && claude plugin validate . 2>&1 | grep -q 'passed' && cd ../.. && make test suite=lib/tests/mods.test.sh 2>&1 | grep -q 'all suites green' && echo W3B-MOD-GREEN
   EXPECT: W3B-MOD-GREEN
   EVIDENCE: MET exit=0 marker-found :: W3B-MOD-GREEN
7. Security posture unchanged: writers, paths, caps, no model-originated write; descriptions truncated and control characters stripped before they enter a question. Judged by reading + one kit test (a description with control characters and 500 chars → ≤ 140 clean chars).

## FILE SCOPE
mods/model-router/routing.json, mods/model-router/hooks/register.ts, mods/model-router/hooks/register.test.ts, lib/tests/effort-routing.test.sh, lib/effort-shift.md; .claude/tasks/contracts/w3b-about.sh (oracle, orchestrator)
