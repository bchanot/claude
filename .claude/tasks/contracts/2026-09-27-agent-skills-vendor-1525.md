# CONTRACT — agent-skills-vendor
- date: 2026-09-27 | flow: feat (ad-hoc dispatch, /feat gates replayed by the orchestrator) | branch: feature/agent-skills-borrow
- status: active

## REQUEST (verbatim — IMMUTABLE)
> Vendor three skills from addyosmani/agent-skills as machine-owned copies, the emil-design-eng way: `observability-and-instrumentation`, `deprecation-and-migration`, `ci-cd-and-automation`. Source pinned to commit `2686b620fc1fed2e8f60c704839c766b8594c6b6` (main, 2026-09-26) in `plugins.lock.json`; the scripts read the pin from the lock, never hardcode it. Each lands in `skills-external/<name>/SKILL.md` (gitignored, curl'd by install-plugins.sh, refreshed by update-all.sh at the pinned commit), symlinked by link.sh, registered wherever emil-design-eng is registered when the semantics apply (toggle-external registry, profiles that carry the dev skills, tests that enumerate externals, CHANGELOG). User go 2026-09-27 ("ok pour les 4", case 2 of the 6-repo review).

## CLARIFICATIONS
- Profiles: add the three to `full.profile` and to every profile that lists `bugfix` (dev-class); never to design/web profiles.
- Not mirrored on purpose (design-only citers): lib/design-gate.md, lib/tests/fixtures/registry-index-drift.md, lib/profiles/{design,web,web-full}.profile, agents/plugin-advisor.md, agents/plugin-probe.md, CLAUDE.global.md.
- Upstream SKILL.md copied byte-for-byte: no edits, no rewrite of internal links (dangling cross-skill mentions accepted).
- The executor materializes the three files with the same curl the install step uses (network read allowed); it never runs `link.sh`, `make link`, `make plugin` or `update-all.sh` (they touch `~/.claude`).
- Lock entry shape: `"agent-skills": {"source": "https://github.com/addyosmani/agent-skills", "commit": "<sha>", "skills": [...], "managed_by": "curl", "note": "..."}`. A helper reading it may follow the `pinned_version` pattern of install-plugins.sh.
- The three raw URLs: `https://raw.githubusercontent.com/addyosmani/agent-skills/<sha>/skills/<name>/SKILL.md` (no extra files under these three skills upstream).

## ACCEPTANCE CRITERIA
1. Three vendored files present, frontmatter name = dir name.
   CHECK: ok=1; for s in observability-and-instrumentation deprecation-and-migration ci-cd-and-automation; do f="skills-external/$s/SKILL.md"; [ -f "$f" ] && grep -q "^name: $s\$" "$f" || { echo "bad $s"; ok=0; }; done; [ "$ok" -eq 1 ] && echo VENDORED
   EXPECT: VENDORED
   EVIDENCE: MET exit=0 marker-found :: VENDORED
2. Pin recorded in the lock with the three names.
   CHECK: python3 -c 'import json; d=json.load(open("plugins.lock.json"))["agent-skills"]; assert d["commit"]=="2686b620fc1fed2e8f60c704839c766b8594c6b6", d; assert set(d["skills"])=={"observability-and-instrumentation","deprecation-and-migration","ci-cd-and-automation"}, d; print("PINNED")'
   EXPECT: PINNED
   EVIDENCE: MET exit=0 marker-found :: PINNED
3. Install and update steps exist and are lock-driven (no hardcoded sha).
   CHECK: grep -q "agent-skills" install-plugins.sh && grep -q "agent-skills" update-all.sh && ! grep -q "2686b620" install-plugins.sh update-all.sh link.sh lib/toggle-external.sh && echo LOCK_DRIVEN
   EXPECT: LOCK_DRIVEN
   EVIDENCE: MET exit=0 marker-found :: LOCK_DRIVEN
4. Both the copy and the symlink path are gitignored.
   CHECK: ok=1; for s in observability-and-instrumentation deprecation-and-migration ci-cd-and-automation; do git check-ignore -q "skills-external/$s" && git check-ignore -q "skills/$s" || { echo "not ignored $s"; ok=0; }; done; [ "$ok" -eq 1 ] && echo IGNORED
   EXPECT: IGNORED
   EVIDENCE: MET exit=0 marker-found :: IGNORED
5. link.sh symlinks them (EXTERNAL_SKILLS list).
   CHECK: ok=1; for s in observability-and-instrumentation deprecation-and-migration ci-cd-and-automation; do grep -q "$s" link.sh || { echo "not linked $s"; ok=0; }; done; [ "$ok" -eq 1 ] && echo LINK_LISTED
   EXPECT: LINK_LISTED
   EVIDENCE: MET exit=0 marker-found :: LINK_LISTED
6. Emil citers census mirrored (tracked files only: the ignored install-*.log files at the root also name emil), except the design-only allowlist.
   CHECK: allow=" lib/design-gate.md lib/tests/fixtures/registry-index-drift.md lib/profiles/design.profile lib/profiles/web.profile lib/profiles/web-full.profile agents/plugin-advisor.md agents/plugin-probe.md CLAUDE.global.md "; miss=0; for f in $(git grep -l emil-design-eng -- . ':!skills-external' ':!skills' ':!.claude'); do grep -q observability-and-instrumentation "$f" && continue; case "$allow" in *" $f "*) ;; *) echo "not mirrored: $f"; miss=1 ;; esac; done; [ "$miss" -eq 0 ] && echo CENSUS_MIRRORED
   EXPECT: CENSUS_MIRRORED
   EVIDENCE: MET exit=0 marker-found :: CENSUS_MIRRORED
7. Profile, toggle-external and doctrine-citers suites green.
   CHECK: out=$(make test suite="lib/tests/profile-default.test.sh lib/tests/profile-set-managed.test.sh lib/tests/toggle-external-repo-resolution.test.sh lib/tests/doctrine-citers.test.sh" 2>&1); echo "$out" | grep -qE "FAIL=[1-9]" && { echo "$out" | tail -20; exit 1; }; echo SUITES_GREEN
   EXPECT: SUITES_GREEN
   EVIDENCE: MET exit=0 marker-found :: SUITES_GREEN
8. shellcheck clean on the touched scripts.
   CHECK: shellcheck install-plugins.sh update-all.sh link.sh lib/toggle-external.sh lib/profile.sh && echo SHELLCHECK_OK
   EXPECT: SHELLCHECK_OK
   EVIDENCE: MET exit=0 marker-found :: SHELLCHECK_OK

## FILE SCOPE
- plugins.lock.json, install-plugins.sh, update-all.sh, link.sh, .gitignore
- lib/toggle-external.sh, lib/profile.sh (only if the externals registry lives there), lib/profiles/full.profile + dev-class profiles
- lib/tests/profile-default.test.sh, lib/tests/profile-set-managed.test.sh, lib/tests/toggle-external-repo-resolution.test.sh (only if they enumerate externals)
- CHANGELOG.md (Unreleased entry)
- skills-external/<name>/SKILL.md x3 (materialized, gitignored)

## PLAN
1. `grep -rn emil-design-eng` census (files listed in criterion 6) → mirror file by file, same comment density.
2. Lock entry; install-plugins.sh new step next to Step 8 ("agent-skills — 3 skills, pinned commit") reading the sha from the lock (python3/jq like the existing helpers), curl each raw URL into skills-external/<name>/SKILL.md, skip when present, `err` with the manual command on failure; update-all.sh step re-curls at the pinned sha (tmp + mv, emil precedent).
3. link.sh EXTERNAL_SKILLS += 3; .gitignore: `skills/<name>` in the symlink allowlist + `skills-external/<name>/` with a short comment naming the source (emil precedent).
4. toggle-external registry + profiles + tests that enumerate externals.
5. Materialize the three files with the curl; run criteria 1-8; report the emil citers you deliberately did not mirror and why.
