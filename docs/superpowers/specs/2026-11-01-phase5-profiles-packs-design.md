# Phase 5: profiles per project and per conversation, native packs

Date 2026-11-01. Branch `feature/phase5-profiles-packs`. Contract
`.claude/tasks/contracts/2026-11-01-phase5-profiles-packs-1300.md`.
Measured facts: scratchpad `p5/FACTS.md` (copied into the plan).
Supersedes BDR-030, BDR-079, part of BDR-101; amends BDR-024/025, BDR-109.

## 0. Intent

One `~/.claude` serves every project and every open conversation. Today the
heavy skill groups (design, gstack, seo, higgsfield, 21st…) are switched
globally: a `skills/` ↔ `skills-disabled/` symlink move plus user-scope
`claude plugin enable|disable`, driven by `lib/profile.sh` and a
`.active-profile` marker. Switching for one project changes every other open
session, and the listing of ~124 skills costs context in every conversation.

After this phase the heavy groups are skills-dir plugins (packs) switched by
`enabledPlugins`: per project through `.claude/settings.local.json`, per
conversation through `claude --settings <profile>.json`. Two conversations in
the same project can hold different packs. Nothing is ever written to the
user scope. The global symlink mode is deleted.

Decisions already taken with the user (2026-10-25 and 2026-11-01): no
profile = `full` (packs ON, as today); gstack split in three packs;
higgsfield connectors denied outside design/web profiles; launcher
`cc <name> [profile]` in `lib/cc.sh`; approach A (tracked packs, profile
fragments, exported flag).

## 1. Packs

A pack is `skills/pack-<n>/` with `.claude-plugin/plugin.json`
(`"name": "pack-<n>"`, `defaultEnabled` as below) and `skills/<s>/` entries.
Claude Code loads it as `pack-<n>@skills-dir`; its skills are listed once as
`pack-<n>:<s>`; `Skill(<s>)`, `Skill(pack-<n>:<s>)`, typed `/<s>` and
`/pack-<n>:<s>` all resolve (spikes 1, 1c). A pack with
`defaultEnabled: false` is OFF with nothing written anywhere (spike 1b).

Each `skills/pack-<n>/skills/<s>` is either a relative symlink
`../../../skills-external/<s>` (or `../../../skills-external/gstack/<s>` for
gstack, a submodule) committed to git, or the skill's real directory moved
with `git mv` from `skills/<s>` (seo, geo, web-validate, site-motion,
impeccable). Installers (`install-plugins.sh`, `update-all.sh`,
`lib/higgsfield-skills.sh`, the gstack and 21st installers) fill
`skills-external/` only; they never create or move a symlink in `skills/`.

| Pack | Skills | Default |
|---|---|---|
| design | impeccable, emil-design-eng, frontend-design, design-motion-principles, 21st-ui-build, 21st-cli-use, site-motion | ON |
| scroll3d | scroll-world-storytelling, build-threejs-scroll-worlds, scroll-scrubbed-visual-sequence, scroll-scrubbed-word-reveal, scroll-progress-timeline | ON |
| seo | seo, geo | ON |
| web-validate | web-validate | ON |
| gstack-dev | review, investigate, codex, cso, health, freeze, unfreeze, retro, spec, skillify, office-hours, plan-eng-review, plan-ceo-review, plan-devex-review, document-release | ON |
| gstack-browser | browse, open-gstack-browser, setup-browser-cookies, scrape, qa, qa-only, benchmark, canary | ON |
| gstack-design | design-review, design-consultation, design-html, plan-design-review | ON |
| higgsfield | the 8 `higgsfield-*` skills | OFF |
| extras | diagram, make-pdf, 21st-ai, 21st-ui-explore, 21st-ui-review | OFF |

Core stays flat in `skills/`: the personal skills, the vendored superpowers
set, the agent-skills trio, `model-router` (already a skills-dir plugin),
`darwin-skill`. Agents stay global. `lib/gstack-removed.sh` keeps naming the
nine gstack skills retired by BDR-117; none of them enters a pack.

`skills-disabled/` is deleted. `.gitignore` loses its ~100 `skills/<x>` lines
(the pack symlinks are tracked) and the `skills-disabled/` line;
`skills-external/*` stays ignored except the vendored entries and the gstack
submodule. A pack symlink whose target is absent: red in `make test` and in
doctor when the pack is ON by manifest; a doctor warning when the pack is
OFF and its installer has not run.

## 2. Profiles

`lib/profiles/<n>.json` is a literal settings fragment, usable verbatim as
`claude --settings <file>`. `dev.json` in full:

```json
{
  "enabledPlugins": {
    "model-router@skills-dir": true,
    "pack-design@skills-dir": false,
    "pack-scroll3d@skills-dir": false,
    "pack-seo@skills-dir": false,
    "pack-web-validate@skills-dir": false,
    "pack-gstack-dev@skills-dir": true,
    "pack-gstack-browser@skills-dir": false,
    "pack-gstack-design@skills-dir": false,
    "pack-higgsfield@skills-dir": false,
    "pack-extras@skills-dir": false,
    "ui-ux-pro-max@ui-ux-pro-max-skill": false,
    "security-guidance@claude-code-plugins": true,
    "pr-review-toolkit@claude-code-plugins": false,
    "example-skills@anthropic-agent-skills": false,
    "brightdata-plugin@synced": false
  },
  "deniedMcpServers": [
    {"serverName": "claude.ai higgsfield"},
    {"serverName": "claude.ai Higgsfield AI"}
  ]
}
```

A profile may add `"model": "<alias>"` as a third key.

Every profile lists every pack and every managed plugin (`model-router`,
`ui-ux-pro-max@ui-ux-pro-max-skill`, `security-guidance@claude-code-plugins`,
`pr-review-toolkit@claude-code-plugins`, `example-skills@…`,
`brightdata-plugin@synced`) explicitly, so a profile set after another leaves
nothing behind. `model-router` and `security-guidance` are true in every
profile, `minimal` included; `example-skills` and `brightdata-plugin` are
false in every profile. `model` is optional; no shipped profile carries one
(the key exists for the user's own profiles). `deniedMcpServers` names both
higgsfield connectors in every profile except design, web, web-full, full
and max, where the key is absent. Descriptions live in
`lib/profiles/README.md`, not in the JSON.

| Profile | Packs ON (plus core) | ui-ux-pro-max | pr-review-toolkit |
|---|---|---|---|
| full | all except higgsfield, extras | on | off |
| max | all | on | on |
| minimal | none | off | off |
| dev, backend | gstack-dev | off | off |
| design | design, scroll3d, gstack-design, gstack-browser | on | off |
| web | design, scroll3d, web-validate, gstack-design, gstack-browser, gstack-dev | on | off |
| web-full | web + seo | on | off |
| seo | seo, web-validate, gstack-browser, gstack-dev | off | off |
| qa | gstack-browser, web-validate | off | off |
| audit | seo, web-validate, gstack-dev, gstack-browser | off | on |

A project with no profile runs the manifest defaults, which equal `full`
minus the connector deny (higgsfield connectors present, as today).

### `lib/profile.sh` verbs

- `list`: names + one-line description from the README.
- `show <n>`: the fragment's packs ON/OFF, denied connectors, model; a pack
  named in the fragment with no `skills/pack-<n>/` directory is marked
  `missing`.
- `current [--plain]`: the effective state of THIS project and conversation.
  Reads, in precedence order, `$CLAUDE_PROFILE_SETTINGS` (the `--settings`
  file exported by `cc`), `.claude/settings.local.json`,
  `.claude/settings.json`, `~/.claude/settings.json`, merging per key
  (higher source wins, `disableClaudeAiConnectors` any-source-true); then
  `disabledMcpServers` for this project path in `~/.claude.json`. Matches
  the effective packs + denies against the fragments: a match prints the
  profile name, else `custom`; `disabledMcpServers` non-empty prints
  `custom (off: <names>)`. `--plain` prints one `key=value` per line:
  `profile=<n>|custom|none`, `source=flag|local|default`,
  `pack-<n>=on|off` for every pack, `plugin:<id>=on|off` for every managed
  plugin, `connector:<name>=denied` per denied connector, `model=<m|->`.
  `--plain` is the single truth for every gate, hook and statusline
  (supersedes BDR-024 `show --plain`). Limit: `source=flag` is known only
  through the variable `cc` exports; a `claude --settings` launched by hand
  reads as `local` or `default` (said in USAGE).
- `set <n>`: merges the fragment's `enabledPlugins`, `deniedMcpServers` and
  `model` (when present) into `.claude/settings.local.json`, keeping every
  other key (`permissions`, a `/model` project write…). Refuses outside a
  project root (no `CLAUDE.md` and no `.git`), on an unreadable or invalid
  local JSON (rc 2, file untouched), on an unknown profile (list + rc 2).
  Prints what changed and `/reload-plugins` as the next step.
- `unset`: removes from the local file the `enabledPlugins` ids and the
  `deniedMcpServers` names any fragment manages; removes `model` only when
  the local value equals the model of the profile `current` detects.
- `enable <pack>` / `disable <pack>`: one `enabledPlugins` id in the local
  file, same refusals as `set`.
- `diff <n>`: the effective state against the fragment, per key.

Removed: `apply`, `reset`, `gstack on|off`, `show --plain`, `.active-profile`,
`DEFAULT_PROFILE`, every symlink move, every `claude plugin enable|disable`.

## 3. `lib/cc.sh` launcher

`cc <name> [profile]` replaces `dtach_claude` in `~/.bashrc`; the user adds
`. ~/.claude/lib/cc.sh` to `.bashrc` (documented in MIGRATION.md, checked by
doctor). Without a profile it does what `dtach_claude` does today. With one:

1. `lib/profiles/<profile>.json` absent → print the list, return 2, no
   session.
2. Export `CLAUDE_PROFILE=<profile>`,
   `CLAUDE_PROFILE_SETTINGS=$HOME/.claude/lib/profiles/<profile>.json`,
   `TMPDIR=$HOME/.cache/claude-tmp` (created; exported with or without a
   profile; closes BLK-021 / TODO line 145).
3. `systemd-run --user --scope` + `dtach -c "$HOME/.dtach/<name>"` + the
   `.env` sourcing, then `exec claude --settings "$CLAUDE_PROFILE_SETTINGS"`.
   The scope inherits the exported variables; the test proves it.

`lib/tests/cc.test.sh` runs `cc` with PATH shims for `systemd-run`, `dtach`
and `claude` (each shim drops its own options, execs the command that
 follows, and the last records argv + env to a
file): asserts the `--settings` path, the three variables, rc 2 on an unknown
profile and no `claude` call in that case.

A `--settings` conversation is frozen: the flag is read once at startup and
`/reload-plugins` keeps it (spike 2b). A pack OFF in the flag file cannot be
turned on in that conversation; the remedy is `cc <name> <other profile>`.

## 4. Gates, hooks, detection

- `lib/design-tool-gate.sh`: needs `pack-design=on`, `pack-gstack-design=on`
  and `plugin:ui-ux-pro-max@ui-ux-pro-max-skill=on` from `current --plain`;
  the `21st login` SIGN-IN check stays. INCOMPLETE with `source=flag` →
  "relaunch: `cc <name> web`"; otherwise → "`bash ~/.claude/lib/profile.sh set
  web` (or `enable design`), then `/reload-plugins`". No `skills/` file check.
- `lib/plugin-gate.md`, `agents/plugin-advisor.md`, `agents/plugin-probe.md`:
  probe = `current --plain`; the advisor maps its canonical profile to a
  `lib/profiles` name; PROPOSED CHANGES = `profile.sh set <n>` or
  `enable <pack>`, written only on consent, never user scope; in a
  `--settings` conversation a missing pack is reported as "relaunch", never
  written.
- `lib/design-gate.md`: the same remedy text; `/profile design` becomes the
  two forms above.
- `hooks/session-start.sh`: one line `profile: <n> (local|conv)` or
  `profile: none (full) · /plugin-check proposes one`. The banner hint
  "/plugin-check before starting a new project" is deleted.
- `hooks/statusline.sh`: reads `current --plain`, shows `<n>` and `(conv)`
  when `source=flag`. One call per refresh, no network, under 50 ms.
- `doctor.sh`: pack symlink targets (red ON / warn OFF), every manifest
  parses and its `name` equals the folder, every profile JSON parses and
  names only existing packs, `~/.bashrc` sources `lib/cc.sh`,
  `settings.json` `model` is `opus`.
- `skills/profile/SKILL.md`: rewritten around `set`/`enable`/`disable`/
  `current`, the relaunch rule, and "a `--settings` file edited mid-session
  has no effect".
- `make profile*` targets follow the verbs; `profile-reset` is deleted.

## 5. Listing budget (last task, after the proof)

Re-run the ctxprobe bench (2026-10-25: 124 skills, 46 name-only at the
default budget; 60000 → 0 name-only for +5.7k tokens) on `full` and `dev`.
Names are longer now (`pack-gstack-browser:open-gstack-browser`), so the
number is measured again. Set `SLASH_COMMAND_TOOL_CHAR_BUDGET` in
`settings.json` `env` to the smallest value leaving 0 name-only on `full`;
record the cost per profile in CHANGELOG.

## 6. Cleanup and registers

Deleted: `skills-disabled/` (24 symlinks, `git rm` on literal paths),
`lib/toggle-external.sh`, `lib/tests/higgsfield.test.sh`,
`lib/tests/toggle-external-repo-resolution.test.sh`,
`lib/profiles/*.profile`, `.active-profile`, the `.gitignore` `skills/<x>`
block, the banner hint.

Rewritten: `lib/profile.sh`, `skills/profile/SKILL.md`, `lib/plugin-gate.md`,
`lib/design-gate.md`, `lib/design-tool-gate.sh`, `agents/plugin-probe.md`,
`agents/plugin-advisor.md`, `install-plugins.sh`, `update-all.sh`,
`lib/higgsfield-skills.sh`, the gstack and 21st installers,
`hooks/session-start.sh`, `hooks/statusline.sh`, `doctor.sh`, `Makefile`,
`lib/skill-routing-census.py` (adds the glob
`skills/pack-*/skills/*/SKILL.md`), the tests `profile-census`,
`profile-default`, `profile-set-managed`, `gstack-removed`,
`design-tool-gate`, and `design-toolchain-reminder` and `gstack-links` where
they read the old layout.

Docs: CLAUDE.global.md (the "toggle-external.sh enable higgsfield" lines
become "`bash ~/.claude/lib/profile.sh enable higgsfield`, then
`/reload-plugins`"; the higgsfield routing and the "max only" note on
21st-ai/ui-explore/ui-review stay), README, USAGE, MIGRATION (the `.bashrc`
line), ARCHITECTURE, CHANGELOG. Every citer of a changed rule, label or
path is patched in the same commit (doctrine-citers census).

Registers: one phase-5 BDR superseding BDR-030 (gstack on demand via
symlinks), BDR-079 (`set` symmetric on externals and MCPs) and BDR-101 for
the mechanism (full by default stays the policy, the manifest is the
mechanism); amends BDR-024/025 (`show --plain` → `current --plain`) and
BDR-109 (the two higgsfield toggles → pack OFF + `enable`; the npm CLI
unchanged). BDR-126/127/132 stay: `/model` project scope writes the same
`model` key of `settings.local.json`; `profile.sh set` replaces it only when
the profile carries one; `current` prints the source.

## 7. Proof

Hermetic, `make test`:
- `profile.sh set` merges and keeps other keys, refuses invalid JSON,
  refuses outside a project root; `current` on the four precedence levels
  and on `disabledMcpServers`; `enable`/`disable`/`unset`.
- `cc.sh` with the fake `claude` (§3).
- Pack census: every pack dir has a manifest whose `name` is the folder,
  every symlink resolves or is on an OFF pack, no skill listed twice across
  packs and core, the nine retired gstack skills absent, zero citations of
  `~/.claude/skills/<moved skill>` for the five moved skills, zero of
  `skills-disabled/` or `toggle-external.sh` outside CHANGELOG, MIGRATION,
  `.claude/memory/` and `.claude/tasks/` (append-only history).
- `design-tool-gate` driven by `current --plain` fixtures.
- Routing: every row of `mods/model-router/routing.json` still names a skill
  present in core or a pack. Verified first in the plan: a headless canary on
  `turnMain.source` shows whether the harness reports `pack-x:skill` or
  `skill`; rows gain the long name if needed.

Headless canaries, scratchpad, kept out of the repo:
- Two concurrent conversations in one project (`--settings dev.json` and
  `web.json`) list different skills and different tools (higgsfield denied
  in dev).
- Two projects with a different local profile.
- `enable` + `/reload-plugins` in a conversation without a flag.
- Both slash forms on a real pack skill (`/seo`, `/pack-seo:seo`).
- A dangling pack symlink does not break the pack's other skills.

Interactive, the user: `/context` on `full`, `dev`, `web` once (numbers to
CHANGELOG); `cc <name> web` on a real project.

## 8. Errors

Unknown profile → list + rc 2, nothing written, no session. Pack named in a
profile without a directory → `show` marks `missing`, doctor warns, `set`
still writes (the CLI ignores an unknown plugin id). Dangling symlink on an
ON pack → red test, red doctor. `--settings` file edited mid-session → no
effect, said in `/profile` and USAGE. Unreadable `settings.local.json` →
`set`/`enable` refuse, never overwrite. `~/.claude.json` unreadable →
`current` prints `disabledMcpServers=unknown` and goes on.

## 9. Out of scope

Skill routing (deferred). A pack `.mcp.json` for higgsfield (spike 4: the
connector already serves it; a pack server would duplicate its tools).
Managed-settings and `--plugin-dir` flows. The faunosteo integration.
