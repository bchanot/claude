# /feat citers-blind-spots — PLAN r2

r2 2026-10-31 after 3 lenses: simplicity SOLID (2 MINOR), correctness CONCERNS(3),
robustness CONCERNS(2). No BLOCKER. Changes named in § R2 CHANGES.

FEAT: doctrine-citers census blind spots — rule 7, 1 file
(lib/tests/doctrine-citers.test.sh), one hoisted path ERE + citer-aware target
mapping + a second scan list for T6 + flip-tests.

## Facts (2026-10-31, measured by the lenses)
- develop's ERE `(rules|lib)/[a-z0-9-]+\.md` emits no row for a nested
  `lib/sub/x.md § Y` (blind, and a missing row reads as "resolves").
- No left boundary: `templates/project-rules/ci.md § X` is read as
  `rules/ci.md`; `foo-rules/x.md` matches from `rules/`.
- Real census FILES (`find skills agents lib rules hooks`) feeds BOTH T3
  (`CLAUDE.md "X"` vs CLAUDE.global.md) and T6 (file citations).
  `templates/` (12 .md) and `.claude/rules/` (4 .md) are never scanned. In
  those two trees `CLAUDE.md` means a PROJECT CLAUDE.md (templates/project-
  CLAUDE.md, templates/project-rules/ci.md:10), so T3 must not see them.
- Bare `.claude/rules/<f>.md` has two meanings: inside this repo's own
  `.claude/rules/*` it is this repo; in skills/agents/templates it names the
  TARGET project's copy, emitted from `templates/project-rules/<f>.md`
  (agents/onboarder.md:135, agents/scaffolder.md:85).
- 5 live home-prefixed citations (agents/interviewer.md:26, agents/commit-
  changer.md:220, lib/architecture-defaults.md:49, hooks/design-toolchain-
  reminder.sh:78, CLAUDE.global.md:261) resolve today through the suffix and
  must keep resolving against this repo (`~/.claude/{rules,lib}` link here).
- 0 real citations in any blind spot today: preventive.

## Plan
- [ ] One path ERE, hoisted into a variable used by both grep branches of
      `_citers_extract_files` (lines ≤ 80 cols, may span two assignments):
      left boundary `(^|[^A-Za-z0-9_-])` (captured, dropped by sed), then
      `((~|\$[{]?HOME[}]?)/\.claude/|\.claude/)?(templates/project-)?`
      `(rules|lib)/([a-z0-9-]+/)*[a-z0-9-]+\.md`.
      ONE sed over the `{ branch1; branch2; }` output strips an OPTIONAL
      boundary char of class `[^A-Za-z0-9_~$.-]` (absent at column 1: never eat
      the path's own first char) and a home prefix (`~/.claude/`, `$HOME/.claude/`, `${HOME}/.claude/`)
      → repo-relative target. A bare `.claude/` stays in the target.
- [ ] `citers_check_files`: citer-aware mapping of a bare `.claude/rules/<f>`
      target: citer path matches `.claude/rules/*` (or `*/.claude/rules/*`) →
      or `rules/*` (rules/README.md cites this repo's own .claude/rules) → keep
      `.claude/rules/<f>.md` (resolves against `$root/.claude/rules`); a citer
      under skills/ agents/ templates/ lib/ hooks/ or CLAUDE.global.md →
      `templates/project-rules/<f>.md`. A bare `.claude/lib/`
      stays as is (resolves against `$root/.claude/lib`, absent → DANGLING).
- [ ] Scan lists: `FILES` (T3) unchanged roots `skills agents lib rules hooks`;
      new `FILES_ALL` = FILES roots + `templates` + `.claude/rules` (same name
      filter and excludes, find roots on a continuation line) feeds T6.
- [ ] Header comment: lines 2-3 (scope list), 11-13, 59-63 (drop "would be
      read as rules/<f>.md"): nested dirs, home prefixes, the citer-aware
      `.claude/rules/` rule, `templates/project-rules/`, T3 vs T6 lists; an
      absolute `/home/<u>/…` path is unsupported (resolved as a bare
      `.claude/…` or suffix).
- [ ] Fixtures (in the `$FIX` block, before the real census), check names:
      T8a-nested-lib-resolves: `_citers_extract_files` on `lib/sub/x.md § Alpha`
        emits exactly one `:lib/sub/x.md:Alpha` row AND citers_check_files rc 0
        with `$FIX/lib/sub/x.md` holding `## Alpha`.
      T8b-nested-lib-dangling: `lib/sub/x.md § Beta` → rc 1, culprit named.
      T8c-project-rules-resolve: a citer at `$FIX/.claude/rules/c.md` citing
        `.claude/rules/p.md § Gamma`, `$FIX/.claude/rules/p.md` holds `## Gamma`,
        no `$FIX/rules/p.md` → rc 0.
      T8d-project-rules-not-user-rules: a skill-side citer (`$FIX/s.md`) citing
        `.claude/rules/q.md § Delta`: rc 0 when `$FIX/templates/project-rules/
        q.md` holds `## Delta`; rc 1 when only `$FIX/rules/q.md` and
        `$FIX/.claude/rules/q.md` hold it.
      T8e-home-prefix-maps-to-repo: `~/.claude/rules/api.md § Versioning`,
        `${HOME}/.claude/lib/cc.md § WRITE`, and quoted
        `$HOME/.claude/lib/cc.md § "WRITE (before the commit)"` → rc 0
        (`# shellcheck disable=SC2016` on the single-quoted printf). Includes
        column-1 lines (`~/.claude/…`, `$HOME/.claude/…`). T8e is a guard of
        the new code, NOT a flip-test vs develop (develop resolves these by
        suffix): its negative control = the r3 ERE without the home
        alternative → the targets go bare `.claude/…` → DANGLING.
        T8c also carries a column-1 `.claude/rules/p.md § Gamma` line.
      T8g-left-boundary: `foo-rules/api.md § Versioning` → no row extracted.
      T8h-template-rules-path: `templates/project-rules/t.md § Eps` resolves
        against `$FIX/templates/project-rules/t.md` → rc 0; with a wrong label
        → rc 1.
      T8f-scan-lists (placed right after the mapfiles): FILES_ALL holds ≥1
        `templates/` and ≥1 `.claude/rules/` path; FILES holds none.
- [ ] T3 runs on FILES, T6 on FILES_ALL + CLAUDE.global.md; T4-T7c unchanged.

## Edge cases
- grep -o is leftmost: a home or `templates/project-` prefix is captured
  whole when present.
- `$HOME` / `${HOME}` are literal text in the scanned sources.
- BSD-safe ERE, `/usr/bin/grep` pinned, no grep -P, no lookbehind.

## R2 CHANGES
- ERE hoisted once, nested prefix, left boundary, `${HOME}`, `templates/
  project-` (simplicity 1, correctness 4/8, robustness 3/4).
- Citer-aware `.claude/rules/` mapping (correctness 2, robustness 1;
  simplicity 2 documents it).
- T3 keeps the old roots, T6 gets FILES_ALL (correctness 3, robustness 2).
- T8a asserts the extracted row (correctness 1); T8e quoted + `${HOME}`
  (robustness 5); T8g, T8h added; T8f after mapfile (correctness 6); header
  lines 2-3 (correctness 7); live count 5 (correctness 5).

## R3 CHANGES (confirmation correctness CONCERNS(1), folded, no 3rd pass)
- T8e reclassified: guard of the new code, own negative control (C1).
- Boundary strip optional and excludes `~ $ .`; column-1 fixtures (C2).
- Citers under rules/ map bare `.claude/rules/` to this repo (C3).
- `\$[{]?HOME[}]?` instead of `\$\{?HOME\}?` (C4).

## Disposition
Honors BDR-100 (the census is the mechanism) and LRN-096 (each extension has
a flip-test that fails on develop's extractor: T8a row assert, T8b, T8c, T8d,
T8g, T8h, T8f; T8e guards the new home mapping with its own negative control).
