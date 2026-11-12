# CONTRACT — claude-md-split
- date: 2026-10-26 | flow: ship-feature | branch: feature/claude-md-split (to be started off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
Phase 0 of the context mod queue (BDR-125), TODO.md "Phase 0, no mod: split project CLAUDE.md": move the 4 project CLAUDE.md sections to .claude/rules/<name>.md with paths: frontmatter, .gitignore !.claude/rules/, higgsfield MCP user step, /onboard split mode, onboarder + scaffolder emit path rules, then per-repo pass. Shared rules at TODO.md lines 8-13 (baseline /context first, static glob check + InstructionsLoaded session proof, cleanup + citers).

(TODO.md lines 6-30 at commit aaeaac8 are the detailed spec this request points at.)

## CLARIFICATIONS
Pass A (gaps found by the read-before analysis, asked in the STEP 1 brainstorm batch, answered 2026-10-26):
- Q: Scope of this run: the per-repo pass cannot live in this repo's feature branch. / A: this run = this repo's split + static check suite + gitignore socle + proof hook + `/onboard split` mode + onboarder/scaffolder path rules. The per-repo pass over the 6 other repos runs AFTER merge through the shipped `/onboard split`, one chore branch per repo, user approval per repo. [gated 2026-10-26]
- Q: No InstructionsLoaded hook exists anywhere. Throwaway bench or permanent? / A: permanent logging hook `hooks/instructions-loaded.sh` registered in settings.json, one JSON line per loaded instruction file into `~/.claude/logs/instructions-loaded.jsonl`; reused by phase 1 and the per-repo proofs. [gated 2026-10-26]
- Q: `docs/superpowers/**` matches 0 tracked files at rest and those files are Written, never Read: static check fails by construction. / A: path rule `.claude/rules/transient-artifacts.md` (paths `docs/superpowers/**`, `.audit/**`) with a YAML comment `# static-check: skip` in the frontmatter that the checker honors; its proof is the logged session. [gated 2026-10-26]
- Q: Patch `templates/gitignore/standard.gitignore` (the socle) too? / A: yes, socle + this repo's `.gitignore`, gitflow-test assertions updated. [gated 2026-10-26]
Brainstorm (design approved 2026-10-26): rule files `rules-maintenance.md`, `graphify-vendored.md`, `mods.md`, `transient-artifacts.md`; lib `lib/project-rules.sh` (check / sections / extract); generator skeleton set docker + testing + ci under `templates/project-rules/`; onboarder `MODE: split` executes the approved table; RED-then-GREEN pressure test on the skill edit. [gated 2026-10-26]
Pass B (plan, 2026-10-26):
- Q: name of the fourth lib subcommand that writes a skeleton with the matching globs only? / A: `emit <skeleton> <out>`. [gated 2026-10-26]
- Q: heading of the pointer section left in a split CLAUDE.md? / A: `## Path-scoped rules`. [gated 2026-10-26]
- Q: language of the new onboard § SPLIT MODE and onboarder MODE: split inside a French skill? / A: English. [gated 2026-10-26]

## ACCEPTANCE CRITERIA
1. Project `CLAUDE.md` no longer holds the 4 sections (rules/ maintenance, graphify vendored skill, mods/, transient planning artifacts); it keeps Health Stack plus a short pointer to `.claude/rules/`.
   CHECK: cd /home/bchanot/Documents/claude && ! grep -qE '^## (rules/ maintenance|Machine-owned: the vendored graphify skill|mods/ — function-hooks|Transient planning artifacts)' CLAUDE.md && grep -q '.claude/rules' CLAUDE.md && echo SPLIT-OK
   EXPECT: SPLIT-OK
   EVIDENCE: MET exit=0 marker-found :: SPLIT-OK
2. Each moved section lives in `.claude/rules/<name>.md` with a `paths:` frontmatter that parses (same shape as `rules/a11y.md`), is tracked by git (`!.claude/rules/` negation in `.gitignore`), and each glob matches at least one path in the working tree (the static check, `lib/project-rules.sh check`), unless the rule carries the `# static-check: skip` marker (transient-artifacts only).
   CHECK: cd /home/bchanot/Documents/claude && test "$(git ls-files .claude/rules | wc -l)" -ge 4 && bash lib/project-rules.sh check | grep -q '4 rule(s) ok' && echo RULES-STATIC-OK
   EXPECT: RULES-STATIC-OK
   EVIDENCE: MET exit=0 marker-found :: RULES-STATIC-OK
3. The static glob check is a `make test` suite (`lib/tests/project-rules.test.sh`) with flip tests (an unmatched glob, a literal typo, a dep-dir-only match each fail it).
   CHECK: cd /home/bchanot/Documents/claude && make test suite=lib/tests/project-rules.test.sh 2>&1 | grep -q 'all suites green' && grep -c 'T2c-literal-typo-fails\|T2d-dep-dir-only' lib/tests/project-rules.test.sh | grep -qx 2 && echo SUITE-OK
   EXPECT: SUITE-OK
   EVIDENCE: MET exit=0 marker-found :: SUITE-OK
4. One real session shows each moved rule loading on `load_reason: path_glob_match` (`~/.claude/logs/instructions-loaded.jsonl`, filtered on `memory_type == "Project"` and `/.claude/rules/`), plus one sub-agent probe recording whether a path rule loads inside a sub-agent; evidence pasted into the journal.
5. `/context` measured before and after at the repo root; the always-on delta recorded in the journal.
6. The higgsfield user-scope MCP is removed by the user (`claude mcp remove -s user higgsfield`), recorded as a manual step, no toggle ownership and no doctor check added.
7. Every citer of the moved headings or of "project CLAUDE.md" as their location is patched (rules/README.md:9, doctor.sh:76 comment, ARCHITECTURE.md tree, any skill/lib/agent grep hit); append-only registries untouched.
   CHECK: cd /home/bchanot/Documents/claude && ! grep -rnE 'CLAUDE\.md`? \(project scope\)|29-line project CLAUDE.md' rules/ doctor.sh skills/ agents/ lib/ hooks/ --include='*.md' --include='*.sh' | grep -v skills-external && echo CITERS-OK
   EXPECT: CITERS-OK
   EVIDENCE: MET exit=0 marker-found :: CITERS-OK
8. `/onboard` gains a `split` mode (public name per pass B) that classifies an existing project CLAUDE.md's sections always-on vs path-scoped, proposes globs from the real tree, gets per-project approval, writes `.claude/rules/<name>.md` + slimmed CLAUDE.md + the `!.claude/rules/` negation when `.claude/*` is ignored. Skill edit goes through /writing-skills with a RED pressure test first.
9. onboarder and scaffolder emit path rules from day one (the sections classified path-scoped per the brainstorm), with the gitignore negation reaching the project through the gitflow socle: before the root commit for a scaffold (init-project STEP 5f `gitflow init`), at /onboard STEP 2.6 `gitflow init` for an onboarded project (after the onboarder's write, before any commit); the onboarder's own PHASE 4 is unchanged. [amended 2026-10-26, plan r2/r3]
10. Full suite green: `make test`.
   CHECK: cd /home/bchanot/Documents/claude && make test 2>&1 | tail -3 | grep -q 'all suites green' && echo MAKE-TEST-OK
   EXPECT: MAKE-TEST-OK
   EVIDENCE: MET exit=0 marker-found :: MAKE-TEST-OK
11. shellcheck clean on the Health Stack scope.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck ./*.sh hooks/*.sh lib/*.sh && echo SHELLCHECK-OK
   EXPECT: SHELLCHECK-OK
   EVIDENCE: MET exit=0 marker-found :: SHELLCHECK-OK
12. `lib/project-rules.sh matches <glob>`: rc 0 + up to 3 hits on stdout; rc 1 + `no match: <glob>` on stderr; a glob with more than a pipe buffer of hits is still a match (no `head` after the producer; T5k/T5l). [gated 2026-10-26]
   CHECK: cd /home/bchanot/Documents/claude && bash lib/project-rules.sh matches 'skills/**' >/dev/null && ! bash lib/project-rules.sh matches 'nowhere/**' 2>/dev/null && grep -c 'T5k-many-hits-rc\|T5l-three-lines' lib/tests/project-rules.test.sh | grep -qx 2 && echo MATCHES-OK
   EXPECT: MATCHES-OK
   EVIDENCE: MET exit=0 marker-found :: MATCHES-OK
13. Every subcommand takes a leading `-C <dir>` (a dispatched agent's cwd is the session's); a missing dir is rc 2. [gated 2026-10-26]
   CHECK: cd / && bash /home/bchanot/Documents/claude/lib/project-rules.sh -C /home/bchanot/Documents/claude check | grep -q '4 rule(s) ok' && ! bash /home/bchanot/Documents/claude/lib/project-rules.sh -C /nonexistent-dir check 2>/dev/null && echo DASH-C-OK
   EXPECT: DASH-C-OK
   EVIDENCE: MET exit=0 marker-found :: DASH-C-OK
14. `emit <skeleton> <out>` writes the skeleton with the matching globs only, rc 1 and nothing written when none matches, rc 2 when the target exists; the three skeletons `templates/project-rules/{docker,testing,ci}.md` exist with `paths:` frontmatter and `TODO(/onboard STEP 3)` stubs. [gated 2026-10-26]
   CHECK: cd /home/bchanot/Documents/claude && test -f templates/project-rules/docker.md && test -f templates/project-rules/testing.md && test -f templates/project-rules/ci.md && grep -c 'T12b-docker-globs-pruned\|T12f-ci-not-emitted-rc\|T12h-existing-target-rc' lib/tests/project-rules.test.sh | grep -qx 3 && echo EMIT-OK
   EXPECT: EMIT-OK
   EVIDENCE: MET exit=0 marker-found :: EMIT-OK
15. The hook logs `ts, session_id, agent_id, agent_type, cwd, file_path, memory_type, load_reason, globs, trigger_file_path`, honors `CLAUDE_INSTRUCTIONS_LOG`, rotates above 5 MB, exits 0 with no stdout when jq is absent or the log is unwritable; registered in `settings.json` under `InstructionsLoaded`. [gated 2026-10-26]
   CHECK: cd /home/bchanot/Documents/claude && jq -r '.hooks.InstructionsLoaded[0].hooks[0].command' settings.json | grep -q 'instructions-loaded.sh' && grep -c 'T10e-ids-kept\|T10h-no-jq-rc0\|T10k-rotated' lib/tests/project-rules.test.sh | grep -qx 3 && echo HOOK-OK
   EXPECT: HOOK-OK
   EVIDENCE: MET exit=0 marker-found :: HOOK-OK
16. `skills/onboard/SKILL.md` gains `## MODE DISPATCH` and `## SPLIT MODE` (S1 preconditions, S2 baseline, S3 branch, S4 classify with `matches`, S5 mandatory gate, S6 onboarder dispatch, S7 after, never `finish`); `agents/onboarder.md` gains `## MODE: split` (S0 preflight incl. gitignore negation, S1 extract with rollback, S2 pointer, S3 check + commit rc checked + `cat-file -e HEAD:` per rule, two STOP shapes); the routing locks stay green. [gated 2026-10-26]
   CHECK: cd /home/bchanot/Documents/claude && grep -q '^## MODE DISPATCH' skills/onboard/SKILL.md && grep -q '^## SPLIT MODE' skills/onboard/SKILL.md && grep -q '^## MODE: split' agents/onboarder.md && grep -q 'cat-file -e HEAD:' agents/onboarder.md && grep -q 'not in HEAD after commit' agents/onboarder.md && echo SPLIT-MODE-OK
   EXPECT: SPLIT-MODE-OK
   EVIDENCE: MET exit=0 marker-found :: SPLIT-MODE-OK
17. onboarder `## PHASE 5b` and scaffolder `## PHASE 3b` emit `docker`/`testing`/`ci` through `emit`, then run `check`; `templates/project-CLAUDE.md` header names `.claude/rules/`. [gated 2026-10-26]
   CHECK: cd /home/bchanot/Documents/claude && grep -q '^## PHASE 5b' agents/onboarder.md && grep -q '^## PHASE 3b' agents/scaffolder.md && grep -q 'Path-scoped rules: .claude/rules' templates/project-CLAUDE.md && echo GENERATORS-OK
   EXPECT: GENERATORS-OK
   EVIDENCE: MET exit=0 marker-found :: GENERATORS-OK
18. Socle: `templates/gitignore/standard.gitignore` carries `!.claude/rules/` after `.claude/*`, `lib/gitflow-test.sh` asserts it, and `.claude/rules/` is not ignored in this repo. [gated 2026-10-26]
   CHECK: cd /home/bchanot/Documents/claude && grep -qxF '!.claude/rules/' templates/gitignore/standard.gitignore && grep -q 'socle: !.claude/rules/' lib/gitflow-test.sh && ! git check-ignore -q .claude/rules/probe.md && echo SOCLE-OK
   EXPECT: SOCLE-OK
   EVIDENCE: MET exit=0 marker-found :: SOCLE-OK
19. RED then GREEN pressure test on the `/onboard split` skill text (Tasks 6 and 8: RED = the current skill runs archetype detection on `split`; GREEN = the edited skill reaches the S5 table and stops; the onboarder dry run on a branched scratch commits 2 rules with `all rules in HEAD` and leaves this repo's status unchanged). Outcomes recorded for the STEP 7 EVAL entry. Manual. [gated 2026-10-26]
20. `.claude/tasks/TODO.md`: phase 0 item checked with what shipped, the proof / higgsfield / phase-2 sub-items open, phase 0b per-repo pass queued with the repo order. [gated 2026-10-26]
   CHECK: cd /home/bchanot/Documents/claude && grep -q 'Phase 0b, per-repo pass' .claude/tasks/TODO.md && grep -q '\[x\] \*\*Phase 0, no mod' .claude/tasks/TODO.md && echo TODO-OK
   EXPECT: TODO-OK
   EVIDENCE: MET exit=0 marker-found :: TODO-OK

## FILE SCOPE
- `CLAUDE.md`, `.claude/rules/*.md` (new), `.gitignore`, `templates/gitignore/standard.gitignore` (pending clarification), `rules/README.md`
- `skills/onboard/SKILL.md`, `agents/onboarder.md`, `agents/scaffolder.md`, `skills/init-project/SKILL.md`, `templates/project-CLAUDE.md`, `templates/` (new path-rule template)
- `lib/project-rules.sh` (new), `lib/tests/project-rules.test.sh` (new), `lib/gitflow-test.sh` (socle assertion), `templates/project-rules/` (new skeletons)
- `doctor.sh`, `ARCHITECTURE.md`, `README.md` (doc pipeline), `hooks/instructions-loaded.sh` (new) + `settings.json` (hook registration)
- `docs/superpowers/specs/`, `docs/superpowers/plans/` (run artifacts, purged at finish)
- `.claude/tasks/TODO.md`, `.claude/memory/*` (capitalize)
- Out of scope in this repo: the 6 other projects' trees (per-repo pass, pending clarification).
