# Claude Code — Settings Rule Syntax

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

### WebFetch / WebSearch
```json
"WebFetch(domain:docs.rs)" // specific domain only
"WebFetch"                  // all web fetches
"WebSearch"                 // no sub-patterns supported
```

### Agent / Skill / MCP
```json
"Agent(explorer)"
"Skill(deploy *)"
"mcp__github__*"           // all tools from github MCP server
```

## defaultMode values

| Value | Behavior | When to use |
|---|---|---|
| `default` | Prompts on first use of each tool | Normal development |
| `acceptEdits` | Auto-accepts file edits, prompts for Bash | Trusting sessions |
| `plan` | Read-only — Claude plans, cannot execute | Code review, audit |
| `bypassPermissions` | Skips all prompts — **dangerous** | CI/CD only, sandboxed env |

## Security notes

- `Read(**/.env)` only blocks the Read tool. `Bash(cat .env)` bypasses it unless separately denied.
  → Use `.claudeignore` for hard file exclusion regardless of tool.
- `disableBypassPermissionsMode: "disable"` prevents switching to bypass mode mid-session.
- Prefer `ask` over `allow` for anything touching external systems.
- `deny` in `~/.claude/settings.json` cannot be overridden by project-level `allow` — deny always wins.

## managed-settings.json (enterprise)

| OS | Path |
|---|---|
| Windows | `C:\ProgramData\ClaudeCode\managed-settings.json` |
| macOS | `/Library/Application Support/ClaudeCode/managed-settings.json` |
| Linux | `/etc/claude-code/managed-settings.json` |
