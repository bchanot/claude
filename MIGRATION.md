# Migration guides

## `.claude/` restructure (2026-04-23)

The claude-config layout moved task tracking, memory registries, and audit
reports out of scattered roots (`tasks/`, `SEO.md`, `HARDEN.md`, etc.) into
a single governance root: `.claude/{tasks,memory,audits}/`.

This guide walks through the migration for **existing projects** that use
claude-config skills and were onboarded before this change.

---

### TL;DR — full migration in one block

Run from the project root. Inspect the output before committing.

```bash
# 1. Create the new directory layout
mkdir -p .claude/tasks .claude/memory .claude/audits

# 2. Move task files
[ -d tasks ] && {
  for f in tasks/*.md; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in
      LESSONS.md)
        # Deprecated - content goes into learnings.md (see step 3)
        mv "$f" .claude/tasks/LESSONS.legacy.md
        ;;
      AUDIT_GOOD.md|AUDIT_ISSUES.md|AUDIT_PROPOSALS.md|ONBOARD_REPORT.md)
        mv "$f" ".claude/audits/$(basename "$f")"
        ;;
      *)
        mv "$f" ".claude/tasks/$(basename "$f")"
        ;;
    esac
  done
  # Remove the empty tasks/ dir if nothing's left
  rmdir tasks 2>/dev/null
}

# 3. Move orphan audit reports from project root
for f in SEO.md GEO.md HARDEN.md VALIDATE.md BUGS-FOUND.md; do
  [ -f "$f" ] && mv "$f" ".claude/audits/$f"
done

# 4. Seed the 5 memory registries from the shipped templates
#    (only if they don't exist yet - never overwrite real content)
for reg in decisions learnings blockers journal evals; do
  target=".claude/memory/${reg}.md"
  src="$HOME/.claude/templates/memory/${reg}.md"
  if [ ! -f "$target" ] && [ -f "$src" ]; then
    cp "$src" "$target"
    echo "✅ Created $target"
  elif [ -f "$target" ]; then
    echo "⏭️  Kept existing $target"
  else
    echo "⚠️  Template missing: $src"
  fi
done

# 5. If LESSONS.legacy.md had useful entries, convert each one with
#    `bash ~/.claude/lib/memory.sh add learning --title … --body-file …`, then delete LESSONS.legacy.md

# 6. Update .gitignore - see "Gitignore patch" section below
#    (`bash ~/.claude/lib/gitflow.sh reconcile` appends only the missing
#    template lines and never rewrites project rules.)

# 7. Update CLAUDE.md - see "CLAUDE.md patch" section below

# 8. Verify
git status
git check-ignore -v .claude/memory/decisions.md .claude/tasks/TODO.md 2>&1
```

---

### Gitignore patch

If your project's `.gitignore` contains a bare `.claude/` rule, it will ignore
every memory/tasks/audit file you just created. Replace that line with:

```gitignore
# Local project config (per-machine)
.claude/*
!.claude/tasks/
!.claude/memory/
!.claude/audits/
!.claude/settings.json
!.claude/deploy/
# These stay ignored (per-machine state)
.claude/settings.local.json
.claude/agent-memory/
.claude/gstack/
.claude/deploy/PENDING.json
.claude/deploy/NEXT.sh
```

Verify after edit:

```bash
# These MUST be trackable (exit 1)
git check-ignore .claude/memory/decisions.md .claude/tasks/TODO.md .claude/audits/

# These MUST still be ignored (exit 0)
git check-ignore .claude/settings.local.json .claude/agent-memory/
```

---

### CLAUDE.md patch

If your project's `CLAUDE.md` references `tasks/LESSONS.md` / `tasks/TODO.md`,
update the `## Session start`, `## Workflow`, `## After code changes`, and
`## Task tracking` sections to use `.claude/tasks/TODO.md` and reference the
5 memory registries.

Fastest route: run `/onboard` on the project (safe, won't overwrite existing
CLAUDE.md — it will merge). Otherwise, apply this diff manually:

```diff
 ## Session start
-1. Read `tasks/LESSONS.md` — apply all lessons before touching anything.
-2. Read `tasks/TODO.md` — understand current state.
-3. If neither exists, create both before starting.
+1. Read `.claude/memory/` — the 5 registries (decisions, learnings, blockers, journal, evals).
+2. Read `.claude/tasks/TODO.md` — understand current state.
+3. If missing, create from `~/.claude/templates/memory/`.
```

Add a new section referencing the registries (full template in
`~/.claude/CLAUDE.md` — copy the `## Memory registries (.claude/memory/)` block).

---

### What gets committed vs ignored

| Path | Committed? | Reason |
|------|-----------|--------|
| `.claude/tasks/*.md` | ✅ yes | Shared project backlog |
| `.claude/memory/*.md` | ✅ yes | Shared decisions/learnings/blockers |
| `.claude/audits/*.md` | ✅ yes | Snapshot of project state — version-able |
| `.claude/settings.json` | ✅ yes | Shared project config |
| `.claude/deploy/*.md` | ✅ yes | Deploy runbook + incidents |
| `.claude/settings.local.json` | 🚫 no | Per-machine overrides |
| `.claude/agent-memory/` | 🚫 no | Per-session agent state |
| `.claude/deploy/PENDING.json`, `NEXT.sh` | 🚫 no | Per-deploy transient state |

---

### Post-migration sanity check

```bash
# 1. No legacy tasks/ dir left
[ -d tasks ] && echo "⚠️ tasks/ still exists" || echo "✅ tasks/ gone"

# 2. No orphan audit files at project root
for f in SEO.md GEO.md HARDEN.md VALIDATE.md BUGS-FOUND.md; do
  [ -f "$f" ] && echo "⚠️ $f still at root"
done

# 3. Structure in place
ls .claude/tasks .claude/memory .claude/audits

# 4. Git sees the new files as trackable
git status -u .claude/ --short
```

All four checks should be clean before committing the migration.

---

### If anything goes wrong

- The migration block only uses `mv`, not `rm` — nothing is deleted.
- Old `LESSONS.md` is preserved as `LESSONS.legacy.md` — review it, copy
  meaningful entries into `.claude/memory/learnings.md` (with `LRN-XXX` IDs),
  then delete.
- To undo: `git checkout .` before commit.

---

## Upgrading an existing machine to 2.0.0

2.0.0 removes components that 1.x installed. `make plugin` installs their replacements; the leftovers go by hand.

```bash
git pull --recurse-submodules
make plugin     # vendors the 7 superpowers skills (Step 8e), installs the Higgsfield and 21st CLIs (8.6, 8.7), re-runs link.sh (10)
claude plugin uninstall superpowers@superpowers-marketplace   # once, if the plugin is still cached
make doctor
```

- **Superpowers**: the plugin is gone. Its 7 wired skills are vendored at v6.4.1 and always on. The 8 other skills and the session-start injection are not replaced.
- **Magic MCP**: replaced by the `21st` CLI (`21st login`, no API key). If 1.x registered the `magic` server, remove it from `~/.claude.json` and drop `MAGIC_API_KEY` from `~/.claude/.env`. Nothing reads them any more.
- **Git hooks in every repo**: `link.sh` sets git's global `core.hooksPath` to `~/.claude/githooks`. Every repo on the machine now gets the gitflow pre-commit guard and pushes each commit as it lands. For a foreign clone: `git config gitflow.protect false` and `git config gitflow.autopush false`.
- **Default profile**: a project with no local profile runs the manifest defaults (= `full`). Check with `bash ~/.claude/lib/profile.sh current` from the project. Nine gstack skills (`ship`, `land-and-deploy`, `setup-deploy`, `autoplan`, `context-save`, `learn`, `careful`, `guard`, `design-shotgun`) left every profile and are denylisted.
- **Higgsfield**: installed, off by default. Nothing to do until you enable it.

### Profiles and packs (2026-11)

Run on every machine that pulls this version (the live tree may still be in
an old profile). Run steps 1 and 2 before any commit on that machine: the
removed `.gitignore` lines expose the old links as untracked files. Step 3
is the only one that removes a real directory (`make plugin` replaces
`skills-external/impeccable` on a refresh); steps 1 and 2 use `mv`, never
`rm -r`.

1. From the clone root. `~/.claude` is a real directory of symlinks into
   the clone, not the clone itself, so resolve the root first. `git pull
   --autostash` (a plain `git pull` aborts when `settings.json` is modified
   locally and the incoming commits touch it; autostash keeps your UI
   writes), then restore the user-scope plugins the old `profile.sh` had
   toggled. Never `git checkout -- settings.json`: it would drop your UI
   writes.

   ```bash
   ep= next=
   root="$(dirname "$(readlink -f ~/.claude/settings.json)")"
   [ -n "$root" ] && [ -f "$root/lib/profile.sh" ] && cd "$root" \
     || { echo "no clone root"; false; } \
     && git pull --autostash \
     && ep="$(mktemp)" \
     && git show HEAD:settings.json | jq -e '.enabledPlugins | objects' \
       > "$ep" \
     && next="$(mktemp)" \
     && jq --slurpfile ep "$ep" '.enabledPlugins = $ep[0]' settings.json \
       > "$next" \
     && jq -e . "$next" >/dev/null && [ -s "$next" ] \
     && cp "$next" settings.json
   rm -f "$ep" "$next"
   ```

   Every command is chained with `&&` so that a failed step never reaches
   `cp`, which writes through the symlink into the live tracked
   `settings.json`; a failure prints `no clone root` or stops the chain
   without closing your shell. `ep= next=` comes first so the final `rm -f`
   never removes a file an earlier run named. `jq -e '.enabledPlugins |
   objects'` fails when HEAD holds no object (a null would wipe every
   plugin). `jq -e .` and `[ -s ]` refuse an invalid or empty result (an
   empty file would drop the plugins, the deny rules and the hooks).

   If the autostash pop conflicts, `settings.json` holds conflict markers:
   the second `jq` then fails closed and nothing is copied. Resolve the
   markers (`git stash list` shows the kept stash) before re-running step 1.

2. Old layout. List the flat links first, then remove the links of
   `skills-disabled/` and the links of `skills/` that are not kept
   (model-router, darwin-skill, the seven superpowers, the agent-skills
   trio). If `skills/impeccable` or `skills-disabled/impeccable` is a real
   directory, `mv` it to `skills-external/impeccable` (never `rm`). It
   re-derives `$root`, so it also runs in a new shell; `mkdir -p
   skills-disabled` lets a machine that never had that dir pass the same
   chain, and `rmdir` removes it at the end. The trailing slash and
   `-mindepth 1` keep `find` from matching the start point, which is itself
   a symlink in `~/.claude`.

   ```bash
   root="$(dirname "$(readlink -f ~/.claude/settings.json)")"
   [ -f "$root/lib/profile.sh" ] && cd "$root" \
     || { echo "no clone root"; false; } \
     && mkdir -p skills-disabled skills-external \
     && find skills/ skills-disabled/ -mindepth 1 -maxdepth 1 -type l \
     && for d in skills skills-disabled; do
          if [ -d "$d/impeccable" ] && [ ! -L "$d/impeccable" ] \
              && [ ! -e skills-external/impeccable ]; then
            mv "$d/impeccable" skills-external/impeccable
          fi
        done \
     && find skills-disabled/ -mindepth 1 -maxdepth 1 -type l -delete \
     && find skills/ -mindepth 1 -maxdepth 1 -type l \
          ! -name model-router ! -name darwin-skill \
          ! -name observability-and-instrumentation \
          ! -name deprecation-and-migration ! -name ci-cd-and-automation \
          ! -name brainstorming ! -name writing-plans \
          ! -name subagent-driven-development ! -name test-driven-development \
          ! -name requesting-code-review ! -name using-git-worktrees \
          ! -name writing-skills -delete \
     && rmdir skills-disabled && rm -f .active-profile
   ```

3. From `$root`: `make link` (link.sh no longer links the design and scroll skills flat),
   `make plugin` (fills `skills-external/`; impeccable ends in
   `skills-external/impeccable`).
4. `~/.bashrc`: delete `dtach_claude()` and `alias cc='dtach_claude'` (the
   alias would shadow the function and drop the profile argument); add
   `[ -f "$HOME/.claude/lib/cc.sh" ] && . "$HOME/.claude/lib/cc.sh"`. New
   shell. `cc <name>` behaves as before; `cc <name> web` starts a conversation
   under `lib/profiles/web.json`.
5. Per project: `bash ~/.claude/lib/profile.sh set <profile>` then
   `/reload-plugins`. `lib/toggle-external.sh` is gone (`profile.sh enable
   higgsfield` replaces it).
6. `make doctor` until no warn; `make test`.

## Memory registries v2 (2026-10-28)

A v2 registry is the same `.claude/memory/<name>.md` file, versioned and pushed with the code, with `format: 2` in its frontmatter and no `## Index`. The session banner line `registry v1: N file(s) (memory.sh check)` flags a project still on v1. v1 stays readable and writable (lenient), and the `check --staged` chokepoint skips it.

To migrate, run `bash ~/.claude/lib/memory.sh -C <project> upgrade` on a clean `.claude/memory`, then commit through `/commit-change` when headings were rewritten (memory-commit refuses heading rewrites by design). `upgrade` refuses a registry with duplicate IDs or a non-table Index and leaves the file untouched: a human renumbers or converts first. A v1 blocker closure is carried over only from a `Status`/`Statut` label holding a single closed word that is not negated (`Status: not resolved yet` holds none). A blocker the v1 reader closed through prose, a mixed or a negated Status line is named with its v1 line and the whole run is refused (rc 2, file untouched). Record its real status with `bash ~/.claude/lib/memory.sh -C <project> status <ID> "<word>, …"` (the leading word decides), then re-run `upgrade`.

## Auto memory off (2026-10-29)

`settings.json` now sets `"autoMemoryEnabled": false`, so Claude Code no longer loads `~/.claude/projects/<slug>/memory/`. Anything left there is knowledge no session reads. `make doctor` (section "Auto memory") counts the project dirs that still hold files. For each one, move what is worth keeping into that project's registries with `bash ~/.claude/lib/memory.sh -C <project> add <kind> --title … --body-file …`, then delete the leftover dir by hand.

## Claude.ai-synced skills off (2026-11-09)

`settings.json` now sets the claude.ai-synced skills to `"off"` in `skillOverrides`. The change was measured on Claude Code 2.1.319: run `claude --version` on a machine before pulling it there. A project that uses one of those skills brings it back with `{"skillOverrides": {"<name>": "on"}}` in its `.claude/settings.local.json`.

## Upgrading to 3.0.0

3.0.0 removes the typed `/effort-*` commands and narrows what Claude runs without asking. Run the machine steps of "Profiles and packs (2026-11)" in the 2.0.0 section first: they cover the pull, `make link`, `make plugin` and `make doctor`. Then check the items below.

- **Effort commands removed**: `/effort-low` through `/effort-max` no longer exist, nor do `lib/effort-pins.sh`, `lib/effort-pins.txt` and `lib/model-check.sh`. Type `ultrathink` in a prompt to raise one turn's effort, or `/route effort=max` to hold it until `/route clear`. The model-router rows now set each skill's model and effort. With the router off, a skill that goes through `lib/model-gate.md` stops and names `/route on`.
- **Profiles**: `skills-disabled/`, `lib/toggle-external.sh`, the `.profile` files, `.active-profile` and `make profile-reset` are gone. A profile is now a `lib/profiles/<name>.json` settings fragment; `backend` became `dev` and `web-full` became `full`. Re-set each project with `bash ~/.claude/lib/profile.sh set <profile>`, and turn Higgsfield on with `bash ~/.claude/lib/profile.sh enable higgsfield`.
- **Code edits run inside a skill**: model-router redirects a main-loop Edit or Write of a code file (config included) to `/hotfix`, `/feat`, `/bugfix` or `/ship-feature`. Markdown, `.txt`, `docs/` and the project's `.claude/` stay free, sub-agents write freely, and a typed `/route` lifts the redirect.
- **Merges ask**: `gitflow.sh finish` and `git merge` raise a permission prompt every time, `/close` and `/capitalize` included. Declining stops the flow with "nothing merged, branch kept". `sh -c` and its flag forms (`bash -lc`, `dash -c`), a bare `bash` or `sh` fed by a heredoc, `bash <(…)` and `/bin/sh`, `/bin/bash`, `/usr/bin/env sh|bash` ask too.
- **`gitflow.*` keys are yours alone**: Claude can no longer read or write them through `git config`, `git -c` or the git config env overrides, nor Edit `.git/config`, `.gitconfig` or `~/.config/git/config`. A custom skill that read `gitflow.autopush` through `git config` calls `bash ~/.claude/lib/gitflow.sh push-mode` instead; it prints `auto`, `manual` or `invalid`.
- **Commits on `main` and `develop`**: the pre-commit exemption shrank from all of `.claude/**` to `.claude/memory/`, `.claude/tasks/`, `.claude/audits/`, `.claude/deploy/` and `.githooks/`. A commit there that touches `.claude/rules/`, `.claude/settings.json`, agents or skills is blocked: branch first. The global hooks update at `make link`, a project's own `.githooks/` at its next session start.
- **Invalid `gitflow.autopush` value**: anything but unset, `true` or `false` now pushes nothing, where it used to push. `bash ~/.claude/lib/gitflow.sh push-mode` prints `invalid` in that case; fix the value by hand. A project with committed `.githooks/` keeps its old hooks until a session start rewrites them: commit that refresh so other clones get it.

Also part of 3.0.0, each with its own section above: "Memory registries v2" (optional), "Auto memory off" and "Claude.ai-synced skills off" (check `claude --version` before pulling).
