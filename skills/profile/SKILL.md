---
name: profile
effort: low
description: |
  Set the pack profile of THIS project (writes .claude/settings.local.json)
  or show the effective one of this conversation. Packs are skills-dir
  plugins (design, scroll3d, seo, web-validate, gstack-dev/-browser/-design,
  higgsfield, extras); a profile is a settings fragment lib/profiles/<n>.json.
  Trigger: "profile", "skill profile", "design profile", "set profile",
  "active profile", "quel profil", "profil design", "active les skills
  design", "enable higgsfield", "désactive gstack", "réduire le listing".
argument-hint: list | show <name> | current | set <name> | unset | enable <pack> | disable <pack> | diff <name>
allowed-tools:
  - Bash
  - Read
---

# /profile — packs per project and per conversation

Run `bash "$HOME/.claude/lib/profile.sh" -C "$PWD" $ARGUMENTS` and show its
output. With no argument, run `current` and then `list`.

## What a profile is

`lib/profiles/<name>.json` holds `enabledPlugins` (every pack and managed
plugin, explicit), optional `deniedMcpServers` (the two higgsfield claude.ai
connectors) and optional `model`. Descriptions: `lib/profiles/README.md`.

- Per project: `set <name>` merges the fragment into
  `.claude/settings.local.json` (other keys kept). Then `/reload-plugins`
  loads the packs in this session; connectors and model apply to the next
  session.
- Per conversation: `cc <session> <name>` (lib/cc.sh) runs
  `claude --settings lib/profiles/<name>.json`. That conversation is frozen:
  editing the fragment or the local file changes nothing here, and a pack the
  fragment turns off cannot come back; start another `cc`.
- No profile: the manifest defaults, which equal `full` with the connectors
  present.

## Verbs

| verb | effect |
|---|---|
| `list` | names + descriptions |
| `show <n>` | the fragment: packs on/off, denied connectors, model; `missing` on a pack with no `skills/pack-<n>/` |
| `current [--plain]` | effective state of this project and conversation; `--plain` is what gates and the statusline read |
| `set <n>` | write the fragment into the local file |
| `unset` | remove the managed keys from the local file |
| `enable <pack>` / `disable <pack>` | one pack (`design`, `pack-design` or a plugin id) |
| `diff <n>` | effective state against a fragment |

Refusals (rc 2, nothing written): unknown profile or pack, not a project
root (no `CLAUDE.md`, no `.git`), unreadable or invalid local JSON.

## Rules

- Never write the user scope (`~/.claude/settings.json`); never toggle
  plugins through the `claude plugin` CLI. A pack need found mid-skill is proposed to
  the user (`set <n>` or `enable <pack>` + `/reload-plugins`, or a relaunch
  under `--settings`), written only on consent (lib/plugin-gate.md).
- `deniedMcpServers` is a union across settings files: a `cc x web` over a
  project set to `dev` keeps the connectors denied; `set web` in the
  project brings them back for the next session.
- `max` turns on `pack-extras` (diagram, make-pdf, 21st-ai, 21st-ui-explore,
  21st-ui-review); `pack-higgsfield` is on in `max` only, else `enable
  higgsfield` for a named media ask.
