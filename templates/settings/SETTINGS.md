# Claude Code — Settings Reference

## Where each file goes

```
~/.claude/
├── settings.json          ← home-settings.json (renamed) — global, NEVER commit
│
mon-projet/
└── .claude/
    ├── settings.json      ← settings.json — project rules, commit to git
    └── settings.local.json← settings.local.json — personal, gitignored
```

Add to your project `.gitignore`:
```
.claude/settings.local.json
```

---

## Precedence (highest → lowest)

```
managed-settings.json     system-wide, cannot be overridden
  └── CLI flags            --allowedTools, --disallowedTools (session only)
        └── settings.local.json   personal local
              └── settings.json   project (team)
                    └── ~/.claude/settings.json   global user
```

**DENY always wins over ALLOW, regardless of level.**

---

## What goes where

| Rule type | File |
|---|---|
| Deny secrets, SSH, rm -rf, sudo | `~/.claude/settings.json` |
| Deny git push --force, curl\|bash | `~/.claude/settings.json` |
| Ask git push, docker run, deploy | `~/.claude/settings.json` |
| Ask package managers (brew, apt) | `~/.claude/settings.json` |
| Allow git read-only, ls, cat, grep | `~/.claude/settings.json` |
| Allow npm/cargo/make/pytest... | `.claude/settings.json` (project) |
| Ask psql, mysql, redis-cli | `.claude/settings.json` (project) |
| Allow specific WebFetch domains | `.claude/settings.local.json` |
| Personal additionalDirectories | `.claude/settings.local.json` |

---

## defaultMode values

| Value | Behavior | When to use |
|---|---|---|
| `default` | Prompts on first use of each tool | Normal development |
| `acceptEdits` | Auto-accepts file edits, prompts for Bash | Trusting sessions |
| `plan` | Read-only — Claude plans, cannot execute | Code review, audit |
| `bypassPermissions` | Skips all prompts — **dangerous** | CI/CD only, sandboxed env |

Disable bypass permanently (set in `~/.claude/settings.json`):
```json
{ "permissions": { "disableBypassPermissionsMode": "disable" } }
```

---

## Rule syntax

### Bash
```json
"Bash(git status)"         // exact match
"Bash(npm run test:*)"     // wildcard suffix
"Bash(git push*)"          // prefix match
"Bash(curl * | bash)"      // pipe pattern — block code injection
```

### Read / Write / Edit — gitignore syntax
```json
"Read(**/.env)"            // any .env in any subdirectory
"Read(**/secrets/**)"      // anything inside secrets/
"Read(src/**/*.ts)"        // all .ts under src/
"Write(**/*.key)"          // deny writing any .key file
```

### WebFetch
```json
"WebFetch(domain:docs.rs)" // specific domain only
"WebFetch"                  // all web fetches (no sub-pattern)
```

### WebSearch
```json
"WebSearch"                 // no sub-patterns supported
```

### Agent / Skill / MCP
```json
"Agent(explorer)"
"Skill(deploy *)"
"mcp__github__*"           // all tools from github MCP server
"mcp__playwright__navigate"
```

---

## Security notes

- `Read(**/.env)` only blocks the Read tool.
  `Bash(cat .env)` bypasses it unless you also deny that Bash command.
  → Use `.claudeignore` for hard file exclusion.

- `disableBypassPermissionsMode: "disable"` prevents switching to
  bypass mode mid-session — set it in `~/.claude/settings.json`.

- Prefer `ask` over `allow` for anything touching external systems
  (git push, deploy, database commands, package install).

- `deny` rules in `~/.claude/settings.json` cannot be overridden
  by project-level `allow` rules — deny always wins globally.

---

## managed-settings.json (enterprise)

Cannot be overridden by any user or project setting.

| OS | Path |
|---|---|
| Windows | `C:\ProgramData\ClaudeCode\managed-settings.json` |
| macOS | `/Library/Application Support/ClaudeCode/managed-settings.json` |
| Linux | `/etc/claude-code/managed-settings.json` |
