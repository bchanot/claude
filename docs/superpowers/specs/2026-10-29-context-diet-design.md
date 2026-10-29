# Phase 1 — native context diet (design)

Contract: `.claude/tasks/contracts/2026-10-28-context-diet-1944.md` (the
acceptance criteria live there). Queue: BDR-125, TODO bullet "Phase 1,
native context diet: no mod". Approved in chat 2026-10-29 (A = 200 chars,
B = extend the census).

## Goal

Cut the always-on context loaded by every session, without a mod: each
section moves to the native carrier that fires when it is needed (path rule,
hook, lib Read by our skills, setting). Nothing is lost: every moved text is
reachable where it serves. Estimate: −2 to −2.5k tokens per session
(baseline 2026-10-28: 30.5k total, Memory files 9.6k, System prompt 4.4k,
Custom agents 2.6k).

## Carriers

| Source (develop 017a28b) | Carrier | Always-on residue |
|---|---|---|
| auto-memory system section | `"autoMemoryEnabled": false` (settings.json) | none |
| CLAUDE.global.md § Design work — full toolchain (tiered by scope) | appended verbatim to `rules/web-building.md` (same UI globs) | Skill-routing line points to it; design hook one-liner says Read it |
| CLAUDE.global.md § graphify usage body | `hooks/session-start.sh`, free lines after the box, only when `<repo root>/graphify-out/graph.json` exists | `## graphify` + the 200-file threshold rule |
| CLAUDE.global.md § Public websites — never SPA + `rules/default-language.md` | `lib/architecture-defaults.md` (verbatim, H1 of the language rule demoted to H2) | one line under `# Architecture decisions` naming Rust default, never SPA, `/api/v1`, the lib path |
| CLAUDE.global.md § Web APIs — always versioned | `rules/rest-api.md` § Versioning (full text, replaces "Not repeated here"); the lib carries a one-line summary + pointer | named in the architecture line |
| `rules/secure-by-default.md` §4 Supabase, §6 Cloud functions bodies | `rules/supabase.md` (`**/supabase/**`, `**/*supabase*.*`), `rules/cloud-functions.md` (`**/functions/**`, `**/serverless.*`, `**/firebase.json`), bullets verbatim | the two headings stay, one line each (critical rule + pointer) |
| `agents/*.md` `description:` (23 tracked) | trimmed at the source to ≤ 200 chars | n/a |

`rules/default-language.md` is deleted. The always-on rule set becomes
exactly `writing-style.md` + `secure-by-default.md`.

## Exact visible strings

- CLAUDE.global.md, under `# Architecture decisions` (replaces the intro and
  the two sections):
  `New project, scaffolding, stack brainstorm or whole-project rewrite: Rust
  by default, a public site is never a SPA (Astro; Next.js when SSR is
  needed), every web API versioned `/api/v1/` from day one. Read
  `~/.claude/lib/architecture-defaults.md` before proposing a stack.`
- CLAUDE.global.md Skill routing: `Design / UI (build, system, audit,
  polish) → Read ~/.claude/rules/web-building.md § Design work first`.
- Design hook stdout: `Design work detected → Read
  ~/.claude/rules/web-building.md § "Design work — full toolchain" first.
  Trivial (≤2 files, cosmetic) → /hotfix.` (one line).
- secure-by-default.md §4: `- RLS on every table, never a service_role or
  secret key client-side. Full domain: rules/supabase.md (loads on Supabase
  files).` §6: `- Max instances and a timeout on every function, never a
  self-trigger. Full domain: rules/cloud-functions.md (loads on function
  files).`

## Readers of the lib

init-project (interviewer row, STEP 3 brainstorm input, STEP 5 scaffolder
brief), agents/interviewer.md, agents/scaffolder.md, ship-feature STEP 1
(when the feature picks a language, framework or API shape), onboard STEP 6
(audit briefs), audit-delta conformity axis. agents/seo-analyzer.md cites the
lib for "public sites are never SPAs". /refactor is not edited (no
whole-project mode; the always-on line covers it).

## Hook fixes (user scope additions, pass A)

- design-toolchain-reminder.sh skips `<agent-message` turns (857 of 2,779
  logged fires) like it skips `<task-notification>`.
- Its suite runs every call under a temp HOME (1,770 logged fires were suite
  prompts); the exact one-liner is asserted.

## Auto memories

One decision entry into robin_petier's registry (LAN dev server: never start
unprompted, detached form on ask, a server found running = user-started → ask
before killing), via `memory.sh -C`, on a `chore/*` branch of that repo, text
shown to the user first. The other four are dropped (already in registries,
or contrary to doctrine). The user removes the auto-memory dirs by hand.
`lib/doctor-automem.sh` + suite: doctor warns while any
`~/.claude/projects/*/memory/` holds a file.

## Proofs

- New suite `lib/tests/user-rules.test.sh`: every `rules/*.md` frontmatter
  parses (one-line JSON `paths:` or none); the always-on set is exactly
  writing-style + secure-by-default; flip controls (two-line `paths:`, an
  extra always-on file).
- Census extension (`lib/tests/doctrine-citers.test.sh`): citations of
  `rules/<f>.md § Label` and `lib/<f>.md § Label` resolve against that file's
  headings; flip-tested.
- New suite for the session-start graphify branch (graph present / absent).
- `lib/tests/doctor-automem.test.sh` (empty → silent, one file → warn, count).
- Controller proof (journaled, not in make test): `project-rules.sh -C
  <project> matches <glob>` per new glob in a real project; one headless
  session per moved path rule whose prompt names the Read tool, logged
  `path_glob_match` (faunosteo supabase, game supabase/functions, a UI file);
  `/context` after vs baseline.

## Cleanup and citers

lib/project-rules.sh:22-23 comment (engine matching is gitignore-style:
trailing `/**` dropped, any depth, hidden dirs included; evidence
InstructionsLoaded `globs: ["rules"]` on `.claude/rules/*.md`);
.claude/rules/rules-maintenance.md (always-on exception list, the
"always-on doctrine stays in CLAUDE.global.md" sentence, matching note);
lib/design-gate.md:48 (stale "+motion / +static" citation);
lib/project-archetypes/rest-api-node.md:58; CLAUDE.global.md Higgsfield line;
hooks/session-start.sh BDR-031 comment; TODO.md phase 1 checked + follow-ups.
CLAUDE.global.md ends ≤ 320 lines.

## Out of scope

/refactor edits; the four vendored `impeccable-*` agents; the per-repo memory
v2 upgrade pass; settings.json `model`/`theme` lines written by the user's
`/model` (left uncommitted, user decides).

## Risks

- `autoMemoryEnabled: false` may also affect the analyzer's `memory:
  project`: checked during the proof, not promised.
- Engine glob semantics differ from compgen: the static suite proves parsing
  only; loading is proved by the logged sessions.
- `**/functions/**` also fires in non-cloud `functions/` dirs (≈80 tokens of
  noise there), accepted.
