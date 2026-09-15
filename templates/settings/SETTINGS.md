# Claude Code — Settings Rule Syntax

## Rule syntax

### Bash
```json
"Bash(git status)"         // exact match
"Bash(npm run test:*)"     // wildcard suffix
"Bash(git push*)"          // prefix match
"Bash(curl * | bash)"      // pipe pattern — block code injection
```

### Read / Edit — gitignore syntax
```json
"Read(**/.env)"            // any .env in any subdirectory
"Read(**/secrets/**)"      // anything inside secrets/
"Read(src/**/*.ts)"        // all .ts under src/
"Edit(**/*.key)"           // deny writing any .key file — Edit covers
                           // Write/Edit/MultiEdit/NotebookEdit
```
`Write(path)` rules are **inert**: file permission checks only match
`Edit(path)`. Claude Code warns at startup for every `Write(glob)` rule.
Always write the file-write ban as `Edit(...)`.

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
| `auto` | Research preview — agentic default, permission model evolving. This config's default (BDR-004) | Daily driving with guardrails |
| `bypassPermissions` | Skips all prompts — **dangerous** | CI/CD only, sandboxed env |

## Auto mode (`autoMode`)

With `defaultMode: auto`, a classifier decides each action instead of a static
prompt. The `autoMode` block is what you hand that classifier.

| Key | What it holds |
|---|---|
| `environment` | Facts about the machine and the repo. Context, not rules. |
| `allow` | Action classes the classifier may clear on its own. |
| `soft_deny` | Destructive or irreversible actions. Explicit user intent clears them. |
| `hard_deny` | Security boundaries. User intent does **not** clear them. |
| `classifyAllShell` | `true` suspends every Bash allow rule so all shell goes through the classifier. |

All four lists are prose spliced into the classifier prompt, not permission-rule
syntax. Write `Sending SIGKILL reaches processes outside this session`, not
`Bash(kill -9 *)`.

### `$defaults`

Each list **replaces** the built-in entries unless it contains the literal
string `"$defaults"`, which splices them in at that position. Put it first and
your own entries refine what follows. Omit it and you silently drop every
built-in rule, which is almost never the intent.

### Scope it right

`autoMode` in `~/.claude/settings.json` reaches **every** project on the
machine. Project facts (this repo's deploy target, its secrets, its data)
belong in that project's `.claude/settings.local.json`. A global block naming
one repo feeds the classifier false facts in all the others.

### `ask` is not a prompt under auto mode

Verified in-session (LRN-146): with `defaultMode: auto`, Bash rules in
`permissions.ask` were auto-approved and raised no prompt. `deny` is the only
tier the classifier cannot lift.

So for a destructive command you want gated but still reachable, `ask` is the
wrong tier. Use `autoMode.soft_deny`: blocked until the user's intent clears
it. Keep `deny` for what must never run at all.

### Picking a tier

| You want | Tier |
|---|---|
| Never runs, no exception, matchable by a command pattern | `permissions.deny` |
| Never runs, and a pattern cannot express it (a read then a send, a prod target) | `autoMode.hard_deny` |
| Runs when the user asks for it, blocked otherwise | `autoMode.soft_deny` |
| Runs freely | `permissions.allow`, or nothing |

`permissions.ask` is not on this list on purpose. Under `defaultMode: auto` it
gates nothing.

### Scope of intent

A `soft_deny` clears on the user's instruction, and this config scopes that to
the **current turn**. An approval from an earlier turn is not an approval now.
State the scope in the rules themselves: the classifier reads the list, it has
no separate setting for this.

## Security notes

- `Read(**/.env)` only blocks the Read tool. `Bash(cat .env)` bypasses it unless separately denied.
  → Use `.claudeignore` for hard file exclusion regardless of tool.
- `disableBypassPermissionsMode: "disable"` prevents switching to bypass mode mid-session.
- Prefer `ask` over `allow` for anything touching external systems.
- `deny` in `~/.claude/settings.json` cannot be overridden by project-level `allow` — deny always wins.
- Under `defaultMode: auto`, `ask` does not raise a prompt (see above). A destructive
  command belongs in `deny` or in `autoMode.soft_deny`, not in `ask`.

## managed-settings.json (enterprise)

| OS | Path |
|---|---|
| Windows | `C:\ProgramData\ClaudeCode\managed-settings.json` |
| macOS | `/Library/Application Support/ClaudeCode/managed-settings.json` |
| Linux | `/etc/claude-code/managed-settings.json` |
