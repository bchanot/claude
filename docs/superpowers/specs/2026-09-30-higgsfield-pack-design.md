# Higgsfield pack: design

Date: 2026-09-30. Contract: `.claude/tasks/contracts/2026-09-30-higgsfield-pack-1412.md`
(binding: request, clarifications, 14 acceptance criteria).

## Goal

Generate images, video, audio and brand media from Claude Code through the
Higgsfield CLI, and have `make plugin` reproduce the setup on any machine.
The pack costs nothing when unused: it is installed on disk, linked on demand.

## Decisions (validated by the user)

- Two toggles in `lib/toggle-external.sh`, both off by default, additive on
  any profile: `higgsfield` (7 media skills) and `higgsfield-websites` (one
  skill).
- `higgsfield-websites` is an aid for landing pages inside the existing
  Design work stack and site rules: assets and references. Never
  `higgsfield website create|deploy|publish`.
- Skills come from a git clone of `higgsfield-ai/skills` (tracks `main`),
  not from `npx skills add`, which re-links all 8 skills on every refresh.
- CLI `@higgsfield/cli` at `latest` (21st precedent).
- Routing lines in `CLAUDE.global.md`: explicit ask → enable the toggle →
  follow the skill.
- The two dead login offers already in `install-plugins.sh` (ctx7, 21st) are
  fixed here: they test stdout, which is the `tee` pipe.
- `settings.json` denies the `npm i -g` aliases (done by hand, outside the
  installer).

## Units

### `lib/higgsfield-skills.sh` (new, sourced)

Owns everything both installers share.

- `HIGGSFIELD_SKILLS_URL`: defaults to
  `https://github.com/higgsfield-ai/skills.git`; an env value wins (tests
  point it at a local fixture repo).
- `higgsfield_sync_skills <repo>`: `git clone --depth 1` into a `mktemp -d`
  stage. Every `higgsfield-*/` directory of the stage that holds a
  `SKILL.md` replaces `<repo>/skills-external/<name>` (rm, then mv). Prints
  the number of skills synced. Returns non-zero, leaving the existing copies
  untouched, when the clone fails or yields no skill. Always removes the
  stage. Nothing else from upstream is kept (`setup`, `scripts/`, plugin
  manifests, `.git`).
- `higgsfield_signed_in`: `timeout 15 higgsfield auth token </dev/null
  >/dev/null 2>&1`. The CLI is closed source, so the call is bounded and its
  output never reaches a terminal or a log.

Depends on: `git`, `mktemp`, `timeout`. No dependency on the repo's other
libs.

### `install-plugins.sh`: Step 8.6, between 8.5 and 8.7

1. CLI: present → `ok`. Absent → `npm install -g @higgsfield/cli` (or the
   pinned version from `plugins.lock.json`), then `higgsfield version` as
   the proof; failure prints the manual command, including the
   `--allow-scripts=@higgsfield/cli` form, since the package vendors its
   binary in a postinstall script that newer npm versions may hold back.
2. Skills: only when the CLI is present, `higgsfield_sync_skills "$REPO"`.
   A failed refresh with an existing copy is an `ok` (copy kept); with no
   copy, a `warn` naming the manual command.
3. Sign-in: signed in → `ok`. Otherwise, stdin is a terminal → offer
   `higgsfield auth login` (default no). Else an `info` line with the
   command.
4. Nothing is linked. The summary block lists the pack and both toggles.

Step 8.6 runs before the `apply_effort_pins` call of Step 8.7, so the
"pins after the last vendoring step" order holds (BDR-108).

The ctx7 (Step 6) and 21st (Step 8.7) login offers change from
`[ -t 0 ] && [ -t 1 ]` to `[ -t 0 ]`.

### `update-all.sh`: block before 7.4

CLI absent → `info`, skip. Else `npm install -g` the lock version, then
`higgsfield_sync_skills "$REPO"`. A parked skill is a symlink in
`skills-disabled/` pointing at `skills-external/<name>`: replacing the
source keeps the parked state.

### `lib/toggle-external.sh`

- `MANAGED_TOOLS` gains `higgsfield` and `higgsfield-websites`.
- `higgsfield_skills()`: the `skills-external/higgsfield-*/` directories
  holding a `SKILL.md`, minus `higgsfield-websites`.
- The three pack arms (status, disable, enable) serve `21st|higgsfield`
  through `pack_skills <tool>`, which dispatches to the right enumerator.
  Messages use the tool name. Status is `enabled` when any member is linked.
- After enabling a pack, a per-tool hint warns (never blocks) when the CLI
  is missing or signed out. For Higgsfield the probe is inlined: this script
  takes no new `source` (four fixture suites copy it).
- `higgsfield-websites` joins the single-symlink arm, source
  `skills-external/higgsfield-websites`.
- Header: two tool lines after `21st`; `usage()` prints two more lines.

### `doctor.sh`: section 4

CLI present → `pass` with its version; absent → `info` with the install
command. When present: signed in → `pass`, else `info` naming
`higgsfield auth login`. Never `warn`, never `fail`.

### Config and docs

- `plugins.lock.json`: `higgsfield` entry (source, version, note naming the
  skills repo and the toggles; no `managed_by`).
- `.gitignore`: `skills/higgsfield-*` and `skills-external/higgsfield-*/`.
- `CLAUDE.global.md`, Skill routing, 8 lines (306 → 314, guard 320):

  ```
  - Media generation (image, video, audio, brand kit), explicit ask →
    Higgsfield pack, off by default: `bash ~/.claude/lib/toggle-external.sh
    enable higgsfield`, then its skill (not listed yet → Read its SKILL.md
    under `~/.claude/skills/`). Metered: `higgsfield generate cost` before
    a paid run. Landing page "with Higgsfield", named ask only → `enable
    higgsfield-websites` as an aid (assets, references) inside the Design
    work stack and the site rules above; never `higgsfield website
    create|deploy|publish`.
  ```
- `README.md`: `### Higgsfield CLI` after the 21st section.
- `CHANGELOG.md`: one `### Added` bullet under `[Unreleased]`.

## Not changed, on purpose

`link.sh`, `lib/profile.sh`, every `lib/profiles/*.profile`,
`lib/effort-pins.txt`, hooks. Listing the pack in any of them would either
re-enable it on every `make link` or pull it into the profile census.

## Error handling

| Case | Behaviour |
|---|---|
| npm install fails or the binary is not vendored | `err` with the manual command; the step goes on, skills skipped |
| clone fails, copy exists | copy kept, `ok` |
| clone fails, no copy | `warn` with the manual command |
| upstream layout changes (no `higgsfield-*/SKILL.md`) | sync returns non-zero, copies kept, `warn` |
| toggle enabled, CLI missing or signed out | links created, `warn` |
| `enable` with no source | `err` naming the path checked, rc 1 |

## Tests: `lib/tests/higgsfield.test.sh`

Hermetic: a mktemp repo holding copies of `toggle-external.sh`,
`gstack-removed.sh` and `higgsfield-skills.sh`; a local git repo as the
skills source; a fake `higgsfield` first on PATH, switchable between signed
in and signed out.

Named cases (the contract's oracle greps them): `SYNC_MOVES_PACK_ONLY`,
`SYNC_REFRESH_DROPS_STALE`, `SYNC_KEEPS_PARKED`, `SYNC_FAIL_KEEPS_COPY`,
`ENABLE_PACK_EXCLUDES_WEBSITES`, `ENABLE_WEBSITES_ALONE`, `DISABLE_PARKS`,
`STATUS_STATES`, `SIGNED_OUT_WARNS`. Plus static locks on the two installers:
the sync call sits before the last `apply_effort_pins`, and no `-t 1` test
remains in `install-plugins.sh`.

## Known limits

- Upstream prompts change with no diff to review (same trade-off as 21st).
- Each upstream skill reinstalls the CLI through `curl | sh` when
  `higgsfield` is off PATH. With the CLI installed by npm this never fires.
- `higgsfield auth token` locality is unverified.
