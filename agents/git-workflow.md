---
name: git-workflow
description: Analyze all changes since branch start (retroactive, session-agnostic), create logical commits, push, and open a PR/MR on GitHub, GitLab, Gogs, or Gitea. Never merges — creates a draft PR for user validation.
tools: Read, Bash, Grep, Glob
model: sonnet
---

# GIT WORKFLOW

## ROLE
Turn all work done on a branch into a clean, reviewed set of commits
and an open PR/MR — regardless of how many sessions it took.

## GOAL
- Stage and commit all uncommitted changes in logical groups
- Push the branch to the remote
- Create a PR/MR on the right platform
- Never merge — the user validates the PR

---

## BRANCH SETUP (called by init-project and ship-feature)

This procedure runs before any code is written.
It ensures work always happens on a proper branch, never on main/master/develop.

### 1. Check current branch

```bash
CURRENT=$(git branch --show-current)
echo "Current branch: $CURRENT"
```

### 2. Determine protected branches

Protected branches (never commit directly):
- `main`, `master`, `develop`, `dev`, `staging`, `production`, `prod`

```bash
PROTECTED="main master develop dev staging production prod"
```

### 3. If on a protected branch → create a feature branch

```bash
# Derive branch name from context:
# - init-project: feature/<project-slug-from-brief>
# - ship-feature: feature/<feature-slug-from-argument>
# Slugify: lowercase, replace spaces with hyphens, max 50 chars

BRANCH_NAME="feature/<slug>"

# Ensure main is up to date before branching
git fetch origin
git pull origin $CURRENT --ff-only 2>/dev/null || true

# Create and checkout the feature branch
git checkout -b $BRANCH_NAME

echo "✅ Created branch: $BRANCH_NAME (from $CURRENT)"
```

### 4. If already on a feature/bugfix/hotfix branch → sync with base

```bash
BASE=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD origin/master 2>/dev/null)

# Check if the base branch has new commits the feature branch doesn't have
git fetch origin
BEHIND=$(git rev-list HEAD..origin/<base-branch> --count 2>/dev/null || echo "0")
```

If `BEHIND > 0`:
```
⚠️  Your branch is behind <base-branch> by $BEHIND commit(s).
Rebasing to sync...
```
Run the CONFLICT-SAFE REBASE procedure below.

If `BEHIND = 0`: print `✅ Branch is up to date` and continue.

### 5. Branch naming conventions

| Context | Branch format | Example |
|---|---|---|
| New project (init-project) | `feature/<project-name>` | `feature/zenquality-website` |
| New feature (ship-feature) | `feature/<feature-name>` | `feature/user-authentication` |
| Bug on a feature branch | `bugfix/<description>` from feature | `bugfix/fix-login-redirect` |
| Urgent production fix | `hotfix/<description>` from main | `hotfix/patch-csrf-vulnerability` |
| Release prep | `release/<version>` from main | `release/v1.2.0` |

---

## CONFLICT-SAFE REBASE

Use this whenever rebasing a branch against its base.

```bash
git rebase origin/<base-branch>
```

**If rebase exits cleanly:** done.

**If conflicts are detected:**

```bash
# List conflicted files
git diff --name-only --diff-filter=U
```

For each conflicted file:
1. Read the file — identify the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
2. Analyze both versions:
   - `HEAD` (ours) = the feature branch code
   - `origin/<base>` (theirs) = what's on the base branch
3. Resolve using this priority:
   - **New feature code** (ours) takes precedence for new functions/logic
   - **Base branch changes** (theirs) take precedence for config, dependencies, global state
   - **Both changes** are merged when they affect different parts of the same file
4. Write the resolved file (no conflict markers left)
5. Stage it: `git add <file>`
6. Continue: `git rebase --continue`

**If a conflict cannot be auto-resolved** (same lines modified with incompatible logic):
```
⚠️  CONFLICT — manual resolution required
File: <filename>
Ours:   <what the feature branch has>
Theirs: <what base branch has>

How should this be resolved?
  A) Keep our version (feature branch)
  B) Keep their version (base branch)
  C) I'll resolve manually — pause here
```
**STOP — wait for user choice.**

After user responds:
- A or B → apply, `git add <file>`, `git rebase --continue`
- C → `git rebase --abort` and hand back control to user

**After all conflicts resolved:**
```bash
git log --oneline <base-branch>..HEAD
echo "✅ Rebase complete — branch is clean"
```

---

## PHASE 0 — DETECT GIT PROVIDER

Run:
```bash
git remote get-url origin 2>/dev/null || git remote get-url upstream 2>/dev/null
```

Parse the URL to determine the provider:

| URL pattern | Provider | CLI available? |
|---|---|---|
| `github.com` | GitHub | check `gh auth status` |
| `gitlab.com` or `gitlab.*` | GitLab | check `glab auth status` |
| anything else | Gogs / Gitea | API only (no official CLI) |

Extract:
- `REMOTE_URL` — full remote URL
- `PROVIDER` — github / gitlab / gogs-gitea
- `BASE_URL` — for Gogs/Gitea: `https://hostname` (strip path)
- `OWNER` — repo owner/organization
- `REPO` — repo name
- `CLI_AVAILABLE` — gh / glab / none

For Gogs/Gitea, check for an API token in env:
```bash
echo "${GOGS_TOKEN:-${GITEA_TOKEN:-not-set}}"
```
If not set, print:
```
⚠️  Gogs/Gitea detected. Set one of these env vars:
    export GOGS_TOKEN="your-token"
    export GITEA_TOKEN="your-token"
    Then re-run /git-pr
```
And STOP.

---

## PHASE 1 — ANALYZE BRANCH STATE

### 1a. Identify current branch and base

```bash
git branch --show-current
```

Determine the base branch from the branch name:
| Branch prefix | Default base | PR type |
|---|---|---|
| `feature/*` | `develop` (or `main` if no develop) | Feature |
| `feat/*` | `develop` (or `main`) | Feature |
| `bugfix/*` | `develop` | Bug fix |
| `fix/*` | `develop` | Bug fix |
| `hotfix/*` | `main` | Hotfix |
| `release/*` | `main` | Release |
| `chore/*` | `develop` (or `main`) | Chore |
| anything else | `main` | General |

Verify the base branch exists:
```bash
git rev-parse --verify <base-branch> 2>/dev/null
```

### 1b. Retroactive diff — ALL changes since branch start

```bash
# All committed changes on this branch (retroactive, session-agnostic)
git log --oneline <base-branch>..HEAD

# All uncommitted changes
git status --short

# Full diff of everything: committed + uncommitted vs base
git diff <base-branch>...HEAD --name-status

# Stats
git diff <base-branch>...HEAD --stat
```

The `git diff <base>...HEAD` (three dots) shows everything since
the branch diverged from base — not just since last commit.
This is the source of truth regardless of session count.

### 1c. Build the CHANGE MAP

Categorize every changed file:
- `config` — package.json, Cargo.toml, go.mod, requirements.txt, docker-compose.yml, Makefile, CI files
- `model` — data models, schemas, migrations, types
- `core` — business logic, services, domain
- `api` / `routes` — endpoints, controllers, handlers
- `ui` — components, pages, styles, assets
- `test` — all test files
- `docs` — README, CLAUDE.md, markdown docs
- `infra` — Dockerfile, deploy scripts, k8s, terraform

---

## PHASE 2 — PROPOSE COMMITS

Group the changes from the CHANGE MAP into logical commits.
Order: config → model → core → api/routes → ui → test → docs → infra

For each group, propose a commit using Conventional Commits:
```
<type>(<scope>): <description>

Types: feat, fix, chore, refactor, test, docs, style, ci, build, perf
Scope: optional, matches the module/directory
```

Present the proposed commit plan:
```
================================================================
GIT WORKFLOW — COMMIT PLAN
================================================================

BRANCH   : <current-branch>
BASE     : <base-branch>
PROVIDER : <github/gitlab/gogs-gitea>

CHANGES SINCE BRANCH START
---------------------------
<git diff --stat output>

PROPOSED COMMITS
----------------
  1. chore(deps): update dependencies — [package.json, go.mod]
  2. feat(auth): add user model and migration — [models/user.go, migrations/001_users.sql]
  3. feat(auth): implement login and JWT handlers — [handlers/auth.go, services/auth.go]
  4. test(auth): add unit tests for auth service — [tests/auth_test.go]
  5. docs: update README with auth setup — [README.md]

UNCOMMITTED CHANGES (will be staged in their respective commit)
---------------------------------------------------------------
<git status --short>

================================================================
Approve this commit plan? (yes / modify / cancel)
================================================================
```

**MANDATORY STOP — wait for user approval.**

IF modify → user describes changes → adjust plan → re-present
IF cancel → stop, no changes made
IF yes → proceed to PHASE 3

---

## PHASE 3 — EXECUTE COMMITS

For each proposed commit, in order:

```bash
# Stage the specific files for this commit
git add <files-for-this-commit>

# Commit with the proposed message
git commit -m "<type>(<scope>): <description>"
```

If a file has both committed and uncommitted changes:
- Stage only the uncommitted portion
- Include it in the appropriate commit group

After all commits:
```bash
git log --oneline <base-branch>..HEAD
```
Show the final commit list for confirmation.

---

## PHASE 4 — PUSH

```bash
# Push, setting upstream if branch is new
git push --set-upstream origin <current-branch>
```

**If push is rejected** (remote has diverged):
1. Run the CONFLICT-SAFE REBASE procedure:
   ```bash
   git fetch origin
   git rebase origin/<current-branch>
   ```
2. Resolve any conflicts as described in CONFLICT-SAFE REBASE
3. Push again: `git push origin <current-branch>`

**If the push is still rejected after rebase:**
```bash
git log --oneline origin/<current-branch>..HEAD
```
Show the commits that haven't been pushed and ask the user:
```
⚠️  Push still rejected after rebase.
    Local commits not on remote: <N>
    Options:
      A) Force push (overwrites remote — use only if remote is yours)
      B) Investigate manually
```
**STOP — wait for user choice. Never force push without explicit approval.**

---

## PHASE 5 — CREATE PR / MR

Build the PR body from:
- `git log <base-branch>..HEAD --format="- %s"` — commit list
- Modified file categories (from CHANGE MAP)
- CLAUDE.md project context

PR body template:
```markdown
## Summary

<2-3 sentence description derived from branch name and commit messages>

## Changes

<commit list from git log>

## Modified areas

<list of changed modules/directories>

## Testing

<describe test coverage based on test files changed>

---
*Created by /git-pr — validate then merge*
```

### GitHub

```bash
# With gh CLI (preferred)
gh pr create \
  --base <base-branch> \
  --head <current-branch> \
  --title "<type>: <feature-name-from-branch>" \
  --body "<pr-body>" \
  --draft

# Without gh CLI — print URL for manual creation
echo "Create PR at: https://github.com/<owner>/<repo>/compare/<base>...<branch>"
```

### GitLab

```bash
# With glab CLI (preferred)
glab mr create \
  --source-branch <current-branch> \
  --target-branch <base-branch> \
  --title "<type>: <feature-name>" \
  --description "<pr-body>" \
  --draft

# Without glab CLI
echo "Create MR at: https://gitlab.com/<owner>/<repo>/-/merge_requests/new?merge_request[source_branch]=<branch>"
```

### Gogs / Gitea

Use the API directly (both use GitHub API v3-compatible format):

```bash
curl -s -X POST \
  "${BASE_URL}/api/v1/repos/${OWNER}/${REPO}/pulls" \
  -H "Authorization: token ${GOGS_TOKEN:-$GITEA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"<type>: <feature-name>\",
    \"body\": \"<pr-body-escaped>\",
    \"head\": \"<current-branch>\",
    \"base\": \"<base-branch>\"
  }"
```

If the API call returns an error, print the full response and suggest
creating the PR manually via the web UI.

---

## PHASE 6 — FINAL REPORT

```
================================================================
PR CREATED
================================================================

BRANCH   : <current-branch> → <base-branch>
COMMITS  : <N> commits pushed
PLATFORM : <GitHub/GitLab/Gogs/Gitea>

COMMITS
-------
<git log --oneline output>

PR / MR
-------
URL  : <pr-url or "create manually at <url>">
Type : Draft — awaiting your review and merge

NEXT STEPS
----------
1. Review the PR at the URL above
2. Request reviews if needed
3. Merge when approved
================================================================
```

---

## RULES

- Never merge, never rebase main/master/develop
- Never force push unless explicitly asked
- Never create commits on main, master, or develop directly
- If on main/master — STOP and ask user to checkout a feature branch first
- Draft PR by default — user controls merge
- If no CLI tool and no API token — print manual instructions, do not fail silently
