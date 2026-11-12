# CONTRACT — router-haiku-effort
- date: 2026-10-25 | flow: bugfix | branch: bugfix/router-haiku-effort (from develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
model-router haiku effort strip (BLK-035 residual, TODO "/bugfix model-router haiku effort strip"): Haiku 5.5 takes effort (low–max, default medium, claude-api model table) but the mod still applies the Haiku 4.5 rule "haiku takes no effort": effort omitted on every haiku step (register.ts step plan ~l.3820 `startsWith(HAIKU) → effort: undefined`), `effortWord` prints "- (haiku takes none)" (~l.1824), isHaiku sites (~l.1372, 3550, 3703, 4095, 4267), census skip `lib/tests/effort-routing.test.sh:170`. Symptom: the `mechanical` phase (cheap tier, effort low) runs status-reporter on haiku at the engine default medium, not low.

## CLARIFICATIONS
- [gated 2026-10-25] Fix approved with challenge (user).
- [gated 2026-10-25] Haiku 5.x behaves like any model (user pick): routes, prompt keywords, sticky effort and session effort apply; reverses the 2026-10-23 edge "haiku session → keywords no-op".
- [after the challenge] The no-effort guard is kept, scoped to Haiku 4.x (`claude-haiku-4` prefix after `canonical`): 4.5 is still served and takes no effort, reachable by override or full id.

## ACCEPTANCE CRITERIA
1. On a Haiku 5.x model (`claude-haiku-5-5`), a routed main step and a spawned agent's steps carry the route's effort (`mechanical` → `low`); `/route show` prints that effort, not "takes none"; an unrouted step passes the engine effort unchanged.
2. On Haiku 4.x (`models.haiku` overridden to `claude-haiku-4-5-20251001`), steps still carry no effort and `/route show` says `haiku 4 takes none`.
3. The no-effort rule is keyed on a version-named constant (`claude-haiku-4`), not on the family prefix `claude-haiku`, at every effort site (planStep, handoffOf, the loop.last condition, effortWord).
   CHECK: python3 -I -c "import re;s=open('mods/model-router/hooks/register.ts').read();a=s.count(\"'claude-haiku-4'\");b=len(re.findall(r'haiku takes none',s));print('guard=%d/%d'%(min(a,1),b))"
   EXPECT: guard=1/0
   EVIDENCE: MET exit=0 marker-found :: guard=1/0
4. Tests in register.test.ts: the three former omission assertions now expect the phase effort; new tests for Haiku 4.x keeping the strip, the unrouted passthrough, a `plan` keyword on a haiku-5-5 session → xhigh, an unrowed haiku spawn (hand-off `haiku/-`, first step silent), `/route show` on haiku-5-5.
5. Census: the haiku skip at lib/tests/effort-routing.test.sh is gone and agents/status-reporter.md declares `effort: low`.
   CHECK: a=$(grep -c 'field_of "$RD" "$phase" model)" = haiku' lib/tests/effort-routing.test.sh); b=$(awk 'NR==1&&/^---$/{p=1;next} p&&/^---$/{exit} p' agents/status-reporter.md | grep -c '^effort: low$'); echo "census=$a/$b"
   EXPECT: census=0/1
   EVIDENCE: MET exit=0 marker-found :: census=0/1
6. README.md no longer says haiku takes no effort.
   CHECK: echo "readme=$(grep -c 'none on haiku' README.md)"
   EXPECT: readme=0
   EVIDENCE: MET exit=0 marker-found :: readme=0
7. Mod suite green.
   CHECK: make test suite=lib/tests/mods.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
8. Full suite green (census included).
   CHECK: make test 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
9. Diff touches only the FILE SCOPE.
   CHECK: git diff --name-only develop -- . ':!.claude' | grep -vcE '^(mods/model-router/hooks/register.ts|mods/model-router/hooks/register.test.ts|lib/tests/effort-routing.test.sh|agents/status-reporter.md|README.md)$' | sed 's/^/n=/'
   EXPECT: n=0
   EVIDENCE: MET exit=0 marker-found :: n=0
10. No new lint or test suppression.
   CHECK: git diff -U0 develop -- . ':!.claude' | grep -E '^\+' | grep -cE 'eslint-disable|@ts-ignore|@ts-expect-error|shellcheck disable' | sed 's/^/n=/'
   EXPECT: n=0
   EVIDENCE: MET exit=0 marker-found :: n=0

## FILE SCOPE
- mods/model-router/hooks/register.ts
- mods/model-router/hooks/register.test.ts
- lib/tests/effort-routing.test.sh
- agents/status-reporter.md
- README.md (l.124 only)
