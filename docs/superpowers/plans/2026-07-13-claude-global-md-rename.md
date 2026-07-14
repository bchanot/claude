# CLAUDE.global.md Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the repo-root global memory to `CLAUDE.global.md` and free the `CLAUDE.md` name for a real project-scope file, following every dependent script and doc.

**Architecture:** One atomic file-split task (git mv + both file contents + link.sh retarget, so no commit leaves the tree incoherent), then a script-followers task, then docs, then a verification sweep. Spec: `docs/superpowers/specs/2026-07-12-claude-global-md-rename-design.md`. Contract: `.claude/tasks/contracts/2026-07-12-claude-global-md-rename-2342.md`.

**Tech Stack:** bash (shellcheck-clean), markdown, git (gitflow via `~/.claude/lib/gitflow.sh`).

## Global Constraints

- BDR-062: line-count guard threshold stays **320**; only its path changes.
- BDR-021: `## Security`, `# Architecture decisions` content and the heading `## Design work — full toolchain (tiered by scope)` stay **byte-identical** in CLAUDE.global.md.
- BDR-031: global file must NOT grow — expected net: 305 → 301 lines (−7 tail section incl. leading blank, +3 header incl. trailing blank).
- LRN-044: edit repo paths only (`/home/bchanot/Documents/claude/...`), never through `~/.claude/CLAUDE.md`.
- Gitflow: every commit lands on `feature/claude-global-md-rename` (created Task 1). Never commit on develop.
- Shell code: ≤80 cols, shellcheck-clean (`shellcheck *.sh hooks/*.sh lib/*.sh`).
- Deployed-state note: between Task 2's `git mv` and its `bash link.sh` step, `~/.claude/CLAUDE.md` dangles — Task 2 must run to completion without interruption.

---

### Task 1: Feature branch + commit spec and plan

**Files:**
- Commit: `docs/superpowers/specs/2026-07-12-claude-global-md-rename-design.md` (exists)
- Commit: `docs/superpowers/plans/2026-07-13-claude-global-md-rename.md` (this file)

**Interfaces:**
- Produces: branch `feature/claude-global-md-rename` off develop — all later tasks commit here.

- [ ] **Step 1: Create the branch via the gitflow lib (never by hand)**

Run: `bash "$HOME/.claude/lib/gitflow.sh" start feature claude-global-md-rename`
Expected: branch created off develop; `git branch --show-current` → `feature/claude-global-md-rename`

- [ ] **Step 2: Commit the two docs**

```bash
git add docs/superpowers/specs/2026-07-12-claude-global-md-rename-design.md \
        docs/superpowers/plans/2026-07-13-claude-global-md-rename.md
git commit -m "docs(spec): CLAUDE.global.md rename — design + implementation plan"
```

Expected: clean commit; `git status` shows the two files gone from untracked.
NOTE: `settings.json` is dirty with session-scoped plugin toggles — do NOT stage it in any task.

---

### Task 2: Atomic file split (git mv + contents + link.sh)

**Files:**
- Rename: `CLAUDE.md` → `CLAUDE.global.md` (git mv)
- Modify: `CLAUDE.global.md` (add header, drop tail section)
- Create: `CLAUDE.md` (project scope, new content below)
- Modify: `link.sh:20`

**Interfaces:**
- Produces: `CLAUDE.global.md` = global memory (Task 3 scripts point here); `CLAUDE.md` = project memory (stays graphify's / GUARDED_CONFIGS' target name).

- [ ] **Step 1: git mv**

```bash
cd /home/bchanot/Documents/claude
git mv CLAUDE.md CLAUDE.global.md
```

- [ ] **Step 2: Add the scope header to CLAUDE.global.md**

Insert at the very top, ABOVE `# Global coding preferences`:

```markdown
<!-- USER-SCOPE GLOBAL memory — deployed as ~/.claude/CLAUDE.md via link.sh.
     Repo-specific instructions live in ./CLAUDE.md (project scope). -->

```

- [ ] **Step 3: Remove the repo-only tail section from CLAUDE.global.md**

Delete exactly these final lines (and the blank line before `# This repo only`):

```markdown

# This repo only (claude-config)

Apply when working directory = the claude-config repo itself.

## Health Stack
- shell: `shellcheck *.sh hooks/*.sh lib/*.sh`
```

The file now ends with the graphify section's last line:
`- After editing code → \`graphify update .\` (AST-only, free).`

- [ ] **Step 4: Create the project-scope CLAUDE.md**

Full content:

```markdown
<!-- PROJECT SCOPE ONLY (claude-config repo). The user-scope GLOBAL memory is
     ./CLAUDE.global.md, deployed as ~/.claude/CLAUDE.md by link.sh — edit
     THAT file for cross-project doctrine. -->

# claude-config — project instructions

## Health Stack
- shell: `shellcheck *.sh hooks/*.sh lib/*.sh`

## rules/ maintenance

Modular instruction files loaded by Claude Code alongside the global memory.
`rules/` is symlinked to `~/.claude/rules` by `link.sh` (user scope, ALL
projects). One rule = one file = one concern.

A rule WITH `paths:` YAML frontmatter (glob list) loads lazily — only when
Claude reads a file matching a glob; a rule WITHOUT it loads at session
start, same cost as the global memory. Extract from CLAUDE.global.md only
what can be path-scoped (the token win) or what is generated; always-on
doctrine stays in CLAUDE.global.md. `paths:` globs match against the
CURRENT project's tree — a broad glob (e.g. `rules/**`) can fire in foreign
projects; keep rule bodies tiny.
Docs: https://code.claude.com/docs/en/memory.md#path-specific-rules

Machine-owned: `rules/context7.md` is DELETED BY DESIGN (BDR-053,
2026-07-06) — `ctx7 setup --claude --cli` still writes it, but
install-plugins.sh STEP ctx7 purges it right after; the find-docs skill is
the single ctx7 surface. If it reappears (manual `ctx7 setup`), delete it
or re-run `make plugin`.
```

- [ ] **Step 5: Retarget link.sh**

`link.sh:20` — change:

```bash
link_file "$REPO/CLAUDE.md"     "$CLAUDE/CLAUDE.md"
```

to:

```bash
link_file "$REPO/CLAUDE.global.md" "$CLAUDE/CLAUDE.md"
```

- [ ] **Step 6: Run link.sh and verify the symlink**

```bash
bash link.sh
readlink "$HOME/.claude/CLAUDE.md"
```

Expected: `✅ 1 symlink(s) updated in ~/.claude/` (ln -sf replaces the stale
link) and readlink prints `/home/bchanot/Documents/claude/CLAUDE.global.md`.

- [ ] **Step 7: Stage, then verify sizes and byte-identity of protected content**

```bash
wc -l CLAUDE.global.md   # expected: 301 (≤ 320, BDR-062 margin)
git add CLAUDE.global.md CLAUDE.md link.sh
git diff -M --cached --stat        # rename CLAUDE.md→CLAUDE.global.md + new CLAUDE.md + link.sh
git diff -M --cached -- CLAUDE.global.md
```

Expected: rename detected (similarity ~97%); exactly TWO hunks on
CLAUDE.global.md (header insertion at top, tail-section deletion) — nothing
else. `## Security`, `# Architecture decisions`, `## Design work — full
toolchain (tiered by scope)` untouched.

- [ ] **Step 8: shellcheck + commit**

```bash
shellcheck link.sh
git commit -m "feat(memory): split user-scope global (CLAUDE.global.md) from project CLAUDE.md"
```

---

### Task 3: Point dependent scripts at CLAUDE.global.md

**Files:**
- Modify: `hooks/session-start.sh:202-211`
- Modify: `doctor.sh:244,251,277`
- Modify: `install-plugins.sh:33-41,65-68`
- Modify: `lib/doc-commit.sh:44-50`

**Interfaces:**
- Consumes: `CLAUDE.global.md` from Task 2.
- Produces: guard/stats/exclusions used by Task 5's verification sweep.

- [ ] **Step 1: session-start.sh — line-count guard follows the file (BDR-062)**

Replace lines 202-211:

```bash
# CLAUDE.global.md line-count guard (anti-regression). BDR-062 supersedes
# BDR-031's 275 target: 305 is the assumed reality (extraction done at
# job1; further compression costs clarity > token gain) — warn past 320.
if [ -n "$REPO_DIR" ] && [ -f "$REPO_DIR/CLAUDE.global.md" ]; then
  _claude_lines=$(wc -l < "$REPO_DIR/CLAUDE.global.md")
  if [ "$_claude_lines" -gt 320 ]; then
    _cmd_warn="CLAUDE.global.md ${_claude_lines}L (>320) — density pass"
    printf "│  ⚠️  %-44s│\n" "${_cmd_warn:0:44}"
    unset _cmd_warn
  fi
  unset _claude_lines
fi
```

(Behavior guard: without this change the check would silently measure the
NEW 30-line project CLAUDE.md and never warn again — fail-open.)

- [ ] **Step 2: doctor.sh — stats read the global file**

Line 244 comment: `# The passive footprint (CLAUDE.md + skill descriptions`
→ `# The passive footprint (CLAUDE.global.md + skill descriptions`.

Line 251:

```bash
CLAUDE_MD_CHARS=$(wc -c < "$REPO/CLAUDE.global.md" 2>/dev/null || echo 0)
```

Line 277 (keep the `~` column aligned — 4 spaces after the colon):

```bash
echo "  CLAUDE.global.md:    ~${CLAUDE_MD_TOKENS}t"
```

Lines 32, 52, 65 (symlink-NAME references `~/.claude/CLAUDE.md`) unchanged.

- [ ] **Step 3: install-plugins.sh — guard both memory files**

Line 36: `These 3 files` → `These 4 files`. After line 40 (`— anything the
installer should add…`), append one comment line, then replace line 41:

```bash
# CLAUDE.md = project memory (graphify's rewrite target); CLAUDE.global.md
# = user-scope global memory (deployed as ~/.claude/CLAUDE.md).
GUARDED_CONFIGS=("CLAUDE.md" "CLAUDE.global.md" ".claude/settings.json"
  "settings.json")
```

Lines 65-68 err message:

```bash
  err "Config guard could not be created (mktemp failed) — refusing to run" \
    "unguarded: CLAUDE.md/CLAUDE.global.md/.claude/settings.json/settings.json" \
    "could be silently rewritten by the installer. Fix mktemp/TMPDIR and retry."
```

- [ ] **Step 4: lib/doc-commit.sh — exclude the global file (BDR-022)**

Comment (line ~44-45): `or a CLAUDE.md (root or nested)` → `or a CLAUDE.md /
CLAUDE.global.md memory file (root or nested)`. Case patterns:

```bash
_forbidden_path() {
  case "$1" in
    .claude | .claude/* | */.claude/* | CLAUDE.md | */CLAUDE.md | \
      CLAUDE.global.md | */CLAUDE.global.md) return 0 ;;
    *) return 1 ;;
  esac
}
```

- [ ] **Step 5: Lint + smoke test + commit**

```bash
shellcheck hooks/session-start.sh doctor.sh install-plugins.sh lib/doc-commit.sh
bash doctor.sh | sed -n '/Token budget/,/────/p'   # shows "CLAUDE.global.md: ~Nt", N≈3600
git add hooks/session-start.sh doctor.sh install-plugins.sh lib/doc-commit.sh
git commit -m "feat(memory): guards, doctor stats and doc-commit exclusions follow CLAUDE.global.md"
```

---

### Task 4: rules/README.md pointer + README tree

**Files:**
- Rewrite: `rules/README.md`
- Modify: `README.md:16`

- [ ] **Step 1: Rewrite rules/README.md (full new content)**

```markdown
---
paths: ["rules/**"]
---

# rules/

User-scope rules, deployed to `~/.claude/rules` by `link.sh`.
Maintenance doctrine (what belongs here, lazy-load `paths:` semantics,
machine-owned files): see `CLAUDE.md` (project scope) at the repo root.
```

- [ ] **Step 2: README.md tree — show both memory files**

Replace line 16:

```
├── CLAUDE.md              # Global coding preferences (style, rules, workflow)
```

with:

```
├── CLAUDE.global.md       # Global coding preferences — deployed as ~/.claude/CLAUDE.md
├── CLAUDE.md              # Project-scope instructions (this repo only)
```

Lines 29, 100, 152 (per-project CLAUDE.md concept) and 189 (symlink name)
unchanged. USAGE.md / MIGRATION.md / update-all.sh audited: zero references
to the repo-root global file — no edits (contract criterion 10 satisfied
by verification).

- [ ] **Step 3: Commit**

```bash
git add rules/README.md README.md
git commit -m "docs: slim rules/README to a pointer; README tree lists both memory files"
```

---

### Task 5: Verification sweep (no new code)

**Files:** none modified (fixes only if a check fails — then loop the owning task).

- [ ] **Step 1: link.sh idempotence**

Run: `bash link.sh`
Expected: `✅ All symlinks already up to date.`

- [ ] **Step 2: doctor.sh green**

Run: `bash doctor.sh`
Expected: `~/.claude/CLAUDE.md` symlink PASS (resolves inside repo); token
stats line reads `CLAUDE.global.md:`; no new FAIL vs pre-change baseline.

- [ ] **Step 3: Residual reference grep**

```bash
grep -rn '\$REPO/CLAUDE\.md\|\$REPO_DIR/CLAUDE\.md' -- *.sh hooks lib || echo CLEAN
grep -rn 'CLAUDE\.md' -- *.sh hooks/*.sh lib/*.sh
```

First: `CLEAN`. Second — every hit must be one of: link.sh `$CLAUDE/CLAUDE.md`
(dst name), session-start.sh `readlink "$HOME/.claude/CLAUDE.md"`, doctor.sh
`check_symlink "CLAUDE.md"` + name comments, install-plugins.sh
`"CLAUDE.md"` guard entry + comments, doc-commit.sh case patterns,
update-all.sh graphify comment (targets the project file — accurate).

- [ ] **Step 4: History + guard smoke**

```bash
git log --follow --oneline CLAUDE.global.md | tail -3   # pre-rename commits
awk '/line-count guard/,/^fi$/' hooks/session-start.sh | grep -c 'CLAUDE\.global\.md'   # ≥ 2
wc -l CLAUDE.global.md CLAUDE.md   # 301 and ~31
```

- [ ] **Step 5: Full Health Stack**

Run: `shellcheck *.sh hooks/*.sh lib/*.sh`
Expected: exit 0, no findings on modified files.
