# CONTRACT — routing-audit-phase (feat A of the routing policy, BLK-032)

## REQUEST (verbatim, feat A scope after the 2026-10-21 scope split)
model-router `judge` level split: security-auditor and verifier gates → Fable, plan-challenger / analyzer / code review → opus; executors stay sonnet. Citers census: skills/agents/lib rows that name the judge level must be patched in the same commit (make test runs the census). Feat B (settings model, CLAUDE.global.md ceiling rule, BDR) is a separate run.

## CLARIFICATIONS
- [gated 2026-10-21] New phase name: `audit` (user pick over `gate`), tier `best`, effort `xhigh`.
- [gated 2026-10-21, amended after the challenge] Scope split: feat A = router + agent floors + census + citers, preceded on the feature branch by one dedicated commit of the pre-existing routing.json (router dialog writes) and settings.json (session model `opus`) diffs; feat B = CLAUDE.global.md ceiling rule, BDR, docs.
- Internal: `confirmed.agents` for verifier and security-auditor set to `audit` by hand (this feat is the user's confirmation; no dialog re-fire). The `about` lines of `judge` and `verify` drop the words that now describe `audit`.
- [gated 2026-10-21] Outage floor: the gates keep `model: opus` in frontmatter (inTier never writes below the tier head; a fable floor would spawn on a dead Fable during a credit outage). The census gets a named carve-out: a best-tier agent row floors on the tier's second alias.
- [gated 2026-10-21] Scope: 11 files in one /feat run (user call over /ship-feature after the challenge).
- Internal: no stash. The pre-existing diffs on `mods/model-router/routing.json` (router dialog writes) and `settings.json` (session model `opus`) are committed first on the feature branch as one dedicated commit, before the executor runs.
- Internal: `confirmed.phases.audit` is NOT written: the first-use dialog stays as the tripwire against a main-loop `route(phase="audit")`.
- Internal: feature branch `feature/routing-audit-phase` started from the lib off develop before any commit.

## ACCEPTANCE CRITERIA
1. routing.json has the `audit` phase: tier best, effort xhigh, the exact about "the fresh gates: contract verdict and security scan; dispatched agents, not a main-loop phase", placed right after `judge`.
   CHECK: python3 -I -c "import json;d=json.load(open('mods/model-router/routing.json'));p=d['phases'];k=list(p);a=p['audit'];assert a['tier']=='best' and a['effort']=='xhigh' and a['about']=='the fresh gates: contract verdict and security scan; dispatched agents, not a main-loop phase' and k[k.index('judge')+1]=='audit';print('AUDIT-PHASE ok')"
   EXPECT: AUDIT-PHASE ok
   EVIDENCE: MET exit=0 marker-found :: AUDIT-PHASE ok
2. register.ts DEFAULT_CONFIG phases carry the same `audit` line, right after `judge`.
   CHECK: grep -n -A1 "^    judge: { tier: 'big', effort: 'xhigh' }," mods/model-router/hooks/register.ts | grep -c "audit: { tier: 'best', effort: 'xhigh' },"
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
3. routing.json rows `agents.verifier` and `agents.security-auditor` are `audit`, so are their `confirmed.agents` entries; `confirmed.phases` has NO `audit` key (first-use dialog kept for main).
   CHECK: python3 -I -c "import json;d=json.load(open('mods/model-router/routing.json'));assert all(t[n]=='audit' for t in (d['agents'],d['confirmed']['agents']) for n in ('verifier','security-auditor'));assert 'audit' not in d['confirmed']['phases'];print('ROWS ok')"
   EXPECT: ROWS ok
   EVIDENCE: MET exit=0 marker-found :: ROWS ok
4. `agents/verifier.md` and `agents/security-auditor.md` frontmatter read `model: opus` and `effort: xhigh` (opus = outage floor of the best tier).
   CHECK: for f in agents/verifier.md agents/security-auditor.md; do awk 'NR==1&&/^---$/{p=1;next} p&&/^---$/{exit} p' "$f" | grep -cE '^(model: opus|effort: xhigh)$'; done | tr '\n' ' '
   EXPECT: 2 2 
   EVIDENCE: MET exit=0 marker-found :: 2 2
5. The `judge` and `verify` `about` lines no longer claim audits or security review: judge = "independent judgment of work: challenges, analyses and reviews", verify = "checking a result against its spec: tests and suites".
   CHECK: grep -c '"about": "independent judgment of work: challenges, analyses and reviews"\|"about": "checking a result against its spec: tests and suites"' mods/model-router/routing.json
   EXPECT: 2
   EVIDENCE: MET exit=0 marker-found :: 2
6. `lib/tests/model-routing.test.sh` locks the new floors (`agents/verifier.md` `model: opus`, `agents/security-auditor.md` `model: opus`, both commented as the audit row) and no longer locks `verifier.md` on sonnet.
   CHECK: a=$(grep -c "has \"agents/verifier.md\" *'model: opus'.*audit\|has \"agents/security-auditor.md\" *'model: opus'.*audit" lib/tests/model-routing.test.sh); b=$(grep -c "verifier.md\" *'model: sonnet'" lib/tests/model-routing.test.sh); echo "$a/$b"
   EXPECT: 2/0
   EVIDENCE: MET exit=0 marker-found :: 2/0
7. Census suites green: `make test suite=lib/tests/effort-routing.test.sh` and `make test suite=lib/tests/model-routing.test.sh` exit 0.
   CHECK: make test suite=lib/tests/effort-routing.test.sh >/dev/null 2>&1 && make test suite=lib/tests/model-routing.test.sh >/dev/null 2>&1 && echo CENSUS-GREEN
   EXPECT: CENSUS-GREEN
   EVIDENCE: MET exit=0 marker-found :: CENSUS-GREEN
8. Mod suite green and not skipped: `make test suite=lib/tests/mods.test.sh` exits 0 and reports `plugin test passed` for model-router (the CLI is present on this machine).
   CHECK: make test suite=lib/tests/mods.test.sh 2>&1 | grep -c 'model-router: plugin test passed'
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
9. `register.test.ts` carries the `audit` phase in `baseRouting()`, the `pending confirmation` counts 20 and 18, and two audit-row cases: fable already down → no write + log `tier best down, frontmatter model kept`; first spawn on fable then `rate_limit` → the retry writes nothing (`[FABLE, undefined]`).
   CHECK: f=mods/model-router/hooks/register.test.ts; a=$(grep -c "^    audit: { tier: 'best', effort: 'xhigh' }," $f); b=$(grep -c "pending confirmation: 20'\|pending confirmation: 18'" $f); c=$(grep -c "tier best down, frontmatter model kept" $f); d=$(grep -c "toEqual(\[FABLE, undefined\])" $f); echo "$a/$b/$([ "$c" -ge 1 ] && echo ok)/$d"
   EXPECT: 1/2/ok/1
   EVIDENCE: MET exit=0 marker-found :: 1/2/ok/1
10. `lib/tests/effort-routing.test.sh` names the best-tier carve-out: a `tier_floor` helper returning the second alias for `best`, used by the model check, a comment naming BLK-030, and a flip test of the helper on the fixture (best → opus, big → opus).
   CHECK: f=lib/tests/effort-routing.test.sh; a=$(grep -c '^tier_floor()' $f); b=$(grep -c 'tier_floor "\$REG" "\$tier"' $f); c=$(grep -c 'BLK-030' $f); d=$(grep -c 'tier_floor "\$FIX/reg.ts" best\|tier_floor "\$FIX/reg.ts" big' $f); echo "$a/$b/$([ "$c" -ge 1 ] && echo ok)/$d"
   EXPECT: 1/1/ok/2
   EVIDENCE: MET exit=0 marker-found :: 1/1/ok/2
11. The four citers no longer claim sonnet gates: `agents/plan-challenger.md`, `lib/challenge-plan.md`, `skills/tour/SKILL.md`, `README.md` each carry the token `` `audit` row `` (whitespace-normalised, survives a reflow), the old sentences are gone, and README's phase list names `` `audit` best/xhigh `` (checked by the verifier, no oracle).
   CHECK: a=0; for f in agents/plan-challenger.md lib/challenge-plan.md skills/tour/SKILL.md README.md; do tr '\n' ' ' < "$f" | tr -s ' ' | grep -q '`audit` row' && a=$((a+1)); done; b=$(cat agents/plan-challenger.md lib/challenge-plan.md skills/tour/SKILL.md README.md | tr '\n' ' ' | tr -s ' ' | grep -o 'both sonnet, oracle-anchored\|The executor gates stay sonnet\|security-auditor (sonnet frontmatter)\|| verifier | sonnet (pinned)\|| security-auditor | opus (judge row' | wc -l); echo "$a/$b"
   EXPECT: 4/0
   EVIDENCE: MET exit=0 marker-found :: 4/0
12. Doctrine citers census green: `make test suite=lib/tests/doctrine-citers.test.sh` exits 0.
   CHECK: make test suite=lib/tests/doctrine-citers.test.sh >/dev/null 2>&1 && echo CITERS-GREEN
   EXPECT: CITERS-GREEN
   EVIDENCE: MET exit=0 marker-found :: CITERS-GREEN
13. `lib/challenge-plan.md` still states the challengers run on the `judge` row (opus): no edit needed, the statement stays true.
   CHECK: grep -c 'routed to the `judge` row (opus)' lib/challenge-plan.md
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
14. No new lint or test suppression in the diff (floor-guard clean).
   CHECK: git diff -U0 -- . ':!.claude' | grep -E '^\+' | grep -cE 'shellcheck disable|noqa|eslint-disable|@ts-ignore|@ts-expect-error' | sed 's/^/n=/'
   EXPECT: n=0
   EVIDENCE: MET exit=0 marker-found :: n=0
15. The diff touches only the FILE SCOPE: `git status --short` lists nothing outside it (the dialog-write and session-model diffs are committed before the executor runs).
   CHECK: git status --short -- . ':!.claude' | awk '{print $2}' | grep -vcE '^(mods/model-router/routing.json|mods/model-router/hooks/register.ts|mods/model-router/hooks/register.test.ts|agents/verifier.md|agents/security-auditor.md|lib/tests/model-routing.test.sh|lib/tests/effort-routing.test.sh|agents/plan-challenger.md|lib/challenge-plan.md|skills/tour/SKILL.md|README.md)$' | sed 's/^/n=/'
   EXPECT: n=0
   EVIDENCE: MET exit=0 marker-found :: n=0

## FILE SCOPE
- mods/model-router/routing.json
- mods/model-router/hooks/register.ts
- mods/model-router/hooks/register.test.ts
- agents/verifier.md
- agents/security-auditor.md (no edit expected: frontmatter already opus/xhigh)
- lib/tests/model-routing.test.sh
- lib/tests/effort-routing.test.sh
- agents/plan-challenger.md
- lib/challenge-plan.md
- skills/tour/SKILL.md
- README.md
