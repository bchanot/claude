# PLAN r3 — D1+D5+D6 (doctrine, web rules, graphify rule), /feat 2026-11-12

Contract: .claude/tasks/contracts/2026-11-12-doctrine-rules-graphify-1123.md
Branch: feature/doctrine-rules-graphify (off develop 1cc89be)
Style: foreign code (keep each file's wrap, tone, list shape). Lines ≤ 80 chars.

## r2 changes (challenge round 1: correctness FATAL(2), robustness FATAL(3), simplicity CONCERNS(1))
- D5 intro = bare pointer (no summary of secure-by-default): closes the oracle clash ("rate limits"
  matched `! grep -qi 'rate limit'`) and the parallel-copy drift (simplicity 3, correctness 1, robustness 1).
- D6 also rewrites the rule's lead paragraph (:7-9 credited the skill copy to `graphify claude install`;
  only `install()` calls `_copy_skill_file`, install.py:713) (all three lenses).
- D6 recovery wording: delete the trailing `# graphify` block (one EOF hunk), never check out the whole
  file (robustness 4). Step 7 warn for `graphify claude install` drops "run manually" (robustness 5).
- D1 re-gated by the user 2026-11-12: `_digest_todo` reads only a `### Actionable` heading, which only this
  repo has, so TODO.md stays read at start; digest = blockers + journal; registries on demand, planning
  flows scan per lib/analyze-before-plan.md (robustness 2, correctness 3-4).
- Contract D6 oracle also asserts the bare `graphify claude install` call is gone (robustness 6).
- Not taken: trimming the gated D1 registry list (simplicity 2, user-approved text); guard-comment dedup
  (simplicity 4) → follow-up.
- Follow-ups (BUGS-FOUND at capitalize): `_digest_todo` fallback to first `- [ ]` items without an
  Actionable heading (hook + session-digest test); .gitignore:55-56 and plugins.lock.json:37 same stale
  claim / bare recipe; guard comment vs rule duplication; LRN-154 status line at capitalize.

## r3 changes (challenge round 2: correctness SOLID, robustness CONCERNS(2), simplicity SOLID)
- D1 step 1 gains "a `+N` line → read those entries in `blockers.md`" (upstream blockers with live
  workarounds fold into the digest's count line; user re-gate 2026-11-12) (robustness 2).
- Step 7: `graphify claude install` failure no longer sets `_graphify_ok=0`, so :697 "re-run the failed
  step manually" fires only for `graphify install` (the skill copy); short warn (robustness 1,
  simplicity 1, correctness 2).
- D5 keeps web-security.md:13 RLS line verbatim (already "Supabase/Postgres and kin") (simplicity 2).
- D6: lead paragraph replaces lines 7-10 (correctness 1); cwd clause attached to install-plugins.sh,
  not `make plugin` (simplicity 3); guard comment wording fixed (correctness 3).
- Contract D1 width check pinned to `LC_ALL=C.UTF-8` (correctness 4).
- More follow-ups: install-plugins.sh:688/690/1269 graphify labels; update-all.sh:310-312 manual
  `graphify claude install` recipe → `make plugin`; digest `- open: none` so a missing line means
  "reader failed"; curated-config-guard test asserting the Step 7 subshell line.

## Facts checked (read-only)
- `~/.claude/CLAUDE.md` → symlink to `$REPO/CLAUDE.global.md`; `~/.claude/rules` → `$REPO/rules`.
- graphifyy 0.9.67 install.py:691 `install(platform="claude")` (CLI default claude, :2151): copies the
  skill (:713 `_copy_skill_file`), then `_register_always_on_block(~/.claude/CLAUDE.md or
  $CLAUDE_CONFIG_DIR/CLAUDE.md)` → appends an H1 `# graphify` block at EOF of CLAUDE.global.md.
  install.py:1827 `claude_install(project_dir=None)`: writes `./CLAUDE.md` + `_install_claude_hook(".")`
  (`.claude/settings.json`) in the cwd. It never copies the skill.
- install-plugins.sh:17 `REPO=...`; :34-50 guard comment + GUARDED_CONFIGS (CLAUDE.md, CLAUDE.global.md,
  .claude/settings.json, settings.json) restored from `$REPO/` by the EXIT trap; :686-699 Step 7.
- hooks/session-start.sh: digest on startup/clear/compact; none on resume, `memory.json` enabled:false,
  foreign repo (`gitflow.protect false`), missing jq/timeout in a hook, nothing to show. Content: open
  blockers (≤3 + upstream count), first 3 unchecked items under `### Actionable` only (:329-333), last
  journal bullet.
- rules/secure-by-default.md has no `paths:` → always on (BDR-120).
- Citers: `Read \`.claude/memory/\`` CLAUDE.global.md:53 + MIGRATION.md:127 (historical 1.x diff, left);
  `read .claude/memory/ at startup` skills/capitalize/SKILL.md:375 only; "written by `graphify claude
  install`" graphify-vendored.md:8 + .gitignore:55-56 (follow-up); `touches nothing else`
  graphify-vendored.md:16 + learnings.md:1381 (LRN-154, status line at capitalize).

## PLAN
  [ ] CLAUDE.global.md:53-55 — replace the `## Session start` body with D1 text (exact, below)
  [ ] skills/capitalize/SKILL.md:375 — tail `Next session: read .claude/memory/ at startup.`
      → `Next session: TODO.md and the startup digest (open blockers, last journal line).`
      (only that sentence; the rest of the line verbatim)
  [ ] rules/web-security.md — rewrite body (exact, below); frontmatter `paths:` line unchanged
  [ ] .claude/rules/graphify-vendored.md — lead paragraph :7-9 and the two command bullets + the
      `make plugin` sentence (exact, below); rest verbatim
  [ ] install-plugins.sh:691 — replace the line with exactly:
      `  (cd "$REPO" && graphify claude install) 2>/dev/null || warn "graphify claude install failed"`
      (no `_graphify_ok=0`: its writes are reverted by the trap, the LRN-071 gate tracks `graphify install`)
  [ ] install-plugins.sh:38-41 — in the guard comment: ":39 `in the caller's cwd`" → "in its own cwd";
      "(fully effective when run from $REPO, e.g. `make plugin`)" → "(Step 7 runs `graphify claude
      install` from $REPO in a subshell, so the trap covers its CLAUDE.md and .claude/settings.json
      writes whatever the caller's cwd)"; rewrap to ≤ 80 chars, rest verbatim.

## Exact texts

D1 (CLAUDE.global.md, replaces lines 53-55; heading kept):
```
1. Read `.claude/tasks/TODO.md`. The banner's `memory digest` lists open
   blockers and the last journal line: apply both before touching
   anything; a `+N` line → read those entries in `blockers.md`. No
   digest (foreign repo, memory mod off) → list the open blockers
   yourself.
2. Read a registry (`.claude/memory/`: decisions, learnings, blockers,
   journal, evals) when the task needs it; planning flows scan them per
   `~/.claude/lib/analyze-before-plan.md`.
3. Either missing → create it first (templates: `~/.claude/templates/memory/`).
```

D5 (rules/web-security.md body after the frontmatter):
```
# Web app security — specifics

Extends `~/.claude/rules/secure-by-default.md` (always on). If a request
breaks one of these rules, say so instead of doing it.

- Row Level Security enabled on every table (Supabase/Postgres and kin).
- No IDOR: changing an id in a URL must never expose another user's
  data. Authorize object access on every request.
- Session cookies httpOnly + secure + sameSite.
- Uploads restricted by type and size.
- HTTPS forced.
- Security headers set.
```

D6 (.claude/rules/graphify-vendored.md). Lead paragraph, replaces lines 7-10:
```
`skills/graphify/SKILL.md`, `skills/graphify/references/` and
`.graphify_version` are written by `graphify install` (default platform
claude; `install-plugins.sh` STEP graphify), which lands in the repo
because `~/.claude/skills` is a symlink to `skills/`. They are gitignored: a
```
(line 11 "`pipx upgrade graphifyy` used to dirty the tree and cost a" and what follows stay verbatim.)
The two bullets and the sentence after them:
```
Two graphify commands, easy to confuse, and only one restores the skill:
- `graphify install --platform claude` copies SKILL.md + `references/` +
  `.graphify_version` into `skills/graphify/`, and appends a `# graphify`
  block to `~/.claude/CLAUDE.md` = `CLAUDE.global.md` (graphifyy 0.9.67).
  This is the recovery command; then delete that trailing block (one EOF
  hunk in `git diff`), never check out the whole file.
- `graphify claude install` writes the CLAUDE.md graphify section and the
  `.claude/settings.json` PreToolUse hooks in the current directory. It
  **rewrites both guarded configs** (EVAL-020, verified again 2026-09-15),
  so revert them after. It does NOT copy the skill.

`make plugin` runs both (`install-plugins.sh` STEP graphify) behind the
guarded-config EXIT trap, so a fresh clone is covered; `install-plugins.sh`
runs the second from `$REPO`, whatever the caller's cwd.
```

## Edge cases
- Caller cwd ≠ $REPO: the subshell cd leaves the caller's CLAUDE.md/.claude/settings.json untouched; the
  trap restores $REPO's. Subshell keeps the script's cwd for later steps.
- `cd "$REPO"` failure → `&&` short-circuits, `||` warns, `_graphify_ok=0` (same path as today).
- Digest absent or without TODO lines: TODO.md is read anyway (step 1); blockers listed by hand only
  when no digest prints.

## Tests
- No new test file (5-file limit; prose + one subshell line). Contract oracles lock each change;
  doctrine-citers census, project-rules check, user-rules, curated-config-guard and the full make test run
  in GREEN.

## Disposition
- honors BDR-028 / LRN-039: guarded-config trap kept, now effective from any cwd.
- honors BDR-120: web-security points at the always-on secure-by-default (one source per rule).
- honors BDR-125: the 4a/4c digest premise reaches the doctrine, TODO read kept where the digest is blind.
- honors BDR-100: citers grepped; out-of-cap citers logged as follow-ups.
- LRN-275 explicit staging; LRN-277 executor brief forbids stdin readers.
