---
name: release-candidate
description: 'Use when develop is ahead of main and you want to cut a versioned release — finalize version.txt + CHANGELOG, merge develop→main via the gitflow fan-out, tag it, and push. Triggers: "cut a release", "release candidate", "tag a version", "ship develop to main". NOT feature/bugfix integration (that is gitflow finish via /ship-feature) nor a hotfix.'
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
---

# /release-candidate — cut a gitflow release (orchestrator)

## Overview
Turns the accumulated work on `develop` into a tagged release on `main`. THIN ORCHESTRATOR over `lib/gitflow.sh`: the lib does the generic fan-out (release branch → main + back to develop + delete the branch); the skill adds what the lib deliberately does not know — the **version number, the CHANGELOG, the human "is it time?" gate, and the git tag**.

**Division of labour (lib = mechanic, skill = judgment):** the tag lives HERE, not in `gitflow.sh`, because it is release-specific (version + message + human decision) while the lib's fan-out is generic. **Consequence (accepted):** a release cut by calling `gitflow finish` directly, bypassing this skill, fans out but is NOT tagged — `/release-candidate` is the canonical release path.

The two mechanical spans (prep, finish+tag) run on the sonnet-pinned
`release-executor` subagent (dispatch makes the pin effective) — no model
gate needed here, dispatch does the job. This dispatcher keeps everything
the executor must never own: the version-NUMBER decision (judgment — derives
from semver change nature), and the two human gates (when to release, and
the push). A human gate sits BETWEEN the two spans by construction, so the
executor is never dispatched twice in one call.

## When to use
- `develop` is ahead of `main` and you want to publish a version.
- "cut a release", "release candidate", "tag a version", "ship develop to main".

Not for: integrating a feature/bugfix → `gitflow finish` (via /ship-feature). A prod emergency fix off main → `hotfix` (different fan-out).

## Versioning
- Tag scheme `vX.Y.Z` (semver, v-prefix — Gitea/GitHub release convention). **Continues** the `version.txt` + CHANGELOG lineage (the repo's authority); never restart at v1.0.0 (desyncs from a CHANGELOG already at 3.x+).
- The number DERIVES from the change nature (semver), not the reverse: a migration-requiring/breaking change → MAJOR; new features → MINOR; fixes → PATCH. Personal repo ⇒ "breaking" = requires a migration of your own usage. Decide the number BEFORE running.

## Flow
**REQUIRED:** `lib/gitflow.sh` (the release mechanic, via the `release-executor` subagent). Clean tree, identity set, `develop` ahead of `main`.

### STEP 1 — Preconditions
```bash
git status --porcelain=v1 | wc -l    # 0 required — clean tree
git config user.email                # must be set
git rev-list --count main..develop   # 0 → nothing to release, STOP
```
Any of these fail their check → STOP, tell the user what's blocking, dispatch nothing.

### STEP 2 — Version-number decision (judgment, stays HERE)
Read the `## [Unreleased]` section of `CHANGELOG.md` and the commits on
`develop` since `main`. Apply the Versioning rule above (breaking → MAJOR,
features → MINOR, fixes → PATCH) and settle `<X.Y.Z>` before dispatching
anything — the executor never derives or second-guesses this number.

### STEP 3 — Dispatch: prep
```
Agent(subagent_type="release-executor")
prompt: "SPAN: prep <X.Y.Z>
<any release-candidate fixes to fold into the prep commit, or 'none'>"
```
Parse the `RELEASE-EXEC REPORT`:
- `STATUS: DONE` → continue to STEP 4, carrying the `TESTS` line forward.
- `STATUS: NEED-DECISION` → surface the exact question to the user, STOP
  (don't guess the CHANGELOG wording on its behalf).
- `STATUS: BLOCKED` → surface the blocker verbatim, STOP.

### STEP 4 — HUMAN GATE: when to release
STOP. Show the prep report's `TESTS` result, then:
```
AskUserQuestion:
  Release <X.Y.Z> now? (tests: <TESTS line from STEP 3>) — go / hold
```
Proceed only on an explicit human go. **Never fire on "tests pass"** — a
green suite means ready to release, not authorized to. `hold` → stop here;
the prepped `release/<X.Y.Z>` branch stays as-is for a later run.

### STEP 5 — Dispatch: finish + tag
```
Agent(subagent_type="release-executor")
prompt: "SPAN: finish <X.Y.Z>"
```
Parse the `RELEASE-EXEC REPORT`:
- `STATUS: DONE` → continue to STEP 6, carrying the `TAG` value forward.
- `STATUS: BLOCKED` → surface the blocker verbatim (e.g. a merge conflict
  the fan-out hit), STOP — resolving a conflicted fan-out is a human call,
  not an auto-retry.

### STEP 6 — Push GATE (ASK)
STOP. On explicit go only ([[LRN-069]]) — run the push HERE, in this
dispatcher, never delegated to the executor:
```
AskUserQuestion:
  Push main, develop, and v<X.Y.Z> to origin? — go / hold
```
Go →
```bash
git push origin main develop && git push origin v<X.Y.Z>
```
`hold` → stop; the release is fanned out and tagged locally, unpushed.

## Common mistakes
- Tagging before `gitflow finish` → tag wouldn't sit on main's merge commit. Tag AFTER, on main.
- Auto-firing finish because tests pass → finish is a HUMAN gate.
- Restarting the tag at v1.0.0 → desyncs from the CHANGELOG lineage. Continue it.
- Pushing without the ASK gate → [[LRN-069]].

## Validation
`RC_WORK=$(mktemp -d) RC_TAG=1 bash lib/tests/run-release-candidate.sh` → 5/5 (fan-out + tag on main). `RC_TAG=0` reds the tag assertion — proves the lib alone never tags (the gap this skill fills).
