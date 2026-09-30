# Higgsfield pack: design

Date: 2026-09-30. Contract: `.claude/tasks/contracts/2026-09-30-higgsfield-pack-1412.md`
(binding: request, clarifications, 14 acceptance criteria).
Revision 2, after the three-lens plan challenge: changes marked `[r2]`.

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
  not from `npx skills add`, which re-links every skill on each refresh.
- CLI `@higgsfield/cli` at `latest` (21st precedent).
- Routing lines in `CLAUDE.global.md`: explicit ask → enable the toggle →
  follow the skill.
- The two dead login offers already in `install-plugins.sh` (ctx7, 21st) are
  fixed here: they test stdout, which is the `tee` pipe.
- `settings.json` denies the `npm i -g` aliases (done by hand, outside the
  installer).

## Units

### `lib/higgsfield-skills.sh` (new, sourced)

Owns everything the installers and the doctor share.

- `HIGGSFIELD_SKILLS_URL`: defaults to
  `https://github.com/higgsfield-ai/skills.git`; an env value wins (tests
  point it at a local fixture repo).
- `higgsfield_sync_skills <repo>`: `git clone --depth 1` into a stage
  created inside `<repo>/skills-external/` `[r2]`, so each replacement is a
  rename on one filesystem. Every real `higgsfield-*/` directory of the
  clone that holds a `SKILL.md` replaces `<repo>/skills-external/<name>`;
  symlinked entries are skipped `[r2]`; a skill counts only once its move
  succeeded `[r2]`. Prints the number of skills synced. Returns non-zero,
  leaving the existing copies untouched, when the clone fails or yields no
  skill. The clone never prompts for credentials `[r2]`. Always removes the
  stage. Nothing else from upstream is kept (`setup`, `scripts/`, plugin
  manifests, `.git`).
- `higgsfield_cli_ok` `[r2]`: the binary answers (`higgsfield version`).
  `command -v` alone only proves the npm shim: the binary is vendored by a
  postinstall script that npm may hold back, on a first install or on any
  later update.
- `higgsfield_signed_in`: `higgsfield auth token` succeeds.
- Both probes run silently and for 15 s at most. The CLI is closed source,
  so its output never reaches a terminal or a log.

Depends on: `git`, `mktemp`, optionally `timeout`. No dependency on the
repo's other libs.

### `install-plugins.sh`: Step 8.6, between 8.5 and 8.7

1. CLI: `higgsfield_cli_ok` → `ok`. Otherwise `npm install -g` the lock
   version, then the probe again as the proof; failure prints the manual
   command with `--allow-scripts=@higgsfield/cli`.
2. Skills: only when the CLI answers, `higgsfield_sync_skills "$REPO"`. A
   failed sync is one `warn` (existing copies kept) `[r2]`.
3. Sign-in: signed in → `ok`. Otherwise, stdin is a terminal → offer
   `higgsfield auth login` (default no). Else an `info` line with the
   command.
4. Nothing is linked. The summary block lists the pack and both toggles.

Step 8.6 runs before the `apply_effort_pins` call of Step 8.7, so the
"pins after the last vendoring step" order holds (BDR-108).

The ctx7 (Step 6) and 21st (Step 8.7) login offers change from
`[ -t 0 ] && [ -t 1 ]` to `[ -t 0 ]`.

### `update-all.sh`: block before 7.4

CLI absent → `info`, skip. Else `npm install -g` the lock version, then the
probe: a shim left without its binary gets a `warn` with the remedy, never a
success line `[r2]`. Then `higgsfield_sync_skills "$REPO"`. A parked skill is
a symlink in `skills-disabled/` pointing at `skills-external/<name>`:
replacing the source keeps the parked state.

### `lib/toggle-external.sh`

- `MANAGED_TOOLS` gains `higgsfield` and `higgsfield-websites`.
- `HIGGSFIELD_MEDIA_SKILLS` `[r2]`: the seven media skill names, an explicit
  allowlist. Upstream is unpinned, so a skill it adds or renames is never
  linked without an edit here (default deny).
- `higgsfield_skills()`: the allowlisted names synced under
  `skills-external/`. `higgsfield_unlisted()` `[r2]`: synced `higgsfield-*`
  skills that no tool owns.
- The three pack arms (status, disable, enable) serve `21st|higgsfield`
  through `pack_skills <tool>`. Messages use the tool name. Status is
  `enabled` when any member is linked.
- `pack_hints <tool>`, after a pack enable and after
  `enable higgsfield-websites` `[r2]`: warns (never blocks) when the CLI is
  missing, does not answer, or is signed out, and names each unlisted
  skill. Its probes go through `bounded`, a local twin of the helper's
  probe `[r2]`: this script takes no new `source` (four fixture suites copy
  it alone).
- `higgsfield-websites` joins the single-symlink arm, source
  `skills-external/higgsfield-websites`.
- Header: two tool lines after `21st`; `usage()` prints them.

### `doctor.sh`: section 4

CLI answers → `pass` with its version, then signed in → `pass`, else `info`
naming `higgsfield auth login`. Shim on PATH without its binary → `info`
with the remedy `[r2]`. Absent → `info`. Never `warn`, never `fail`.

### Config and docs

- `plugins.lock.json`: `higgsfield` entry (source, version, note naming the
  skills repo and the toggles; no `managed_by`).
- `.gitignore`: `skills/higgsfield-*`, `skills-external/higgsfield-*/` and
  the sync stage `skills-external/.higgsfield-stage.*/` `[r2]`.
- `CLAUDE.global.md`, Skill routing, 6 lines `[r2]` (306 → 312, guard 320):

  ```
  - Media generation (image, video, audio, brand kit), explicit ask →
    Higgsfield pack, off by default: `bash ~/.claude/lib/toggle-external.sh
    enable higgsfield`, then Read the skill under `~/.claude/skills/`;
    `higgsfield generate cost` before a paid run. Landing page "with
    Higgsfield", named ask → `enable higgsfield-websites`: an aid inside
    Design work and the site rules, never `website create|deploy|publish`.
  ```
- `README.md`: `### Higgsfield CLI` after the 21st section.
- `CHANGELOG.md`: `[Unreleased]` bullets under Added, Security, Fixed.

## Not changed, on purpose

`link.sh`, `lib/profile.sh`, every `lib/profiles/*.profile`,
`lib/effort-pins.txt`, hooks. Listing the pack in any of them would either
re-enable it on every `make link` or pull it into the profile census.

## Error handling

| Case | Behaviour |
|---|---|
| npm install fails, or the binary is not vendored | `err` with the `--allow-scripts` command; the step goes on, skills skipped |
| an update leaves the shim without its binary | `warn` with the remedy; doctor says so at info level; the toggle names that cause |
| clone fails, or upstream holds no skill | copies kept, one `warn` |
| upstream adds or renames a skill | synced, reported by the toggle, not linked |
| toggle enabled, CLI missing, mute or signed out | links created, `warn` |
| `enable` with no source | `err` naming the path checked, rc 1 |

## Tests: `lib/tests/higgsfield.test.sh`

Hermetic: a mktemp repo holding copies of `toggle-external.sh` and
`gstack-removed.sh`; a local git repo as the skills source; fake
`higgsfield` and `21st` first on PATH; a clean PATH built from symlinks for
the no-CLI cases, so the suite behaves the same whatever is installed.

Named cases (the contract's oracle greps them): `SYNC_MOVES_PACK_ONLY`,
`SYNC_REFRESH_DROPS_STALE`, `SYNC_KEEPS_PARKED`, `SYNC_FAIL_KEEPS_COPY`,
`PROBES_SILENT`, `STATUS_STATES`, `ENABLE_PACK_EXCLUDES_WEBSITES`,
`UNLISTED_NOT_LINKED`, `ENABLE_WEBSITES_ALONE`, `DISABLE_PARKS`,
`SIGNED_OUT_WARNS`, `ENABLE_MISSING_ERRS`, `PACK_21ST_UNCHANGED`,
`OFF_BY_DEFAULT_WIRING`, `INSTALL_WIRING`, `UPDATE_WIRING`.

## Known limits

- Upstream prompts change with no diff to review (same trade-off as 21st).
- A skill that upstream removes or renames keeps its last local copy.
- Each upstream skill reinstalls the CLI through `curl | sh` when
  `higgsfield` is off PATH. With the CLI installed by npm this never fires,
  and the deny rule on `* | sh` blocks it anyway.
- `higgsfield auth token` locality is unverified, hence the 15 s bound.
