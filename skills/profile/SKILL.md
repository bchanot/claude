---
name: profile
description: |
  Partition Claude skills by purpose: design, dev, qa, audit, minimal.
  Toggles symlinks between skills/ and skills-disabled/ to keep only
  the skills relevant to the current kind of work.
  Trigger: "profile", "skill profile", "design profile", "qa profile",
  "switch to design", "set profile", "active profile", "quel profil",
  "profil design", "active les skills design", "désactive gstack",
  "réduire le bruit gstack".
argument-hint: list | show <name> | current | apply <name> | set <name> | reset | gstack on|off | diff <a> <b>
allowed-tools:
  - Bash
  - Read
---

# profile

Activate a curated subset of skills for a specific kind of work — instead of
carrying every gstack + personal skill in every session.

## When to invoke

- User asks to switch profile (`set design`, `profile dev`, `quel profil actif`).
- User wants to see what's in a profile (`profile show qa`).
- User wants to compare profiles (`profile diff design qa`).
- User asks to "reduce gstack noise" or "only design skills".

## Profiles available

| Profile    | Use case |
|------------|----------|
| `web`      | Public website work — frontend + content + light dev |
| `seo`      | SEO + GEO + W3C audit — search/AI indexability + standards |
| `web-full` | Production website end-to-end — `web` + `seo` combined |
| `full`     | Maximum — web-full + plan + dev for `/init-project` MVP pipeline |
| `backend`  | Backend / API / system dev — no design, no SEO |
| `design`   | Visual QA, design systems, mockups, polish |
| `dev`      | Daily code work — features, fixes, refactor, ship (any stack) |
| `qa`       | Site testing, perf, canary, validation |
| `audit`    | Comprehensive audit — security + SEO + GEO + W3C + perf + health |
| `minimal`  | Strip all gstack skills (quiet session) |

## Mechanism

Each profile is a plain-text file under `lib/profiles/<name>.profile` that
lists items + types:

| Type                    | Toggle mechanism |
|-------------------------|------------------|
| `gstack`                | symlink move skills/ ↔ skills-disabled/gstack__\<name\> |
| `personal`              | symlink move skills/ ↔ skills-disabled/\<name\> (no prefix) |
| `external`              | symlink move skills/ ↔ skills-disabled/\<name\> |
| `plugin@<marketplace>`  | `claude plugin enable\|disable <name>@<marketplace>` (auto) |
| `mcp` (known: magic)    | delegate to `lib/toggle-external.sh` (uses `.env`) |
| `mcp` (other)           | advisory — prints manual `claude mcp add …` command |
| `cli`                   | advisory only — reports installed/not-installed |

**Always-on plugins** (`security-guidance`, `superpowers`) are
protected — `set` will refuse to disable them even if the profile omits them.
**Managed plugins** that `set` may disable when not in profile:
`ui-ux-pro-max@ui-ux-pro-max-skill`, `plugin-dev@claude-code-plugins`,
`pr-review-toolkit@claude-code-plugins`. Other plugins are never auto-toggled.

## Commands

```bash
# List available profiles
bash "$HOME/.claude/lib/profile.sh" list

# Show profile contents + per-skill status
bash "$HOME/.claude/lib/profile.sh" show <name>

# Detect which profile is currently active
bash "$HOME/.claude/lib/profile.sh" current

# Enable skills in profile (additive — keeps others enabled)
bash "$HOME/.claude/lib/profile.sh" apply <name>

# Enable only skills in profile (disables non-listed gstack skills)
bash "$HOME/.claude/lib/profile.sh" set <name>

# Re-enable every gstack skill (undo any set/apply) — resets active label to "none"
bash "$HOME/.claude/lib/profile.sh" reset

# Toggle gstack only, keeping the active-profile label intact
bash "$HOME/.claude/lib/profile.sh" gstack on    # re-enable ALL gstack on top of current profile
bash "$HOME/.claude/lib/profile.sh" gstack off   # disable gstack skills not in the active profile

# Compare two profiles
bash "$HOME/.claude/lib/profile.sh" diff <a> <b>
```

## Execution

Run `lib/profile.sh` with the user's arguments. If user passed nothing, default
to `list`. If user named a profile without a verb (e.g. "profile design"),
treat it as `set <name>` — but confirm first because `set` disables other gstack
skills.

```bash
bash "$HOME/.claude/lib/profile.sh" $ARGUMENTS
```

## Output policy

- After `set` / `apply` / `reset` / `gstack on|off`: show the count of skills
  moved + tell the user to start a new Claude session to pick up the changes
  (Claude scans `skills/` at session start).
- After `current`: report the active profile + match percentage.
- After `show`: render the grouped output directly — no extra commentary unless
  the user asks.

## Tradeoffs to mention if asked

- gstack skills still depend on `~/.claude/skills/gstack/bin/` for telemetry,
  update-check, learnings — script doesn't touch that infra. Disabled skills
  are just hidden from Claude Code's scanner; the gstack repo stays installed.
- Profile changes DO toggle the managed Claude Code plugins (ui-ux-pro-max,
  plugin-dev, pr-review-toolkit) and the `magic` MCP — see the Mechanism table
  above (BDR-008). Anything outside that managed set stays manual:
  `claude plugin enable|disable`, `claude mcp add|remove`.
- `set` is destructive in the sense that it disables non-listed gstack skills.
  Use `apply` if the user wants additive behavior.
