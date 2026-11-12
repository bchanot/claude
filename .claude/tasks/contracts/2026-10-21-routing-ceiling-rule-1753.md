# CONTRACT — routing-ceiling-rule (feat B of the routing policy, BLK-032)

## REQUEST (verbatim, feat B scope)
ceiling rule in CLAUDE.global.md: main loop on Fable never writes code beyond a hotfix-sized edit, it dispatches an executor; new BDR superseding the affected parts of BDR-066 and BDR-115; README doctrine sentences (deferred P2/P3 of feat A); `skills/deploy/SKILL.md` effort aligned with its `verify` row.

## CLARIFICATIONS
- [gated 2026-10-21] Short wording (user pick): the rule names the ceiling only; the model split lives in the BDR and routing.json.
- [gated 2026-10-21] Budget (user pick): compact the Sub-agents bullet so CLAUDE.global.md stays at 320 lines.
- [gated 2026-10-21, fitted wording acked by user] Fitted text cites the `/hotfix` scope (defined at CLAUDE.global.md:80 as "≤2 files, obvious fix"); "multi-file" dropped from "wide multi-file exploration"; "whatever the task size" → "even small". Safety sentences of the bullet unchanged word for word.
- [gated 2026-10-21, after the challenge] Dispatch target (user pick): "it hands it to /feat or /bugfix". To keep 320 lines, "main context stays clean" (rationale of "one task each") is dropped.
- [gated 2026-10-21, after the challenge] Best-tier skills that write code inline (design Build stack, writing-skills, deprecation-and-migration, /tour single-project, /harden STEP 3) are a declared temporary exception recorded in BDR-123 [deferred] (user pick); no skill file changes here.
- [gated 2026-10-21, after round 2] The keyword prompt-rule lift to Fable (unwitnessed) is a known gap closed by a feat C right after (keyword rules capped at the session model); BLK-032 stays open until then (user pick).
- [gated 2026-10-21, executor NEED-DECISION] Criterion 8 = no regression vs develop: CLI 2.1.306 adds advisory plugin-directory warnings (ICON_MISSING) that mods.test.sh:57 counts as failure; develop's copy fails identically. Fixed by a separate /bugfix on the suite (user pick).
- Internal: deploy's `changed` entry is dropped (the floor now follows the row; a stale `from: apply` would make `/route forget` turn the census red). Session-model citers: lib/challenge-plan.md:47-48, agents/plan-challenger.md:111, README.md:95. README's enforcement clause is anchored to the model floor ("The Fable/Opus model floor is enforced"), since model-gate.md checks the model id, not the ceiling.
- Internal: BDR-123 is written at CAPITALIZE (memory), not by the executor.

## ACCEPTANCE CRITERIA
1. The Sub-agents bullet of CLAUDE.global.md equals the fitted text in `.claude/tasks/plans/2026-10-21-routing-ceiling-rule-1753.bullet.txt` byte for byte.
   CHECK: python3 -I -c "s=open('CLAUDE.global.md').read();b=open('.claude/tasks/plans/2026-10-21-routing-ceiling-rule-1753.bullet.txt').read();print('BULLET ok' if s.count(b)==1 else 'BULLET missing')"
   EXPECT: BULLET ok
   EVIDENCE: MET exit=0 marker-found :: BULLET ok
2. CLAUDE.global.md stays at 320 lines and no line exceeds 80 columns in the edited range.
   CHECK: echo "n=$(wc -l < CLAUDE.global.md)/$(sed -n 49,58p CLAUDE.global.md | awk 'length($0)>80' | wc -l)"
   EXPECT: n=320/0
   EVIDENCE: MET exit=0 marker-found :: n=320/0
3. The rest of CLAUDE.global.md is unchanged: the diff touches only lines 49-58.
   CHECK: git diff -U0 develop -- CLAUDE.global.md | grep -E '^@@' | sed 's/ @@.*//' | tr '\n' '|' | sed 's/^/[/; s/$/]/'
   EXPECT: [@@ -49,10 +49,10|]
   EVIDENCE: MET exit=0 marker-found :: [@@ -49,10 +49,10|]
4. The safety sentences of the bullet survive word for word (whitespace-normalised).
   CHECK: tr '\n' ' ' < CLAUDE.global.md | tr -s ' ' | grep -c 'A brief never authorizes a sub-agent to run a destructive tool (Security → Destructive tools & data loss) or to route around a guardrail: a refused command is reported with its rule, never rerun through a wrapper, alias, env file or other shell. Hermetic tests run through `make test \[suite=…\]` only.'
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
5. README.md "What it is" (l.15-17) reads "(haiku collects, sonnet executes, opus judges and runs the session, Fable plans and runs the merge gates)" and no longer says "the session model only reflects".
   CHECK: f=README.md; a=$(tr '\n' ' ' < $f | tr -s ' ' | grep -c '(haiku collects, sonnet executes, opus judges and runs the session, Fable plans and runs the merge gates)'); b=$(tr '\n' ' ' < $f | tr -s ' ' | grep -c 'the session model only reflects'); echo "$a/$b"
   EXPECT: 1/0
   EVIDENCE: MET exit=0 marker-found :: 1/0
6. README.md "Agent model routing" doctrine sentence no longer claims "the session model (Fable)" nor puts gates in the main loop, names the ceiling, keeps the model-gate clause anchored to the model floor, and the edited lines stay ≤80 columns.
   CHECK: f=README.md; t=$(tr '\n' ' ' < $f | tr -s ' '); a=$(printf '%s' "$t" | grep -c 'the session model (Fable)'); b=$(printf '%s' "$t" | grep -c 'Doctrine: the main loop runs on the `opus` session model; the model-router rows lift it to Fable for main-loop reflection ONLY: brainstorm, plan, contract, audit judgment, loop decisions. On Fable it writes no code past the `/hotfix` scope; the fresh gates run as dispatched agents on the `audit` row. The Fable/Opus model floor is enforced by a blocking gate (`lib/model-gate.md`) at the entry of the 17 reflection skills'); c=$(awk '/^## Agent model routing/{p=1} /^\| Agent/{p=0} NR>=14&&NR<=19{print;next} p' $f | awk 'length($0)>80' | wc -l); echo "$a/$b/$c"
   EXPECT: 0/1/0
   EVIDENCE: MET exit=0 marker-found :: 0/1/0
7. `skills/deploy/SKILL.md` frontmatter `effort: xhigh` (its `verify` row), and the census no longer warns floor drift on deploy.
   CHECK: a=$(awk 'NR==1&&/^---$/{p=1;next} p&&/^---$/{exit} p' skills/deploy/SKILL.md | grep -c '^effort: xhigh$'); b=$(make test suite=lib/tests/effort-routing.test.sh 2>&1 | grep -c 'floor drift: skills/deploy'); echo "$a/$b"
   EXPECT: 1/0
   EVIDENCE: MET exit=0 marker-found :: 1/0
8. Full suite green, except the pre-existing `lib/tests/mods.test.sh` failure "validate printed a warning" (CLI 2.1.306 directory-check ICON_MISSING, reproduced on develop's copy of the mod 2026-10-21; separate /bugfix): exactly that one suite red, and the only FAIL lines are that check and the suite's own summary line.
   CHECK: o=$(make test 2>&1); echo "[$(printf '%s\n' "$o" | grep -c 'suite(s) red: lib/tests/mods.test.sh$')$(printf '%s\n' "$o" | grep -cE '^ *FAIL ' | sed 's/^2$/ok/')$(printf '%s\n' "$o" | grep -c 'FAIL model-router: validate printed a warning')]"
   EXPECT: [1ok1]
   EVIDENCE: MET exit=0 marker-found :: [1ok1]
9. No new lint or test suppression in the diff (floor-guard clean).
   CHECK: git diff -U0 develop -- . ':!.claude' | grep -E '^\+' | grep -cE 'shellcheck disable|noqa|eslint-disable|@ts-ignore|@ts-expect-error' | sed 's/^/n=/'
   EXPECT: n=0
   EVIDENCE: MET exit=0 marker-found :: n=0
10. The diff touches only the FILE SCOPE.
   CHECK: git diff --name-only develop -- . ':!.claude' | grep -vcE '^(CLAUDE.global.md|README.md|skills/deploy/SKILL.md|mods/model-router/routing.json|lib/challenge-plan.md|agents/plan-challenger.md)$' | sed 's/^/n=/'
   EXPECT: n=0
   EVIDENCE: MET exit=0 marker-found :: n=0
11. routing.json: `changed` holds no deploy entry, `skills.deploy` and `confirmed.skills.deploy` stay `verify`, nothing else in the file changes.
   CHECK: python3 -I -c "import json,subprocess;d=json.load(open('mods/model-router/routing.json'));o=json.loads(subprocess.run(['git','show','develop:mods/model-router/routing.json'],capture_output=True,text=True).stdout);assert 'deploy' not in d['changed'].get('skills',{}) and d['skills']['deploy']=='verify' and d['confirmed']['skills']['deploy']=='verify';o['changed']['skills'].pop('deploy');o['changed']={k:v for k,v in o['changed'].items() if v};assert d==o;print('ROUTING ok')"
   EXPECT: ROUTING ok
   EVIDENCE: MET exit=0 marker-found :: ROUTING ok
12. The three session-model citers are patched: lib/challenge-plan.md ("off the main loop. The main loop (Fable through its best-tier row) keeps only this loop"), agents/plan-challenger.md ("the main loop, on Fable through its best-tier row, stays inline"), README.md:95 ("inline-load = the main loop's model"); the old phrases are gone (whitespace-normalised).
   CHECK: n(){ tr '\n' ' ' < "$1" | tr -s ' ' | grep -c "$2"; }; echo "[$(n lib/challenge-plan.md 'The session model (Fable)')$(n lib/challenge-plan.md 'off the main loop. The main loop (Fable through its best-tier row) keeps only this loop')$(n agents/plan-challenger.md 'the session model stays on the inline loop')$(n agents/plan-challenger.md 'the main loop, on Fable through its best-tier row, stays inline')$(n README.md 'inline-load = session model')$(n README.md "inline-load = the main loop's model")]"
   EXPECT: [010101]
   EVIDENCE: MET exit=0 marker-found :: [010101]

## FILE SCOPE
- CLAUDE.global.md
- README.md
- skills/deploy/SKILL.md
- mods/model-router/routing.json
- lib/challenge-plan.md
- agents/plan-challenger.md
