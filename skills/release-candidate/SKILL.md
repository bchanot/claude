---
name: release-candidate
description: 'Use when develop is ahead of main and you want to cut a versioned release — finalize version.txt + CHANGELOG, merge develop→main via the gitflow fan-out, tag it, and push. Triggers: "cut a release", "release candidate", "tag a version", "ship develop to main". NOT feature/bugfix integration (that is gitflow finish via /ship-feature) nor a hotfix.'
---

# /release-candidate — cut a gitflow release (orchestrator)

## Overview
Turns the accumulated work on `develop` into a tagged release on `main`. THIN ORCHESTRATOR over `lib/gitflow.sh`: the lib does the generic fan-out (release branch → main + back to develop + delete the branch); the skill adds what the lib deliberately does not know — the **version number, the CHANGELOG, the human "is it time?" gate, and the git tag**.

**Division of labour (lib = mechanic, skill = judgment):** the tag lives HERE, not in `gitflow.sh`, because it is release-specific (version + message + human decision) while the lib's fan-out is generic. **Consequence (accepted):** a release cut by calling `gitflow finish` directly, bypassing this skill, fans out but is NOT tagged — `/release-candidate` is the canonical release path.

## When to use
- `develop` is ahead of `main` and you want to publish a version.
- "cut a release", "release candidate", "tag a version", "ship develop to main".

Not for: integrating a feature/bugfix → `gitflow finish` (via /ship-feature). A prod emergency fix off main → `hotfix` (different fan-out).

## Versioning
- Tag scheme `vX.Y.Z` (semver, v-prefix — Gitea/GitHub release convention). **Continues** the `version.txt` + CHANGELOG lineage (the repo's authority); never restart at v1.0.0 (desyncs from a CHANGELOG already at 3.x+).
- The number DERIVES from the change nature (semver), not the reverse: a migration-requiring/breaking change → MAJOR; new features → MINOR; fixes → PATCH. Personal repo ⇒ "breaking" = requires a migration of your own usage. Decide the number BEFORE running.

## Flow
**REQUIRED:** `lib/gitflow.sh` (the release mechanic). Clean tree, identity set, `develop` ahead of `main`.

1. **Preconditions** — clean tree, git identity, `develop` ahead of `main` (else nothing to release).
2. `gitflow start release <X.Y.Z>` — forks from develop, lands on `release/<X.Y.Z>`.
3. **Prep** on the release branch:
   - `version.txt` → `<X.Y.Z>`.
   - CHANGELOG: `## [Unreleased]` → `## [<X.Y.Z>] — <date>`, re-open an empty `[Unreleased]`. A MAJOR must spell out its breaking change (`### Changed`/`### Removed`/BREAKING); review the doc-syncer draft for completeness.
   - Any release-candidate fixes; commit the prep on the branch.
   - **Run the test suite** (`lib/tests/*`, gitflow-test) — RC gate; never release red.
4. **HUMAN GATE — WHEN to release.** STOP. Proceed only on an explicit human go (mirror /ship-feature's finish gate). Never fire on "tests pass".
5. `gitflow finish` — lib fans out: merge `release/*`→`main`, merge-back→`develop`, delete the branch.
6. **Tag** (the piece the lib lacks): `git tag -a v<X.Y.Z> main -m "release <X.Y.Z>"` — annotated, on main's release-merge commit, AFTER finish.
7. **Push — GATED (ASK).** On explicit go only ([[LRN-069]]): `git push origin main develop && git push origin v<X.Y.Z>`.

## Common mistakes
- Tagging before `gitflow finish` → tag wouldn't sit on main's merge commit. Tag AFTER, on main.
- Auto-firing finish because tests pass → finish is a HUMAN gate.
- Restarting the tag at v1.0.0 → desyncs from the CHANGELOG lineage. Continue it.
- Pushing without the ASK gate → [[LRN-069]].

## Validation
`RC_WORK=$(mktemp -d) RC_TAG=1 bash lib/tests/run-release-candidate.sh` → 5/5 (fan-out + tag on main). `RC_TAG=0` reds the tag assertion — proves the lib alone never tags (the gap this skill fills).
