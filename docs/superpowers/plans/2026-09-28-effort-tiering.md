# Effort Tiering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route reasoning effort per role and per phase (low → max) across the claude-config orchestrators, instead of one session-wide `xhigh`.

**Architecture:** Effort becomes the second axis of the BDR-077 routing table. Three layers, each a one-line frontmatter mechanism the harness already honours: `effort:` pins on the 20 repo-authored agents (dispatched work), `effort:` on the 33 user-invoked skills (the run's entry level), and five empty "shifter" skills the orchestrators load at phase boundaries (`Skill(effort-<level>)`), including `max` at the loop caps and ship-feature error recovery. A census suite locks every value.

**Tech Stack:** bash, GNU sed, python3 stdlib, jq, shellcheck, `make test` (suites under `lib/tests/*.test.sh` are auto-discovered).

**Spec:** `docs/superpowers/specs/2026-09-28-effort-tiering-design.md` (read it first; every decision below is argued there, §2 holds the harness evidence, §3 the measurement).

## Global Constraints

- Claude Code ≥ 2.1.267 on the executing machine (skill/agent `effort:` honoured on Fable); the spike ran on 2.1.283.
- `CLAUDE_CODE_EFFORT_LEVEL` must be unset in every session that runs a smoke: it silences every frontmatter override.
- Branch `feature/effort-tiering` (exists, off develop). Every task ends with a commit on it; never `--no-verify`; never commit on develop/main; `gitflow finish` only on the human's signal.
- `make test` green after every task; `shellcheck *.sh hooks/*.sh lib/*.sh` clean after any shell edit.
- Allowed effort values, exactly: `low`, `medium`, `high`, `xhigh`, `max`. `max` never in `settings.json` (harness rejects it there).
- Never edit: `agents/impeccable-*.md`, `skills/graphify/**`, anything under `skills-external/`. The two vendored superpowers files edited (`skills/brainstorming/SKILL.md`, `skills/writing-plans/SKILL.md`) get a resync re-apply in Task 9.
- No new `CLAUDE.md "…"` citations anywhere (doctrine-citers census); the doctrine lives in `lib/`.
- `BDR-NEXT` is a literal token used in lib text and CHANGELOG until Task 10 computes the real id and replaces it. It must not survive Task 10.
- Shell: functions ≤ 25 logic lines, 80-char lines. Registry entries: English, caveman.
- Commit messages: no attribution lines.

## Review Focus

1. A run launched headless (`claude -p`, `claude agents`, SDK) never shifts: the include must say so, and the census locks that sentence (Task 5).
2. `CLAUDE_CODE_EFFORT_LEVEL` exported in the user's shell silently disables every pin and shift: the session banner must warn, tested by running the hook with the variable set (Task 2).
3. A nested skill at a different level (feat → commit-change at low) leaves the rest of the run at low: feat must re-assert `Skill(effort-high)` right after, locked by the census (Task 6).
4. An `effort:` on a model without effort support (haiku) is at best ignored: `status-reporter` must carry none, locked (Task 3).
5. A superpowers resync overwrites the vendored frontmatter: the census lock alarms, and install-plugins re-applies it (Task 9).

---

### Task 1: Census suite skeleton with flip-test and the settings lock

**Files:**
- Create: `lib/tests/effort-routing.test.sh`
- Test: itself (`make test suite=lib/tests/effort-routing.test.sh`)

**Interfaces:**
- Produces: helpers `has`, `lacks`, `fm`, `fm_effort`, `fm_has_effort <repo-path> <level>`, `fm_no_effort <repo-path>`, counters `pass`/`fail`, final line `effort-routing census: N pass, M fail`. Later tasks append `has`/`fm_has_effort` lines to this file, above the summary block.

- [ ] **Step 1: Write the suite with the flip-test and one real lock that fails today**

```bash
cat > lib/tests/effort-routing.test.sh <<'EOF'
#!/usr/bin/env bash
# lib/tests/effort-routing.test.sh — census: effort tiering (BDR-NEXT)
# agent pins, skill entry levels, shifter skills, orchestrator wiring, settings.
set -u
R="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
ok() { pass=$((pass+1)); }
ko() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
has()   { if grep -qF "$2" "$R/$1"; then ok; else ko "$1 missing: $2"; fi; }
lacks() { if grep -qF "$2" "$R/$1"; then ko "$1 must NOT contain: $2"; else ok; fi; }
# frontmatter = the lines between the first two '---' lines
fm() { awk 'NR==1&&/^---$/{p=1;next} p&&/^---$/{exit} p' "$1"; }
fm_effort() { fm "$1" | grep -E '^effort: (low|medium|high|xhigh|max)$' | head -1 | cut -d' ' -f2; }
fm_has_effort() {
  got="$(fm_effort "$R/$1")"
  if [ "$got" = "$2" ]; then ok; else ko "$1 frontmatter effort must be '$2', got '${got:-none}'"; fi
}
fm_no_effort() { if fm "$R/$1" | grep -q '^effort:'; then ko "$1 must NOT pin effort"; else ok; fi; }

# ── flip-test: the frontmatter reader must accept a valid level and reject an invalid one
FIX="$(mktemp -d)"; trap 'rm -rf "$FIX"' EXIT
printf -- '---\nname: good\neffort: xhigh\n---\nbody with effort: low in prose\n' > "$FIX/good.md"
printf -- '---\nname: bad\neffort: turbo\n---\n' > "$FIX/bad.md"
[ "$(fm_effort "$FIX/good.md")" = "xhigh" ] && ok || ko "flip: valid level not read"
[ -z "$(fm_effort "$FIX/bad.md")" ] && ok || ko "flip: invalid level accepted"
[ "$(fm "$FIX/good.md" | grep -c 'prose')" -eq 0 ] && ok || ko "flip: body leaked into frontmatter"

# ── 1) session default (spec D1)
has "settings.json" '"effortLevel": "high"'

# ── summary (later tasks insert their locks ABOVE this line)
printf 'effort-routing census: %d pass, %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
EOF
chmod +x lib/tests/effort-routing.test.sh
```

- [ ] **Step 2: Run it, expect the flip-test to pass and the settings lock to fail**

Run: `make test suite=lib/tests/effort-routing.test.sh`
Expected: `FAIL settings.json missing: "effortLevel": "high"` then `effort-routing census: 3 pass, 1 fail`, non-zero exit.

- [ ] **Step 3: Shellcheck**

Run: `shellcheck lib/tests/effort-routing.test.sh`
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add lib/tests/effort-routing.test.sh
git commit -m "test(effort): census suite skeleton with flip-test and settings lock"
```

---

### Task 2: Session default `high`, banner warning, live effort in the statusline

**Files:**
- Modify: `settings.json` (line with `"effortLevel"`)
- Modify: `hooks/session-start.sh` (after the line `unset _claude_real _repo_dir`, and after the banner's closing box line)
- Modify: `hooks/statusline.sh:36-41` (the `EFFORT=` block)
- Test: `lib/tests/effort-routing.test.sh`

**Interfaces:**
- Produces: banner line `⚠️  CLAUDE_CODE_EFFORT_LEVEL=<v> set: skill/agent effort pins ignored` when the variable is exported; statusline `effort: <live level>`.

- [ ] **Step 1: Add the two hook locks to the census (above the summary block)**

```bash
python3 - <<'PY'
p="lib/tests/effort-routing.test.sh"; s=open(p).read()
s=s.replace("# ── summary", """# ── 2) hooks: env-var warning + live effort in the statusline (spec D1, D5)
has "hooks/session-start.sh" 'CLAUDE_CODE_EFFORT_LEVEL'
has "hooks/statusline.sh" 'CLAUDE_EFFORT'

# ── summary""")
open(p,"w").write(s)
PY
```

- [ ] **Step 2: Run the suite, expect 3 failures (settings + two hooks)**

Run: `make test suite=lib/tests/effort-routing.test.sh`
Expected: three `FAIL` lines, non-zero exit.

- [ ] **Step 3: Set the session default to `high`**

```bash
sed -i 's/"effortLevel": "xhigh"/"effortLevel": "high"/' settings.json
git diff settings.json
```
Expected diff: exactly one changed line. If anything else moved (LRN-098: `/effort` and `/model` rewrite this file), `git checkout settings.json` and redo the sed.

- [ ] **Step 4: Banner warning in session-start.sh**

Insert after the line `unset _claude_real _repo_dir`:

```bash
python3 - <<'PY'
p="hooks/session-start.sh"; L=open(p).read().split("\n")
i=L.index("unset _claude_real _repo_dir")
L[i+1:i+1]=[
"",
"# Effort tiering (BDR-NEXT): this env var beats every skill/agent `effort:` pin.",
"EFFORT_WARN=\"\"",
"if [ -n \"${CLAUDE_CODE_EFFORT_LEVEL:-}\" ]; then",
"  EFFORT_WARN=\"⚠️  CLAUDE_CODE_EFFORT_LEVEL=${CLAUDE_CODE_EFFORT_LEVEL} set: skill/agent effort pins ignored\"",
"fi",
]
open(p,"w").write("\n".join(L))
PY
grep -n '└' hooks/session-start.sh
```
Expected: two lines, both plain `echo` statements (an early fix-hint box near l.32, the main banner near l.255). The python below inserts after the last one:

```bash
python3 - <<'PY'
p="hooks/session-start.sh"; L=open(p).read().split("\n")
i=max(k for k,l in enumerate(L) if "└" in l)
L.insert(i+1, '[ -n "$EFFORT_WARN" ] && printf \'%s\\n\' "$EFFORT_WARN"')
open(p,"w").write("\n".join(L))
PY
```

- [ ] **Step 5: Live effort in the statusline**

Replace the block from the comment `# Effort level from settings.json` through the `fi` that closes `if [ -f "$REPO/settings.json" ]; then`:

```bash
python3 - <<'PY'
p="hooks/statusline.sh"; s=open(p).read()
old_start=s.index("# Effort level from settings.json")
old_end=s.index("fi\n", s.index('jq -r \'.effortLevel', old_start))+3
new='''# Effort level: the live value when the harness exports it (skill/agent
# `effort:` shifts included, BDR-NEXT), else the persisted settings.json key
# (.effortLevel — set by /effort or manual edit; symlinked into ~/.claude).
EFFORT="${CLAUDE_EFFORT:-}"
if [ -z "$EFFORT" ] && [ -f "$REPO/settings.json" ]; then
  EFFORT=$(jq -r '.effortLevel // "?"' "$REPO/settings.json" 2>/dev/null)
fi
[ -z "$EFFORT" ] && EFFORT="?"
'''
open(p,"w").write(s[:old_start]+new+s[old_end:])
PY
sed -n 34,46p hooks/statusline.sh
```
Expected: the new block, no duplicate `EFFORT=` lines.

- [ ] **Step 6: Run the hook with the variable set, then the suites**

```bash
CLAUDE_CODE_EFFORT_LEVEL=medium bash hooks/session-start.sh 2>/dev/null | grep -c 'effort pins ignored'
bash hooks/session-start.sh 2>/dev/null | grep -c 'effort pins ignored'
shellcheck hooks/session-start.sh hooks/statusline.sh
make test suite=lib/tests/effort-routing.test.sh
```
Expected: `1`, then `0`, shellcheck silent, census all pass.

- [ ] **Step 7: Full test run and commit**

Run: `make test`
Expected: every suite green (curated-config-guard accepts a hand edit of settings.json).

```bash
git add settings.json hooks/session-start.sh hooks/statusline.sh lib/tests/effort-routing.test.sh
git commit -m "feat(effort): session default high, env-var warning, live effort in statusline"
```

---

### Task 3: Agent effort pins (spec D2)

**Files:**
- Modify: 20 files `agents/<name>.md` (line 5 is `model: sonnet` or `model: opus` in every one of them; `agents/scaffolder.md` already has `effort: high` on line 6)
- Modify: `skills/init-project/SKILL.md` (the sentence `(pin sonnet, effort high — BDR-077`)
- Test: `lib/tests/effort-routing.test.sh`

**Interfaces:**
- Produces: `effort: <level>` on line 6 of each pinned agent.

- [ ] **Step 1: Add the 23 locks to the census (above the summary block)**

```bash
python3 - <<'PY'
p="lib/tests/effort-routing.test.sh"; s=open(p).read()
locks="""# ── 3) agent pins (spec D2): one effort per agent file, judgment mode wins on mode-based agents
for a in hotfixer release-executor plugin-probe validator-analyzer; do fm_has_effort "agents/$a.md" low; done
for a in feater bugfixer code-cleaner onboarder scaffolder; do fm_has_effort "agents/$a.md" medium; done
for a in refactorer analyzer commit-changer doc-syncer handover-doc-writer; do fm_has_effort "agents/$a.md" high; done
for a in plan-challenger plugin-advisor verifier security-auditor seo-analyzer geo-analyzer; do fm_has_effort "agents/$a.md" xhigh; done
for a in interviewer client-handover-writer status-reporter; do fm_no_effort "agents/$a.md"; done
has "skills/init-project/SKILL.md" 'pin sonnet, effort medium'

# ── summary"""
open(p,"w").write(s.replace("# ── summary", locks))
PY
make test suite=lib/tests/effort-routing.test.sh | tail -1
```
Expected: `... 20 fail` (19 pins + the citer; the three `fm_no_effort` pass already).

- [ ] **Step 2: Apply the pins**

```bash
pin() { L=$1; shift; for a in "$@"; do
  sed -i "0,/^model: \(sonnet\|opus\)$/s//&\neffort: $L/" "agents/$a.md"; done; }
pin low    hotfixer release-executor plugin-probe validator-analyzer
pin medium feater bugfixer code-cleaner onboarder
sed -i 's/^effort: high$/effort: medium/' agents/scaffolder.md
pin high   refactorer analyzer commit-changer doc-syncer handover-doc-writer
pin xhigh  plan-challenger plugin-advisor verifier security-auditor seo-analyzer geo-analyzer
sed -i 's/(pin sonnet, effort high — BDR-077/(pin sonnet, effort medium — BDR-077/' skills/init-project/SKILL.md
grep -c '^effort:' agents/*.md | grep -v ':0' | grep -v impeccable | wc -l
```
Expected: `20`.

- [ ] **Step 3: Suites**

Run: `make test suite=lib/tests/effort-routing.test.sh && make test suite=lib/tests/model-routing.test.sh`
Expected: both green (the model locks read `model: sonnet` on line 5, untouched).

- [ ] **Step 4: Smoke, planted input, disk-verified**

From an interactive session in this repo, dispatch:
```
Agent(subagent_type="release-executor", description="effort pin smoke",
      prompt="Diagnostic only, no release work. Run exactly one bash command and report its raw output: echo CLAUDE_EFFORT=$CLAUDE_EFFORT")
```
Expected report: `CLAUDE_EFFORT=low`. Then read the subagent transcript:
```bash
f=$(ls -t ~/.claude/projects/-home-bchanot-Documents-claude/*/subagents/*.jsonl | head -1)
grep -o '"effort":"[a-z]*"' "$f" | sort | uniq -c
```
Expected: only `"effort":"low"`.

- [ ] **Step 5: Commit**

```bash
git add agents/*.md skills/init-project/SKILL.md lib/tests/effort-routing.test.sh
git commit -m "feat(effort): pin effort on the 20 repo-authored agents (BDR-077 second axis)"
```

---

### Task 4: Skill entry levels (spec D3) with a before/after measurement

**Files:**
- Modify: 31 files `skills/<name>/SKILL.md` (line 2 is `name: <name>` in every one of them; the two superpowers files are Task 9)
- Test: `lib/tests/effort-routing.test.sh`

**Interfaces:**
- Produces: `effort: <level>` on line 3 of each listed skill; the `lvl` helper reused by Task 9.

- [ ] **Step 1: Baseline measurement BEFORE the change (spec §9)**

```bash
S=/tmp/claude-1000/-home-bchanot-Documents-claude/e593bc78-da6b-469b-9d0c-08d1a4aa8373/scratchpad
mkdir -p "$S"; cd ~/Documents/claude
claude -p "/reconcile" --output-format json --allowedTools "Read" "Grep" "Glob" "Bash(git status:*)" "Bash(git log:*)" > "$S/ab-before.json" 2>/dev/null
python3 - "$S/ab-before.json" <<'PY'
import json,sys,glob,os
d=json.load(open(sys.argv[1])); sid=d["session_id"]
P=os.path.expanduser("~/.claude/projects/-home-bchanot-Documents-claude")
n=o=t=0; eff=set()
for line in open(f"{P}/{sid}.jsonl", errors="ignore"):
    r=json.loads(line)
    if r.get("type")!="assistant": continue
    u=r["message"].get("usage") or {}; n+=1; o+=u.get("output_tokens",0)
    t+=(u.get("output_tokens_details") or {}).get("thinking_tokens",0); eff.add(r.get("effort"))
print(f"BEFORE requests={n} output={o} thinking={t} effort={eff} duration_ms={d.get('duration_ms')}")
PY
```
Expected: one line, `effort={'high'}` (session default after Task 2). Keep the line for Task 10.

- [ ] **Step 2: Add the 31 locks to the census**

```bash
python3 - <<'PY'
p="lib/tests/effort-routing.test.sh"; s=open(p).read()
locks="""# ── 4) skill entry levels (spec D3): the user's invocation sets the run's level
for s in status commit-change release-candidate doc capitalize close reconcile deploy profile plugin-check; do fm_has_effort "skills/$s/SKILL.md" low; done
for s in gitflow prune-memory find-docs; do fm_has_effort "skills/$s/SKILL.md" medium; done
for s in feat hotfix bugfix refactor web-validate harden seo geo; do fm_has_effort "skills/$s/SKILL.md" high; done
for s in ship-feature init-project onboard tour audit-delta analyze code-clean client-handover spec skillify; do fm_has_effort "skills/$s/SKILL.md" xhigh; done

# ── summary"""
open(p,"w").write(s.replace("# ── summary", locks))
PY
make test suite=lib/tests/effort-routing.test.sh | tail -1
```
Expected: `... 31 fail`.

- [ ] **Step 3: Apply the levels**

```bash
lvl() { L=$1; shift; for s in "$@"; do
  sed -i "0,/^name: $s\$/s//&\neffort: $L/" "skills/$s/SKILL.md"; done; }
lvl low    status commit-change release-candidate doc capitalize close reconcile deploy profile plugin-check
lvl medium gitflow prune-memory find-docs
lvl high   feat hotfix bugfix refactor web-validate harden seo geo
lvl xhigh  ship-feature init-project onboard tour audit-delta analyze code-clean client-handover spec skillify
grep -l '^effort:' skills/*/SKILL.md | wc -l
```
Expected: `31`.

- [ ] **Step 4: Suites**

Run: `make test suite=lib/tests/effort-routing.test.sh && make test suite=lib/tests/skill-routing-census.test.sh`
Expected: both green.

- [ ] **Step 5: Measurement AFTER, same command as Step 1 with `ab-after.json` and the label `AFTER`**

Expected: `effort={'low'}`. Record both lines in the commit body; Task 10 turns them into the EVAL.

- [ ] **Step 6: Commit**

```bash
git add skills/*/SKILL.md lib/tests/effort-routing.test.sh
git commit -m "feat(effort): entry effort level on the 31 user-invoked skills (spec D3)" \
  -m "A/B /reconcile headless — <paste the BEFORE and AFTER lines>"
```

---

### Task 5: Shifter skills, `lib/effort-shift.md`, model-gate paragraph (spec D4)

**Files:**
- Create: `skills/effort-low/SKILL.md`, `skills/effort-medium/SKILL.md`, `skills/effort-high/SKILL.md`, `skills/effort-xhigh/SKILL.md`, `skills/effort-max/SKILL.md`
- Create: `lib/effort-shift.md`
- Modify: `lib/model-gate.md` (end of §4)
- Test: `lib/tests/effort-routing.test.sh`, `lib/tests/skill-routing-census.test.sh`

**Interfaces:**
- Produces: skill names `effort-low`, `effort-medium`, `effort-high`, `effort-xhigh`, `effort-max`; the include path `$HOME/.claude/lib/effort-shift.md`; the wiring vocabulary Tasks 6-8 insert: `Skill(effort-<level>)` lines with a trailing `# effort-shift: <reason>` comment.

- [ ] **Step 1: Locks (above the summary block)**

```bash
python3 - <<'PY'
p="lib/tests/effort-routing.test.sh"; s=open(p).read()
locks="""# ── 5) shifter skills + include (spec D4)
for l in low medium high xhigh max; do fm_has_effort "skills/effort-$l/SKILL.md" "$l"; has "skills/effort-$l/SKILL.md" "name: effort-$l"; done
has "lib/effort-shift.md" 'Headless sessions'
has "lib/effort-shift.md" 'Skill(effort-max)'
has "lib/effort-shift.md" 'never inside a dispatched agent'
has "lib/model-gate.md" 'lib/effort-shift.md'

# ── summary"""
open(p,"w").write(s.replace("# ── summary", locks))
PY
```

- [ ] **Step 2: Create the five shifters (descriptions pre-validated against the routing census, pairwise ≤ 0.03)**

```bash
mk() { mkdir -p "skills/effort-$1"; printf '%s\n' '---' "name: effort-$1" "description: $2" "effort: $1" '---' \
  "Effort shifted to $1 for the rest of this turn (lib/effort-shift.md). Continue with the caller's next step." \
  > "skills/effort-$1/SKILL.md"; }
mk low    "Bookkeeping shift. Lowers reasoning to the cheapest level for the rest of the turn: journal lines, memory commits, capitalize, release bookkeeping, status output."
mk medium "Orchestration shift. Standard reasoning between two dispatches: read a subagent report, pick the next step, relay a gate verdict, route a branch."
mk high   "Investigation shift. Deeper reasoning for diagnosis, LOCATE, contract drafting, refactor judgement inside feat, hotfix and bugfix runs."
mk xhigh  "Reflection shift. Deep reasoning for brainstorm, planning, challenge synthesis and audit verdicts before a human validation gate."
mk max    "Escalation shift. Maximum reasoning when a verify or security loop hits its cap, a gate fails twice, or error recovery starts in ship-feature."
```

- [ ] **Step 3: Write the include**

```bash
cat > lib/effort-shift.md <<'EOF'
# Effort shift — phase-level reasoning effort on the main loop (BDR-NEXT)

Shared include, companion of `lib/model-gate.md`: the gate fixes WHICH model
reflects, this include fixes HOW HARD each phase thinks. The rungs are the
user's: low (fix a line, run a script) · medium (day-to-day) · high
(refactor, resisting bug) · xhigh (architecture, audit before validation) ·
max (stuck error, judged need).

## Mechanics (verified on Claude Code 2.1.283)

- A skill's `effort:` frontmatter applies from the moment it loads to the
  end of the turn: on the user's `/skill` and on a `Skill(...)` call by
  Claude in an interactive session. Last loaded wins, both directions. The
  prompt cache survives a shift.
- Dispatched agents run on their own `effort:` pin, never on a shift.
  Unpinned agents inherit the level in force at dispatch.
- Headless sessions (`-p`, `claude agents`, SDK) ignore skill-level effort:
  the run stays at the session level. `CLAUDE_CODE_EFFORT_LEVEL` beats every
  frontmatter; keep it unset (the session banner warns).

## Shifters

`Skill(effort-low)` · `Skill(effort-medium)` · `Skill(effort-high)` ·
`Skill(effort-xhigh)` · `Skill(effort-max)`. One tool call, one-line body.
Typed by the user, `/effort-max` is a turn-scoped max: the relaunch lever
after a STOP. `ultrathink` only adds an in-context nudge; the API level
does not move.

## Wiring — per orchestrator

1. A dispatch span starts (executor, collector, fan-out) →
   `Skill(effort-medium)`.
2. Reflection resumes after a dispatch span (challenge synthesis, verdict,
   plan revision) → `Skill(effort-<the skill's own level>)`. Concretely:
   the line before every `lib/challenge-plan.md` call.
3. The bookkeeping tail (memory commit, doc commit) → `Skill(effort-low)`.
4. Escalation → `Skill(effort-max)`, then the skill's own level again once
   the diagnosis is produced. Automatic points: verify-secure loop caps
   (GATE 0 floor, GATE 1 conformity, GATE 2 security) and ship-feature
   STEP 4b. Not automatic, by doctrine: the challenge fail-safe (a mute
   challenger is an infrastructure failure) and "gone WRONG → STOP" (STOP
   precedes any further reasoning); their STOP text names the level
   reached and suggests `/effort-max` for the relaunch.

## Re-assert

- After any nested `Skill(...)` whose frontmatter carries a different
  effort (feat → commit-change), reload the orchestrator's own level.
- After a prose gate that ends the turn, the resumed turn runs at the
  session level. If the resumed phase is reflection, its first step is
  `Skill(effort-<own level>)`; dispatch and orchestration phases need
  nothing.

## Never

- A shift never inside a dispatched agent: pins rule there.
- Max is for diagnosis, not for retrying the same fix harder.
EOF
```

- [ ] **Step 4: Model-gate paragraph (append to §4)**

```bash
cat >> lib/model-gate.md <<'EOF'

Effort is the second axis of the same table (BDR-NEXT): every typed agent
carries an `effort:` pin next to `model:`, and the main loop shifts per phase
through `lib/effort-shift.md`. Nothing dispatched inherits either axis.
EOF
```

- [ ] **Step 5: Suites**

Run: `make test suite=lib/tests/effort-routing.test.sh && make test suite=lib/tests/skill-routing-census.test.sh && make test suite=lib/tests/profile-census.test.sh`
Expected: all green; the routing census prints no `effort-` pair under WARN.

- [ ] **Step 6: Main-session smoke (interactive session only, cannot be headless)**

In an interactive session in this repo, after `/reload-skills`: call `Skill(effort-max)`, then Bash `echo $CLAUDE_EFFORT`, then `Skill(effort-xhigh)`, then the echo again.
Expected: `max`, then `xhigh`. Transcript check for the cache:
```bash
f=~/.claude/projects/-home-bchanot-Documents-claude/$(ls -t ~/.claude/projects/-home-bchanot-Documents-claude/ | grep jsonl | head -1)
python3 -c "
import json,sys
for l in open('$f',errors='ignore'):
    r=json.loads(l)
    if r.get('type')=='assistant':
        u=r['message'].get('usage') or {}; print(r.get('effort'), u.get('cache_creation_input_tokens'), u.get('cache_read_input_tokens'))" | tail -6
```
Expected: the first `max` row has `cache_creation` in the low thousands and `cache_read` unchanged from the row before (no cache bust).

- [ ] **Step 7: Commit**

```bash
git add skills/effort-*/SKILL.md lib/effort-shift.md lib/model-gate.md lib/tests/effort-routing.test.sh
git commit -m "feat(effort): five shifter skills, lib/effort-shift.md, model-gate second axis"
```

---

### Task 6: Orchestrator wiring (include line, medium at dispatch, own level at challenge, low at the tail, nested re-assert)

**Files:**
- Modify: `skills/{feat,hotfix,bugfix,ship-feature,init-project,onboard,tour,code-clean,seo,geo,harden,web-validate,audit-delta}/SKILL.md`, `agents/client-handover-writer.md` (the client-handover skill loads this agent inline; its dispatches live there)
- Test: `lib/tests/effort-routing.test.sh`

**Interfaces:**
- Consumes: shifter names and the include path from Task 5.
- Produces: helpers `ins_before`, `ins_after`, `ins_after_para` (local to this task's shell).

- [ ] **Step 1: Locks (above the summary block)**

```bash
python3 - <<'PY'
p="lib/tests/effort-routing.test.sh"; s=open(p).read()
locks="""# ── 6) orchestrator wiring (spec D4)
for s in feat hotfix bugfix ship-feature init-project onboard tour code-clean seo geo harden web-validate audit-delta; do
  has "skills/$s/SKILL.md" 'lib/effort-shift.md'; has "skills/$s/SKILL.md" 'Skill(effort-medium)'; done
has "agents/client-handover-writer.md" 'lib/effort-shift.md'; has "agents/client-handover-writer.md" 'Skill(effort-medium)'
for s in feat hotfix bugfix; do has "skills/$s/SKILL.md" 'Skill(effort-high)'; done
for s in ship-feature init-project onboard code-clean audit-delta; do has "skills/$s/SKILL.md" 'Skill(effort-xhigh)'; done
for s in seo geo harden web-validate; do has "skills/$s/SKILL.md" 'Skill(effort-high)'; done
for s in feat hotfix bugfix ship-feature init-project; do has "skills/$s/SKILL.md" 'Skill(effort-low)'; done
has "skills/feat/SKILL.md" 'effort-shift: nested commit-change'

# ── summary"""
open(p,"w").write(s.replace("# ── summary", locks))
PY
```

- [ ] **Step 2: Define the three insertion helpers (exact-string anchors, first occurrence)**

```bash
ins_before() { python3 - "$1" "$2" "$3" <<'PY'
import sys; f,a,t=sys.argv[1:]; L=open(f).read().split("\n")
i=next(k for k,l in enumerate(L) if a in l); L[i:i]=t.split("\\n"); open(f,"w").write("\n".join(L))
PY
}
ins_after() { python3 - "$1" "$2" "$3" <<'PY'
import sys; f,a,t=sys.argv[1:]; L=open(f).read().split("\n")
i=next(k for k,l in enumerate(L) if a in l); L[i+1:i+1]=t.split("\\n"); open(f,"w").write("\n".join(L))
PY
}
ins_after_para() { python3 - "$1" "$2" "$3" <<'PY'
import sys; f,a,t=sys.argv[1:]; L=open(f).read().split("\n")
i=next(k for k,l in enumerate(L) if a in l)
j=next(k for k in range(i,len(L)) if L[k].strip()=="")
L[j:j]=t.split("\\n"); open(f,"w").write("\n".join(L))
PY
}
INC='EFFORT SHIFTS: follow `$HOME/.claude/lib/effort-shift.md` (BDR-NEXT): medium when a dispatch span starts, own level before challenge synthesis, low at the bookkeeping tail, max at escalation.'
```
`next(...)` raises `StopIteration` when an anchor is absent: that is the intended failure, fix the anchor rather than the helper.

- [ ] **Step 3: Include line, after the model-gate paragraph, in all 13 skills and the writer agent**

```bash
for s in feat hotfix bugfix ship-feature init-project onboard tour code-clean seo geo harden web-validate audit-delta; do
  ins_after_para "skills/$s/SKILL.md" 'lib/model-gate.md' "$INC"; done
ins_after_para agents/client-handover-writer.md 'model: "fable"' "$INC"
grep -c 'lib/effort-shift.md' skills/*/SKILL.md agents/client-handover-writer.md | grep -v ':0' | wc -l
```
Expected: `14`.

- [ ] **Step 4: Medium at the first executor/collector dispatch (anchors verified in the repo on 2026-09-28)**

```bash
M='Skill(effort-medium)   # effort-shift: dispatch span starts'
ins_before skills/feat/SKILL.md      'Agent(subagent_type="feater")'      "$M"
ins_before skills/hotfix/SKILL.md    'Agent(subagent_type="hotfixer")'    "$M"
ins_before skills/bugfix/SKILL.md    'Agent(subagent_type="bugfixer")'    "$M"
ins_before skills/code-clean/SKILL.md 'Agent(subagent_type="code-cleaner")' "$M"
ins_before skills/seo/SKILL.md 'Agent(subagent_type="seo-analyzer", model="sonnet")' "$M"
ins_before skills/geo/SKILL.md 'Agent(subagent_type="geo-analyzer", model="sonnet")' "$M"
ins_before skills/web-validate/SKILL.md 'Agent('                          "$M"
ins_before skills/harden/SKILL.md    'Agent('                             "$M"
ins_after  skills/ship-feature/SKILL.md '## STEP 4 — IMPLEMENT' "First: \`Skill(effort-medium)\` (effort-shift: dispatch span starts)."
ins_after  skills/init-project/SKILL.md '## STEP 8 — IMPLEMENT' "First: \`Skill(effort-medium)\` (effort-shift: dispatch span starts)."
ins_before skills/onboard/SKILL.md   'Agent(subagent_type="onboarder")'   "\`Skill(effort-medium)\` first (effort-shift: dispatch span starts)."
ins_after  agents/client-handover-writer.md '## STEP 3 — BASELINE AUDITS' "First: \`Skill(effort-medium)\` (effort-shift: dispatch span starts)."
ins_before skills/tour/SKILL.md      'Agent(subagent_type="general-purpose",' "$M"
ins_before skills/audit-delta/SKILL.md 'Agent(subagent_type="security-auditor", description="audit-delta security' "$M"
```
Anchors verified 2026-09-28: `web-validate` and `harden` open their first dispatch with a bare `Agent(` line (l.181 and l.262), the first `Agent(` in each file; `seo` (l.326) and `geo` (l.48) open the collect dispatch with the full call line, unique as first occurrence. `MODE: collect` is not an anchor: it sits inside the prompt string.

- [ ] **Step 5: Own level before every challenge-plan call (reflection resumes)**

```bash
for s in feat hotfix bugfix seo geo harden web-validate; do
  ins_before "skills/$s/SKILL.md" 'lib/challenge-plan.md' "\`Skill(effort-high)\` first (effort-shift: reflection resumes)."; done
for s in ship-feature init-project onboard code-clean audit-delta; do
  ins_before "skills/$s/SKILL.md" 'lib/challenge-plan.md' "\`Skill(effort-xhigh)\` first (effort-shift: reflection resumes)."; done
```
`seo`, `geo` and `web-validate` dispatch their applier after the challenge (seo l.557, geo l.117, web-validate l.312; the first `Agent(subagent_type="hotfixer")` in each file), so a second medium shift goes there:
```bash
for s in seo geo web-validate; do ins_before "skills/$s/SKILL.md" 'Agent(subagent_type="hotfixer")' "$M"; done
```
`harden` applies inline in its STEP 3 (main loop, after the user's confirmation): no applier dispatch, the own-level shift before its challenge line is its last shift.

- [ ] **Step 6: Low at the bookkeeping tail (the five skills with a memory-commit include)**

```bash
for s in feat hotfix bugfix ship-feature init-project; do
  ins_before "skills/$s/SKILL.md" 'lib/capitalize-commit.md' "\`Skill(effort-low)\` first (effort-shift: bookkeeping tail).\\n"; done
```

- [ ] **Step 7: Nested re-assert in feat (commit-change runs at low)**

```bash
grep -n -E 'commit-change' skills/feat/SKILL.md
```
Expected: two consecutive prose lines near l.199 (`… or run \`/commit-change\` on the pending work (it dispatches the …`). The sentence continues, so append at the end of that paragraph, not after the line:
```bash
ins_after_para skills/feat/SKILL.md '/commit-change' "Then \`Skill(effort-high)\` (effort-shift: nested commit-change loaded at low; reload feat's level)."
```

- [ ] **Step 8: Suites, then a read-through of each edited file around the insertions**

Run: `make test suite=lib/tests/effort-routing.test.sh && make test suite=lib/tests/model-routing.test.sh && make test suite=lib/tests/loops-light.test.sh`
Expected: all green (the model-routing and loops-light locks match single lines that this task never splits).

```bash
git diff -U1 -- skills agents | grep -E '^\+' | grep -v '^+++' | wc -l
```
Expected: about 40 added lines, none inside a YAML frontmatter block (every insertion sits below the second `---`).

- [ ] **Step 9: Commit**

```bash
git add skills/*/SKILL.md agents/client-handover-writer.md lib/tests/effort-routing.test.sh
git commit -m "feat(effort): wire phase shifts in the 13 orchestrators and the handover writer"
```

---

### Task 7: Escalation points at max (loop caps, ship-feature 4b) and STOP texts

**Files:**
- Modify: `lib/verify-secure-loop.md` (the three `**Max 3 … iterations** → STOP + human escalation` sentences, lines 38, 77, 107 on 2026-09-28)
- Modify: `skills/ship-feature/SKILL.md` (STEP 4b, `1. Load \`$HOME/.claude/agents/analyzer.md\` in DEBUG MODE`, and step 4 `If A →` / `If B →`)
- Modify: `lib/challenge-plan.md` (line `retry ONCE with a fresh challenger; a 2nd failure on that lens → STOP and escalate`)
- Test: `lib/tests/effort-routing.test.sh`

**Interfaces:**
- Consumes: `Skill(effort-max)` and `/effort-max` from Task 5.

- [ ] **Step 1: Locks**

```bash
python3 - <<'PY'
p="lib/tests/effort-routing.test.sh"; s=open(p).read()
locks="""# ── 7) escalation at max (spec D4)
[ "$(grep -c 'Skill(effort-max)' "$R/lib/verify-secure-loop.md")" -eq 3 ] && ok || ko "verify-secure-loop.md must shift to max at its 3 caps"
has "skills/ship-feature/SKILL.md" 'Skill(effort-max)'
has "lib/challenge-plan.md" '/effort-max'
has "lib/verify-secure-loop.md" '/effort-max'

# ── summary"""
open(p,"w").write(s.replace("# ── summary", locks))
PY
```

- [ ] **Step 2: Loop caps**

```bash
python3 - <<'PY'
p="lib/verify-secure-loop.md"; s=open(p).read()
for cap in ("floor","conformity","security"):
    old=f"**Max 3 {cap} iterations** → STOP + human escalation"
    new=(f"**Max 3 {cap} iterations** → `Skill(effort-max)` (effort-shift: cap reached, "
         f"diagnose at max before escalating), then STOP + human escalation")
    assert s.count(old)==1, cap; s=s.replace(old,new)
s=s.replace("STOP + human escalation with the\n  BLOCKING table.",
  "STOP + human escalation with the\n  BLOCKING table. Every STOP text names the level reached (`$CLAUDE_EFFORT`)\n  and suggests `/effort-max` for the relaunch.")
open(p,"w").write(s)
PY
grep -c 'Skill(effort-max)' lib/verify-secure-loop.md; grep -c '/effort-max' lib/verify-secure-loop.md
```
Expected: `3` and `1`.

- [ ] **Step 3: ship-feature 4b**

```bash
python3 - <<'PY'
p="skills/ship-feature/SKILL.md"; s=open(p).read()
old="1. Load `$HOME/.claude/agents/analyzer.md` in DEBUG MODE on the exact error output."
assert s.count(old)==1
s=s.replace(old, "1. `Skill(effort-max)` (effort-shift: error recovery), then load\n   `$HOME/.claude/agents/analyzer.md` in DEBUG MODE on the exact error output.")
old2="4. If A → apply minimal fix, re-run STEP 4 for the failed task only."
assert s.count(old2)==1
s=s.replace(old2, "4. On resume the turn is at the session level (effort-shift: turn reset).\n   If A → `Skill(effort-medium)`, apply minimal fix, re-run STEP 4 for the failed task only.")
old3="   If B → before skipping:"
assert s.count(old3)==1
s=s.replace(old3, "   If B or C → `Skill(effort-xhigh)` first.\n   If B → before skipping:")
open(p,"w").write(s)
PY
```

- [ ] **Step 4: Challenge fail-safe STOP text**

```bash
python3 - <<'PY'
p="lib/challenge-plan.md"; s=open(p).read()
old="retry ONCE with a fresh challenger; a 2nd failure on that lens → STOP and escalate"
assert s.count(old)==1
s=s.replace(old, old+"\n(the STOP text names the level reached, `$CLAUDE_EFFORT`, and suggests `/effort-max`\nfor the relaunch; no shift here: a mute challenger is an infrastructure failure)")
open(p,"w").write(s)
PY
```

- [ ] **Step 5: Suites and commit**

Run: `make test`
Expected: green.

```bash
git add lib/verify-secure-loop.md lib/challenge-plan.md skills/ship-feature/SKILL.md lib/tests/effort-routing.test.sh
git commit -m "feat(effort): max at the verify-secure caps and ship-feature 4b; STOP texts suggest /effort-max"
```

---

### Task 8: Turn-ending gate audit and re-assert

**Files:**
- Modify: `skills/bugfix/SKILL.md` (the gate `behavior change): wait for user approval.` before pass B of the contract interview)
- Possibly modify: any other orchestrator where the audit below finds a prose gate followed by reflection
- Test: `lib/tests/effort-routing.test.sh`

- [ ] **Step 1: Lock**

```bash
python3 - <<'PY'
p="lib/tests/effort-routing.test.sh"; s=open(p).read()
locks="""# ── 8) turn-reset re-assert after a prose gate followed by reflection
has "skills/bugfix/SKILL.md" 'effort-shift: turn reset'

# ── summary"""
open(p,"w").write(s.replace("# ── summary", locks))
PY
```

- [ ] **Step 2: Audit every prose gate**

```bash
grep -n -i -E "end the turn|end your turn|wait for (the )?(user|human)|STOP and wait|wait for user" \
  skills/{feat,hotfix,bugfix,ship-feature,init-project,onboard,tour,code-clean,seo,geo,harden,web-validate,audit-delta}/SKILL.md \
  lib/contract-interview.md lib/challenge-plan.md lib/plugin-gate.md lib/verify-secure-loop.md
```
Known on 2026-09-28: `bugfix:119` (resume = contract pass B, reflection → re-assert), `ship-feature:205` (handled in Task 7), `ship-feature:14` and `init-project:14` (model-gate STOP, the run ends → nothing). Classify every other hit the same way: model-gate STOP or loop-cap STOP → nothing; resume into dispatch/orchestration → nothing; resume into reflection → re-assert with the skill's own level.

- [ ] **Step 3: Re-assert in bugfix**

```bash
python3 - <<'PY'
p="skills/bugfix/SKILL.md"; s=open(p).read()
old="  behavior change): wait for user approval.\n"
assert s.count(old)==1
s=s.replace(old, old+"  On resume: `Skill(effort-high)` first (effort-shift: turn reset).\n")
open(p,"w").write(s)
PY
```
Apply the same one-line pattern to any other reflection resume found in Step 2, with that skill's level.

- [ ] **Step 4: Manual verification of the reset itself (interactive, once)**

In an interactive session: type `/effort-max`, wait for the reply, then send a plain message such as `echo test` and read the transcript:
```bash
f=~/.claude/projects/-home-bchanot-Documents-claude/$(ls -t ~/.claude/projects/-home-bchanot-Documents-claude/ | grep jsonl | head -1)
grep -o '"effort":"[a-z]*"' "$f" | tail -4
```
Expected: `max` rows for the first turn, `high` for the second (the session default from Task 2).

- [ ] **Step 5: Suites and commit**

Run: `make test`
```bash
git add skills/*/SKILL.md lib/tests/effort-routing.test.sh
git commit -m "feat(effort): re-assert the skill level after prose gates that end the turn"
```

---

### Task 9: Vendored superpowers patch with resync re-apply

**Files:**
- Modify: `skills/brainstorming/SKILL.md`, `skills/writing-plans/SKILL.md` (line 2 `name: …`)
- Modify: `install-plugins.sh` (end of the STEP 8e block that vendors the 7 superpowers skills)
- Test: `lib/tests/effort-routing.test.sh`

- [ ] **Step 1: Locks**

```bash
python3 - <<'PY'
p="lib/tests/effort-routing.test.sh"; s=open(p).read()
locks="""# ── 9) vendored superpowers carry xhigh; a resync that drops it fails here (spec D3)
for s in brainstorming writing-plans; do fm_has_effort "skills/$s/SKILL.md" xhigh; done
has "install-plugins.sh" 'effort: xhigh'

# ── summary"""
open(p,"w").write(s.replace("# ── summary", locks))
PY
```

- [ ] **Step 2: Patch the two files (same `lvl` helper as Task 4)**

```bash
lvl() { L=$1; shift; for s in "$@"; do
  sed -i "0,/^name: $s\$/s//&\neffort: $L/" "skills/$s/SKILL.md"; done; }
lvl xhigh brainstorming writing-plans
sed -n 1,4p skills/brainstorming/SKILL.md skills/writing-plans/SKILL.md
```
Expected: `effort: xhigh` on line 3 of both.

- [ ] **Step 3: Re-apply after every resync in install-plugins.sh**

```bash
grep -n -i 'STEP 8e' install-plugins.sh
```
Expected: three hits on 2026-09-28: a cross-reference comment near l.535, the heading `# ── Step 8e: Agent Skills …` near l.908, and its `echo` near l.915. The block ends where the `# ====` banner of STEP 8.5 begins (near l.937). Insert the re-apply right before that banner:
```bash
python3 - <<'PY'
p="install-plugins.sh"; L=open(p).read().split("\n")
i=next(k for k,l in enumerate(L) if l.startswith("# ── Step 8e:"))
j=next(k for k in range(i+1,len(L)) if L[k].startswith("# ===="))   # the STEP 8.5 banner
L[j:j]=[
"# Effort tiering (BDR-NEXT): the vendored brainstorming/writing-plans carry an",
"# effort pin upstream lacks; re-apply after every resync (census lock in",
"# lib/tests/effort-routing.test.sh alarms if this ever stops working).",
"for _s in brainstorming writing-plans; do",
"  _f=\"$(cd \"$(dirname \"$0\")\" && pwd)/skills/$_s/SKILL.md\"",
"  if [ -f \"$_f\" ] && ! grep -q '^effort:' \"$_f\"; then",
"    sed -i \"0,/^name: $_s\\$/s//&\\neffort: xhigh/\" \"$_f\"",
"  fi",
"done",
"unset _s _f",
"",
]
open(p,"w").write("\n".join(L))
PY
shellcheck install-plugins.sh
```
Expected: shellcheck silent, and `sed -n '/^unset _s _f/,+2p' install-plugins.sh` shows the blank line then the `# ====` banner of STEP 8.5.

- [ ] **Step 4: Prove the re-apply works**

```bash
sed -i '/^effort: xhigh$/d' skills/brainstorming/SKILL.md
bash -c 'source /dev/stdin <<<"$(sed -n "/Effort tiering (BDR-NEXT)/,/^unset _s _f/p" install-plugins.sh)"'
grep -c '^effort: xhigh' skills/brainstorming/SKILL.md
```
Expected: `1` (the extracted block re-added the line without running the whole installer).

- [ ] **Step 5: Suites and commit**

Run: `make test`
```bash
git add skills/brainstorming/SKILL.md skills/writing-plans/SKILL.md install-plugins.sh lib/tests/effort-routing.test.sh
git commit -m "feat(effort): xhigh on the vendored brainstorming and writing-plans, re-applied at resync"
```

---

### Task 10: BDR id, CHANGELOG, registries, journal, TODO reconcile

**Files:**
- Modify: `lib/effort-shift.md`, `lib/model-gate.md`, `lib/tests/effort-routing.test.sh`, `hooks/session-start.sh`, `hooks/statusline.sh`, `install-plugins.sh`, 14 orchestrator files (every `BDR-NEXT` token)
- Modify: `CHANGELOG.md` (`## [Unreleased]` → `### Added`), `.claude/memory/decisions.md`, `.claude/memory/evals.md`, `.claude/memory/journal.md`, `.claude/tasks/TODO.md`

- [ ] **Step 1: Compute the id and replace the token everywhere**

```bash
N=$(( $(grep -o -E 'BDR-[0-9]+' .claude/memory/decisions.md | sort -t- -k2 -n | tail -1 | cut -d- -f2) + 1 ))
echo "BDR-$N"
grep -rl 'BDR-NEXT' --include='*.md' --include='*.sh' --include='*.json' . | grep -v '^./docs/superpowers/' | xargs sed -i "s/BDR-NEXT/BDR-$N/g"
grep -rn 'BDR-NEXT' . --include='*.md' --include='*.sh' | grep -v '^./docs/superpowers/' | wc -l
```
Expected: `0` (the spec and this plan keep the token as history).

- [ ] **Step 2: CHANGELOG under `## [Unreleased]` → `### Added` (first bullet position)**

```bash
python3 - <<'PY'
p="CHANGELOG.md"; s=open(p).read()
anchor="## [Unreleased]\n\n### Added\n"
assert s.count(anchor)==1
entry=("- **Effort tiering (BDR-$N)**: reasoning effort routed per role and per phase. "
"Session default `high`; `effort:` pins on the 20 repo-authored agents; entry level on "
"the 33 user-invoked skills (low → xhigh); five shifter skills `effort-low` … `effort-max` "
"loaded at phase boundaries through `lib/effort-shift.md`, with `max` at the verify-secure "
"caps and ship-feature 4b; `/effort-max` as the turn-scoped relaunch lever; statusline shows "
"the live level; session banner warns when `CLAUDE_CODE_EFFORT_LEVEL` silences the pins; "
"census `lib/tests/effort-routing.test.sh`.\n")
open(p,"w").write(s.replace(anchor, anchor+entry))
PY
sed -i "s/BDR-\$N/BDR-$N/" CHANGELOG.md
```

- [ ] **Step 3: BDR entry (index row after the last row, section at the end), caveman English**

Index row (columns `| ID | Date | Decision | Status |` — copy the exact header of the table in `decisions.md` and match it):
```
| BDR-<N> | 2026-09-28 | Effort tiering: session high, agent effort pins (BDR-077 second axis), skill entry levels, five shifter skills for phase shifts, max at loop caps + 4b | accepted |
```
Section:
```
## BDR-<N> — Effort tiering: session high, pins, skill levels, phase shifts, max at escalation [accepted] (2026-09-28)
- **Decision**: settings `effortLevel` high; `effort:` pin on 20 repo-authored agents by role (low appliers, medium executors, high judgment on sonnet/opus, xhigh challengers + gates); `effort:` on 33 user-invoked skills = run entry level; `skills/effort-{low,medium,high,xhigh,max}` loaded by orchestrators at phase boundaries per `lib/effort-shift.md` (medium at dispatch, own level before challenge synthesis, low at bookkeeping tail, max at verify-secure caps + ship-feature 4b); STOP texts suggest `/effort-max`; statusline live level; banner warns on `CLAUDE_CODE_EFFORT_LEVEL`; census `lib/tests/effort-routing.test.sh`.
- **Why**: session-wide xhigh burned thinking on bookkeeping; measurement (EVAL-035) put 97 % of thinking in the main loop, so the main-loop lever (skill effort, verified LRN-179) carries the savings; pins = explicitness + future models.
- **Alternatives rejected**: executor pins only (executors think 26 tok/request); escalation-diagnoser agent fable+max (no context, one more agent, main-loop max keeps the failure context); reflection in fable skill-runner children with session medium (loses interactivity/context); settings.json rewrite mid-run (global side effect, LRN-098); `maxEffortLevel` caps (hide a mis-pin the census should fail).
- **Caveats**: shifts inert in `-p`/SDK; a turn-ending prose gate resets to session level (re-assert wired where reflection resumes); one effort per agent file → mode-based agents pin their judgment mode; vendored superpowers patch re-applied by install-plugins STEP 8e.
- **Refs**: spec `docs/superpowers/specs/2026-09-28-effort-tiering-design.md`, plan `docs/superpowers/plans/2026-09-28-effort-tiering.md`, [[LRN-179]], [[EVAL-035]], [[BDR-077]].
```
Replace `<N>` by the computed id. Insert the row after the last `| BDR-` row with the same python pattern as Task 4's lock insertion; append the section at the end of the file.

- [ ] **Step 4: EVAL row + section for the Task 4 A/B (columns `| ID | Date | Output | Action |`)**

```
| EVAL-036 | 2026-09-28 | A/B `/reconcile` headless, session high vs skill low (Task 4): requests <n1→n2>, output <o1→o2>, thinking <t1→t2>, ms <d1→d2> | keep low on bookkeeping skills; repeat on a reflection skill before touching the medium/high split |
```
Section with `- **Date**`, `- **Method**` (the Task 4 Step 1 command), `- **Result**` (the two lines), `- **Anomaly**` (anything odd: for example thinking near zero in both runs means effort did not matter for that skill), `- **Action**`. Use the next free EVAL id (`grep -o -E 'EVAL-[0-9]+' .claude/memory/evals.md | sort -t- -k2 -n | tail -1`).

- [ ] **Step 5: Journal line and TODO reconcile**

Append under today's heading in `.claude/memory/journal.md` (create the `## 2026-09-28` heading if absent): `- effort tiering shipped on feature/effort-tiering: session high, 20 pins, 33 skill levels, 5 shifters, max at caps + 4b; census green; finish awaits human signal.`
In `.claude/tasks/TODO.md`, tick the four wave checkboxes of the `effort tiering` section.

- [ ] **Step 6: Suites, then commit code and docs, then the memory surgically**

Run: `make test && shellcheck *.sh hooks/*.sh lib/*.sh`
```bash
git add CHANGELOG.md lib hooks install-plugins.sh skills agents
git commit -m "docs(effort): BDR-$N id, CHANGELOG entry"
bash lib/memory-commit.sh commit "chore(memory): BDR-$N effort tiering, EVAL A/B, journal, TODO"
git status --short
```
Expected: clean tree, both commits pushed by the post-commit hook.

---

### Task 11: Keep the transcript audit script (spec §9 tooling)

**Files:**
- Create: `lib/effort-audit.py` (from the spike's `effort_split2.py`, cleaned: functions ≤ 25 logic lines, 80-char lines, no globals beyond constants)
- Modify: `lib/effort-shift.md` (one line under Mechanics: `Measure with python3 ~/.claude/lib/effort-audit.py [projects-root]`)
- Test: `lib/tests/effort-routing.test.sh`

- [ ] **Step 1: Lock**

```bash
python3 - <<'PY'
p="lib/tests/effort-routing.test.sh"; s=open(p).read()
locks="""# ── 11) audit tooling
has "lib/effort-shift.md" 'effort-audit.py'
[ -x "$R/lib/effort-audit.py" ] && ok || ko "lib/effort-audit.py missing or not executable"

# ── summary"""
open(p,"w").write(s.replace("# ── summary", locks))
PY
```

- [ ] **Step 2: Write the script**

```bash
cat > lib/effort-audit.py <<'EOF'
#!/usr/bin/env python3
"""Sum output/thinking/cache tokens per (scope, model, effort) over Claude Code
transcripts. scope = main (session jsonl) | sub (subagents/*.jsonl or
isSidechain records). Read-only. Usage: effort-audit.py [projects-root]"""
import collections
import glob
import json
import os
import sys

WEIGHTS = {"in": 1.0, "cc": 1.25, "cr": 0.1, "out": 5.0}  # relative to input price
FIELDS = ("in", "cc", "cr", "out", "think")


def usage_row(usage):
    """Map one API usage block to the five counted fields."""
    details = usage.get("output_tokens_details") or {}
    return {
        "in": usage.get("input_tokens", 0) or 0,
        "cc": usage.get("cache_creation_input_tokens", 0) or 0,
        "cr": usage.get("cache_read_input_tokens", 0) or 0,
        "out": usage.get("output_tokens", 0) or 0,
        "think": details.get("thinking_tokens", 0) or 0,
    }


def scan(path, scope, agg):
    """Add every assistant record of one transcript to agg."""
    with open(path, errors="ignore") as handle:
        for line in handle:
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            msg = rec.get("message") or {}
            if rec.get("type") != "assistant" or not msg.get("usage"):
                continue
            sub = scope == "sub" or bool(rec.get("isSidechain"))
            key = ("sub" if sub else "main",
                   str(msg.get("model", "?")).replace("claude-", ""),
                   str(rec.get("effort") or "?"))
            row = usage_row(msg["usage"])
            agg[key]["msgs"] += 1
            for field in FIELDS:
                agg[key][field] += row[field]


def weighted(counter):
    return sum(counter[f] * WEIGHTS[f] for f in WEIGHTS)


def report(agg):
    """Print the per-key table, then the main/sub split and the thinking share."""
    total = collections.Counter()
    for counter in agg.values():
        total.update(counter)
    total_w = weighted(total) or 1
    print(f"{'scope':5} {'model':22} {'effort':7} {'msgs':>6} {'think/msg':>9} "
          f"{'think_tok':>10} {'out_tok':>10} {'cache_read':>12} {'%wcost':>7}")
    for (scope, model, effort), c in sorted(agg.items(), key=lambda kv: -weighted(kv[1])):
        per_msg = c["think"] / max(c["msgs"], 1)
        print(f"{scope:5} {model:22} {effort:7} {c['msgs']:6d} {per_msg:9.0f} "
              f"{c['think']:10d} {c['out']:10d} {c['cr']:12d} {100 * weighted(c) / total_w:6.1f}%")
    by_scope = collections.defaultdict(collections.Counter)
    for (scope, _, _), c in agg.items():
        by_scope[scope].update(c)
    for scope, c in by_scope.items():
        print(f"  {scope:5} weighted-cost {100 * weighted(c) / total_w:5.1f}%  "
              f"thinking {100 * c['think'] / max(total['think'], 1):5.1f}%  requests {c['msgs']}")
    print(f"  thinking = {100 * total['think'] * WEIGHTS['out'] / total_w:.1f}% of weighted cost; "
          f"cache reads = {100 * total['cr'] * WEIGHTS['cr'] / total_w:.1f}%")


def main():
    root = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/.claude/projects")
    agg = collections.defaultdict(collections.Counter)
    for project in sorted(glob.glob(os.path.join(root, "*"))):
        if not os.path.isdir(project):
            continue
        for path in glob.glob(os.path.join(project, "*.jsonl")):
            scan(path, "main", agg)
        for path in glob.glob(os.path.join(project, "*", "subagents", "*.jsonl")):
            scan(path, "sub", agg)
    report(agg)


if __name__ == "__main__":
    main()
EOF
chmod +x lib/effort-audit.py
python3 lib/effort-audit.py | head -5
```
Expected: the table header and the top rows, `main fable-5-1` first.

- [ ] **Step 3: Pointer in the include, suites, commit**

```bash
python3 - <<'PY'
p="lib/effort-shift.md"; s=open(p).read()
anchor="## Shifters\n"
assert s.count(anchor)==1
s=s.replace(anchor, "Measure the split any time: `python3 ~/.claude/lib/effort-audit.py`\n(thinking/output/cache tokens per scope, model and effort).\n\n"+anchor)
open(p,"w").write(s)
PY
make test suite=lib/tests/effort-routing.test.sh
git add lib/effort-audit.py lib/effort-shift.md lib/tests/effort-routing.test.sh
git commit -m "feat(effort): transcript audit script for the thinking/cost split"
```

---

## Self-review against the spec

- **§4 D1** → Task 2 (settings, banner, statusline). **D2** → Task 3. **D3** → Tasks 4 and 9. **D4** → Tasks 5, 6, 7, 8. **D5** → Task 2. **§6** every file listed has a task. **§7** every census item has a lock: 1 (Task 3 `fm_has_effort`/`fm_no_effort`), 2 (Task 3), 3 (Tasks 4, 9), 4 (Task 5), 5 (Tasks 6, 7), 6 (Task 1), 7 and 8 run as existing suites in `make test`. **§8** waves = Tasks 1-3 / 4, 9 / 5-8 / 10-11. **§9** → Task 4 Steps 1 and 5, EVAL in Task 10, tooling in Task 11.
- **Placeholders**: `BDR-NEXT` is a defined token with a defined replacement step (Task 10); the three `grep -n -m1` recipes in Task 6 Step 4 and Task 8 Step 2 name the expected match and the exact insertion to make.
- **Names**: `Skill(effort-<level>)`, `lib/effort-shift.md`, `fm_has_effort`, `ins_before`/`ins_after`/`ins_after_para`, `lvl`, `pin` are spelled identically across tasks.
- **Review Focus**: 1 → Task 5 lock `Headless sessions`; 2 → Task 2 Step 6; 3 → Task 6 Step 7 + lock; 4 → Task 3 `fm_no_effort status-reporter`; 5 → Task 9 Steps 3-4 + lock.
