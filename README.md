# claude-config

Global Claude Code configuration — agents, skills, plugins, and project templates.

---

## Overview

This repo is your personal Claude Code setup, versioned and reproducible across machines.

```
claude-config/
├── CLAUDE.md                  # Global coding preferences (style, rules, workflow)
├── settings.json              # Global permissions + SessionStart hook
├── install-plugins.sh         # One-shot installer: prerequisites + all plugins
├── link.sh                    # Symlinks this repo into ~/.claude/
├── .gitmodules                # Submodule declaration (GStack)
├── hooks/
│   └── session-start.sh       # Shows toggle plugin status at every session start
├── skills-external/
│   └── gstack/                # Git submodule — garrytan/gstack
│                                (symlinked → ~/.claude/skills/gstack)
├── agents/
│   ├── analyzer.md            # Factual codebase analysis (read-only)
│   ├── git-workflow.md        # Branch setup, commits, PR creation, conflict resolution
│   ├── interviewer.md         # Project questionnaire → PROJECT BRIEF
│   ├── plugin-advisor.md      # Detect plugin mismatches, recommend actions
│   ├── readme-updater.md      # CREATE / SYNC / AUDIT README (3 modes)
│   ├── refactorer.md          # Surgical refactoring with norm enforcement
│   └── scaffolder.md          # Project skeleton (CLAUDE.md, settings, structure)
├── skills/
│   ├── analyze/               # /analyze        — deep factual analysis
│   ├── git-pr/                # /git-pr          — commit, push, open draft PR/MR
│   ├── init-project/          # /init-project    — full project initialization
│   ├── plugin-check/          # /plugin-check    — check plugin config vs project needs
│   ├── readme/                # /readme          — full README audit + update
│   ├── refactor/              # /refactor        — improve code without changing behavior
│   └── ship-feature/          # /ship-feature    — ship a feature end-to-end
└── templates/
    ├── project-CLAUDE.md      # Template for per-project CLAUDE.md
    └── settings/
        ├── home-settings.json # Template for ~/.claude/settings.json
        ├── settings.json      # Template for project .claude/settings.json
        ├── settings.local.json# Template for personal .claude/settings.local.json
        ├── .claudeignore      # Template for project .claudeignore
        └── SETTINGS.md        # Full settings reference
```

**Architecture:**
- `skills/` = entry points you invoke via `/skill-name`
- `agents/` = execution units called by skills (never invoked directly)
- Custom skills use **Superpowers** agents for implementation phases
- **Plugins** (Superpowers, GStack, GSD, etc.) install separately via `install-plugins.sh`

---

## Fresh install (new machine)

```bash
# 1. Clone with submodules (GStack is a git submodule)
git clone --recurse-submodules git@github.com:youruser/claude-config.git ~/claude-config

# 2. Symlink into ~/.claude/
cd ~/claude-config && bash link.sh

# 3. Install prerequisites + all plugins
#    Handles: git, Node.js 22, Rust/Cargo, Python 3, gh CLI, glab CLI,
#             RTK, GStack (submodule), GSD, all marketplace plugins
bash ~/claude-config/install-plugins.sh

# 4. Authenticate git provider CLIs (for /git-pr)
gh auth login        # GitHub
glab auth login      # GitLab
# Gogs/Gitea: see "Git setup" section below

# 5. Add Context7 API key (free at context7.com)
claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp --api-key YOUR_KEY

# 6. Restart Claude Code → /reload-plugins
```

All `claude plugin install` calls use `--scope user` — always installs
to `~/.claude/plugins/` regardless of working directory.

---

## Available slash commands

### Custom skills (this repo)

| Command | Description |
|---|---|
| `/analyze` | Deep factual analysis of code before any modification |
| `/refactor` | Improve code quality without changing behavior (strict norms) |
| `/readme` | Full README audit — diff vs codebase, mandatory stop, surgical updates |
| `/plugin-check` | Check active plugins vs project needs — recommend enable/disable |
| `/git-pr` | Commit all changes, push, open draft PR/MR (GitHub/GitLab/Gogs/Gitea) |
| `/init-project` | Initialize a complete project from scratch (full orchestrator) |
| `/ship-feature` | Ship a feature end-to-end with validation gates (full orchestrator) |

### Superpowers skills (auto-invoked or explicit)

| Command | When it auto-activates |
|---|---|
| `/superpowers:brainstorm` | When you describe something to build |
| `/superpowers:write-plan` | After design is approved |
| `/superpowers:execute-plan` | With an approved plan |
| `systematic-debugging` | Auto — when debugging |
| `test-driven-development` | Auto — when implementing |
| `requesting-code-review` | Auto — after a feature step |

### GStack skills (full-product projects only)

> Submodule at `skills-external/gstack/`, symlinked to `~/.claude/skills/gstack/`.
> **Use when:** project has UI + design + deploy + browser QA.
> Skip for backend-only, libs, CLI, scripts.

| Command | Description |
|---|---|
| `/office-hours` | Discovery consultant — scope and challenge before code |
| `/plan-ceo-review` | CEO challenges product scope and feature value |
| `/plan-eng-review` | Staff engineer locks architecture decisions |
| `/design-consultation` | Build a design system from scratch |
| `/design-shotgun` | Generate multiple visual variants for comparison |
| `/design-html` | Turn approved mockup into production HTML |
| `/review` | Code review (GStack version) |
| `/ship` | One-command: test → build → deploy |
| `/qa` | QA with real Chrome browser automation |
| `/browse` | Headless Chrome web navigation |
| `/careful` | Activate safety guardrails |
| `/freeze` | Lock edits to current directory |
| `/retro` | Engineering retrospective |
| `/gstack-upgrade` | Self-update GStack to latest |

### GSD skills (multi-session large features)

> Installed globally via `npx get-shit-done-cc --claude --global` (done by install-plugins.sh).
> **Use when:** feature spans multiple days/sessions.

| Command | Description |
|---|---|
| `/gsd:discuss-phase` | Refine spec for a phase through conversation |
| `/gsd:plan-phase` | Generate hierarchical phase plan |
| `/gsd:execute-phase` | Execute phase in an isolated context window |
| `/gsd:ship` | Create PR from verified work |
| `/gsd:next` | Auto-advance to the next phase |

### Other plugin commands

| Command | Plugin | Description |
|---|---|---|
| `/pr-review-toolkit:review-pr` | pr-review-toolkit | Multi-agent PR review (6 specialized agents) |
| `/context7:docs <lib>` | context7 | Manual doc lookup for a specific library |

---

## Orchestrators in detail

### `/init-project`

Same rigor as `/ship-feature`. Two validation gates. Full TDD subagent pipeline for v1 features.
Scaffolder creates only the skeleton. readme-updater handles README in two passes (CREATE + SYNC).
Always works on a feature branch — never on main/master.

```
/init-project <project idea>
    │
    ├── STEP 0a: BRANCH SETUP (git-workflow)          ← create feature branch from main
    │                                                    or sync existing branch
    ├── STEP 0b: PLUGIN CHECK (plugin-advisor)        ← blocks if wrong plugins
    ├── STEP 1:  INTERVIEWER (custom)                 → PROJECT BRIEF
    ├── STEP 2:  ANALYZER (custom)                    → ANALYSIS REPORT
    ├── STEP 3:  superpowers:brainstorming             → VALIDATED DESIGN
    ├── STEP 4:  VALIDATION GATE #1                   → approve architecture
    ├── STEP 5:  SCAFFOLDER (custom)                  → skeleton (CLAUDE.md + settings +
    │                                                    structure + empty entry points,
    │                                                    NO features, NO README)
    ├── STEP 5b: README-UPDATER create mode           → CREATE README from CLAUDE.md
    ├── STEP 6:  superpowers:writing-plans             → decompose v1 features into tasks
    ├── STEP 7:  VALIDATION GATE #2                   → approve task plan
    ├── STEP 8:  superpowers:subagent-driven (TDD)    → implement each feature
    ├── STEP 9:  ANALYZER (custom)                    → regression + deviation check
    ├── STEP 10: superpowers:requesting-review         → full code review
    ├── STEP 11: superpowers:finishing-branch          → cleanup + build + tests
    └── STEP 12: README-UPDATER sync mode             → sync README with implementation
```

### `/ship-feature`

```
/ship-feature <feature description>
    │
    ├── STEP 0a: BRANCH SETUP (git-workflow)          ← create/sync feature branch
    ├── STEP 0b: PLUGIN CHECK (plugin-advisor)        ← blocks if wrong plugins
    ├── STEP 1:  superpowers:brainstorming             → VALIDATED DESIGN
    ├── STEP 2:  superpowers:writing-plans             → task plan
    ├── STEP 3:  VALIDATION GATE                      → user approval required
    ├── STEP 4:  superpowers:subagent-driven (TDD)    → implementation
    ├── STEP 5:  ANALYZER (custom)                    → regression / deviation check
    ├── STEP 6:  superpowers:requesting-review         → code review
    ├── STEP 7:  superpowers:finishing-branch          → cleanup
    ├── STEP 8:  README-UPDATER sync mode             → update README
    └── STEP 9:  CREATE PR (optional gate)            → /git-pr if user approves
```

### `/git-pr`

Works on any provider. Retroactive — `git diff <base>...HEAD` sees ALL changes since
branch creation, regardless of session count. Creates a **draft PR** — you control the merge.

```
/git-pr [optional title]
    │
    ├── PHASE 0: Detect provider (GitHub/GitLab/Gogs/Gitea)
    │           Check CLI: gh / glab / API fallback
    ├── PHASE 1: Analyze branch (retroactive)
    │           git diff <base>...HEAD — ALL changes since branch start
    │           Categorize: config / model / core / api / ui / test / docs / infra
    ├── PHASE 2: Propose commit plan (conventional commits)
    │           [VALIDATION GATE] — user approves before any commit
    ├── PHASE 3: Execute commits (staged per logical group)
    ├── PHASE 4: Push (with conflict-safe rebase if rejected)
    └── PHASE 5: Create draft PR/MR
                GitHub → gh pr create --draft  (or API)
                GitLab → glab mr create --draft (or API)
                Gogs   → POST /api/v1/repos/{owner}/{repo}/pulls
                Gitea  → same API format as Gogs
```

**Branch → base mapping:**
| Branch prefix | Default base | Commit type |
|---|---|---|
| `feature/*`, `feat/*` | `develop` or `main` | `feat:` |
| `bugfix/*`, `fix/*` | `develop` | `fix:` |
| `hotfix/*` | `main` | `fix:` |
| `release/*` | `main` | `chore(release):` |

### `/plugin-check`

Standalone — run before any significant work. Also auto-runs as STEP 0b
in `/init-project` and `/ship-feature`.

```
/plugin-check "React + FastAPI SaaS with auth"
→ Detects active plugins
→ Analyzes signals: frontend? design? QA? multi-session? fast-evolving libs?
→ Produces recommendation table
→ Blocks if critical plugins missing, or confirms "proceed"
```

---

## Git setup for `/git-pr`

`/git-pr` auto-detects your provider from the remote URL and uses the best available
authentication method. Here is how to set up each provider.

---

### GitHub

**Option A — gh CLI (recommended)**

```bash
# Install (done by install-plugins.sh)
brew install gh          # macOS
sudo apt install gh      # Linux

# Authenticate (interactive — opens browser)
gh auth login
# Choose: GitHub.com → HTTPS → authenticate with browser

# Verify
gh auth status
```

**Option B — Personal Access Token (for CI or headless)**

1. Go to **github.com → Settings → Developer settings → Personal access tokens → Tokens (classic)**
2. Click **Generate new token**
3. Required scopes: `repo` (full), `read:org` (if org repo)
4. Copy the token

```bash
# Set in environment
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
echo 'export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"' >> ~/.zshrc  # persist

# Claude Code reads GITHUB_TOKEN automatically for gh CLI fallback
```

---

### GitLab

**Option A — glab CLI (recommended)**

```bash
# Install (done by install-plugins.sh)
brew install glab        # macOS

# Authenticate
glab auth login
# Choose: gitlab.com → Token or browser

# For self-hosted GitLab
glab auth login --hostname gitlab.yourcompany.com

# Verify
glab auth status
```

**Option B — Personal Access Token**

1. Go to **gitlab.com → User Settings → Access Tokens** (or your instance)
2. Click **Add new token**
3. Required scopes: `api`, `read_repository`, `write_repository`
4. Copy the token

```bash
export GITLAB_TOKEN="glpat-xxxxxxxxxxxx"
echo 'export GITLAB_TOKEN="glpat-xxxxxxxxxxxx"' >> ~/.zshrc

# For self-hosted
export GITLAB_HOST="https://gitlab.yourcompany.com"
```

---

### Gogs

Gogs has no official CLI. `/git-pr` uses the REST API directly.

**Create an API token:**

1. Log in to your Gogs instance
2. Go to **User Settings (top-right avatar) → Applications**
3. Under **Token Name**, enter `claude-code`
4. Click **Generate Token**
5. Copy the token (shown only once)

```bash
# Set in environment
export GOGS_TOKEN="your-token-here"
echo 'export GOGS_TOKEN="your-token-here"' >> ~/.zshrc

# Verify the API works
curl -H "Authorization: token $GOGS_TOKEN" \
  https://your-gogs-server/api/v1/user
# Should return your user JSON
```

**Required API permissions:** read/write on repos (tokens in Gogs have full API access by default).

---

### Gitea

Same API format as Gogs. Gitea is a Gogs fork.

**Create an API token:**

1. Log in to your Gitea instance
2. Go to **User Settings → Applications → Manage Access Tokens**
3. Enter token name `claude-code`
4. Select permissions: `Issues: Read/Write`, `Repository: Read/Write`
5. Click **Generate Token** and copy it

```bash
export GITEA_TOKEN="your-token-here"
echo 'export GITEA_TOKEN="your-token-here"' >> ~/.zshrc

# Verify
curl -H "Authorization: token $GITEA_TOKEN" \
  https://your-gitea-server/api/v1/user
```

---

### Self-hosted GitHub Enterprise

```bash
# Configure gh for your instance
gh config set -h github.yourcompany.com git_protocol https
gh auth login --hostname github.yourcompany.com

# Verify
gh auth status --hostname github.yourcompany.com
```

---

### Self-hosted GitLab

```bash
glab auth login --hostname gitlab.yourcompany.com --token glpat-xxxx
```

---

### Token security

- **Never commit tokens** to git — they go in `~/.zshrc`, `~/.bashrc`, or a secrets manager
- **Rotate tokens** when they expire or are compromised
- **Minimum scopes** — only grant what `/git-pr` needs (repo read/write)
- Claude Code reads env vars securely — tokens are never written to disk by Claude

---

### Verify your setup

```bash
# Run inside Claude Code to verify everything
/git-pr check-auth
# → Detects provider from current repo remote
# → Tests authentication
# → Reports status per provider
```

Or manually:
```bash
git remote get-url origin   # see which provider
gh auth status              # GitHub CLI status
glab auth status            # GitLab CLI status
curl -s -H "Authorization: token $GOGS_TOKEN" \
  <your-gogs-url>/api/v1/user | jq .login  # Gogs/Gitea
```

---

## Plugins reference

All plugins installed by `install-plugins.sh`.

### At-a-glance: always on vs toggle

The mechanism: Claude Code loads every active skill's **description** at session start
into a shared budget (8000 chars). Even if never invoked, the description costs tokens.
Disabling a plugin → descriptions never load.

A `hooks/session-start.sh` hook shows toggle status at every session start.
Run `/plugin-check` for a full recommendation for the current project type.

| Plugin | Status | Cost/session | When to enable | Installed by |
|---|---|---|---|---|
| **security-guidance** | ✅ ALWAYS ON | 0 (hook only) | — | marketplace |
| **RTK** | ✅ ALWAYS ON | 0 (hook only) | — | cargo + rtk init |
| **Superpowers** | ✅ ALWAYS ON | ~600–1000 | — auto-activates | marketplace |
| **skill-creator** | ✅ ALWAYS ON | ~100 | — | marketplace |
| **pr-review-toolkit** | ✅ ALWAYS ON | ~300 | — `/pr-review-toolkit:review-pr` | marketplace |
| **GStack** | 🔄 TOGGLE | ~2500–3000 | Full-product: UI + design + deploy + QA browser | submodule |
| **GSD** | 🔄 TOGGLE | ~500–800 | Feature spanning multiple days/sessions | npx |
| **frontend-design** | 🔄 TOGGLE | ~200 | Any project with a UI | marketplace |
| **ui-ux-pro-max** | 🔄 TOGGLE | ~400 | Design system, color/typography | marketplace |
| **Context7 MCP** | 🔄 TOGGLE | ~200 | Fast-evolving libs (Next.js, React, Prisma…) | MCP manual |

Toggle plugins start **OFF**. `/plugin-check` signals when to enable them.
`/init-project` and `/ship-feature` run plugin-check automatically as STEP 0b.

### Disable a plugin for a specific project

```bash
/plugin    # inside Claude Code → toggle off
```

Or in `.claude/settings.json`:
```json
{
  "enabledPlugins": {
    "gstack@gstack": false
  }
}
```

### Enable a plugin for a project (share with teammates)

```json
{
  "enabledPlugins": {
    "ui-ux-pro-max@ui-ux-pro-max-skill": true
  },
  "extraKnownMarketplaces": {
    "ui-ux-pro-max-skill": {
      "source": { "source": "github", "repo": "nextlevelbuilder/ui-ux-pro-max-skill" }
    }
  }
}
```

---

## Settings and permissions

### File hierarchy

```
Highest
  managed-settings.json        — enterprise, cannot be overridden
  CLI flags                    — --allowedTools / --disallowedTools (session only)
  .claude/settings.local.json  — personal machine overrides (gitignored)
  .claude/settings.json        — project rules (committed to project repo)
  ~/.claude/settings.json      — global user rules (this repo's settings.json)
Lowest

DENY always wins over ALLOW at any level.
.claudeignore applies independently of all permission rules.
```

### Global `settings.json` (this repo)

Contains global deny/ask/allow rules AND a SessionStart hook:

```json
"hooks": {
  "SessionStart": [
    { "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/session-start.sh" }] }
  ]
}
```

The hook prints toggle plugin status at every session start — zero API calls, filesystem only.

| Section | Purpose |
|---|---|
| `deny` — secrets | Blocks `.env`, `.pem`, `.key`, SSH keys, cloud credentials |
| `deny` — destructive | Blocks `rm -rf`, `git push --force`, `chmod 777` |
| `deny` — system | Blocks `sudo`, `ssh`, `scp`, `crontab`, `systemctl` |
| `deny` — injection | Blocks `curl \| bash`, `wget \| sh` |
| `ask` — risky | Prompts before `git push`, `docker run`, package managers |
| `allow` — safe reads | Auto-approves git read-only, `ls`, `cat`, `grep`, `find` |
| `disableBypassPermissionsMode` | Prevents YOLO mode globally |

### Per-project setup

```bash
cd your-project && mkdir -p .claude

# Project settings (commit)
cp ~/claude-config/templates/settings/settings.json .claude/settings.json

# Personal overrides (never commit)
cp ~/claude-config/templates/settings/settings.local.json .claude/settings.local.json
echo ".claude/settings.local.json" >> .gitignore

# Hard file exclusions (commit)
cp ~/claude-config/templates/settings/.claudeignore .claudeignore

# Project CLAUDE.md (commit)
cp ~/claude-config/templates/project-CLAUDE.md .claude/CLAUDE.md
```

---

## Updating

### This repo
```bash
cd ~/claude-config && git pull
# Symlinks → changes active immediately, no restart needed
```

### GStack (submodule)
```bash
# Option A — from Claude Code
/gstack-upgrade

# Option B — via submodule (pins version in your repo)
cd ~/claude-config
git submodule update --remote skills-external/gstack
cd skills-external/gstack && ./setup
git add skills-external/gstack
git commit -m "chore: update gstack"
```

### Marketplace plugins
```bash
/plugin marketplace update
```

### RTK
```bash
cargo install --git https://github.com/rtk-ai/rtk --force
rtk init -g --auto-patch   # re-apply hook if needed
```

---

## Adding a new custom skill

1. Create `agents/myagent.md` — role, tasks, rules, output format
2. Create `skills/myskill/SKILL.md`:

```markdown
---
name: myskill
description: What this skill does — front-load the key use case (max 250 chars)
argument-hint: <what to pass>
disable-model-invocation: true
---

Load and follow strictly:
- .claude/agents/myagent.md

Execute MYAGENT on:

$ARGUMENTS
```

3. Or use `/skill-creator` to generate a skill from conversation.

---

## Per-project agent overrides

```bash
# Override an agent for a specific project
cp ~/claude-config/agents/refactorer.md .claude/agents/refactorer.md
# Edit — the local version takes precedence over global
```
