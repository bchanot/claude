# Phase 1 native context diet — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move four always-on doctrine blocks, two secure-by-default domain bodies and the long agent descriptions to native carriers that load only when needed, and switch off auto memory, without losing any rule.

**Architecture:** No mod. Each text moves to the carrier whose trigger matches it: a `paths:` rule (loads on Read of a matching file), the SessionStart hook (prints only when a graph exists), a lib file our skills Read, a setting. CLAUDE.global.md keeps one always-on line where plain chat still needs the rule.

**Tech Stack:** bash 5.3 (shellcheck-clean, GNU + BSD portable, no `grep -P`), markdown doctrine, jq, python3 (`-I`) with PyYAML for one oracle.

**Spec:** `docs/superpowers/specs/2026-10-29-context-diet-design.md`. Contract (acceptance criteria, judged by the verifier): `.claude/tasks/contracts/2026-10-28-context-diet-1944.md`. Oracles: `.claude/tasks/contracts/c1-*.sh` (already written, do not edit them).

## Global Constraints

- Execute IN PLACE in `/home/bchanot/Documents/claude` on `feature/context-diet`, no worktree: `~/.claude/{CLAUDE.md,rules,lib,hooks,settings.json}` are symlinks into this checkout and Task 7 relies on the user's uncommitted hunks in THIS working tree.
- Branch `feature/context-diet` (exists). Never commit on develop/main. Never `--no-verify`. Never `git add -A` / `git add .`: add the exact paths listed in the task.
- Moved text is moved VERBATIM (byte-identical lines) unless the task shows the new text. The oracles compare against develop commit `017a28b`.
- Hook stdout strings name deployed paths (`~/.claude/...`); maintainer comments name `CLAUDE.global.md` (BDR-064).
- Foreign-style repo: match the neighbouring code (inline shell, `check()` test idiom, `PASS=%s FAIL=%s` footer, comments only for the why). Doctrine lines ≤ 80 chars; do not add a line over 80 chars to CLAUDE.global.md (3 exist today).
- Tests run only through `make test suite=<path>` or the full `make test`. shellcheck: `shellcheck *.sh hooks/*.sh lib/*.sh` (+ any new `lib/tests/*.sh` you create).
- Bash pitfalls: no `head` reading a producer under pipefail (SIGPIPE rc 141); a sourced lib never changes the caller's shell options.
- `settings.json` carries one uncommitted UI line (`"theme": "dark"`): never stage or revert it (Task 7 gives the exact recipe).
- No destructive commands, no file outside this repo (the robin_petier write is a controller step, not yours).

## Review Focus

1. A real user prompt that starts with `<` (pasted content: `<pasted_content>…`) must still fire the design hook; only `<task-notification>` and `<agent-message` turns are skipped. Pinned: Task 1 F11.
2. session-start run from a subdirectory of a repo whose root holds `graphify-out/graph.json` prints the usage block; run outside any git repo it prints none and does not error. Pinned: Task 2 T3, T5.
3. A `§` citation whose label is a prefix of a heading (`§ "Version"` vs `## Versioning`) or whose target file does not exist must be reported DANGLING, never skipped. Pinned: Task 6 T5.
4. doctor runs under `set -euo pipefail`: an absent `~/.claude/projects`, or memory dirs holding only empty subdirs, must yield 0 and rc 0. Pinned: Task 7 T1, T5, T6.
5. The settings.json commit must carry only the `autoMemoryEnabled` line, the user's `/model` hunks stay unstaged in the working tree. Pinned: Task 7 Step 6.

---

### Task 1: Design work moves to rules/web-building.md; the hook points there

**Files:**
- Modify: `CLAUDE.global.md` (Skill routing line ~280, Higgsfield line ~295-296, delete the `## Design work — full toolchain (tiered by scope)` section ~300-322)
- Modify: `rules/web-building.md` (append the section at the end)
- Modify: `hooks/design-toolchain-reminder.sh` (header comment, skip case, output line)
- Modify: `lib/tests/design-toolchain-reminder.test.sh`
- Modify: `lib/tests/effort-routing.test.sh:213`
- Modify: `lib/design-gate.md:47-49`

**Interfaces:**
- Produces: the heading `## Design work — full toolchain (tiered by scope)` as the LAST section of `rules/web-building.md` (Task 6's census resolves citations to it); the hook output line below (exact).

- [ ] **Step 1: Update the hook test first (it must fail on the current hook)**

In `lib/tests/design-toolchain-reminder.test.sh`:

Replace the two lines

```bash
H="$(cd "$(dirname "$0")/../.." && pwd)/hooks/design-toolchain-reminder.sh"
pass=0; fail=0
```

with

```bash
H="$(cd "$(dirname "$0")/../.." && pwd)/hooks/design-toolchain-reminder.sh"
# Every hook call runs under a throwaway HOME (the fire log is
# $HOME/.claude/logs/design-toolchain-fires.log): the suite never writes the
# real one (1,770 of 2,779 logged fires were this suite's prompts, 2026-10-28).
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T"
LINE='Design work detected → Read ~/.claude/rules/web-building.md § "Design work — full toolchain" first. Trivial (≤2 files, cosmetic) → /hotfix.'
pass=0; fail=0
```

(`fire()` stays as it is: the exported HOME covers it. The L1 block keeps its own `tmp` HOME.)

After the line `check D11-bare-ux ...` add

```bash
check D12-agent-msg  "$(fire '<agent-message from=a1> [Subagent hand-back] add css header fonts')" quiet
```

After the line `check F10-bare-ui ...` add

```bash
check F11-pasted     "$(fire '<pasted_content> add a button')" fire

# --- The one-liner is a contract (LRN-104): exact text ---
check O1-exact-line "$(printf '{"prompt":"add a button"}' | bash "$H")" "$LINE"
# the fires above landed in the throwaway HOME, positively (not a global count)
check G1-fires-in-temp-home "$([ -s "$T/.claude/logs/design-toolchain-fires.log" ] && echo yes)" yes
```

- [ ] **Step 2: Run it, expect FAIL**

Run: `make test suite=lib/tests/design-toolchain-reminder.test.sh`
Expected: FAIL lines for `D12-agent-msg` (got fire) and `O1-exact-line` (old text); the others pass.

- [ ] **Step 3: Update the hook**

In `hooks/design-toolchain-reminder.sh`, replace the header lines

```bash
# UserPromptSubmit hook. When the prompt carries a UI/design signal, inject a
# reminder to mobilize the full design toolchain (tiered by scope, per CLAUDE.global.md
# "Design work — full toolchain"). A UserPromptSubmit hook's stdout is appended
# to the model's context, so the cat block below becomes additional guidance.
```

with

```bash
# UserPromptSubmit hook. When the prompt carries a UI/design signal, point the
# model at the design toolchain section (tiered by scope). Since BDR-125
# phase 1 it lives in rules/web-building.md § "Design work — full toolchain",
# not in CLAUDE.global.md: it loads by itself on a UI file Read, and a
# chat-only design request needs this pointer. A UserPromptSubmit hook's
# stdout is appended to the model's context.
```

Replace

```bash
# Harness-generated turns (subagent/task notifications) are not user
# requests — never fire on them (CLAUDE.global.md trigger = a design/UI *request*).
case "$prompt" in
  '<task-notification>'*) exit 0 ;;
esac
```

with

```bash
# Harness-generated turns (task notifications, sub-agent hand-backs: 857 of
# 2,779 logged fires on 2026-10-28) are not user requests — never fire on
# them (the Design work trigger = a design/UI *request*).
case "$prompt" in
  '<task-notification>'*|'<agent-message'*) exit 0 ;;
esac
```

Replace the heredoc body line

```
Design work detected → apply global CLAUDE.md section "Design work — full toolchain" (already in context). Trivial (≤2 files, cosmetic) → /hotfix.
```

with

```
Design work detected → Read ~/.claude/rules/web-building.md § "Design work — full toolchain" first. Trivial (≤2 files, cosmetic) → /hotfix.
```

- [ ] **Step 4: Move the section**

Cut the whole section from `CLAUDE.global.md`: from the line `## Design work — full toolchain (tiered by scope)` through the line `ui-explore / ui-review are \`max\`-profile only.` (22 lines, CLAUDE.global.md:300-321), plus the one blank line that follows it (322), so `## graphify` follows the Skill-routing block's last line `office-hours…) are gone: use the fallback above, else say so.` and one blank line. Never touch the `## graphify` heading.

Append to `rules/web-building.md`: one blank line, then those 22 lines byte-identical (the file must END with `ui-explore / ui-review are \`max\`-profile only.` + newline). Do not touch its frontmatter.

- [ ] **Step 5: Retarget the two CLAUDE.global.md pointers**

Replace

```
- Design / UI (build, system, audit, polish) → "Design work" below
```

with

```
- Design / UI (build, system, audit, polish) → Read
  `~/.claude/rules/web-building.md` § "Design work" first
```

Replace

```
  Higgsfield", named ask → `enable higgsfield-websites`: an aid inside
  Design work and the site rules, never `website create|deploy|publish`.
```

with

```
  Higgsfield", named ask → `enable higgsfield-websites`: an aid inside
  the Design work rules (`rules/web-building.md`), never
  `website create|deploy|publish`.
```

- [ ] **Step 6: Patch the two other citers**

`lib/tests/effort-routing.test.sh:213`: replace

```bash
has "CLAUDE.global.md" 'route to `reflect` (high) through their'
```

with

```bash
has "rules/web-building.md" 'route to `reflect` (high) through their'
```

`lib/design-gate.md`: replace

```
already in the core set — checked regardless; their CLAUDE.md "+motion /
+static" notes say which tool you'll lean on, not a separate activation step.
```

with

```
already in the core set — checked regardless; the Design work section
(`rules/web-building.md`) names them as the motion and static tools, not a
separate activation step.
```

- [ ] **Step 7: Run the suites, expect PASS**

Run each: `make test suite=lib/tests/design-toolchain-reminder.test.sh`, `make test suite=lib/tests/effort-routing.test.sh`, `make test suite=lib/tests/doctrine-citers.test.sh`, then `bash .claude/tasks/contracts/c1-design-moved.sh`.
Expected: three `all suites green`; the oracle prints `DESIGN-MOVED`. `shellcheck hooks/design-toolchain-reminder.sh lib/tests/design-toolchain-reminder.test.sh` clean.

- [ ] **Step 8: Commit**

```bash
git add CLAUDE.global.md rules/web-building.md hooks/design-toolchain-reminder.sh \
  lib/tests/design-toolchain-reminder.test.sh lib/tests/effort-routing.test.sh lib/design-gate.md
git commit -m "feat(design): Design work moves to rules/web-building.md, hook points there and skips sub-agent hand-backs"
```

---

### Task 2: graphify usage printed by session-start only where a graph exists

**Files:**
- Modify: `CLAUDE.global.md` (`## graphify` section, now the last section)
- Modify: `hooks/session-start.sh` (quick health-check list line ~10; line-count guard comment ~257-259; new block before the final `echo ""`)
- Modify: `lib/tests/graphify-gate.test.sh` (new S-checks before its final `echo "PASS=…"`)

**Interfaces:**
- Produces: when `$(git rev-parse --show-toplevel)/graphify-out/graph.json` exists, session-start stdout carries, after the box, the block shown in Step 3 (first line `graphify (graphify-out/graph.json present):`).

- [ ] **Step 1: Write the failing checks**

In `lib/tests/graphify-gate.test.sh`, insert before the final `echo "PASS=$pass FAIL=$fail"` (reuse its `mkrepo`, `check`, `$WORK/plain`; one banner run per fixture state):

```bash
# ── session-start prints the usage rules only where a graph exists
#    (BDR-125 phase 1: the body left CLAUDE.global.md) ──
SS="$(cd "$(dirname "$0")/../.." && pwd)/hooks/session-start.sh"
banner() { (cd "$1" && SESSION_START_OFFLINE=1 bash "$SS" </dev/null 2>/dev/null); }
d=$(mkrepo ss 1)
out=$(banner "$d")
check S1-banner-control "$(grep -c 'Claude Code config' <<<"$out")" 1
check S1b-no-graph-silent "$(grep -c 'graphify query' <<<"$out")" 0
mkdir -p "$d/graphify-out" "$d/app/sub"; echo '{}' > "$d/graphify-out/graph.json"
out=$(banner "$d")
check S2-graph-prints "$(grep -c 'graphify query' <<<"$out")" 1
check S2b-update-rule "$(grep -c 'graphify update \.' <<<"$out")" 1
check S3-from-subdir "$(banner "$d/app/sub" | grep -c 'graphify query')" 1
out=$(banner "$WORK/plain")
check S4-not-a-repo "$(grep -c 'graphify query' <<<"$out")/$(grep -c 'Claude Code config' <<<"$out")" 0/1
```

- [ ] **Step 2: Run it, expect FAIL**

Run: `make test suite=lib/tests/graphify-gate.test.sh`
Expected: FAIL on S2, S2b, S3 (got 0); T1-T9, S1, S1b, S4 pass.

- [ ] **Step 3: Edit session-start.sh**

Replace `for f in CLAUDE.md settings.json agents skills; do` (quick health check, ~line 10) with `for f in CLAUDE.md settings.json agents skills rules; do` (Design work and the Supabase / cloud-functions bodies now live only under `~/.claude/rules`).

Between the line `[ -n "$EFFORT_WARN" ] && printf '%s\n' "$EFFORT_WARN"` and the final `echo ""`, insert:

```bash
# graphify usage (BDR-125 phase 1): the rules left CLAUDE.global.md, which
# keeps the 200-file threshold and a one-line reminder; they print where a
# graph exists.
_gx_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -n "$_gx_root" ] && [ -f "$_gx_root/graphify-out/graph.json" ]; then
  cat <<'EOF'
graphify (graphify-out/graph.json present):
- Codebase-wide question → `graphify query`; relationships → `path A B`;
  concept → `explain`. Scoped subgraph beats raw grep.
- Known file / small task → read directly, no graphify.
- `wiki/index.md` → broad-nav entry; `GRAPH_REPORT.md` → whole-architecture.
- After editing code → `graphify update .` (AST-only, free).
EOF
fi
unset _gx_root
```

Replace the comment

```bash
# CLAUDE.global.md line-count guard (anti-regression). BDR-062 supersedes
# BDR-031's 275 target: 305 is the assumed reality (extraction done at
# job1; further compression costs clarity > token gain) — warn past 320.
```

with

```bash
# CLAUDE.global.md line-count guard (anti-regression, BDR-062): warn past
# 320. BDR-125 phase 1 moved Design work, the graphify usage and the
# architecture defaults to their carriers (333 → ~285 lines).
```

- [ ] **Step 4: Trim the CLAUDE.global.md section**

Replace the whole `## graphify` section (heading through `- After editing code → \`graphify update .\` (AST-only, free).`) with the lines below. The reminder clause stays always-on because dispatched sub-agents load CLAUDE.md, never the main session's SessionStart output:

```
## graphify

Threshold: graphify from 200 tracked code files, never below (banner line
`graphify? N code files ≥ 200, no graph` informs, the user decides; never
build or `graphify claude install` without that go). With a graph
(`graphify-out/graph.json`): `graphify query` before raw grep,
`graphify update .` after code edits; the session banner prints the rest.
```

- [ ] **Step 5: Run, expect PASS**

Run: `make test suite=lib/tests/graphify-gate.test.sh`, `make test suite=lib/tests/memory.test.sh`, `make test suite=lib/tests/push-guard.test.sh` (the last two grep the banner).
Expected: three `all suites green`. `shellcheck hooks/session-start.sh lib/tests/graphify-gate.test.sh` clean.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.global.md hooks/session-start.sh lib/tests/graphify-gate.test.sh
git commit -m "feat(graphify): usage rules print from session-start only where a graph exists"
```

---

### Task 3: Architecture defaults move to lib/architecture-defaults.md; Web APIs to rules/rest-api.md

**Files:**
- Create: `lib/architecture-defaults.md`
- Delete: `rules/default-language.md` (`git rm`)
- Modify: `CLAUDE.global.md` (`# Architecture decisions` H1: intro + `## Public websites — never SPA` + `## Web APIs — always versioned`, ~142-167)
- Modify: `rules/rest-api.md` (`## Versioning`; the `/api/tasks` example in `## Naming`)
- Modify: `.claude/rules/rules-maintenance.md` (second paragraph)
- Modify: `lib/project-archetypes/rest-api-node.md:58`
- Modify (readers): `skills/init-project/SKILL.md` (STEP 3, STEP 5), `agents/interviewer.md:26`, `agents/scaffolder.md` (INPUTS REQUIRED, PHASE 1), `skills/ship-feature/SKILL.md` (STEP 1), `skills/onboard/SKILL.md` (STEP 6), `skills/audit-delta/SKILL.md:276`, `agents/seo-analyzer.md:542-543`

**Interfaces:**
- Produces: `lib/architecture-defaults.md` headings `## Public websites — never SPA`, `## Default language — Rust`, `## Web APIs — always versioned`; `rules/rest-api.md` heading `## Versioning` with the full rule (Task 6 resolves citations to both).

- [ ] **Step 1: Run the oracles, expect FAIL**

Run: `bash .claude/tasks/contracts/c1-arch-moved.sh; bash .claude/tasks/contracts/c1-readers.sh`
Expected: `no lib/architecture-defaults.md`, `no lib in skills/init-project/SKILL.md`.

- [ ] **Step 2: Create the lib**

Create `lib/architecture-defaults.md` with exactly this structure:

```
# Architecture defaults — read before proposing a stack

Read at project creation, scaffolding, a stack brainstorm or a whole-project
rewrite (BDR-125 phase 1). The three defaults are named always-on in
`~/.claude/CLAUDE.md` § "Architecture decisions"; the detail lives here.

<the `## Public websites — never SPA` section of CLAUDE.global.md, byte-identical: heading + its 13 body lines, up to and including `  silently pick React CRA.`>

<the whole content of rules/default-language.md, byte-identical, except its first line `# Default language — Rust` becomes `## Default language — Rust`>

## Web APIs — always versioned
Every endpoint `/api/v1/...` from day one; breaking change → `v2`, the old
version keeps working. Full rule: `~/.claude/rules/rest-api.md` § Versioning
(loads on API files).
```

One blank line between sections; the `<…>` lines are instructions, not text to write.

- [ ] **Step 3: Replace the H1 block in CLAUDE.global.md**

Replace everything from the line `# Architecture decisions` down to (not including) `## Version control — gitflow (universal)` with:

```
# Architecture decisions
New project, scaffolding, stack brainstorm or whole-project rewrite: Rust
by default, a public site is never a SPA (Astro; Next.js when SSR is
needed), every web API versioned `/api/v1/` from day one. Read
`~/.claude/lib/architecture-defaults.md` before proposing a stack.

```

- [ ] **Step 4: Web APIs into rules/rest-api.md, delete default-language.md**

In `rules/rest-api.md` replace

```
## Versioning
CLAUDE.md § Web APIs — always versioned. Not repeated here.
```

with (body byte-identical to the former CLAUDE.global.md § Web APIs body):

```
## Versioning
Every endpoint versioned from day one: `/api/v1/...`, no bare `/api/`; the
router mirrors it (`api/v1/routes/`). Breaking change → `v2`, the old
version keeps working and clients migrate at their pace; non-breaking
additions → current version. Each version is a self-contained contract,
never bent to match a newer one.
```

In the same file, `## Naming` now contradicts it: replace `Plural nouns for endpoints (\`/api/tasks\`), no verbs.` with `Plural nouns for endpoints (\`/api/v1/tasks\`), no verbs.`

In `.claude/rules/rules-maintenance.md` (it names `default-language.md` as an always-on exception, which `c1-readers.sh` reads as a stale citer), replace the paragraph that starts `A rule WITH \`paths:\` YAML frontmatter` and ends `keep rule bodies tiny.` with (it names `lib/tests/user-rules.test.sh`, which Task 5 of this branch creates):

```
A rule WITH `paths:` YAML frontmatter (glob list) loads lazily — only when
Claude Reads a file matching a glob (never on the Write of a new file;
sub-agents too); a rule WITHOUT it loads at session start, same cost as the
global memory. Doctrine leaves CLAUDE.global.md only for a carrier that fires
when it is needed (BDR-125 phase 1: a path rule, a hook, a lib our skills
Read), with one always-on line wherever plain chat still needs the rule.
Exception: a standalone user-authored rule set that would bust the 320-line
density budget may live here WITHOUT `paths:` (always-on load) —
writing-style.md (BDR-085), secure-by-default.md (BDR-120);
`lib/tests/user-rules.test.sh` locks that set. `paths:` globs match against
the CURRENT project's tree, gitignore-style (a pattern without an inner `/`
matches at any depth, hidden dirs included) — a broad glob (e.g. `rules/**`)
can fire in foreign projects; keep rule bodies tiny.
```

In `lib/project-archetypes/rest-api-node.md` replace

```
- Pas de versioning API (/api/v1/) — flag CLAUDE.md : "Web APIs — always versioned"
```

with

```
- Pas de versioning API (/api/v1/) — flag `rules/rest-api.md` § Versioning
```

Run: `git rm -q rules/default-language.md`

- [ ] **Step 5: Wire the readers**

`agents/interviewer.md` row "Language not stated": replace `(\`rules/default-language.md\`)` with `(\`~/.claude/lib/architecture-defaults.md\` § Default language)`.

`skills/init-project/SKILL.md` STEP 3: after the line `Invoke \`brainstorming\` (vendored superpowers skill) with BRIEF + ANALYSIS REPORT.` insert:

```
Read `~/.claude/lib/architecture-defaults.md` first and pass it as binding
context: its defaults (Rust, never a SPA for a public site, `/api/v1/`) hold
unless the BRIEF names otherwise.
```

`skills/init-project/SKILL.md` STEP 5: replace

```
+ DESIGN (verbatim) + paths `~/.claude/templates/project-CLAUDE.md` +
`~/.claude/CLAUDE.md`. A STOP (missing input) comes back as its report —
```

with

```
+ DESIGN (verbatim) + paths `~/.claude/templates/project-CLAUDE.md` +
`~/.claude/CLAUDE.md` + `~/.claude/lib/architecture-defaults.md`. A STOP
(missing input) comes back as its report —
```

`agents/scaffolder.md`: after `4. \`~/.claude/CLAUDE.md\`` add `5. \`~/.claude/lib/architecture-defaults.md\``; replace `Read \`~/.claude/templates/project-CLAUDE.md\` and \`~/.claude/CLAUDE.md\`.` with `Read \`~/.claude/templates/project-CLAUDE.md\`, \`~/.claude/CLAUDE.md\` and \`~/.claude/lib/architecture-defaults.md\`.`

`skills/ship-feature/SKILL.md` STEP 1: after the line `   BLK already closed."` insert:

```
When the feature picks a language, a framework or an API shape, Read
`~/.claude/lib/architecture-defaults.md` first and add its defaults to the
in-force constraints.
```

`skills/onboard/SKILL.md` STEP 6: after the line `Lire le bloc \`audit_stack:\` du fichier \`~/.claude/lib/project-archetypes/<archetype>.md\`.` insert one blank line and:

```
Les audits jugent l'architecture contre `~/.claude/lib/architecture-defaults.md`
(site public jamais SPA, API `/api/v1/`, Rust par défaut pour une réécriture) :
passer ce chemin dans chaque brief d'audit.
```

`skills/audit-delta/SKILL.md`: replace

```
- **conformity** — read project `CLAUDE.md` (+ `~/.claude/CLAUDE.md`)
  FIRST, then check changed code against those norms. This repo's:
```

with

```
- **conformity** — read project `CLAUDE.md` (+ `~/.claude/CLAUDE.md` and
  `~/.claude/lib/architecture-defaults.md`) FIRST, then check changed code
  against those norms. This repo's:
```

`agents/seo-analyzer.md`: replace

```
HTML). Global score excludes it. Fix: SSR/SSG (CLAUDE.md: public sites are
never SPAs).`
```

with

```
HTML). Global score excludes it. Fix: SSR/SSG
(lib/architecture-defaults.md: public sites are never SPAs).`
```

- [ ] **Step 6: Run, expect PASS**

Run: `bash .claude/tasks/contracts/c1-arch-moved.sh` → `ARCH-MOVED`; `bash .claude/tasks/contracts/c1-readers.sh` → `READERS-OK`; `make test suite=lib/tests/doctrine-citers.test.sh` → `all suites green`.

- [ ] **Step 7: Commit**

```bash
git add lib/architecture-defaults.md CLAUDE.global.md rules/rest-api.md \
  .claude/rules/rules-maintenance.md \
  lib/project-archetypes/rest-api-node.md agents/interviewer.md agents/scaffolder.md \
  agents/seo-analyzer.md skills/init-project/SKILL.md skills/ship-feature/SKILL.md \
  skills/onboard/SKILL.md skills/audit-delta/SKILL.md
git commit -m "feat(doctrine): architecture defaults move to lib/architecture-defaults.md, Web APIs to rules/rest-api.md"
```

(`git rm` already staged the deletion of `rules/default-language.md`.)

---

### Task 4: Supabase and cloud-functions bodies become path rules

**Files:**
- Create: `rules/supabase.md`, `rules/cloud-functions.md`
- Modify: `rules/secure-by-default.md` (§4 and §6 bodies only)
- Modify: `skills/guardrails/SKILL.md:10`, `agents/interviewer.md:27`

- [ ] **Step 1: Run the oracle, expect FAIL**

Run: `bash .claude/tasks/contracts/c1-supabase-functions.sh` → `no rules/supabase.md`.

- [ ] **Step 2: Create the two rules**

`rules/supabase.md`:

```
---
paths: ["**/supabase/**", "**/*supabase*.*"]
---

# Supabase — secure by default, domain 4

Path-scoped body of `rules/secure-by-default.md` domain 4 (BDR-125 phase 1);
the always-on line there keeps RLS and the client-side key ban.

<the 7 body lines under `## 4. Supabase` of rules/secure-by-default.md, byte-identical, from `- RLS enabled on every table, in the migration that creates it.` to `  and revoke execute from anon. Buckets private by default.`>
```

`rules/cloud-functions.md`:

```
---
paths: ["**/functions/**", "**/serverless.*", "**/firebase.json"]
---

# Cloud functions — secure by default, domain 6

Path-scoped body of `rules/secure-by-default.md` domain 6 (BDR-125 phase 1);
the always-on line there keeps the instance cap and the self-trigger ban.

<the 4 body lines under `## 6. Cloud functions`, byte-identical, from `- No function re-triggers itself: never write to the resource that fires it,` to `- Budget alert wired to an automatic stop beyond the budget.`>
```

No line of the intro paragraph may start with `- ` (the oracle takes everything from the first `- ` line as the bullets).

- [ ] **Step 3: Shrink the two sections of secure-by-default.md**

Replace the body under `## 4. Supabase` (7 lines) with:

```
- RLS on every table, never a service_role or secret key client-side. Full
  domain: rules/supabase.md (loads on Supabase files).
```

Replace the body under `## 6. Cloud functions` (4 lines) with:

```
- Max instances and a timeout on every function, never a self-trigger. Full
  domain: rules/cloud-functions.md (loads on function files).
```

Every other line of the file stays byte-identical (the oracle checks it).

- [ ] **Step 4: Patch the two citers**

`skills/guardrails/SKILL.md`: replace

```
Checks a project against `rules/secure-by-default.md`, then fixes what the
user accepts and proves each fix. A scanner reads the tree as data and finds
```

with

```
Checks a project against `rules/secure-by-default.md` (domains 4 and 6 in
full: `rules/supabase.md`, `rules/cloud-functions.md`), then fixes what the
user accepts and proves each fix. A scanner reads the tree as data and finds
```

`agents/interviewer.md` row "Project has an API…": replace `Apply \`rules/secure-by-default.md\`:` with `Apply \`rules/secure-by-default.md\` (Supabase and cloud-function detail: \`rules/supabase.md\`, \`rules/cloud-functions.md\`):`.

- [ ] **Step 5: Run, expect PASS**

Run: `bash .claude/tasks/contracts/c1-supabase-functions.sh` → `SB-CF-MOVED`; `make test suite=lib/tests/guardrails-scan.test.sh` → `all suites green`.

- [ ] **Step 6: Commit**

```bash
git add rules/supabase.md rules/cloud-functions.md rules/secure-by-default.md \
  skills/guardrails/SKILL.md agents/interviewer.md
git commit -m "feat(rules): Supabase and cloud-functions bodies become path rules, one always-on line each"
```

---

### Task 5: user-rules suite locks the always-on set; engine matching documented

**Files:**
- Create: `lib/tests/user-rules.test.sh`
- Modify: `lib/project-rules.sh` (header comment lines 21-23 only)

**Interfaces:**
- Consumes: `_rules_frontmatter <file>` (rc 1 = no frontmatter) and `_rules_globs <frontmatter>` (rc 0 globs, 1 no `paths:`, 2 malformed) from `lib/project-rules.sh` (sourced; it runs nothing when sourced).

- [ ] **Step 1: Write the test**

Create `lib/tests/user-rules.test.sh`:

```bash
#!/usr/bin/env bash
# lib/tests/user-rules.test.sh — user-scope rules (rules/*.md, deployed as
# ~/.claude/rules): every frontmatter parses (one-line JSON `paths:` or no
# frontmatter at all) and the always-on set is exactly the two rules chat
# needs (BDR-125 phase 1 moved default-language to lib/architecture-defaults.md
# and the Supabase / cloud-functions bodies to path rules). Globs are not
# matched here: user rules span every stack; the load is proved by an
# InstructionsLoaded session (contract context-diet, criterion 15).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../project-rules.sh disable=SC1091
source "$ROOT/lib/project-rules.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

# rule_kind <file> → path | always | bad
rule_kind() {
  local fm
  fm=$(_rules_frontmatter "$1") || { echo always; return; }
  _rules_globs "$fm" >/dev/null
  case $? in 0) echo path ;; 1) echo always ;; *) echo bad ;; esac
}
# always_on <dir> → the always-on rule file names, space-joined
always_on() {
  local f out=""
  for f in "$1"/*.md; do
    [ "$(rule_kind "$f")" = always ] && out="$out ${f##*/}"
  done
  printf '%s\n' "${out# }"
}

# ── flip controls: the checker bites (LRN-096) ──
FIX="$(mktemp -d)"; trap 'rm -rf "$FIX"' EXIT
printf -- '---\npaths: ["**/*.css"]\n---\n\n# A\n' > "$FIX/a.md"
printf '# B, always-on\n' > "$FIX/b.md"
printf -- '---\npaths:\n  - "**/*.css"\n---\n\n# C\n' > "$FIX/c.md"
check F1-path-rule "$(rule_kind "$FIX/a.md")" path
check F2-no-frontmatter-always "$(rule_kind "$FIX/b.md")" always
check F3-multiline-paths-bad "$(rule_kind "$FIX/c.md")" bad
check F4-extra-always-on-seen "$(always_on "$FIX")" "b.md"
# the R2 lock itself bites on a dir whose always-on set differs
cp "$FIX/b.md" "$FIX/writing-style.md"; cp "$FIX/b.md" "$FIX/secure-by-default.md"
check F5-lock-bites "$([ "$(always_on "$FIX")" = "secure-by-default.md writing-style.md" ] && echo match || echo mismatch)" mismatch

# ── the real rules ──
bad=""
for f in "$ROOT"/rules/*.md; do
  [ "$(rule_kind "$f")" = bad ] && bad="$bad ${f##*/}"
done
check R1-every-frontmatter-parses "${bad# }" ""
check R2-always-on-set "$(always_on "$ROOT/rules")" "secure-by-default.md writing-style.md"
check R3-moved-rules-path "$(rule_kind "$ROOT/rules/supabase.md")/$(rule_kind "$ROOT/rules/cloud-functions.md")" path/path

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run, expect PASS (Tasks 3-4 already landed)**

Run: `make test suite=lib/tests/user-rules.test.sh` → `all suites green`. The lock's bite is F4 (fixture). Never create a file under `rules/` to flip-test: it is the live `~/.claude/rules` of every session on this machine.

- [ ] **Step 3: Correct the project-rules.sh comment (comment only)**

In `lib/project-rules.sh` replace

```bash
# dotglob makes `*` match dotfiles, which the engine's matcher skips: a
# glob that only hits hidden paths passes here but never loads),
```

with

```bash
# dotglob makes `*` match dotfiles; the engine reaches hidden dirs too. Its
# matcher looks gitignore-style (InstructionsLoaded log, 2026-10-26:
# `paths: ["rules/**"]` logged as `globs: ["rules"]` and loaded on a Read
# of `.claude/rules/*.md`): a trailing `/**` dropped, a pattern without an
# inner `/` matching at any depth. A glob can thus load where this check
# does not look; the load proof is the logged session, not this check),
```

- [ ] **Step 4: Run, expect PASS**

Run: `make test suite=lib/tests/project-rules.test.sh` and `make test suite=lib/tests/user-rules.test.sh` → `all suites green`; `bash lib/project-rules.sh check` → `project-rules: 4 rule(s) ok`; `shellcheck lib/project-rules.sh lib/tests/user-rules.test.sh` clean.

- [ ] **Step 5: Commit**

```bash
git add lib/tests/user-rules.test.sh lib/project-rules.sh
git commit -m "test(rules): user-rules suite locks the always-on set; engine matching documented"
```

---

### Task 6: doctrine-citers census resolves rules/ and lib/ § citations

**Files:**
- Modify: `lib/tests/doctrine-citers.test.sh`

**Interfaces:**
- Consumes: `_citers_resolve <doctrine-file> <name>` (existing, rc 0 when a heading starts with `<name>` then end/space/`:`/`(`/`—`, or a bold label `**<name>` exists).
- Produces: `_citers_extract_files <file>…` → `file:line:target:name`; `citers_check_files <root> <file>…` → `DANGLING:` lines, rc = count (≤ 99).

- [ ] **Step 1: Add the extractor, the checker and the flip tests**

In `lib/tests/doctrine-citers.test.sh`, after the `citers_check()` function (before `# ── flip-test`), insert:

```bash
# _citers_extract_files <file>… → "file:line:target:name" per citation of a
# heading in another doctrine file: `rules/<f>.md § Label` or
# `lib/<f>.md § Label`, backticks around the path and quotes around the
# label allowed. A quoted label runs to its closing quote (`—` included); an
# unquoted one ends at the first character that is not a letter, space or
# hyphen: quote a label that prose follows. A citation of
# `.claude/rules/<f>.md § X` would be read as `rules/<f>.md` (none exist;
# ERE has no lookbehind and the portability census bans grep -P).
_citers_extract_files() {
  /usr/bin/grep -nHoE '(rules|lib)/[a-z0-9-]+\.md`? § ?"[^"]{2,60}"' "$@" 2>/dev/null \
    | sed -E 's/^([^:]+:[0-9]+):(.*\.md)`? § ?"([^"]+)"$/\1:\2:\3/'
  /usr/bin/grep -nHoE '(rules|lib)/[a-z0-9-]+\.md`? § ?[A-Z][A-Za-z][A-Za-z -]{1,40}' "$@" 2>/dev/null \
    | sed -E 's/^([^:]+:[0-9]+):(.*\.md)`? § ?(.*)$/\1:\2:\3/; s/[[:space:]]+$//'
}

# citers_check_files <root> <file>… → DANGLING lines; rc = their count (capped 99)
citers_check_files() {
  local root="$1" line file lno target name n=0; shift
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    file="${line%%:*}"; lno="$(printf '%s' "$line" | cut -d: -f2)"
    target="$(printf '%s' "$line" | cut -d: -f3)"; name="${line#*:*:*:}"
    if [ ! -f "$root/$target" ] || ! _citers_resolve "$root/$target" "$name"; then
      echo "DANGLING: $file:$lno → $target § \"$name\""; n=$((n+1))
    fi
  done < <(_citers_extract_files "$@")
  return $(( n > 99 ? 99 : n ))
}
```

After the line `check T2c-label-named ...` insert:

```bash
mkdir -p "$FIX/rules" "$FIX/lib"
printf '## Versioning\nx\n' > "$FIX/rules/api.md"
printf '## WRITE (before the commit)\n' > "$FIX/lib/cc.md"
# shellcheck disable=SC2016  # literal backticks in the fixture
printf 'ok: see `rules/api.md` § Versioning, and lib/cc.md § WRITE (x)\n' > "$FIX/fgood.md"
printf 'quoted: rules/api.md § "Versioning" first\n' >> "$FIX/fgood.md"
printf '## Design work — full toolchain (tiered)\n' > "$FIX/rules/web.md"
printf 'dash: rules/web.md § "Design work — full toolchain" first\n' >> "$FIX/fgood.md"
printf 'bad: rules/api.md § "Version", rules/none.md § Alpha, lib/cc.md § Read\n' > "$FIX/fbad.md"
printf 'dash: rules/web.md § "Design work — full kit" first\n' >> "$FIX/fbad.md"
citers_check_files "$FIX" "$FIX/fgood.md" >/dev/null; check T4-file-citations-resolve "$?" 0
out=$(citers_check_files "$FIX" "$FIX/fbad.md"); rc=$?
check T5-file-dangling-caught "$rc" 4
check T5d-quoted-label-whole "$(printf '%s\n' "$out" | grep -c 'full kit')" 1
check T5b-missing-file-named "$(printf '%s\n' "$out" | grep -c 'rules/none.md')" 1
check T5c-prefix-not-a-heading "$(printf '%s\n' "$out" | grep -c '"Version"')" 1
```

After the line `check T3-repo-citations-resolve "$rc" 0` insert:

```bash
out=$(cd "$ROOT" && citers_check_files "$ROOT" "${FILES[@]}" CLAUDE.global.md); rc=$?
[ -n "$out" ] && printf '%s\n' "$out"
check T6-repo-file-citations-resolve "$rc" 0
# T7: the real citers bite — the same two files against a copy of
# rules/rest-api.md whose heading is renamed (never edit the live rules/)
mkdir -p "$FIX/copy/rules"
cp "$ROOT/rules/rest-api.md" "$FIX/copy/rules/rest-api.md"
(cd "$ROOT" && citers_check_files "$FIX/copy" lib/architecture-defaults.md \
  lib/project-archetypes/rest-api-node.md) >/dev/null
check T7a-real-citers-control "$?" 0
sed 's/^## Versioning$/## Version policy/' "$ROOT/rules/rest-api.md" > "$FIX/copy/rules/rest-api.md"
(cd "$ROOT" && citers_check_files "$FIX/copy" lib/architecture-defaults.md \
  lib/project-archetypes/rest-api-node.md) >/dev/null
check T7b-real-rename-bites "$?" 2
# the hook's pointer is checked whole, not as its "Design work" prefix
check T7c-hook-label-whole "$(cd "$ROOT" && _citers_extract_files hooks/design-toolchain-reminder.sh \
  | grep -c ':rules/web-building.md:Design work — full toolchain$')" 2
```

Also update the file header comment: after the line `# skill's own sections and are out of scope.` add:

```bash
# Since BDR-125 phase 1 doctrine also lives in rules/ and lib/: a
# `rules/<f>.md § Label` / `lib/<f>.md § Label` citation resolves against
# that file (T4-T6).
```

- [ ] **Step 2: Run, expect PASS**

Run: `make test suite=lib/tests/doctrine-citers.test.sh` → `all suites green`. If T6 prints a DANGLING line, the citation text is wrong (fix the citing file's wording, never the checker), report it.

- [ ] **Step 3: Commit**

```bash
git add lib/tests/doctrine-citers.test.sh
git commit -m "test(census): resolve rules/ and lib/ § citations against their file"
```

---

### Task 7: auto memory off; doctor warns on leftover auto-memory files

**Files:**
- Modify: `settings.json` (ONE line; the user's hunks stay unstaged)
- Create: `lib/doctor-automem.sh`, `lib/tests/doctor-automem.test.sh`
- Modify: `doctor.sh` (source line near 28; `check_symlink "rules"` + `_EXPECTED_LINKS=8`; new section 5d after 5c "Scratchpad")

**Precondition (controller):** Task 7 is dispatched only once C1 (the robin_petier entry) is committed: Step 6 switches auto memory off for every session on the machine.

**Interfaces:**
- Produces: `automem_leftover_dirs <projects_dir>` → prints the number of `<projects_dir>/*/memory` dirs holding ≥ 1 file; always rc 0.

- [ ] **Step 1: Write the failing test**

Create `lib/tests/doctor-automem.test.sh`:

```bash
#!/usr/bin/env bash
# lib/tests/doctor-automem.test.sh — lib/doctor-automem.sh's
# automem_leftover_dirs(): absent dir, empty memory dirs, a file, a nested
# file, an empty subdir only, rc 0 under errexit (doctor.sh runs under
# `set -euo pipefail`) — BDR-125 phase 1.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/lib/doctor-automem.sh"
# shellcheck source=../doctor-automem.sh disable=SC1091
source "$LIB"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

check T1-absent-dir "$(automem_leftover_dirs "$W/nope")" 0
mkdir -p "$W/p/-home-a/memory" "$W/p/-home-b/memory"
check T2-empty-dirs "$(automem_leftover_dirs "$W/p")" 0
echo x > "$W/p/-home-a/memory/MEMORY.md"
check T3-one-file "$(automem_leftover_dirs "$W/p")" 1
mkdir -p "$W/p/-home-b/memory/sub"; echo y > "$W/p/-home-b/memory/sub/note.md"
check T4-nested-file-counts "$(automem_leftover_dirs "$W/p")" 2
mkdir -p "$W/p/-home-c/memory/empty-sub"
check T5-empty-subdir-silent "$(automem_leftover_dirs "$W/p")" 2
check T6-rc0-under-errexit "$(bash -c 'set -euo pipefail; source "$1"; automem_leftover_dirs "$2" >/dev/null; echo "rc$?"' _ "$LIB" "$W/nope")" rc0
# doctor.sh calls it on "$HOME/.claude/projects": the same call under a temp HOME
mkdir -p "$W/h/.claude/projects/-home-x/memory"; echo z > "$W/h/.claude/projects/-home-x/memory/a.md"
check T7-via-temp-home "$(HOME="$W/h" bash -c 'source "$1"; automem_leftover_dirs "$HOME/.claude/projects"' _ "$LIB")" 1

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run, expect FAIL**

Run: `make test suite=lib/tests/doctor-automem.test.sh` → red (`lib/doctor-automem.sh` missing).

- [ ] **Step 3: Write the lib**

Create `lib/doctor-automem.sh`:

```bash
#!/usr/bin/env bash
# ============================================================
# lib/doctor-automem.sh — doctor.sh's auto-memory leftover check
#
# settings.json sets "autoMemoryEnabled": false (BDR-125 phase 1): Claude
# Code no longer reads ~/.claude/projects/<slug>/memory/, so a file left
# there is knowledge nobody loads. `automem_leftover_dirs <projects_dir>`
# prints how many <slug>/memory dirs hold at least one file and ALWAYS
# exits 0 (doctor.sh runs under `set -euo pipefail`; an absent dir is 0).
#
# No `set -euo pipefail` here: a sourced lib must not change the caller's
# shell options.
# ============================================================

# automem_leftover_dirs <projects_dir> — see file header.
automem_leftover_dirs() {
  local d n=0
  for d in "$1"/*/memory; do
    [ -d "$d" ] || continue
    if [ -n "$(find "$d" -type f -print -quit 2>/dev/null)" ]; then
      n=$((n + 1))
    fi
  done
  echo "$n"
}
```

- [ ] **Step 4: Wire doctor.sh**

Replace `_EXPECTED_LINKS=7` with `_EXPECTED_LINKS=8`, replace the comment line `# Expected: CLAUDE.md, settings.json, agents, skills, templates, hooks/session-start.sh` with `# Expected: CLAUDE.md, settings.json, agents, skills, templates, lib, rules, hooks/session-start.sh`, and after `check_symlink "lib"` add `check_symlink "rules"` (Design work and the Supabase / cloud-functions bodies now live only under `~/.claude/rules`).

After the two lines

```bash
# shellcheck source=lib/doctor-skills.sh disable=SC1091
source "$REPO/lib/doctor-skills.sh"
```

add

```bash
# shellcheck source=lib/doctor-automem.sh disable=SC1091
source "$REPO/lib/doctor-automem.sh"
```

After the Scratchpad section's closing `unset _sp _sp_fs _sp_opts` + `echo ""`, insert:

```bash
# ────────────────────────────────────────────────────────────
# 5d. Auto memory (BDR-125 phase 1): "autoMemoryEnabled": false, so a file
# left under ~/.claude/projects/<slug>/memory/ is never loaded again.
# ────────────────────────────────────────────────────────────
echo "── Auto memory ──"
if jq -e '.autoMemoryEnabled == false' "$REPO/settings.json" >/dev/null 2>&1; then
  pass "settings.json: autoMemoryEnabled false"
else
  warn "settings.json: autoMemoryEnabled is not false — the auto-memory section loads every session (BDR-125 phase 1)"
fi
_am=$(automem_leftover_dirs "$HOME/.claude/projects")
if [ "$_am" -gt 0 ]; then
  warn "auto memory: $_am project dir(s) still hold files under ~/.claude/projects/*/memory/ (never loaded) — migrate them to the project registries, then remove them by hand"
else
  pass "auto memory: no leftover file under ~/.claude/projects/*/memory/"
fi
unset _am
echo ""
```

- [ ] **Step 5: Run, expect PASS**

Run: `make test suite=lib/tests/doctor-automem.test.sh` → `all suites green`; `shellcheck doctor.sh lib/doctor-automem.sh lib/tests/doctor-automem.test.sh` clean.

- [ ] **Step 6: settings.json, one line, staged alone**

The working tree holds one uncommitted line written by the Claude Code UI, `"theme": "dark",` right after `"effortLevel": "high",` (gate 2026-10-29: UI writes are stashed, never committed): leave it. Stage only the new key, built from HEAD's version:

```bash
tmp=$(mktemp)
git show HEAD:settings.json \
  | sed 's/^  "effortLevel": "high",$/&\n  "autoMemoryEnabled": false,/' > "$tmp"
jq -e '.autoMemoryEnabled == false' "$tmp" >/dev/null || { echo "bad edit"; rm -f "$tmp"; exit 1; }
blob=$(git hash-object -w "$tmp"); rm -f "$tmp"
git update-index --cacheinfo "100644,$blob,settings.json"
sed -i.bak 's/^  "effortLevel": "high",$/&\n  "autoMemoryEnabled": false,/' settings.json && rm settings.json.bak
jq -e '.autoMemoryEnabled == false' settings.json >/dev/null || { echo "worktree edit missed"; exit 1; }
git diff --cached settings.json
```

Expected: the cached diff is exactly one added line `+  "autoMemoryEnabled": false,`; `git diff settings.json` still shows only the `"theme"` line and nothing about autoMemoryEnabled; `jq -e '.autoMemoryEnabled == false' settings.json` → true.

- [ ] **Step 7: Commit**

```bash
git add lib/doctor-automem.sh lib/tests/doctor-automem.test.sh doctor.sh
git commit -m "feat(memory): autoMemoryEnabled false; doctor warns on leftover auto-memory files"
git show --stat HEAD | cat
git diff --stat settings.json | cat
```

Expected: the commit lists settings.json with `1 +`; the `"theme"` line remains unstaged.

---

### Task 8: agent descriptions trimmed at the source (≤ 200 chars)

**Files:**
- Modify (the `description:` line only): `agents/{validator-analyzer,doc-syncer,handover-doc-writer,client-handover-writer,plan-challenger,security-auditor,onboarder,verifier,bugfixer,seo-analyzer,code-cleaner,plugin-advisor,geo-analyzer}.md`

- [ ] **Step 1: Run the oracle, expect FAIL**

Run: `bash .claude/tasks/contracts/c1-agent-desc.sh` → lists the 13 files over 200 chars.

- [ ] **Step 2: Replace each `description:` line with exactly the line below (nothing else in the file changes)**

```
agents/validator-analyzer.md:
description: Web standards audit agent, dispatched from /web-validate. W3C HTML/CSS validity and WCAG 2.1 (axe-core, pa11y, WAVE); scored .claude/audits/VALIDATE.md with fix diffs and user actions.
agents/doc-syncer.md:
description: 'Two-mode public-doc sync agent. MODE: audit (opus, read-only: drift, drafts, PATCH PLAN); MODE: patch (sonnet: applies the approved plan, emits PATCHED_FILES). Never touches .claude/.'
agents/handover-doc-writer.md:
description: 'Two-mode client deliverable writer, dispatched twice by client-handover. MODE: synthesize (opus: memory + git, 6-chapter draft); MODE: render (sonnet: annexes, gates, MD + HTML/PDF).'
agents/client-handover-writer.md:
description: Final ship-and-handover orchestrator called by /client-handover. Audit/fix/gate pipeline (SEO+GEO+HARDEN to ≥17/20, live VALIDATE), then the client deliverable via handover-doc-writer.
agents/plan-challenger.md:
description: Fresh plan challenger. Reads a PLAN file and attacks it through ONE lens (correctness | robustness | simplicity), then renders findings + a verdict. Report-only, blind to the other lenses.
agents/security-auditor.md:
description: 'SAST security gate: pinned semgrep rulesets + the CLAUDE.md security checklist on a diff or scope. VERDICT: PASS | BLOCK(n), blocks HIGH/CRITICAL only. Never fixes code. Fresh dispatch.'
agents/onboarder.md:
description: Generate claude-config files (CLAUDE.md, settings.json, .claudeignore, .gitignore safety, .claude/{tasks,memory,audits}/) for an existing project. No interview, no audit. Called by /onboard.
agents/verifier.md:
description: Fresh independent verifier. Reads a CONTRACT file from disk and renders CONFORME / ECARTS / ERROR on the implemented diff. Report-only, never fixes; dispatched with no iteration history.
agents/bugfixer.md:
description: Bug-fix EXECUTOR dispatched by /bugfix (or /guardrails, /a11y) with a closed DIAGNOSIS + FIX PLAN + contract. Applies the fix and a regression test, runs the suite. No investigation, no commit.
agents/seo-analyzer.md:
description: 'Classical SEO audit agent (Google, Bing), dispatched from /seo: Core Web Vitals, on-page, technical, local SEO, legal (FR). Emits a fix bundle + scored report. AI/GEO → geo-analyzer.'
agents/code-cleaner.md:
description: Cleanup EXECUTOR (PHASE 2) dispatched by /code-clean with an APPROVED scope. Deletes approved dead code, hands style items to the refactorer, re-audits. Zero behavior change, no commit.
agents/plugin-advisor.md:
description: Plugin-fit REASONER dispatched by lib/plugin-gate.md with a PROBE REPORT from plugin-probe. Classifies signals, scores complexity, recommends enable/disable. Report-only.
agents/geo-analyzer.md:
description: GEO audit agent for AI search engines, dispatched by /geo and /seo. AI crawlers, llms.txt, entity signals, Schema.org; emits a fix bundle and a scored report. Classical SEO → seo-analyzer.
```

(Lengths 170-193, all parse as YAML; measured 2026-10-29.)

- [ ] **Step 3: Run, expect PASS, then the full suite**

Run: `bash .claude/tasks/contracts/c1-agent-desc.sh` → `AGENT-DESC-OK (23 agents)`; then `make test` → last line `all suites green`; then `shellcheck *.sh hooks/*.sh lib/*.sh` clean.

- [ ] **Step 4: Commit**

```bash
git add agents/validator-analyzer.md agents/doc-syncer.md agents/handover-doc-writer.md \
  agents/client-handover-writer.md agents/plan-challenger.md agents/security-auditor.md \
  agents/onboarder.md agents/verifier.md agents/bugfixer.md agents/seo-analyzer.md \
  agents/code-cleaner.md agents/plugin-advisor.md agents/geo-analyzer.md
git commit -m "chore(agents): descriptions trimmed to ≤ 200 chars at the source"
```

---

## Controller steps (main loop, not dispatched)

- **C0 — track the oracles** (before Task 1): commit the contract and `.claude/tasks/contracts/c1-*.sh` on this branch (`chore(contract)`), so every task and reviewer reads them from HEAD.
- **C1 — robin_petier entry** (after the STEP 3 gate approves its text, BEFORE Task 7 Step 6): `cd ~/Documents/robin_petier && bash ~/.claude/lib/gitflow.sh start chore memory-lan-server`, then `bash ~/.claude/lib/memory.sh -C ~/Documents/robin_petier add decision --title "<approved>" --status accepted --body-file <abs path>`, memory commit per `lib/capitalize-commit.md`, no merge (user go). robin_petier CLAUDE.md:192/:201 cite "Web APIs — always versioned" / "Public websites — never SPA" as global rules: both headings live on in `lib/architecture-defaults.md`, no patch; journal it.
- **C2 — proofs** (after Task 8): `bash lib/project-rules.sh -C <project> matches '<glob>'` per new glob (faunosteo, game; `**/serverless.*` named if nowhere); one headless `claude -p` per moved path rule naming the Read tool (faunosteo supabase file, game `supabase/functions/*`, a UI file) → `path_glob_match` lines from `~/.claude/logs/instructions-loaded.jsonl`; `claude -p "/context"` vs baseline; analyzer `memory: project` check after an analyzer dispatch. All journaled. If the analyzer memory turns out disabled by `autoMemoryEnabled: false`: STOP and ask the user (revert the line, or keep it and record a BDR).
- **C3 — oracles**: `GATES_TIMEOUT=900 bash ~/.claude/lib/gates.sh run .claude/tasks/contracts/2026-10-28-context-diet-1944.md`.
- **C4 — TODO.md** (STEP 7 memory commit): phase 1 checked with its proof numbers, follow-ups added (the user removes the auto-memory dirs; any deferred item from the gate).
- **C5 — finish precondition** (gate 2026-10-29): `gitflow finish` checks out develop, which git refuses while settings.json carries the uncommitted UI line (`"theme"`). Wrap the finish: `git stash push -m "ui settings" -- settings.json`, finish, `git stash pop`. Never `git checkout -- settings.json` / restore it (it is the live ~/.claude/settings.json). Tracked default stays `"model": "opus"`, `"switchModelsOnFlag": true`.
