# CONTRACT — claude-global-md-rename
- date: 2026-07-12 | flow: ship-feature | branch: (feature branch off develop, created at STEP 4)
- status: active

## REQUEST (verbatim — IMMUTABLE)
> pour les soucis 1 et 2, ne serais-ce pas plus judicieux de mettre notre claude.md de ce repo, qui es tle global, le renommer en CLAUDE.prod.md ou quelqeu chose comme ca, avec tout ce qui concerne le userscope, le link.sh fait un lien symbolique de ce fichier avec ce nom vers ~/.claude/CLAUDE.md car on peut avoir un nom differnt du lien, et ca permet d'avoir le claude.md du projet dasn le quel on met ces deux partie qui sont pas destine au userscope. qu'en pense tu ?

> oui, utilise /ship-feature pour faire les modification vers un CLAUDE.global.md et toute les dependance et iunstallateur et update etc

(Name arbitrated in conversation: `CLAUDE.global.md`, not `CLAUDE.prod.md`.)

## CLARIFICATIONS
none — request complete (design questions resolved at STEP 1 brainstorm, gated at STEP 3)

## ACCEPTANCE CRITERIA
1. `CLAUDE.global.md` exists at repo root, renamed via `git mv` (history preserved: `git log --follow CLAUDE.global.md` shows pre-rename commits), containing the former global content MINUS the `# This repo only (claude-config)` section, PLUS a short scope header stating it is the user-scope global memory deployed as `~/.claude/CLAUDE.md`.
2. A new project-level `CLAUDE.md` exists at repo root containing: a short scope header (project-only, not user-scope), the former "This repo only" content (Health Stack / shellcheck), and the rules/ maintenance doctrine migrated from `rules/README.md` (what belongs in rules/, lazy-load semantics, machine-owned context7/BDR-053 note).
3. `link.sh` links `<repo>/CLAUDE.global.md` → `~/.claude/CLAUDE.md`; after running it, `readlink ~/.claude/CLAUDE.md` resolves to `<repo>/CLAUDE.global.md` (stale link replaced, no dangling symlink).
4. `hooks/session-start.sh` line-count guard (BDR-062) reads `CLAUDE.global.md` (new path), threshold 320 unchanged, and does not silently fail-open on the old path.
5. `doctor.sh` passes: `~/.claude/CLAUDE.md` symlink check green; size/token reporting reads `CLAUDE.global.md`.
6. `install-plugins.sh` GUARDED_CONFIGS protects `CLAUDE.global.md` (installer drift guard follows the renamed file).
7. `lib/doc-commit.sh` exclusion list covers `CLAUDE.global.md` as read-only/never-target (BDR-022 unchanged in spirit).
8. `rules/README.md` slimmed to a minimal pointer (keeps `paths:` frontmatter; doctrine lives in the project CLAUDE.md).
9. No stale script reference remains: `grep -rn 'CLAUDE\.md' *.sh hooks/*.sh lib/*.sh` shows no reference meaning the repo-root GLOBAL file under its old name (references to `~/.claude/CLAUDE.md` symlink name and to per-project CLAUDE.md concept are expected and unchanged). [gated 2026-07-14 clarification, user-arbitrated] CONSUMER-facing hook strings (messages injected into sessions, which run in any project) reference the global by its DEPLOYED name — "global CLAUDE.md" — because consumers resolve it via ~/.claude/CLAUDE.md; only MAINTAINER-facing comments use the repo filename CLAUDE.global.md. Both are conformant, not stale.
10. `README.md` / `USAGE.md` / `MIGRATION.md` layout descriptions updated where they mean the repo-root global file.
11. `shellcheck` passes on every modified `.sh` file (repo Health Stack).
12. [gated 2026-07-13] New project CLAUDE.md is MINIMAL — scope header + Health Stack + rules/ maintenance doctrine (incl. context7/BDR-053 note and the foreign-project glob caveat); no empty template sections.
13. [gated 2026-07-13] rules/README.md keeps `paths: ["rules/**"]` frontmatter; body reduced to a pointer referencing the project CLAUDE.md.
14. [gated 2026-07-13] Global file nets 305 → 301 lines; scope header = 2-line HTML comment above the title; `git diff -M --cached -- CLAUDE.global.md` shows exactly two hunks (header insertion, tail-section deletion).
15. [gated 2026-07-13] `GUARDED_CONFIGS` has 4 entries: keeps `"CLAUDE.md"` (graphify's rewrite target = project file) AND adds `"CLAUDE.global.md"`; mktemp error message lists all four.
16. [gated 2026-07-13] USAGE.md / MIGRATION.md / update-all.sh verified as having zero references to the repo-root global file — deliberately not edited.
17. [gated 2026-07-13] Spec + plan docs are the feature branch's first commit; the session-scoped plugin toggles in settings.json are NEVER staged in any commit of this branch.

## FILE SCOPE
- CLAUDE.md → CLAUDE.global.md (git mv + content split)
- CLAUDE.md (new project-level file)
- link.sh
- hooks/session-start.sh
- doctor.sh
- install-plugins.sh
- lib/doc-commit.sh
- rules/README.md
- README.md, USAGE.md, MIGRATION.md (doc references)
- [gated 2026-07-14] hooks/config-protection.sh, hooks/design-toolchain-reminder.sh (required by criterion 9's sweep — global-file references in comments/messages)
- [gated 2026-07-14] docs/superpowers/specs/2026-07-12-claude-global-md-rename-design.md, docs/superpowers/plans/2026-07-13-claude-global-md-rename.md (required by criterion 17 — branch's first commit)
