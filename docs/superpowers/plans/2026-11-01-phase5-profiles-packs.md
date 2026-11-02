# Phase 5 Profiles and Packs Implementation Plan (r2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

r2 2026-11-02 after three lenses (correctness FATAL(11), robustness FATAL(10), simplicity CONCERNS(5)). The r1 BLOCKER: r1 was written against a tree in profile `full`; the live tree is in profile `backend` (`.active-profile` written 2026-11-01 21:34, after the survey). Every removal list is now derived at run time, nothing real is ever deleted, impeccable is moved from wherever it sits. § Challenge summary at the end names each finding and its change.

**Goal:** Replace the global symlink profile system with skills-dir packs switched per project (`.claude/settings.local.json`) and per conversation (`claude --settings lib/profiles/<n>.json`), and delete the old mechanism.

**Architecture:** Nine packs `skills/pack-<n>/` (manifest + tracked relative symlinks into `skills-external/`, four real skill dirs moved in). Nine profiles `lib/profiles/<n>.json` are literal settings fragments. `lib/profile.sh` (bash) merges a fragment into the project's local settings; `lib/profile-state.jq` computes the effective state in ONE jq pass; `lib/cc.sh` launches a conversation with a fragment as `--settings`; gates, hooks and doctor read `profile.sh current --plain`.

**Tech Stack:** bash 5, jq 1.8, python3 (existing census only), Claude Code CLI 2.1.316, `make test` suites `lib/tests/*.test.sh`.

**Spec:** `docs/superpowers/specs/2026-11-01-phase5-profiles-packs-design.md`. Contract: `.claude/tasks/contracts/2026-11-01-phase5-profiles-packs-1300.md` (CLARIFICATIONS hold the measured facts and the user's answers). Facts: § Facts below; Tasks 1 and 12 append theirs there.

## Global Constraints

- Branch `feature/phase5-profiles-packs`. `gitflow finish` only on the user's signal. Stage files by name, never `git add -A`. `settings.json` is committed ONLY in Task 13 and only through the index recipe there; never `git checkout -- settings.json`, never `git stash pop`, never `git add -p` (interactive).
- **No worktree.** The live checkout `/home/bchanot/Documents/claude` IS `~/.claude` (symlinks); the packs must land where Claude Code reads them. When subagent-driven-development offers a worktree, decline.
- **Live state at start (verify in Task 2 Step 0, never assume):** `.active-profile` = `backend`; `skills-disabled/` holds ~54 entries, among them `impeccable/` as a REAL 23 MB dir (the only installed copy) and ~30 `gstack__*` links; `skills/` holds ~20 flat symlinks; the working `settings.json` carries `ui-ux-pro-max@ui-ux-pro-max-skill: false` (user-scope residue of the old `claude plugin disable`, tracked value `true`) plus UI writes `theme`, `switchModelsOnFlag`.
- Deletions: symlinks only, enumerated by `find … -maxdepth 1 -type l` and then removed by name; a real directory is moved or left, never `rm -r`. `rm -rf` appears once (Task 9, installer) on the literal path `skills-external/impeccable`.
- Scratch dir: `$HOME/.cache/claude-tmp/p5`, written literally in EVERY Bash call that needs it (shell state does not survive between calls; `$CLAUDE_SCRATCHPAD` is not set in the Bash tool).
- Suites and the Makefile `test` recipe `unset CLAUDE_PROFILE CLAUDE_PROFILE_SETTINGS` first: a `cc <name> <profile>` conversation exports them and the Bash tool inherits them.
- Nothing writes the user scope: no `claude plugin enable|disable`, no script edit of `~/.claude/settings.json`. The one exception is the residue restore in Task 2 Step 7 (a working-tree restore of a tracked value, not a commit).
- Shell: `shellcheck` clean, 80 columns, ≤25 logic lines per function. Rules changed → every citer patched in the same commit.
- Ids: packs `pack-<n>@skills-dir` (manifest `name` = folder); managed plugins `model-router@skills-dir`, `ui-ux-pro-max@ui-ux-pro-max-skill`, `security-guidance@claude-code-plugins`, `pr-review-toolkit@claude-code-plugins`, `example-skills@anthropic-agent-skills`, `brightdata-plugin@synced`. Connectors `claude.ai higgsfield`, `claude.ai Higgsfield AI`.
- Tasks 2, 3 and 4 commit TOGETHER at the end of Task 4 (commit C1): between the pack creation and the retirement of `lib/toggle-external.sh` / old `lib/profile.sh`, no code that re-creates flat links may remain in `~/.claude`. Run no design work in another conversation until Task 6 lands.
- `skills/gstack/` (helper tree without SKILL.md, `lib/gstack-links.sh`) stays, outside the packs. The core flat links that stay in `skills/`: `model-router` (the TRACKED link to `../mods/model-router`, which loads `model-router@skills-dir`), `darwin-skill`, `brainstorming`, `writing-plans`, `subagent-driven-development`, `test-driven-development`, `requesting-code-review`, `using-git-worktrees`, `writing-skills`, `ci-cd-and-automation`, `deprecation-and-migration`, `observability-and-instrumentation`.

## Review Focus

1. `deniedMcpServers` is a UNION across settings files: `cc x web` over a project set to `dev` keeps the higgsfield connectors denied; `current` prints `custom`. Pinned by Task 3 T7-union; said in `/profile` and USAGE.
2. A fragment naming a pack with no `skills/pack-<n>/`: `set` writes it, the CLI ignores it. Pinned by Task 3 T2-show-missing and T16.
3. A dangling pack symlink must not hide the pack's other skills. Task 1 C3 measures it; the census reports dangling targets (WARN in `make test`, RED in doctor for an ON pack).
4. Keys `profile.sh` does not manage (`permissions`, a `/model` write) survive `set`/`unset`. Pinned by Task 3 T4-keep-perm, T4-keep-model, T12-unset-perm.
5. The statusline and the banner call `profile.sh current --plain` on every refresh: a failing or missing `profile.sh`, a project with no `.claude/`, an unreadable `~/.claude.json`, or a cwd inside a subdirectory must give one line, fast. Pinned by Task 3 T14 (unknown), T19 (walk-up), T20 (timing ≤ 100 ms, spec target 50 ms recorded in Task 12) and Task 8 statusline T4/T5.

## Facts (measured 2026-11-01, CLI 2.1.316, headless)

**Common method.** Every spike ran in a scratch project under `$HOME/.cache/claude-tmp/p5/` (`git init -q`, a `CLAUDE.md`, canary skills that reply a fixed token), in FRESH headless sessions, one per probe. Command shape: `claude -p '<prompt>' --model haiku --output-format stream-json --verbose`, then read the first `type=system subtype=init` message: `plugins[]`, `skills[]`, `tools[]`, `mcp_servers[]`. Multi-turn probes add `--input-format stream-json` (one JSON user message per line on stdin). Settings variants: `--settings <json or file>` (per conversation) and edits of the scratch project's `.claude/settings.local.json` (per project). Spike 4 also used `claude mcp list`.

**CHANGED since 2026-10-25: claude.ai connectors now load under `-p` (they did not on 2026-10-25).** The earlier "interactive only" fact is void.

- **Spike 1, nested skills in a pack.** Method: a skills-dir pack `~/.claude/skills/<pack>/` with `.claude-plugin/plugin.json` and `skills/<s>/SKILL.md` canaries; fresh `-p` session, read init `plugins[]` and `skills[]`, then invoke `Skill(<s>)`, `Skill(<pack>:<s>)`, typed `/<s>` and `/<pack>:<s>`. Result: the dir loads as plugin `<name>@skills-dir`; nested skills are listed ONCE as `<pack>:<s>`; all four invocations resolve.
- **Spike 1b, default state.** Method: same pack, `enabledPlugins` absent everywhere, then with `"defaultEnabled": false` in the manifest; then `.claude/settings.local.json` true/false and `--settings` true/false, init `plugins[]` read each time. Result: absent from every `enabledPlugins` means ON unless the manifest says `defaultEnabled:false` (then OFF with nothing written; local or `--settings` true turns it on). Local true/false is obeyed; `--settings` false beats local true.
- **Spike 1c, typed short slash.** Method: `-p '/<s>'` on a pack skill with canary reply. Result: the typed short `/<skill>` on a pack skill expands like `/<pack>:<skill>`.
- **Spike 2, `/reload-plugins` mid-session.** Method: two-turn session (`--input-format stream-json`): turn 1 a canary prompt, a `.claude/settings.local.json` edit between turns, turn 2 `/reload-plugins` then the canary again. Result: `/reload-plugins` works in `-p` and reloads a pack's skills + hooks after a local edit; a pack `.mcp.json` server needs a new session.
- **Spike 2b, reload under `--settings`.** Method: same two-turn session launched with `--settings <flag file>` setting a pack false, local edit true, `/reload-plugins`. Result: the flag value is read once; `/reload-plugins` re-reads neither the flag file nor a local true over a flag false, so a pack OFF by flag only comes back through a relaunch.
- **Spike 3, claude.ai connectors per project (F0-F5).** Method: fresh `-p` sessions in the scratch project, init `mcp_servers[]` and `tools[]` counted per run. F0 baseline: connectors listed. F1 `.claude/settings.local.json` `deniedMcpServers:[{serverName:"claude.ai <Name>"}]` for Gmail + Higgsfield AI: 199 -> 192 tools. F2 `disableClaudeAiConnectors:true`: all nine dropped, 26 tools, model-router kept. F3 `deniedMcpServers` via `--settings`: the same two connectors dropped per conversation. F4 `disableClaudeAiConnectors:true` via `--settings`: all nine dropped per conversation. F5 `deniedMcpServers` with a `serverUrl` wildcard: matches no connector (no URL exposed). Earlier runs E1-E5 (not levers): `disabledMcpjsonServers`, `enableAllProjectMcpServers:false` + `enabledMcpjsonServers:[]`, a synced plugin true leave the nine connectors; E4 `--strict-mcp-config` drops the connectors and the project `.mcp.json` servers per conversation (199 -> 26 tools). `disableClaudeAiConnectors` is any-source-true. The native `/mcp` toggle writes `disabledMcpServers` per project into `~/.claude.json` (untested, interactive only). Docs, not measured: `/reload-plugins` re-reads `enabledPlugins` from every settings file; `--plugin-dir` loads a pack as `<name>@inline` for one session; the skills-dir id is the manifest `name`.
- **Spike 4, higgsfield MCP in a pack `.mcp.json`.** Method: a canary pack `spike-pack` whose `.mcp.json` is `{"mcpServers":{"spike-hf":{"type":"http","url":"https://mcp.higgsfield.ai/mcp"}}}`; fresh `-p` session reading init `mcp_servers[]`, and `claude mcp list` in the scratch project. Result: the server is registered as `plugin:<pack>:<server>` and `claude mcp list` shows "Needs authentication"; while unauthenticated it is absent from the init `mcp_servers`; the OAuth login is interactive (`/mcp`). Today higgsfield = two claude.ai connectors (`claude.ai higgsfield`, `claude.ai Higgsfield AI`), so a pack server would duplicate their tools.
- Connectors, summary: `deniedMcpServers:[{serverName:"claude.ai <Name>"}]` drops the named ones (199 -> 192 tools); `disableClaudeAiConnectors:true` drops all nine (26 tools), any-source-true. Both work via `--settings`. `--strict-mcp-config` drops connectors and project `.mcp.json` servers.
- model-router (`mods/model-router/hooks/register.ts`): `skillRow` matches `e.skill` by EXACT key in `routing.json` `skills`; `typedSkill` takes the text after `/` up to a space, so a typed `/pack-seo:seo` yields the key `pack-seo:seo` whatever the Skill tool reports. `/route show` prints `main: skill <phase> …`, never the skill name. Consequence: long-name rows are added unconditionally (Task 10); no router canary.
- The Bash tool sets neither `CLAUDE_PROJECT_DIR` nor `CLAUDE_SCRATCHPAD`; its cwd persists across calls, so `profile.sh` resolves the project root by walking up.
- 34 bare `jq -n 1` spawns = 118-137 ms on this machine: `current` must be one or two jq calls.
- FACT-DANGLING = kept (Task 1, 2026-11-02, headless haiku, pack-t1 OFF by manifest + `--settings` true): init listed `pack-t1:t1-alpha` (real dir) and `pack-t1:t1-beta` (symlink) next to the dangling `t1-gamma`; a dangling entry hides nothing. The census keeps WARN for a dangling target in `make test`, RED only with `--installed` on an ON pack. Run by the main loop (the implementer's compound call was denied by the permission rules; cleanup by `mv skills/pack-t1 <scratch>` instead of the `rm -f` trap).
- Task 12 proof (2026-11-02): same project, `--settings` dev -> `pack-gstack-dev`, 41 tools, 0 higgsfield; web -> the six web packs, 199 tools, both connectors `connected`, 158 higgsfield tools listed in init. The stderr line "claude.ai MCP servers blocked by enterprise policy: claude.ai higgsfield, claude.ai Higgsfield AI" appeared on the DENY profiles (dev, qa, seo, minimal): that is `deniedMcpServers` doing its job, not a fault of `web`. Local profiles: qa -> `pack-gstack-browser pack-web-validate`; seo -> `pack-gstack-browser pack-gstack-dev pack-seo pack-web-validate`; both 41 tools, 0 higgsfield. Reload canary, ONE flagless session (`claude -p --model haiku --max-turns 1 --tools "" --input-format stream-json --output-format stream-json --verbose`, stdin from a `coproc`, session id `ee65507c-a958-411b-9580-8aca8105e326` on all four result lines): turn 1 `/seo` on profile minimal -> not available (the model said `/seo` isn't available in this session; no literal "Unknown skill" string under `--max-turns 1`); `profile.sh enable seo` with the session open; turn 2 `/reload-plugins` -> "Reloaded: 3 plugins · 2 skills · 32 agents · 7 hooks · 0 plugin LSP servers"; turn 3 `/seo …` and turn 4 `/pack-seo:seo …` -> both "# /seo — parallel SEO + GEO dispatcher". `--tools ""` did not break `/reload-plugins`. Log: `$HOME/.cache/claude-tmp/p5/t12/reload-one-session.jsonl`. `current --plain` median 30 ms over 5 runs (target 50).

## File Structure

| Path | Responsibility |
|---|---|
| `skills/pack-<n>/.claude-plugin/plugin.json` (9) | pack identity + `defaultEnabled` |
| `skills/pack-<n>/skills/<s>` | tracked relative symlink, or the moved real dir (seo, geo, web-validate, site-motion) |
| `lib/profiles/<n>.json` (9) + `README.md` | fragments + descriptions; `*.profile` deleted |
| `lib/profile.sh` (rewrite) + `lib/profile-state.jq` (new) | CLI verbs; one jq program for the effective state |
| `lib/cc.sh` (new) | `cc <name> [profile]` |
| `lib/pack-census.sh` (new) | pack layout + fragment invariants + old-layout citers; `make test` and doctor |
| `lib/gstack-removed.list` (new) | the nine retired gstack skills, single source; `lib/gstack-removed.sh` reduced to a header + `mapfile` |
| `lib/design-tool-gate.sh` (rewrite core) | reads `current --plain`; keeps the 21st probe |
| `lib/tests/{profile,cc,pack-census,design-tool-gate,statusline}.test.sh` | hermetic suites |
| `hooks/session-start.sh`, `hooks/statusline.sh`, `lib/detect-plugins.sh`, `doctor.sh`, `lib/doctor-vendored.sh`, `lib/doctor-skills.sh`, `link.sh`, `Makefile`, `.gitignore` | consumers |
| `lib/plugin-gate.md`, `lib/design-gate.md`, `agents/plugin-probe.md`, `agents/plugin-advisor.md`, `skills/profile/SKILL.md`, `skills/onboard/SKILL.md`, `skills/plugin-check/SKILL.md` | prose consumers |
| `install-plugins.sh`, `update-all.sh`, `lib/higgsfield-skills.sh`, `plugins.lock.json` | installers write `skills-external/` only |
| `lib/skill-routing-census.py`, `mods/model-router/routing.json`, `lib/tests/effort-routing.test.sh` | pack glob; long-name rows; row → skill check |
| docs, `settings.json` `env` (last) | |

---

### Task 1: Dangling-symlink canary (no repo change)

**Files:** scratch only: `$HOME/.cache/claude-tmp/p5/t1/`; result into § Facts.

**Produces:** FACT-DANGLING = `kept` | `hidden`.

- [ ] **Step 1: Build an OFF canary pack and a scratch project, with a cleanup trap in the same call**

```bash
S="$HOME/.cache/claude-tmp/p5"; mkdir -p "$S/t1/proj" "$S/t1/ext-beta"
cd /home/bchanot/Documents/claude
cleanup() { rm -f skills/pack-t1/skills/t1-beta skills/pack-t1/skills/t1-gamma skills/pack-t1/skills/t1-alpha/SKILL.md skills/pack-t1/.claude-plugin/plugin.json
  rmdir skills/pack-t1/skills/t1-alpha skills/pack-t1/skills skills/pack-t1/.claude-plugin skills/pack-t1 2>/dev/null; }
trap cleanup EXIT
mkdir -p skills/pack-t1/.claude-plugin skills/pack-t1/skills/t1-alpha
printf '{"name":"pack-t1","version":"0.0.1","description":"canary","defaultEnabled":false}\n' > skills/pack-t1/.claude-plugin/plugin.json
printf -- '---\nname: t1-alpha\ndescription: canary alpha\n---\nReply exactly T1-ALPHA-OK.\n' > skills/pack-t1/skills/t1-alpha/SKILL.md
printf -- '---\nname: t1-beta\ndescription: canary beta\n---\nReply exactly T1-BETA-OK.\n' > "$S/t1/ext-beta/SKILL.md"
ln -s "$S/t1/ext-beta" skills/pack-t1/skills/t1-beta
ln -s /nonexistent/t1-gamma skills/pack-t1/skills/t1-gamma
printf '{"enabledPlugins":{"pack-t1@skills-dir":true}}\n' > "$S/t1/on.json"
cd "$S/t1/proj" && git init -q && printf '# t1\n' > CLAUDE.md
claude -p 'say hi' --model haiku --settings "$S/t1/on.json" --output-format stream-json --verbose 2>"$S/t1/c3.err" | head -1 > "$S/t1/c3.jsonl"
python3 -I -c '
import json,sys; d=json.loads(open(sys.argv[1]).readline())
sk=sorted(s for s in d["skills"] if s.startswith("pack-t1:")); print("SKILLS", sk)
print("FACT-DANGLING", "kept" if sk == ["pack-t1:t1-alpha","pack-t1:t1-beta"] else "hidden")' "$S/t1/c3.jsonl"
```

The pack is OFF by manifest and ON only through `--settings`, so no concurrent conversation sees it; the trap removes it even when the canary aborts. Expected: `FACT-DANGLING kept`. `hidden` → Task 2's census treats a dangling target on an ON pack as RED in `make test` too, and MIGRATION says "run `make plugin` before `make test`".

- [ ] **Step 2: Record** the FACT line in this plan's § Facts and in `$HOME/.cache/claude-tmp/p5/FACTS.md`. Verify `ls skills | grep -c pack-t1` prints 0. No commit.

---

### Task 2: Packs on disk, old layout removed, pack census (no commit: C1 lands at Task 4)

**Files:**
- Create: `skills/pack-{design,scroll3d,seo,web-validate,gstack-dev,gstack-browser,gstack-design,higgsfield,extras}/.claude-plugin/plugin.json`, the symlinks of Step 3, `lib/pack-census.sh`, `lib/pack-census-fragments.jq`, `lib/tests/pack-census.test.sh`, `lib/tests/fixtures/pack-census-old-citers.sh` (one line, exactly: `ls $HOME/.claude/skills/a2 skills-disabled/foo; bash lib/toggle-external.sh; cat .active-profile; lib/profiles/web.profile`), `lib/gstack-removed.list`
- `git mv`: `skills/{site-motion,seo,geo,web-validate}`
- Modify: `.gitignore` (by content anchors), the citers of Step 8
- Working tree only: flat symlinks, `skills-disabled/`, `.active-profile`, `settings.json` residue

**Produces:** `bash lib/pack-census.sh [--repo <dir>] [--installed]` → `RED …` / `WARN …` lines then `PACKS OK <p> packs <s> skills`; rc 1 on any RED. Without `--installed` a dangling target is WARN whatever the pack state (hermetic `make test`); with `--installed` (doctor) it is RED on an ON pack. Pack names `pack-<n>` for Tasks 3, 6.

- [ ] **Step 0: Snapshot and verify the live state**

```bash
cd /home/bchanot/Documents/claude && S="$HOME/.cache/claude-tmp/p5"; mkdir -p "$S"
find skills skills-disabled -maxdepth 1 \( -type l -o -type d \) -printf '%y %p %l\n' | sort > "$S/layout-before.txt"
cat .active-profile; wc -l < "$S/layout-before.txt"; grep -c '^d skills-disabled/' "$S/layout-before.txt"
ls -d skills/impeccable skills-disabled/impeccable skills-external/impeccable 2>&1
```

`layout-before.txt` is the rollback recipe: `ln -s <target> <path>` per `l` line, `mv skills-external/impeccable <its d line>`. Keep it until the merge. STOP if `skills-external/impeccable` exists AND one of the other two exists (two copies: ask the user which one wins).

- [ ] **Step 1: Write the failing census test**

`lib/tests/pack-census.test.sh`:

```bash
#!/usr/bin/env bash
# lib/tests/pack-census.test.sh — lib/pack-census.sh: pack layout (manifest
# name = folder, entries resolve, no skill twice, retired gstack names absent),
# fragment invariants (same key set, fixed values, deny set, full = manifest
# defaults), old-layout citers. Fixture cases, then the hermetic part of the
# census on the real repo (dangling targets are WARN without --installed).
set -u
unset CLAUDE_PROFILE CLAUDE_PROFILE_SETTINGS
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
check_has() { case "$2" in *"$3"*) pass=$((pass+1));; *) fail=$((fail+1));
  printf 'FAIL %s: [%s] does not contain [%s]\n' "$1" "$2" "$3";; esac; }

FX="$(mktemp -d)"; trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/lib/profiles" "$FX/hooks" "$FX/skills/core-a"; touch "$FX/skills/core-a/SKILL.md"
printf 'gs-dead\n' > "$FX/lib/gstack-removed.list"
mk_pack() { # name defaultEnabled skill...
  local n="$1" d="$2"; shift 2
  mkdir -p "$FX/skills/pack-$n/.claude-plugin" "$FX/skills/pack-$n/skills"
  printf '{"name":"pack-%s","version":"1.0.0","defaultEnabled":%s}\n' "$n" "$d" \
    > "$FX/skills/pack-$n/.claude-plugin/plugin.json"
  for s in "$@"; do mkdir -p "$FX/skills-external/$s"; touch "$FX/skills-external/$s/SKILL.md"
    ln -s "../../../skills-external/$s" "$FX/skills/pack-$n/skills/$s"; done
}
mk_pack alpha true a1 a2
mk_pack beta false b1
frag() { # name alpha beta deny(yes|no) — the two real connector names
  local d=""; [ "$4" = yes ] && d=', "deniedMcpServers": [{"serverName": "claude.ai higgsfield"}, {"serverName": "claude.ai Higgsfield AI"}]'
  printf '{"enabledPlugins": {"model-router@skills-dir": true, "pack-alpha@skills-dir": %s, "pack-beta@skills-dir": %s, "security-guidance@claude-code-plugins": true, "example-skills@anthropic-agent-skills": false, "brightdata-plugin@synced": false}%s}\n' \
    "$2" "$3" "$d" > "$FX/lib/profiles/$1.json"; }
frag full true false no; frag dev false false yes
census() { bash "$ROOT/lib/pack-census.sh" --repo "$FX" "$@" 2>&1; }

out="$(census)"; rc=$?
check T1-green-rc "$rc" 0; check_has T1-green "$out" "PACKS OK 2 packs 3 skills"

rm -r "$FX/skills-external/b1"
out="$(census)"; rc=$?
check T2-off-dangling-rc "$rc" 0; check_has T2-off-dangling "$out" "WARN pack-beta: b1 target missing"
rm -r "$FX/skills-external/a2"
out="$(census)"; rc=$?
check T3-on-dangling-test-rc "$rc" 0; check_has T3-on-dangling-test "$out" "WARN pack-alpha: a2 target missing"
out="$(census --installed)"; rc=$?
check T3-on-dangling-doctor-rc "$rc" 1; check_has T3-on-dangling-doctor "$out" "RED pack-alpha: a2 target missing (pack ON)"
mkdir -p "$FX/skills-external/a2" "$FX/skills-external/b1"; touch "$FX/skills-external/a2/SKILL.md" "$FX/skills-external/b1/SKILL.md"

sed -i.bak 's/"pack-alpha"/"pack-alpho"/' "$FX/skills/pack-alpha/.claude-plugin/plugin.json"
out="$(census)"; rc=$?
check T4-name-rc "$rc" 1; check_has T4-name "$out" "RED pack-alpha: manifest name is pack-alpho"
mv "$FX/skills/pack-alpha/.claude-plugin/plugin.json.bak" "$FX/skills/pack-alpha/.claude-plugin/plugin.json"

ln -s ../skills-external/a1 "$FX/skills/a1"
out="$(census)"; rc=$?
check T5-dup-rc "$rc" 1; check_has T5-dup "$out" "RED a1 listed twice: skills/a1 and pack-alpha — rm skills/a1 (a flat link)"
rm "$FX/skills/a1"

ln -s "../../../skills-external/a1" "$FX/skills/pack-alpha/skills/gs-dead"
out="$(census)"; rc=$?
check T6-retired-rc "$rc" 1; check_has T6-retired "$out" "RED pack-alpha: gs-dead is a retired gstack skill"
rm "$FX/skills/pack-alpha/skills/gs-dead"
mv "$FX/lib/gstack-removed.list" "$FX/lib/gstack-removed.list.off"
out="$(census)"; rc=$?
check T6-nolist-rc "$rc" 1; check_has T6-nolist "$out" "RED lib/gstack-removed.list missing"
mv "$FX/lib/gstack-removed.list.off" "$FX/lib/gstack-removed.list"

printf 'Read ~/.claude/skills/a1/SKILL.md\n' > "$FX/hooks/x.sh"
cp "$ROOT/lib/tests/fixtures/pack-census-old-citers.sh" "$FX/hooks/y.sh"   # the old-layout terms live in a fixture, not in this file (the census scans lib/tests/)
out="$(census)"; rc=$?
check T7-citer-rc "$rc" 1
check_has T7-citer-tilde "$out" "RED hooks/x.sh cites ~/.claude/skills/a1"
check_has T7-citer-home "$out" "RED hooks/y.sh cites \$HOME/.claude/skills/a2"
check_has T7-citer-disabled "$out" "RED hooks/y.sh cites skills-disabled/"
check_has T7-citer-toggle "$out" "RED hooks/y.sh cites toggle-external"
check_has T7-citer-active "$out" "RED hooks/y.sh cites .active-profile"
check_has T7-citer-profile "$out" "RED hooks/y.sh cites lib/profiles/web.profile"
rm "$FX/hooks/x.sh" "$FX/hooks/y.sh"

# fragment invariants
printf '{"enabledPlugins": {"model-router@skills-dir": true, "pack-alpha@skills-dir": true}}\n' > "$FX/lib/profiles/short.json"
out="$(census)"; rc=$?
check T8-keyset-rc "$rc" 1; check_has T8-keyset "$out" "RED lib/profiles/short.json: key set differs from full.json"
rm "$FX/lib/profiles/short.json"
frag full true true no
out="$(census)"; rc=$?
check T9-full-defaults-rc "$rc" 1; check_has T9-full-defaults "$out" "RED lib/profiles/full.json: pack-beta@skills-dir is true but the manifest default is false"
frag full true false no
sed -i.bak 's/"security-guidance@claude-code-plugins": true/"security-guidance@claude-code-plugins": false/' "$FX/lib/profiles/dev.json"
out="$(census)"; rc=$?
check T10-fixed-rc "$rc" 1; check_has T10-fixed "$out" "RED lib/profiles/dev.json: security-guidance@claude-code-plugins must be true"
mv "$FX/lib/profiles/dev.json.bak" "$FX/lib/profiles/dev.json"

# real repo, hermetic part
out="$(bash "$ROOT/lib/pack-census.sh" 2>&1)"; rc=$?
check T11-real-rc "$rc" 0; check_has T11-real "$out" "PACKS OK 9 packs 55 skills"
check T12-shellcheck "$(shellcheck "$ROOT/lib/pack-census.sh" >/dev/null 2>&1 && echo ok)" ok
check T12-width "$(LC_ALL=C awk 'length($0) > 80' "$ROOT/lib/pack-census.sh" | wc -l | tr -d ' ')" 0
printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
```

Run: `make test suite=lib/tests/pack-census.test.sh` → red (no census yet).

- [ ] **Step 2: Write `lib/pack-census.sh`**

```bash
#!/usr/bin/env bash
# shellcheck disable=SC2088  # the literal "~/.claude/skills" is a grep pattern
# ============================================================
# lib/pack-census.sh — census of the pack layout and its readers
#
# Packs are skills-dir plugins `skills/pack-<n>/` (manifest
# `.claude-plugin/plugin.json`, entries `skills/<s>` = tracked relative
# symlinks into skills-external/ or real dirs). Checks:
#   1. manifest parses, name = folder; every entry resolves (dangling =
#      WARN; RED with --installed on a pack ON by manifest); no skill both
#      flat and in a pack; no retired gstack name (lib/gstack-removed.list).
#   2. fragments lib/profiles/*.json: same key set as full.json; model-router
#      + security-guidance true, example-skills + brightdata false
#      everywhere; the two higgsfield connectors denied on exactly
#      DENY_PROFILES; full.json packs = manifest defaults.
#   3. no reader of the old layout left (scope and terms in check_citers).
# Shared by make test (lib/tests/pack-census.test.sh) and doctor.sh.
# Prints RED/WARN lines, then `PACKS OK <p> packs <s> skills` when no RED.
# Exit: 0 clean or WARN only · 1 any RED.
# Usage: pack-census.sh [--repo <dir>] [--installed]
# ============================================================
set -euo pipefail

REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLED=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --installed) INSTALLED=1; shift ;;
    *) echo "pack-census: unknown option $1" >&2; exit 2 ;;
  esac
done
SKILLS="$REPO/skills"
PROFILES="$REPO/lib/profiles"
REMOVED="$REPO/lib/gstack-removed.list"
DENY_PROFILES="audit backend dev minimal qa seo"   # spec § 2
red=0; packs=0; skills=0
declare -A seen
red() { echo "RED $*"; red=1; }

pack_on() { jq -e '.defaultEnabled != false' "$1/.claude-plugin/plugin.json" >/dev/null; }

check_manifest() { # $1 pack dir
  local n m name; n="$(basename "$1")"; m="$1/.claude-plugin/plugin.json"
  [ -f "$m" ] || { red "$n: no .claude-plugin/plugin.json"; return; }
  jq -e . "$m" >/dev/null 2>&1 || { red "$n: manifest is not JSON"; return; }
  name="$(jq -r '.name // ""' "$m")"
  [ "$name" = "$n" ] || red "$n: manifest name is $name"
}

check_entry() { # $1 pack dir, $2 entry path
  local n s; n="$(basename "$1")"; s="$(basename "$2")"
  if [ ! -e "$2/SKILL.md" ]; then
    if [ "$INSTALLED" = 1 ] && pack_on "$1"; then
      red "$n: $s target missing (pack ON)"
    else echo "WARN $n: $s target missing (installer not run)"; fi
  fi
  [ -f "$REMOVED" ] && grep -qx -- "$s" "$REMOVED" \
    && red "$n: $s is a retired gstack skill"
  if [ -n "${seen[$s]:-}" ]; then
    red "$s listed twice: ${seen[$s]} and $n — rm ${seen[$s]} (a flat link)"
  else seen[$s]="$n"; fi
  skills=$((skills+1))
}

check_fragments() {
  local files=("$PROFILES"/*.json) full="$PROFILES/full.json" out
  [ -f "$full" ] || { red "lib/profiles/full.json missing"; return; }
  out="$(jq -rn --arg deny "$DENY_PROFILES" --argjson m "$(manifests_json)" \
    -f "$FRAG_JQ" "${files[@]}")" \
    || { red "lib/profiles: a fragment is not JSON"; return; }
  [ -z "$out" ] || { echo "$out"; red=1; }
}

manifests_json() { # [{id, on}] for every pack manifest
  jq -cn '[inputs | {id: (.name + "@skills-dir"),
                     on: (.defaultEnabled != false)}]' \
    "$SKILLS"/pack-*/.claude-plugin/plugin.json 2>/dev/null || echo '[]'
}

# The old-layout terms are written with a bracketed last letter so this
# file never matches itself; the test's fixture strings live in
# lib/tests/fixtures/ (excluded) for the same reason.
check_citers() { # $@ pack skill names → one grep over the contract scope
  local args=(-e 'skills-disable[d]/' -e 'toggle-externa[l]'
    -e '\.active-profil[e]' -e 'lib/profiles/[a-z-]*\.profil[e]') n hit
  for n in "$@"; do
    args+=(-e "~/.claude/skills/$n\b" -e "\$HOME/.claude/skills/$n\b")
  done
  hit="$( { grep -rno --include='*.sh' --include='*.md' --include='*.py' \
      --include='*.json' --include='Makefile' "${args[@]}" "$REPO"/hooks \
      "$REPO"/lib "$REPO"/agents "$REPO"/skills "$REPO"/rules \
      "$REPO"/templates "$REPO"/mods "$REPO"/*.sh "$REPO"/CLAUDE.global.md \
      "$REPO"/README.md "$REPO"/USAGE.md "$REPO"/ARCHITECTURE.md \
      "$REPO"/Makefile "$REPO"/plugins.lock.json 2>/dev/null
      grep -nHo "${args[@]}" "$REPO"/.gitignore 2>/dev/null; } \
    | grep -v -e '/lib/tests/fixtures/' -e '/skills/pack-' \
      -e '/skills-external/' \
    | sed 's#:[0-9]*:#\t#' | sort -u || true)"
  [ -n "$hit" ] || return 0
  while IFS=$'\t' read -r f m; do
    red "${f#"$REPO"/} cites $m"
  done <<<"$hit"
}

main() {
  local d s p e names=()
  [ -f "$REMOVED" ] || red "lib/gstack-removed.list missing"
  for d in "$SKILLS"/*/; do
    d="${d%/}"; s="$(basename "$d")"
    case "$s" in pack-*) continue ;; esac
    [ -e "$d/SKILL.md" ] && seen[$s]="skills/$s"
  done
  for p in "$SKILLS"/pack-*/; do
    p="${p%/}"; packs=$((packs+1)); check_manifest "$p"
    for e in "$p"/skills/*; do
      [ -e "$e" ] || [ -L "$e" ] || continue
      check_entry "$p" "$e"; names+=("$(basename "$e")")
    done
  done
  check_fragments
  [ "${#names[@]}" -gt 0 ] && check_citers "${names[@]}"
  [ "$red" -eq 0 ] && echo "PACKS OK $packs packs $skills skills"
  exit "$red"
}
main
```

Two more lines near the top of the file, after `REMOVED=…`: `FRAG_JQ="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pack-census-fragments.jq"` (the program ships with the census, not with the `--repo` tree). And in `check_entry`, the retired check is guarded: `[ -f "$REMOVED" ] && grep -qx -- "$s" "$REMOVED" && red "$n: $s is a retired gstack skill"`. Every line ≤ 80 bytes (`LC_ALL=C awk 'length > 80'`), including the ones with `→` or `—`. `lib/pack-census-fragments.jq`:

```jq
# lib/pack-census-fragments.jq — fragment invariants (lib/pack-census.sh).
# $m = manifests [{id,on}], $deny = space-separated profiles that deny the
# two higgsfield connectors; inputs = lib/profiles/*.json. Prints RED lines.
def name_of: input_filename | sub(".*/"; "");
def dn: [(.deniedMcpServers // [])[] | .serverName] | sort;
[inputs | {f: name_of, frag: .}] as $all
| ($all[] | select(.f == "full.json") | .frag) as $full
| ($full.enabledPlugins | keys) as $keys
| ($deny | split(" ") | map(. + ".json")) as $deny_files
| ($m | map({key: .id, value: .on}) | from_entries) as $mdef
| $all[]
| .f as $f | .frag as $g
| ( if ($g.enabledPlugins | keys) != $keys
    then "RED lib/profiles/\($f): key set differs from full.json" else empty end ),
  ( ["model-router@skills-dir", "security-guidance@claude-code-plugins"][]
    | select($g.enabledPlugins[.] != true)
    | "RED lib/profiles/\($f): \(.) must be true" ),
  ( ["example-skills@anthropic-agent-skills", "brightdata-plugin@synced"][]
    | select($g.enabledPlugins[.] != false)
    | "RED lib/profiles/\($f): \(.) must be false" ),
  ( (["claude.ai higgsfield", "claude.ai Higgsfield AI"] | sort) as $both
    | if (($deny_files | index($f)) != null) and (($g | dn) != $both)
      then "RED lib/profiles/\($f): must deny both higgsfield connectors"
      elif (($deny_files | index($f)) == null) and (($g | dn) | length) > 0
      then "RED lib/profiles/\($f): must deny no connector" else empty end ),
  ( if $f == "full.json" then
      ($mdef | to_entries[] | select($g.enabledPlugins[.key] != .value)
       | "RED lib/profiles/full.json: \(.key) is \($g.enabledPlugins[.key])"
         + " but the manifest default is \(.value)")
    else empty end )
```

The fixture in the test uses connector `claude.ai X` only, so adjust the fixture's deny to the two real names (`frag` prints both `claude.ai higgsfield` and `claude.ai Higgsfield AI`); update the T-expectations accordingly when writing the test file. Until Task 3 writes the real fragments, `check_fragments` is RED on the real repo (`full.json missing`): expected, C1 is green only after Task 4.

- [ ] **Step 3: Build the packs and move the real skill dirs**

```bash
cd /home/bchanot/Documents/claude
mk() { mkdir -p "skills/pack-$1/.claude-plugin" "skills/pack-$1/skills"
  printf '{\n  "name": "pack-%s",\n  "version": "1.0.0",\n  "description": "%s",\n  "author": { "name": "bchanot" },\n  "defaultEnabled": %s\n}\n' "$1" "$2" "$3" > "skills/pack-$1/.claude-plugin/plugin.json"; }
mk design "Design and UI skills: impeccable, Emil design eng, frontend-design, motion, 21st build + CLI, site-motion." true
mk scroll3d "Scroll-driven and Three.js world skills (Mengto set)." true
mk seo "SEO and GEO audit skills." true
mk web-validate "W3C and WCAG conformance skill." true
mk gstack-dev "gstack engineering skills: review, investigate, codex, cso, health, freeze, retro, spec, skillify, office-hours, plan reviews, document-release." true
mk gstack-browser "gstack browser tooling: browse, scrape, qa, benchmark, canary." true
mk gstack-design "gstack design pipeline: design-review, design-consultation, design-html, plan-design-review." true
mk higgsfield "Higgsfield media generation skills (paid runs). OFF by default: profile.sh enable higgsfield." false
mk extras "Occasional skills: diagram, make-pdf, 21st-ai, 21st-ui-explore, 21st-ui-review. OFF by default." false
ext() { ln -s "../../../skills-external/$2" "skills/pack-$1/skills/$2"; }
gst() { ln -s "../../../skills-external/gstack/$2" "skills/pack-$1/skills/$2"; }
for s in impeccable emil-design-eng frontend-design design-motion-principles 21st-ui-build 21st-cli-use; do ext design "$s"; done
git mv skills/site-motion skills/pack-design/skills/site-motion
for s in scroll-world-storytelling build-threejs-scroll-worlds scroll-scrubbed-visual-sequence scroll-scrubbed-word-reveal scroll-progress-timeline; do ext scroll3d "$s"; done
git mv skills/seo skills/pack-seo/skills/seo; git mv skills/geo skills/pack-seo/skills/geo
git mv skills/web-validate skills/pack-web-validate/skills/web-validate
for s in review investigate codex cso health freeze unfreeze retro spec skillify office-hours plan-eng-review plan-ceo-review plan-devex-review document-release; do gst gstack-dev "$s"; done
for s in browse open-gstack-browser setup-browser-cookies scrape qa qa-only benchmark canary; do gst gstack-browser "$s"; done
for s in design-review design-consultation design-html plan-design-review; do gst gstack-design "$s"; done
for s in higgsfield-brandkit higgsfield-generate higgsfield-marketplace-cards higgsfield-product-photoshoot higgsfield-soul-id higgsfield-video-explainer higgsfield-websites higgsfield-youtube-thumbnail; do ext higgsfield "$s"; done
gst extras diagram; gst extras make-pdf
for s in 21st-ai 21st-ui-explore 21st-ui-review; do ext extras "$s"; done
bash -c '. lib/gstack-removed.sh; printf "%s\n" "${GSTACK_REMOVED[@]}"' > lib/gstack-removed.list
wc -l lib/gstack-removed.list   # 9
```

- [ ] **Step 4: Move impeccable from wherever it is**

```bash
cd /home/bchanot/Documents/claude
[ -e skills-external/impeccable ] && { echo "skills-external/impeccable already exists — STOP, ask"; exit 1; }
if [ -d skills-disabled/impeccable ]; then mv skills-disabled/impeccable skills-external/impeccable
elif [ -d skills/impeccable ]; then mv skills/impeccable skills-external/impeccable
else echo "no impeccable install found: pack-design:impeccable will dangle until make plugin"; fi
ls skills-external/impeccable/SKILL.md
```

- [ ] **Step 5: Remove the flat links and `skills-disabled/`, by enumeration**

```bash
cd /home/bchanot/Documents/claude
find skills -maxdepth 1 -type l | grep -v -x -e skills/model-router -e skills/darwin-skill -e skills/brainstorming -e skills/writing-plans -e skills/subagent-driven-development -e skills/test-driven-development -e skills/requesting-code-review -e skills/using-git-worktrees -e skills/writing-skills -e skills/ci-cd-and-automation -e skills/deprecation-and-migration -e skills/observability-and-instrumentation
```

Read the list: `skills/model-router` must NOT be in it (it is the tracked link that loads the router; `git ls-files -s skills/model-router` shows mode 120000). Every printed path is a symlink (`-type l`): remove them in ONE `rm` call whose arguments are the printed names typed out (no variable, no glob). Then:

```bash
find skills-disabled -maxdepth 1 -type l
```

Same: `rm` the printed names. Then `ls -A skills-disabled` must be empty; a remaining entry is a real dir → STOP and report it (never `rm -r`). Then `rmdir skills-disabled && rm .active-profile`.

- [ ] **Step 6: `.gitignore` by content anchors**

Delete every `skills/<x>` line between the comment `# GStack skill symlinks — auto-created by gstack setup` and the comment `# Impeccable — NOT a symlink` EXCEPT these, which stay (one block, with its two comment lines): `skills/gstack`, `skills/ci-cd-and-automation`, `skills/deprecation-and-migration`, `skills/observability-and-instrumentation`, `skills/brainstorming`, `skills/writing-plans`, `skills/subagent-driven-development`, `skills/test-driven-development`, `skills/requesting-code-review`, `skills/using-git-worktrees`, `skills/writing-skills`, `skills/darwin-skill`. The comments "iOS device-farm skills…", "External skill symlinks — auto-created by link.sh", "superpowers, vendored…" go; one comment replaces them: `# Core skills linked flat by link.sh (symlinks, machine-owned); the heavy groups live in skills/pack-*/ as tracked symlinks.` Replace the impeccable block (`# Impeccable — NOT a symlink…` through `skills/impeccable`) with:

```gitignore
# Impeccable — `impeccable skills install --scope=global` writes
# skills/impeccable/ through the ~/.claude/skills symlink; install-plugins.sh
# moves it to skills-external/impeccable (pack-design links it). Machine-owned.
skills/impeccable
skills-external/impeccable/
```

Keep `agents/impeccable-*.md` and its comment, and keep `.gstack/` (the line right below the `.active-profile` block). Delete the blocks headed `# 21st.dev skill pack symlinks` (through `skills/21st-*`) and `# Higgsfield skill pack symlinks` (through `skills/higgsfield-*`), the block `# Staging area used by lib/toggle-external.sh…` + `skills-disabled/`, and the block `# Profile cache…` + `.active-profile`. Keep every `skills-external/…` line.

- [ ] **Step 7: Restore the user-scope residue (working tree, not a commit)**

```bash
cd /home/bchanot/Documents/claude
git show HEAD:settings.json | jq '.enabledPlugins' > "$HOME/.cache/claude-tmp/p5/ep-head.json"
jq --slurpfile ep "$HOME/.cache/claude-tmp/p5/ep-head.json" '.enabledPlugins = $ep[0]' settings.json > "$HOME/.cache/claude-tmp/p5/settings.next.json"
test -s "$HOME/.cache/claude-tmp/p5/settings.next.json" && jq -e . "$HOME/.cache/claude-tmp/p5/settings.next.json" >/dev/null && cp "$HOME/.cache/claude-tmp/p5/settings.next.json" settings.json
git diff settings.json | grep '^[-+] ' | grep -v -e theme -e switchModelsOnFlag -e '^[-+]  *}' ; echo "(expected: nothing above)"
```

The old `claude plugin disable` wrote `ui-ux-pro-max: false` into the user scope; the manifest default `full` needs the tracked `true` back. Only `theme`/`switchModelsOnFlag` stay as uncommitted UI writes.

- [ ] **Step 8: Patch the citers of the moved and removed paths**

Tests: `lib/tests/seo-geo-contract.test.sh:16`, `lib/tests/model-routing.test.sh:13-14, 34, 169-176`, `lib/tests/effort-routing.test.sh:190, 192, 205`, `lib/tests/plan-challenger.test.sh:43`, `lib/seo-data/seo-data.test.sh:542-554`, `lib/tests/doctrine-citers.test.sh:190, 196` (`skills/impeccable/*` → `skills-external/impeccable/*`): `skills/seo/` → `skills/pack-seo/skills/seo/`, `skills/geo/` → `skills/pack-seo/skills/geo/`, `skills/web-validate/` → `skills/pack-web-validate/skills/web-validate/`, `skills/site-motion/` → `skills/pack-design/skills/site-motion/`. Prose: `agents/client-handover-writer.md` (`~/.claude/skills/seo/` → `~/.claude/skills/pack-seo/skills/seo/`, `…/web-validate/` → `…/pack-web-validate/skills/web-validate/`, `…/cso/` → `…/pack-gstack-dev/skills/cso/`), `agents/plugin-advisor.md:222` (`~/.claude/skills/impeccable` → `~/.claude/skills/pack-design/skills/impeccable`), `install-plugins.sh:752, 777, 793` ("symlink OK / will be created by link.sh" for emil-design-eng, frontend-design, design-motion-principles → "linked by pack-design"), `:1326-1327` (the two `~/.claude/skills/<x>/` echoes → the pack paths). Run: `make test suite="lib/tests/seo-geo-contract.test.sh lib/tests/model-routing.test.sh lib/tests/effort-routing.test.sh lib/tests/plan-challenger.test.sh lib/seo-data/seo-data.test.sh lib/tests/doctrine-citers.test.sh"` → green.

- [ ] **Step 9: Headless check that the packs load**

```bash
S="$HOME/.cache/claude-tmp/p5"; mkdir -p "$S/t2/proj" && cd "$S/t2/proj" && { [ -d .git ] || git init -q; } && printf '# t2\n' > CLAUDE.md
claude -p 'say hi' --model haiku --output-format stream-json --verbose 2>/dev/null | head -1 > "$S/t2.jsonl"
python3 -I -c '
import json,sys; d=json.loads(open(sys.argv[1]).readline())
print(sorted(p["name"] for p in d["plugins"] if p["name"].startswith("pack-")))
print(len(d["skills"]), [s for s in d["skills"] if s.startswith("pack-seo:") or s == "pack-design:emil-design-eng"])' "$S/t2.jsonl"
```

Expected: the seven ON packs, no `pack-higgsfield`/`pack-extras`, and `['pack-design:emil-design-eng', 'pack-seo:geo', 'pack-seo:seo']`. No commit yet (C1 at Task 4). `bash lib/pack-census.sh` at this point: `RED lib/profiles/full.json missing` (Task 3 fixes) plus RED citer lines on the files Tasks 6-11 rewrite (`skills/profile/SKILL.md`, `skills/onboard/SKILL.md`, `agents/plugin-probe.md`, `agents/plugin-advisor.md`, `lib/plugin-gate.md`, `hooks/statusline.sh`, `doctor.sh`, `lib/tests/design-tool-gate.test.sh`, `install-plugins.sh`, `update-all.sh`, `plugins.lock.json`, `README.md`, `CLAUDE.global.md`, and the old `lib/toggle-external.sh` / `lib/profile.sh` / `lib/tests/profile-*.test.sh` until Tasks 3-4 delete them). Those are expected; any OTHER RED (a moved-skill citer not in Step 8) is fixed here.
---

### Task 3: Profile fragments, `lib/profile.sh`, `lib/profile-state.jq` (no commit: C1 at Task 4)

**Files:**
- Create: `lib/profiles/{full,max,minimal,dev,backend,design,web,web-full,seo,qa,audit}.json`, `lib/profiles/README.md`, `lib/profile-state.jq`, `lib/tests/profile.test.sh`
- Delete (`git rm`): `lib/profiles/*.profile` (11), `lib/tests/profile-default.test.sh`, `lib/tests/profile-set-managed.test.sh`, `lib/tests/profile-census.test.sh`
- Rewrite: `lib/profile.sh`

**Produces:** `bash lib/profile.sh [-C <dir>] list|show <n>|current [--plain]|set <n>|unset|enable <x>|disable <x>|diff <n>`. `-C <dir>` (default cwd) is resolved to the nearest ancestor holding `.claude/`, `CLAUDE.md` or `.git` (file or dir), else `<dir>` itself. Env overrides: `PROFILE_REPO_OVERRIDE`, `PROFILE_USER_SETTINGS`, `PROFILE_CLAUDE_JSON`; reads `CLAUDE_PROFILE_SETTINGS` / `CLAUDE_PROFILE`. `current --plain` lines, in order: `profile=<name|custom>`, `source=flag|local|default`, `flag=<CLAUDE_PROFILE|->`, `pack-<n>=on|off` (packs sorted), `plugin:<id>=on|off` (managed plugins sorted), `connector:<name>=denied` per denied name, `connector:*=denied` when `disableClaudeAiConnectors` is true anywhere, `model=<m|->`, `model-source=flag|local|project|user|-`, `mcp-off=-|<a,b>|unknown`. Exit 2 on every refusal, nothing written. Two jq processes per `current`.

- [ ] **Step 1: Write the fragments and the README**

Run once (not kept):

```bash
cd /home/bchanot/Documents/claude && python3 -I - <<'EOF'
import json, pathlib
PACKS = ["design","scroll3d","seo","web-validate","gstack-dev","gstack-browser","gstack-design","higgsfield","extras"]
DENY = [{"serverName": "claude.ai higgsfield"}, {"serverName": "claude.ai Higgsfield AI"}]
P = {  # packs on, ui-ux-pro-max, pr-review-toolkit, deny
 "full":     (["design","scroll3d","seo","web-validate","gstack-dev","gstack-browser","gstack-design"], True, False, False),
 "max":      (PACKS, True, True, False),
 "minimal":  ([], False, False, True),
 "dev":      (["gstack-dev"], False, False, True),
 "backend":  (["gstack-dev"], False, False, True),
 "design":   (["design","scroll3d","gstack-design","gstack-browser"], True, False, False),
 "web":      (["design","scroll3d","web-validate","gstack-design","gstack-browser","gstack-dev"], True, False, False),
 "web-full": (["design","scroll3d","web-validate","gstack-design","gstack-browser","gstack-dev","seo"], True, False, False),
 "seo":      (["seo","web-validate","gstack-browser","gstack-dev"], False, False, True),
 "qa":       (["gstack-browser","web-validate"], False, False, True),
 "audit":    (["seo","web-validate","gstack-dev","gstack-browser"], False, True, True),
}
for name, (on, ui, pr, deny) in P.items():
    ep = {"model-router@skills-dir": True}
    for p in PACKS: ep[f"pack-{p}@skills-dir"] = p in on
    ep.update({"ui-ux-pro-max@ui-ux-pro-max-skill": ui, "security-guidance@claude-code-plugins": True,
               "pr-review-toolkit@claude-code-plugins": pr, "example-skills@anthropic-agent-skills": False,
               "brightdata-plugin@synced": False})
    d = {"enabledPlugins": ep}
    if deny: d["deniedMcpServers"] = DENY
    pathlib.Path(f"lib/profiles/{name}.json").write_text(json.dumps(d, indent=2) + "\n")
EOF
git rm -q lib/profiles/audit.profile lib/profiles/backend.profile lib/profiles/design.profile lib/profiles/dev.profile lib/profiles/full.profile lib/profiles/max.profile lib/profiles/minimal.profile lib/profiles/qa.profile lib/profiles/seo.profile lib/profiles/web-full.profile lib/profiles/web.profile
```

`lib/profiles/README.md`:

```markdown
# Profiles

A profile is a literal Claude Code settings fragment: `enabledPlugins`
(every pack `pack-<n>@skills-dir` and managed plugin, explicit), optional
`deniedMcpServers` (the two higgsfield claude.ai connectors), optional
`model`. Per project: `bash ~/.claude/lib/profile.sh set <name>` writes it
into `.claude/settings.local.json`, then `/reload-plugins`. Per
conversation: `cc <session> <name>` (lib/cc.sh) runs
`claude --settings lib/profiles/<name>.json`; that conversation is frozen
(no reload brings a pack back; relaunch instead). No profile = the manifest
defaults = `full` with the connectors present. `deniedMcpServers` is a union
across files: a `cc x web` over a project set to `dev` keeps the connectors
denied; `set web` in the project brings them back next session.

`profile.sh list` reads these lines (format `- **name**: text`):

- **full**: every pack except higgsfield and extras; ui-ux-pro-max on; connectors present. The default.
- **max**: everything on, pr-review-toolkit included; for a one-off session, not a project.
- **minimal**: no pack, no design plugin, connectors denied; the smallest listing.
- **dev**: gstack-dev only; backend or tooling work without UI.
- **backend**: same packs as dev; kept as a name for backend projects.
- **design**: design, scroll3d, gstack-design, gstack-browser, ui-ux-pro-max; connectors present.
- **web**: design + scroll3d + web-validate + the three gstack packs + ui-ux-pro-max; public site work.
- **web-full**: web + seo; a site with SEO/GEO on top.
- **seo**: seo, web-validate, gstack-browser, gstack-dev; audit and fixes on a live site.
- **qa**: gstack-browser + web-validate; dogfooding and conformance only.
- **audit**: seo, web-validate, gstack-dev, gstack-browser, pr-review-toolkit; read-mostly audits.

Invariants (checked by `lib/pack-census.sh`): the same key set in every
fragment; `model-router@skills-dir` and `security-guidance@claude-code-plugins`
true everywhere; `example-skills@anthropic-agent-skills` and
`brightdata-plugin@synced` false everywhere; the connectors denied on exactly
minimal, dev, backend, seo, qa, audit; `full` equal to the manifest defaults.
Add your own profile as another `<name>.json` with the same key set.
```

- [ ] **Step 2: Write the failing suite `lib/tests/profile.test.sh`**

```bash
#!/usr/bin/env bash
# lib/tests/profile.test.sh — lib/profile.sh + lib/profile-state.jq on a
# fixture repo: fragments, the four precedence levels, the deniedMcpServers
# union, set/unset/enable/disable merge semantics, refusals (rc 2, nothing
# written), the /mcp toggle, root walk-up, timing. Hermetic:
# PROFILE_REPO_OVERRIDE + PROFILE_USER_SETTINGS + PROFILE_CLAUDE_JSON, no claude.
set -u
unset CLAUDE_PROFILE CLAUDE_PROFILE_SETTINGS
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
check_has() { case "$2" in *"$3"*) pass=$((pass+1));; *) fail=$((fail+1));
  printf 'FAIL %s: [%s] does not contain [%s]\n' "$1" "$2" "$3";; esac; }

FX="$(mktemp -d)"; trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/lib/profiles" "$FX/skills" "$FX/proj/.claude" "$FX/proj/sub/deeper" "$FX/home" "$FX/nowhere"
mk_pack() { mkdir -p "$FX/skills/pack-$1/.claude-plugin"
  printf '{"name":"pack-%s","defaultEnabled":%s}\n' "$1" "$2" > "$FX/skills/pack-$1/.claude-plugin/plugin.json"; }
mk_pack a true; mk_pack b false   # pack-c has no dir (missing)
frag() { # name pack-a pack-b pack-c ui deny(yes|no) [model]
  local d="" m=""
  [ "$6" = yes ] && d=', "deniedMcpServers": [{"serverName": "claude.ai X"}, {"serverName": "claude.ai Y"}]'
  [ -n "${7:-}" ] && m=", \"model\": \"$7\""
  printf '{"enabledPlugins": {"model-router@skills-dir": true, "pack-a@skills-dir": %s, "pack-b@skills-dir": %s, "pack-c@skills-dir": %s, "ui@mk": %s}%s%s}\n' \
    "$2" "$3" "$4" "$5" "$d" "$m" > "$FX/lib/profiles/$1.json"; }
frag fullx true false false true no      # = manifest defaults + user ui on
frag devx true false false false yes
frag minix false false false false yes haiku
printf -- '- **fullx**: everything\n- **devx**: dev only\n- **minix**: nothing\n' > "$FX/lib/profiles/README.md"
printf '{"enabledPlugins": {"ui@mk": true}}\n' > "$FX/home/settings.json"
printf '{}\n' > "$FX/home/claude.json"
printf '# proj\n' > "$FX/proj/CLAUDE.md"
P() { PROFILE_REPO_OVERRIDE="$FX" PROFILE_USER_SETTINGS="$FX/home/settings.json" \
      PROFILE_CLAUDE_JSON="$FX/home/claude.json" bash "$ROOT/lib/profile.sh" -C "$FX/proj" "$@"; }
plain() { P current --plain | tr '\n' ' '; }
L="$FX/proj/.claude/settings.local.json"

out="$(P list)"; check_has T1-list "$out" "dev only"; check_has T1-list-name "$out" "devx"
out="$(P show devx)"; check_has T2-show-on "$out" "pack-a@skills-dir"
check_has T2-show-missing "$out" "off  missing (no skills/pack-c/)"
check_has T2-show-deny "$out" "connectors denied: claude.ai X, claude.ai Y"

out="$(plain)"
check_has T3-default "$out" "profile=fullx source=default flag=- pack-a=on pack-b=off pack-c=off plugin:model-router@skills-dir=on plugin:ui@mk=on model=- model-source=- mcp-off=-"
out="$(P current)"; check_has T3-human "$out" "profile: fullx [default]"

# precedence, before any local write: project settings.json over user
printf '{"enabledPlugins": {"pack-b@skills-dir": true}, "model": "opus"}\n' > "$FX/proj/.claude/settings.json"
out="$(plain)"; check_has T6-project "$out" "profile=custom source=default flag=- pack-a=on pack-b=on "
check_has T6-project-model "$out" "model=opus model-source=project "
rm "$FX/proj/.claude/settings.json"

# set keeps the other keys, writes the managed ones
printf '{"permissions": {"allow": ["Bash(ls)"]}, "model": "sonnet"}\n' > "$L"
out="$(P set devx)"; rc=$?
check T4-set-rc "$rc" 0; check_has T4-set-hint "$out" "/reload-plugins"
check T4-keep-perm "$(jq -c .permissions "$L")" '{"allow":["Bash(ls)"]}'
check T4-keep-model "$(jq -r .model "$L")" sonnet
check T4-deny "$(jq -c '[.deniedMcpServers[].serverName]' "$L")" '["claude.ai X","claude.ai Y"]'
out="$(plain)"
check_has T5-local "$out" "profile=devx source=local flag=- pack-a=on pack-b=off pack-c=off plugin:model-router@skills-dir=on plugin:ui@mk=off connector:claude.ai X=denied connector:claude.ai Y=denied model=sonnet model-source=local mcp-off=-"

# local over project; flag over local
printf '{"enabledPlugins": {"pack-b@skills-dir": true}}\n' > "$FX/proj/.claude/settings.json"
out="$(plain)"; check_has T6-local-over-project "$out" "profile=devx source=local flag=- pack-a=on pack-b=off "
printf '{"enabledPlugins": {"pack-b@skills-dir": true}}\n' > "$FX/flag.json"
out="$(CLAUDE_PROFILE_SETTINGS="$FX/flag.json" CLAUDE_PROFILE=x plain)"
check_has T6-flag "$out" "profile=custom source=flag flag=x pack-a=on pack-b=on "
rm "$FX/proj/.claude/settings.json"

# union of deniedMcpServers: flag fullx over local devx keeps the denies → custom
out="$(CLAUDE_PROFILE_SETTINGS="$FX/lib/profiles/fullx.json" CLAUDE_PROFILE=fullx plain)"
check_has T7-union "$out" "profile=custom source=flag flag=fullx "
check_has T7-union-denied "$out" "connector:claude.ai X=denied "

# refusals
cp "$L" "$FX/before.json"; printf '{"enabledPlugins": \n' > "$L"; cp "$L" "$FX/broken.json"
out="$(P set devx 2>&1)"; rc=$?
check T8-invalid-rc "$rc" 2; check_has T8-invalid-msg "$out" "not valid JSON"
check T8-invalid-untouched "$(cmp -s "$FX/broken.json" "$L" && echo same)" same
cp "$FX/before.json" "$L"
out="$(PROFILE_REPO_OVERRIDE="$FX" PROFILE_USER_SETTINGS="$FX/home/settings.json" PROFILE_CLAUDE_JSON="$FX/home/claude.json" \
       bash "$ROOT/lib/profile.sh" -C "$FX/nowhere" set devx 2>&1)"; rc=$?
check T9-root-rc "$rc" 2; check_has T9-root-msg "$out" "not a project root"; check T9-root-nothing "$(ls -A "$FX/nowhere")" ""
out="$(P set nope 2>&1)"; rc=$?; check T10-unknown-rc "$rc" 2; check_has T10-unknown-list "$out" "fullx"

# enable / disable, three spellings, flag note
P enable b >/dev/null; check T11-enable "$(jq -r '.enabledPlugins["pack-b@skills-dir"]' "$L")" true
P disable pack-b >/dev/null; check T11-disable "$(jq -r '.enabledPlugins["pack-b@skills-dir"]' "$L")" false
P enable pack-b@skills-dir >/dev/null; check T11-enable-id "$(jq -r '.enabledPlugins["pack-b@skills-dir"]' "$L")" true
out="$(P enable zzz 2>&1)"; rc=$?; check T11-unknown "$rc" 2
out="$(CLAUDE_PROFILE_SETTINGS="$FX/flag.json" CLAUDE_PROFILE=x P enable a 2>&1)"
check_has T11-flag-note "$out" "relaunch: cc <name> <profile>"
P disable b >/dev/null

# unset: managed keys gone, permissions kept; model removed only when it is the profile's
P unset >/dev/null
check T12-unset-ep "$(jq -c '.enabledPlugins // "gone"' "$L")" '"gone"'
check T12-unset-deny "$(jq -c '.deniedMcpServers // "gone"' "$L")" '"gone"'
check T12-unset-perm "$(jq -c .permissions "$L")" '{"allow":["Bash(ls)"]}'
check T12-unset-model-kept "$(jq -r .model "$L")" sonnet
P set minix >/dev/null; check T12-minix-model "$(jq -r .model "$L")" haiku
P unset >/dev/null; check T12-minix-model-gone "$(jq -r '.model // "gone"' "$L")" gone

# /mcp toggle; unreadable ~/.claude.json; disableClaudeAiConnectors any-source
printf '{"projects": {"%s": {"disabledMcpServers": ["foo", "bar"]}}}\n' "$FX/proj" > "$FX/home/claude.json"
out="$(P current)"; check_has T13-mcp-off "$out" "profile: custom (off: foo,bar) [default]"
out="$(plain)"; check_has T13-mcp-off-plain "$out" "mcp-off=foo,bar"
printf '{broken\n' > "$FX/home/claude.json"
out="$(plain)"; rc=$?; check T14-unknown-rc "$rc" 0; check_has T14-unknown "$out" "mcp-off=unknown"
printf '{}\n' > "$FX/home/claude.json"
printf '{"enabledPlugins": {"ui@mk": true}, "disableClaudeAiConnectors": true}\n' > "$FX/home/settings.json"
out="$(plain)"; check_has T15-all-denied "$out" "connector:*=denied"; check_has T15-custom "$out" "profile=custom "
printf '{"enabledPlugins": {"ui@mk": true}}\n' > "$FX/home/settings.json"

# a missing pack still written; diff
P set devx >/dev/null; check T16-missing-written "$(jq -r '.enabledPlugins["pack-c@skills-dir"]' "$L")" false
out="$(P diff fullx)"; check_has T17-diff-ui "$out" "ui@mk: off → on"
check_has T17-diff-conn "$out" "connectors denied: claude.ai X, claude.ai Y → "
out="$(P diff devx)"; check T17-nodiff "$out" "no difference from devx"

# shellcheck + width
check T18-shellcheck "$(shellcheck "$ROOT/lib/profile.sh" >/dev/null 2>&1 && echo ok)" ok
check T18-width "$(LC_ALL=C awk 'length($0) > 80' "$ROOT/lib/profile.sh" "$ROOT/lib/profile-state.jq" | wc -l | tr -d ' ')" 0

# root walk-up from a subdirectory; a bare dir stays itself
out="$(PROFILE_REPO_OVERRIDE="$FX" PROFILE_USER_SETTINGS="$FX/home/settings.json" PROFILE_CLAUDE_JSON="$FX/home/claude.json" \
       bash "$ROOT/lib/profile.sh" -C "$FX/proj/sub/deeper" current --plain | tr '\n' ' ')"
check_has T19-walkup "$out" "profile=devx source=local "

# timing: two jq calls, under 100 ms here (spec target 50 ms, measured in Task 12)
t0=$(date +%s%N); P current --plain >/dev/null; t1=$(date +%s%N)
ms=$(( (t1 - t0) / 1000000 )); echo "current --plain: ${ms} ms"
check T20-timing "$([ "$ms" -le 100 ] && echo fast || echo "slow:${ms}ms")" fast

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
```

Run: `make test suite=lib/tests/profile.test.sh` → red.

- [ ] **Step 3: Write `lib/profile-state.jq`**

```jq
# lib/profile-state.jq — effective profile state of one project and
# conversation, in one pass (lib/profile.sh `current`, `unset`).
# Args: $u $p $l $f raw settings files (user, project, local, --settings;
# "" when absent), $cj raw ~/.claude.json, $m manifests [{id,on}],
# $mode "plain" | "human" | "json", $proj project dir, $flagname CLAUDE_PROFILE
# or "-", $hasflag "1" when a --settings file is in force.
# inputs = lib/profiles/*.json (one fragment per file).
def parse: try fromjson catch {};
def name_of: input_filename | sub(".*/"; "") | sub("\\.json$"; "");
def ep: (.enabledPlugins // {});
def dn: [(.deniedMcpServers // [])[] | .serverName];
def onoff: if . then "on" else "off" end;
def is_pack: startswith("pack-") and endswith("@skills-dir");
def short: sub("@skills-dir$"; "");
def src_word($s):
  if $s.source == "flag" then "conv \($s.flag)" else $s.source end;
def listing($plugins; $on):
  [$plugins | to_entries[] | select(.value == $on) | .key | short]
  | if length == 0 then "none" else join(" ") end;

[inputs | {name: name_of, frag: .}] as $profiles
| ($u | parse) as $U | ($p | parse) as $P
| ($l | parse) as $L | ($f | parse) as $F
| ([$profiles[].frag | ep | keys[]] | unique) as $ids
| ($m | map({key: .id, value: .on}) | from_entries) as $mdef
| ($ids | map({key: ., value: ($mdef[.]
      // (if endswith("@skills-dir") and (is_pack | not) then true
          else false end))}) | from_entries) as $d
| (($d + ($U|ep) + ($P|ep) + ($L|ep) + ($F|ep))
   | with_entries(select(.key as $k | $d | has($k)))) as $plugins
| ((($U|dn) + ($P|dn) + ($L|dn) + ($F|dn)) | unique) as $denied
| ([$U, $P, $L, $F] | any(.disableClaudeAiConnectors == true)) as $all
| ($F.model // $L.model // $P.model // $U.model // "-") as $model
| (if ($F | has("model")) then "flag" elif ($L | has("model")) then "local"
   elif ($P | has("model")) then "project"
   elif ($U | has("model")) then "user" else "-" end) as $msrc
| (if $hasflag == "1" then "flag"
   elif ((($L|ep) | length) + (($L|dn) | length)) > 0 then "local"
   else "default" end) as $src
| (try ($cj | fromjson | .projects[$proj].disabledMcpServers // []
        | if length == 0 then "-" else join(",") end)
   catch (if $cj == "" then "-" else "unknown" end)) as $off
| ([$profiles[] | select((.frag | ep) == $plugins
       and ((.frag | dn | sort) == ($denied | sort)) and ($all | not))
    | .name] | .[0] // "custom") as $name
| {name: $name, source: $src, flag: $flagname, plugins: $plugins,
   denied: $denied, all_denied: $all, model: $model, model_source: $msrc,
   mcp_off: $off} as $s
| if $mode == "json" then $s
  elif $mode == "plain" then
    ( ["profile=\($s.name)", "source=\($s.source)", "flag=\($s.flag)"]
      + [$plugins | to_entries | sort_by(.key)[] | select(.key | is_pack)
         | "\(.key | short)=\(.value | onoff)"]
      + [$plugins | to_entries | sort_by(.key)[]
         | select(.key | is_pack | not) | "plugin:\(.key)=\(.value | onoff)"]
      + [$denied[] | "connector:\(.)=denied"]
      + (if $all then ["connector:*=denied"] else [] end)
      + ["model=\($s.model)", "model-source=\($s.model_source)",
         "mcp-off=\($s.mcp_off)"] ) | .[]
  else
    ( [ (if $s.mcp_off != "-"
         then "profile: custom (off: \($s.mcp_off)) [\(src_word($s))]"
         else "profile: \($s.name) [\(src_word($s))]" end),
        "  on : \(listing($plugins; true))",
        "  off: \(listing($plugins; false))",
        "  connectors denied: \(if $all then "all"
           elif ($denied | length) == 0 then "none"
           else ($denied | join(", ")) end)",
        "  model: \($s.model) (\($s.model_source))" ] ) | .[]
  end
```

- [ ] **Step 4: Write `lib/profile.sh`**

```bash
#!/usr/bin/env bash
# shellcheck disable=SC2016  # jq programs quote $vars on purpose
# ============================================================
# lib/profile.sh — profiles as settings fragments for packs + connectors
#
# A profile `lib/profiles/<name>.json` is a literal Claude Code settings
# fragment: `enabledPlugins` (every pack `pack-<n>@skills-dir` and managed
# plugin, explicit true/false), `deniedMcpServers` (claude.ai connector
# names, optional) and `model` (optional). Per project, `set` merges it
# into `.claude/settings.local.json`; per conversation, `cc <name>
# <profile>` (lib/cc.sh) passes the file as `claude --settings`. Nothing
# here writes the user scope, moves a symlink or calls `claude`.
#
# Usage:
#   profile.sh [-C <dir>] list
#   profile.sh [-C <dir>] show <name>
#   profile.sh [-C <dir>] current [--plain]
#   profile.sh [-C <dir>] set <name>
#   profile.sh [-C <dir>] unset
#   profile.sh [-C <dir>] enable|disable <pack | plugin id>
#   profile.sh [-C <dir>] diff <name>
#
# <dir> (default: cwd) resolves to the nearest ancestor holding .claude/,
# CLAUDE.md or .git, so a subdirectory reads its project's settings.
# `current` = lib/profile-state.jq, ONE jq pass over: $CLAUDE_PROFILE_SETTINGS
# (the --settings file lib/cc.sh exports), <root>/.claude/settings.local.json,
# <root>/.claude/settings.json, ~/.claude/settings.json; a pack absent from
# all takes its manifest `defaultEnabled` (absent key = on); a managed plugin
# absent from all is off; `enabledPlugins` and `model` per key, highest wins;
# `deniedMcpServers` = the UNION of every file; `disableClaudeAiConnectors`
# any-source-true; then ~/.claude.json `projects[<root>].disabledMcpServers`.
# `--plain` = one `key=value` per line: the single truth for gates, hooks
# and the statusline (supersedes `show --plain`, BDR-024).
#
# Exit: 0 ok · 2 usage, unknown profile or pack, not a project root (no
#       CLAUDE.md and no .git), unreadable or invalid local JSON; nothing
#       is written on any refusal.
# ============================================================
set -euo pipefail

REPO="${PROFILE_REPO_OVERRIDE:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." \
  && pwd)}"
PROFILES_DIR="$REPO/lib/profiles"
SKILLS_DIR="$REPO/skills"
STATE_JQ="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)/profile-state.jq"
USER_SETTINGS="${PROFILE_USER_SETTINGS:-$HOME/.claude/settings.json}"
CLAUDE_JSON="${PROFILE_CLAUDE_JSON:-$HOME/.claude.json}"
LOCAL_REL=".claude/settings.local.json"
PROJECT="$PWD"

die() { echo "profile: $*" >&2; exit 2; }
usage() {
  sed -n '/^# Usage:/,/^#$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,2\}//' >&2
  exit 2
}

# ---- project root ----------------------------------------------------------
find_root() { # $1 dir → nearest ancestor with .claude/, CLAUDE.md or .git
  local d="$1"   # the walk stops below $HOME: ~/.claude is not a project
  while [ "$d" != / ] && [ "$d" != "$HOME" ]; do
    if [ -d "$d/.claude" ] || [ -f "$d/CLAUDE.md" ] || [ -e "$d/.git" ]; then
      echo "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  echo "$1"
}
require_project_root() {
  [ -f "$PROJECT/CLAUDE.md" ] || [ -e "$PROJECT/.git" ] \
    || die "not a project root (no CLAUDE.md and no .git): $PROJECT"
}

# ---- inputs ----------------------------------------------------------------
profile_file() { echo "$PROFILES_DIR/$1.json"; }
profile_names() {
  local f
  for f in "$PROFILES_DIR"/*.json; do [ -f "$f" ] && basename "$f" .json; done
  return 0
}
profile_desc() { # the `- **name**: text` line of lib/profiles/README.md
  sed -n "s/^- \*\*$1\*\*: //p" "$PROFILES_DIR/README.md" 2>/dev/null | head -1
}
managed_ids() {
  jq -r '.enabledPlugins | keys[]' "$PROFILES_DIR"/*.json | sort -u
}
managed_connectors() {
  jq -r '(.deniedMcpServers // [])[] | .serverName' "$PROFILES_DIR"/*.json \
    | sort -u
}
as_json_list() { jq -Rn '[inputs]'; }   # stdin lines → JSON string array
json_or_empty() { # $1 file → its JSON, {} when absent; rc 2 when invalid
  [ -f "$1" ] || { echo '{}'; return 0; }
  jq -c . "$1" 2>/dev/null || return 2
}
read_local() {
  json_or_empty "$PROJECT/$LOCAL_REL" \
    || die "$LOCAL_REL is not valid JSON — nothing written"
}
pack_default() { # $1 id → true | false | missing (manifest defaultEnabled)
  local m="$SKILLS_DIR/${1%@skills-dir}/.claude-plugin/plugin.json"
  [ -f "$m" ] || { echo missing; return 0; }
  jq -r 'if .defaultEnabled == false then "false" else "true" end' "$m"
}
manifests_json() { # [{id, on}] for every pack manifest, [] when none
  jq -cn '[inputs | {id: (.name + "@skills-dir"),
                     on: (.defaultEnabled != false)}]' \
    "$SKILLS_DIR"/pack-*/.claude-plugin/plugin.json 2>/dev/null || echo '[]'
}
have_flag() {
  [ -n "${CLAUDE_PROFILE_SETTINGS:-}" ] && [ -f "$CLAUDE_PROFILE_SETTINGS" ]
}
raw_or_null() { # $1 file → the path, or /dev/null when absent or unset
  if [ -n "$1" ] && [ -f "$1" ]; then echo "$1"; else echo /dev/null; fi
}

# ---- effective state: two jq calls -----------------------------------------
state() { # $1 mode: plain | human | json
  local hasflag=0; have_flag && hasflag=1
  jq -rn --arg mode "$1" --arg proj "$PROJECT" --arg hasflag "$hasflag" \
    --arg flagname "${CLAUDE_PROFILE:--}" \
    --rawfile u "$(raw_or_null "$USER_SETTINGS")" \
    --rawfile p "$(raw_or_null "$PROJECT/.claude/settings.json")" \
    --rawfile l "$(raw_or_null "$PROJECT/$LOCAL_REL")" \
    --rawfile f "$(raw_or_null "${CLAUDE_PROFILE_SETTINGS:-}")" \
    --rawfile cj "$(raw_or_null "$CLAUDE_JSON")" \
    --argjson m "$(manifests_json)" -f "$STATE_JQ" "$PROFILES_DIR"/*.json
}

# ---- commands ---------------------------------------------------------------
unknown_profile() {
  echo "profile: unknown profile '$1'. Known:" >&2; cmd_list >&2; exit 2
}
cmd_list() {
  local n d
  for n in $(profile_names); do
    d="$(profile_desc "$n")"
    printf '%-10s %s\n' "$n" "${d:-(no line in lib/profiles/README.md)}"
  done
}
cmd_show() {
  local f id v tag
  f="$(profile_file "$1")"; [ -f "$f" ] || unknown_profile "$1"
  echo "profile $1: $(profile_desc "$1")"
  for id in $(jq -r '.enabledPlugins | keys[]' "$f"); do
    v="$(jq -r --arg k "$id" '.enabledPlugins[$k]
          | if . then "on" else "off" end' "$f")"
    tag=""
    case "$id" in pack-*@skills-dir)
      [ "$(pack_default "$id")" = missing ] \
        && tag="  missing (no skills/${id%@skills-dir}/)" ;;
    esac
    printf '  %-42s %s%s\n' "$id" "$v" "$tag"
  done
  echo "  connectors denied: $(jq -r '(.deniedMcpServers // [])
    | if length == 0 then "none" else map(.serverName) | join(", ") end' "$f")"
  echo "  model: $(jq -r '.model // "-"' "$f")"
}
cmd_current() {
  if [ "${1:-}" = "--plain" ]; then state plain; else state human; fi
}
write_local() { # $1 JSON → atomic replace of the local settings
  local tmp
  mkdir -p "$PROJECT/.claude"
  tmp="$(mktemp "$PROJECT/.claude/.settings.local.XXXXXX")"
  jq . <<<"$1" > "$tmp" && mv -f "$tmp" "$PROJECT/$LOCAL_REL"
}
after_write_hint() {
  echo "next: /reload-plugins loads the packs in this session;" \
    "connectors and model apply to the next session"
  if have_flag; then
    echo "note: this conversation runs --settings ${CLAUDE_PROFILE:-?}:" \
      "a pack it turns off stays off here — relaunch: cc <name> <profile>"
  fi
}
cmd_set() {
  local f cur new
  f="$(profile_file "$1")"; [ -f "$f" ] || unknown_profile "$1"
  require_project_root; cur="$(read_local)"
  new="$(jq --argjson cur "$cur" \
    --argjson names "$(managed_connectors | as_json_list)" '
    . as $p | $cur
    | .enabledPlugins = (($cur.enabledPlugins // {}) + $p.enabledPlugins)
    | .deniedMcpServers = ([($cur.deniedMcpServers // [])[]
        | select(.serverName as $s | ($names | index($s)) == null)]
        + ($p.deniedMcpServers // []))
    | if (.deniedMcpServers | length) == 0 then del(.deniedMcpServers)
      else . end
    | if $p.model then .model = $p.model else . end' "$f")"
  write_local "$new"
  echo "profile $1 → $LOCAL_REL"; after_write_hint
}
cmd_unset() {
  local cur name pm new
  require_project_root; cur="$(read_local)"
  name="$(CLAUDE_PROFILE_SETTINGS='' state json | jq -r .name)"
  pm="-"
  [ "$name" != custom ] \
    && pm="$(jq -r '.model // "-"' "$(profile_file "$name")")"
  new="$(jq --argjson ids "$(managed_ids | as_json_list)" \
    --argjson names "$(managed_connectors | as_json_list)" --arg pm "$pm" '
    .enabledPlugins = ((.enabledPlugins // {})
        | with_entries(select(.key as $k | ($ids | index($k)) == null)))
    | if (.enabledPlugins | length) == 0 then del(.enabledPlugins) else . end
    | .deniedMcpServers = [(.deniedMcpServers // [])[]
        | select(.serverName as $s | ($names | index($s)) == null)]
    | if (.deniedMcpServers | length) == 0 then del(.deniedMcpServers)
      else . end
    | if $pm != "-" and .model == $pm then del(.model) else . end' <<<"$cur")"
  write_local "$new"
  echo "profile keys removed from $LOCAL_REL (was: $name)"; after_write_hint
}
resolve_id() { # design | pack-design | pack-design@skills-dir | <plugin id>
  case "$1" in
    *@*) echo "$1" ;;
    pack-*) echo "$1@skills-dir" ;;
    *) echo "pack-$1@skills-dir" ;;
  esac
}
cmd_toggle() { # $1 true|false, $2 pack or plugin spelling
  local id cur new
  id="$(resolve_id "$2")"
  managed_ids | grep -qx -- "$id" \
    || die "unknown pack or plugin '$2' (known: $(managed_ids | tr '\n' ' '))"
  require_project_root; cur="$(read_local)"
  new="$(jq --arg id "$id" --argjson v "$1" \
    '.enabledPlugins = ((.enabledPlugins // {}) + {($id): $v})' <<<"$cur")"
  write_local "$new"
  echo "$id=$1 → $LOCAL_REL"; after_write_hint
}
cmd_diff() {
  local f out
  f="$(profile_file "$1")"; [ -f "$f" ] || unknown_profile "$1"
  out="$(jq -r --argjson e "$(state json)" '
    def onoff: if . then "on" else "off" end;
    (.enabledPlugins | to_entries[] | select($e.plugins[.key] != .value)
     | .key + ": " + ($e.plugins[.key] | onoff) + " → " + (.value | onoff)),
    (([(.deniedMcpServers // [])[] | .serverName] | sort) as $want
     | ($e.denied | sort) as $have
     | if $want == $have then empty
       else "connectors denied: " + ($have | join(", ")) + " → "
            + ($want | join(", ")) end),
    (if (.model // "-") != $e.model
     then "model: " + $e.model + " → " + (.model // "-")
     else empty end)' "$f")"
  if [ -n "$out" ]; then echo "$out"; else echo "no difference from $1"; fi
}

# ---- main --------------------------------------------------------------------
command -v jq >/dev/null 2>&1 || die "jq is required"
while [ $# -gt 0 ]; do
  case "$1" in
    -C) [ -n "${2:-}" ] || usage
        PROJECT="$(cd "$2" 2>/dev/null && pwd)" || die "no such dir: $2"
        shift 2 ;;
    *) break ;;
  esac
done
PROJECT="$(find_root "$PROJECT")"
case "${1:-}" in
  list)    cmd_list ;;
  show)    [ -n "${2:-}" ] || usage; cmd_show "$2" ;;
  current) cmd_current "${2:-}" ;;
  set)     [ -n "${2:-}" ] || usage; cmd_set "$2" ;;
  unset)   cmd_unset ;;
  enable)  [ -n "${2:-}" ] || usage; cmd_toggle true "$2" ;;
  disable) [ -n "${2:-}" ] || usage; cmd_toggle false "$2" ;;
  diff)    [ -n "${2:-}" ] || usage; cmd_diff "$2" ;;
  *) usage ;;
esac
```

`CLAUDE_PROFILE_SETTINGS='' state json` relies on bash passing a temporary environment to a function (bash does, outside POSIX mode). `cmd_show`'s `missing` tag: `%-42s` then two spaces, as the test checks.

- [ ] **Step 5: Run the suite until green**

Run: `make test suite=lib/tests/profile.test.sh`. Expected `FAIL=0`; count the PASS and write the number here. The timing line prints the measured ms.

- [ ] **Step 6: Delete the old suites, check the real fragments**

```bash
cd /home/bchanot/Documents/claude
git rm -q lib/tests/profile-default.test.sh lib/tests/profile-set-managed.test.sh lib/tests/profile-census.test.sh
bash lib/profile.sh list && bash lib/profile.sh show web && bash lib/profile.sh current
bash lib/pack-census.sh   # expected: PACKS OK 9 packs 55 skills, WARN lines only for uninstalled targets
```

`current` on this repo is expected `profile: full [default]` once Task 2 Step 7 restored the user scope. No commit yet.

---

### Task 4: Retire the toggling libs, commit C1

**Files:**
- Delete (`git rm`): `lib/toggle-external.sh`, `lib/tests/toggle-external-repo-resolution.test.sh`, `lib/tests/gstack-removed.test.sh`
- Rewrite: `lib/gstack-removed.sh` → header (rationale, BDR-117 and BDR-105 pointers) + `mapfile -t GSTACK_REMOVED < "$(dirname "${BASH_SOURCE[0]}")/gstack-removed.list"` and nothing else (no functions: every caller is gone after this task; the census reads the list directly)
- Modify: `lib/tests/higgsfield.test.sh` (keep the skills-external sync and CLI-probe cases; delete the toggle, park and "0 mentions in profile.sh / *.profile" cases, lines 321-323 among them), `lib/higgsfield-skills.sh:8, 41` (comments: "linked by skills/pack-higgsfield (`profile.sh enable higgsfield`)")

- [ ] **Step 1: Apply**

```bash
cd /home/bchanot/Documents/claude
git rm -q lib/toggle-external.sh lib/tests/toggle-external-repo-resolution.test.sh lib/tests/gstack-removed.test.sh
```

Then the edits above. `grep -rn 'gstack_park\|gstack_unpark\|gstack_parked_names\|gstack_is_removed\|gstack_skills' --include='*.sh' .` must print nothing.

- [ ] **Step 2: Green**

Run: `make test suite="lib/tests/higgsfield.test.sh lib/tests/profile.test.sh"` → green. `bash lib/pack-census.sh` → RED citer lines ONLY on files Tasks 6-11 rewrite (the Task 2 Step 9 list minus the deleted libs and suites); no RED on packs, fragments or moved-skill citers. `pack-census.test.sh` T11-real (and so `make test` as a whole) stays red from C1 until Task 11; every other suite is green at C1.

- [ ] **Step 3: Commit C1**

```bash
cd /home/bchanot/Documents/claude
git add .gitignore lib/pack-census.sh lib/pack-census-fragments.jq lib/tests/pack-census.test.sh lib/gstack-removed.list lib/gstack-removed.sh lib/profile.sh lib/profile-state.jq lib/profiles lib/tests/profile.test.sh lib/tests/higgsfield.test.sh lib/higgsfield-skills.sh lib/tests/seo-geo-contract.test.sh lib/tests/model-routing.test.sh lib/tests/effort-routing.test.sh lib/tests/plan-challenger.test.sh lib/seo-data/seo-data.test.sh lib/tests/doctrine-citers.test.sh agents/client-handover-writer.md agents/plugin-advisor.md install-plugins.sh skills/pack-design skills/pack-scroll3d skills/pack-seo skills/pack-web-validate skills/pack-gstack-dev skills/pack-gstack-browser skills/pack-gstack-design skills/pack-higgsfield skills/pack-extras
git add -u lib/toggle-external.sh lib/tests/toggle-external-repo-resolution.test.sh lib/tests/gstack-removed.test.sh lib/tests/profile-default.test.sh lib/tests/profile-set-managed.test.sh lib/tests/profile-census.test.sh lib/profiles
git status --short | grep -v '^ M settings.json'   # only A/R/D/M lines of the above; settings.json must NOT be staged
git commit -m "feat(packs): nine skills-dir packs, profiles as settings fragments, profile.sh on one jq pass; symlink toggling and toggle-external retired"
```

---

### Task 5: `lib/cc.sh` launcher

**Files:** create `lib/cc.sh`, `lib/tests/cc.test.sh`.

**Produces:** function `cc <name> [profile]`; reads `$HOME/.claude/lib/profiles/<profile>.json` and `$HOME/.claude/lib/profile.sh`; exports `CLAUDE_PROFILE`, `CLAUDE_PROFILE_SETTINGS` (empty without a profile), `TMPDIR=$HOME/.cache/claude-tmp`.

- [ ] **Step 1: Failing test** `lib/tests/cc.test.sh`

```bash
#!/usr/bin/env bash
# lib/tests/cc.test.sh — lib/cc.sh `cc <name> [profile]`: unknown profile →
# list + rc 2, no session; a profile → claude --settings <fragment> with
# CLAUDE_PROFILE / CLAUDE_PROFILE_SETTINGS / TMPDIR exported through
# systemd-run + dtach; no profile → plain claude, TMPDIR still set; .env
# sourced. Hermetic: PATH shims, HOME in a fixture holding .claude/lib.
set -u
unset CLAUDE_PROFILE CLAUDE_PROFILE_SETTINGS
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
check_has() { case "$2" in *"$3"*) pass=$((pass+1));; *) fail=$((fail+1));
  printf 'FAIL %s: [%s] does not contain [%s]\n' "$1" "$2" "$3";; esac; }
FX="$(mktemp -d)"; trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/bin" "$FX/home/.claude/lib/profiles"
cp "$ROOT/lib/cc.sh" "$ROOT/lib/profile.sh" "$FX/home/.claude/lib/"
printf '{"enabledPlugins": {"x@skills-dir": true}}\n' > "$FX/home/.claude/lib/profiles/webx.json"
printf -- '- **webx**: web fixture\n' > "$FX/home/.claude/lib/profiles/README.md"
cat > "$FX/bin/systemd-run" <<'EOF'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do case "$1" in --*) shift ;; *) break ;; esac; done
echo "systemd-run" >> "$CC_LOG"; exec "$@"
EOF
cat > "$FX/bin/dtach" <<'EOF'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do case "$1" in -c|-e) shift 2 ;; *) break ;; esac; done
echo "dtach" >> "$CC_LOG"; exec "$@"
EOF
cat > "$FX/bin/claude" <<'EOF'
#!/usr/bin/env bash
{ echo "claude argv: $*"; echo "CLAUDE_PROFILE=${CLAUDE_PROFILE-unset}"
  echo "CLAUDE_PROFILE_SETTINGS=${CLAUDE_PROFILE_SETTINGS-unset}"
  echo "TMPDIR=${TMPDIR-unset}"; echo "canary=${CC_ENV_CANARY-unset}"; } >> "$CC_LOG"
EOF
chmod +x "$FX/bin/"*
export CC_LOG="$FX/log" HOME="$FX/home"
PATH="$FX/bin:$PATH"
# shellcheck disable=SC1091
. "$FX/home/.claude/lib/cc.sh"

: > "$CC_LOG"; out="$(cc s1 nope 2>&1)"; rc=$?
check T1-unknown-rc "$rc" 2; check_has T1-unknown-msg "$out" "cc: unknown profile 'nope'"
check_has T1-unknown-list "$out" "webx"; check T1-no-session "$(cat "$CC_LOG")" ""

: > "$CC_LOG"; cc s2 webx; rc=$?; log="$(cat "$CC_LOG")"
check T2-rc "$rc" 0; check_has T2-chain "$log" "systemd-run"; check_has T2-dtach "$log" "dtach"
check_has T2-argv "$log" "claude argv: --settings $FX/home/.claude/lib/profiles/webx.json"
check_has T2-profile "$log" "CLAUDE_PROFILE=webx"
check_has T2-settings "$log" "CLAUDE_PROFILE_SETTINGS=$FX/home/.claude/lib/profiles/webx.json"
check_has T2-tmpdir "$log" "TMPDIR=$FX/home/.cache/claude-tmp"
check T2-tmpdir-exists "$([ -d "$FX/home/.cache/claude-tmp" ] && echo yes)" yes

: > "$CC_LOG"; cc s3; rc=$?; log="$(cat "$CC_LOG")"
check T3-rc "$rc" 0; check_has T3-argv "$log" "claude argv: "$'\n'
check_has T3-profile-empty "$log" "CLAUDE_PROFILE="$'\n'
check_has T3-tmpdir "$log" "TMPDIR=$FX/home/.cache/claude-tmp"

printf 'CC_ENV_CANARY=1\n' > "$FX/home/.claude/.env"
: > "$CC_LOG"; cc s4 webx; check_has T4-env "$(cat "$CC_LOG")" "canary=1"
check T5-shellcheck "$(shellcheck "$ROOT/lib/cc.sh" >/dev/null 2>&1 && echo ok)" ok
printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
```

- [ ] **Step 2: `lib/cc.sh`**

```bash
#!/usr/bin/env bash
# ============================================================
# lib/cc.sh — `cc <name> [profile]`: a named dtach session running claude,
# optionally under a per-conversation profile.
#
# Sourced from ~/.bashrc (user step, MIGRATION.md), guarded so a checkout
# without the file does not break the shell:
#   [ -f "$HOME/.claude/lib/cc.sh" ] && . "$HOME/.claude/lib/cc.sh"
# The old `dtach_claude()` and `alias cc='dtach_claude'` must go (an alias
# wins over this function and drops the profile argument; doctor warns).
#
# With a profile, claude starts with `--settings lib/profiles/<profile>.json`
# and the session exports CLAUDE_PROFILE + CLAUDE_PROFILE_SETTINGS, which
# `profile.sh current` reads (source=flag). That conversation is frozen:
# `/reload-plugins` re-reads neither the flag file nor a local value the
# flag overrides; to change packs, start another `cc <name> <profile>`.
# Without a profile: manifest defaults + local settings, as before.
# TMPDIR goes to ~/.cache/claude-tmp either way (BLK-021).
# ============================================================

cc() {
  local name="${1:-claude-$(date +%H%M%S)}" profile="${2:-}"
  local lib="$HOME/.claude/lib" settings=""
  if [ -n "$profile" ]; then
    settings="$lib/profiles/$profile.json"
    if [ ! -f "$settings" ]; then
      echo "cc: unknown profile '$profile'. Known:" >&2
      bash "$lib/profile.sh" list >&2
      return 2
    fi
  fi
  mkdir -p "$HOME/.cache/claude-tmp" "$HOME/.dtach"
  # shellcheck disable=SC2016,SC1003  # the inner shell expands $HOME; '^\' is dtach's detach key
  CLAUDE_PROFILE="$profile" CLAUDE_PROFILE_SETTINGS="$settings" \
  TMPDIR="$HOME/.cache/claude-tmp" \
  systemd-run --user --quiet --collect --scope --slice=dev.slice \
    --unit="cc-${name}" \
    dtach -c "$HOME/.dtach/${name}" -e '^\' \
      bash -c 'set -a; [ -f "$HOME/.claude/.env" ] && . "$HOME/.claude/.env"
               set +a
               if [ -n "$CLAUDE_PROFILE_SETTINGS" ]; then
                 exec claude --settings "$CLAUDE_PROFILE_SETTINGS"
               fi
               exec claude'
}
```

- [ ] **Step 3: Green and commit**

Run: `make test suite=lib/tests/cc.test.sh` → `PASS=18 FAIL=0`.

```bash
git add lib/cc.sh lib/tests/cc.test.sh
git commit -m "feat(cc): cc <name> [profile] runs claude --settings lib/profiles/<profile>.json and exports CLAUDE_PROFILE*"
```

---

### Task 6: Design gate on `current --plain`

**Files:** rewrite `lib/design-tool-gate.sh` (keep lines 93-143: `ensure_21st_on_path`, its call, `twentyfirst_auth_state`; drop `ensure_claude_on_path`; reword the comment at 89-91 that cites it) and `lib/tests/design-tool-gate.test.sh`; modify `lib/design-gate.md`, `skills/feat/SKILL.md:76-78`, `skills/bugfix/SKILL.md:60-62`, `skills/feat/test-prompts.json:3`, `agents/plugin-advisor.md:167`.

**Produces:** `design-tool-gate.sh` (no argument). Exit 0 / 10 / 11 / 12 / 2. First lines: `design toolchain: READY — packs design + gstack-design + ui-ux-pro-max on (<profile>)`; `design toolchain: INCOMPLETE`; `design toolchain: SIGN-IN REQUIRED — 21st CLI installed, not signed in`; `design toolchain: READY BUT UNVERIFIED — 21st could not answer: <diag>`. Env: `DESIGN_GATE_PROFILE_SH` (default `$REPO/lib/profile.sh`), `TWENTYFIRST_TOKEN` / `API_KEY_21ST`.

- [ ] **Step 1: Failing suite** (replace `lib/tests/design-tool-gate.test.sh`; keep the file's CURRENT sanitised precondition at lines 20-27, the whole `if … fi`: `PATH=/usr/bin:/bin command -v 21st || [ -e /usr/local/bin/21st ] …` → exit 1 with its message)

```bash
#!/usr/bin/env bash
# lib/tests/design-tool-gate.test.sh — lib/design-tool-gate.sh reads
# `profile.sh current --plain` (fake, $WORK/plain.txt) and the 21st sign-in
# state (fake `21st`, FAKE_21ST_MODE). READY (0); a pack off + source=local →
# INCOMPLETE (10) with the profile.sh remedy; source=flag → relaunch remedy;
# no 21st CLI → 10 with the npm hint; signed out → 12; whoami garbage → 11;
# a token → READY without whoami; bad --plain → 2.
set -u
unset CLAUDE_PROFILE CLAUDE_PROFILE_SETTINGS
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL $1 — $2"; }
<the current lines 20-27 precondition (the whole if…fi), unchanged>
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home"; export WORK
printf '#!/usr/bin/env bash\ncat "$WORK/plain.txt"\n' > "$WORK/bin/profile.sh"
cat > "$WORK/bin/21st" <<'EOF'
#!/usr/bin/env bash
case "${FAKE_21ST_MODE:-in}" in
  in) echo "Logged in as fake@example.com" ;; out) echo "Not logged in" ;;
  garbage) echo "boom"; exit 3 ;;
esac
EOF
chmod +x "$WORK/bin/"*
plain() { # design gstack-design ui source profile
  printf 'profile=%s\nsource=%s\nflag=-\npack-design=%s\npack-gstack-design=%s\nplugin:ui-ux-pro-max@ui-ux-pro-max-skill=%s\nmodel=-\n' \
    "$5" "$4" "$1" "$2" "$3" > "$WORK/plain.txt"
}
gate_run() { # $1 mode, $2 PATH prefix ("" = no 21st)
  local p="$2"; [ -n "$p" ] && p="$p:"
  env -u TWENTYFIRST_TOKEN -u API_KEY_21ST HOME="$WORK/home" PATH="${p}/usr/bin:/bin" \
    FAKE_21ST_MODE="$1" WORK="$WORK" DESIGN_GATE_PROFILE_SH="$WORK/bin/profile.sh" \
    bash "$ROOT/lib/design-tool-gate.sh"
}
expect() { # name rc-want substring
  if [ "$rc" = "$2" ] && case "$out" in *"$3"*) true;; *) false;; esac
  then ok "$1"; else bad "$1" "rc=$rc out=[$out]"; fi
}
plain on on on local web; out="$(gate_run in "$WORK/bin")"; rc=$?
expect T1-ready 0 "READY — packs design + gstack-design + ui-ux-pro-max on (web)"
plain off on on local dev; out="$(gate_run in "$WORK/bin")"; rc=$?
expect T2-incomplete 10 "INCOMPLETE"; expect T2-remedy-local 10 "bash ~/.claude/lib/profile.sh set web"
expect T2-names 10 "off: pack-design"
plain on off off flag dev; out="$(gate_run in "$WORK/bin")"; rc=$?
expect T3-remedy-flag 10 "relaunch this conversation with a design profile:  cc <name> web"
expect T3-names 10 "off: pack-gstack-design plugin:ui-ux-pro-max@ui-ux-pro-max-skill"
plain on on on local web; out="$(gate_run in "")"; rc=$?
expect T4-no-cli 10 "21st needs the CLI: npm i -g @21st-dev/cli   then   21st login"
out="$(gate_run out "$WORK/bin")"; rc=$?
expect T5-signed-out 12 "SIGN-IN REQUIRED"; expect T5-ask 12 "! 21st login"
out="$(gate_run garbage "$WORK/bin")"; rc=$?
expect T6-unverified 11 "READY BUT UNVERIFIED — 21st could not answer: whoami: rc=3 boom"
out="$(TWENTYFIRST_TOKEN=x FAKE_21ST_MODE=out HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" WORK="$WORK" \
       DESIGN_GATE_PROFILE_SH="$WORK/bin/profile.sh" bash "$ROOT/lib/design-tool-gate.sh")"; rc=$?
expect T7-token 0 "READY"
printf 'nonsense\n' > "$WORK/plain.txt"; out="$(gate_run in "$WORK/bin" 2>&1)"; rc=$?
expect T8-bad-plain 2 "design-gate: profile.sh current --plain gave no pack-design line"
if shellcheck "$ROOT/lib/design-tool-gate.sh" >/dev/null 2>&1; then ok T9-shellcheck; else bad T9-shellcheck findings; fi
if [ "$(LC_ALL=C awk 'length($0) > 80' "$ROOT/lib/design-tool-gate.sh" | wc -l | tr -d ' ')" = 0 ]; then ok T9-width; else bad T9-width "lines over 80"; fi
echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Rewrite the gate** (header and body; wrap every line ≤ 80)

```bash
#!/usr/bin/env bash
# ============================================================
# lib/design-tool-gate.sh — deterministic design-toolchain state check.
#
# Answers one question for lib/design-gate.md § DECISION: "is the design
# toolchain active enough to proceed?" Source of truth = `profile.sh
# current --plain` (packs + managed plugins of THIS project and
# conversation). Required: pack-design, pack-gstack-design and the
# ui-ux-pro-max plugin, plus the `21st` CLI signed in (gate-only state:
# in / out / unknown, from `21st whoami`).
#
# Exit: 0 ready · 10 incomplete (a pack or plugin off, or no 21st CLI) ·
#       11 ready-but-unverified (21st could not answer) · 12 sign-in
#       required · 2 error (profile.sh failed or gave no pack lines).
# Remedy on 10: source=flag → relaunch `cc <name> web` (a --settings
# conversation is frozen); else `profile.sh set web` (or `enable design`)
# then /reload-plugins. The CLI is a global npm install either way.
# Usage: design-tool-gate.sh        (no argument; env DESIGN_GATE_PROFILE_SH)
# ============================================================
set -euo pipefail

REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_SH="${DESIGN_GATE_PROFILE_SH:-$REPO/lib/profile.sh}"
NEEDED=(pack-design pack-gstack-design
  "plugin:ui-ux-pro-max@ui-ux-pro-max-skill")

# ---- 21st CLI on PATH + sign-in state (kept from the previous version) ----
<current lines 93-143; in the comment that said "the repair above only fires
 when claude ITSELF is unresolvable", say "a PATH repair for the 21st CLI only
 (claude is no longer called here)">

# ---- packs and plugin from profile.sh ---------------------------------------
plain="$(bash "$PROFILE_SH" -C "$PWD" current --plain 2>/dev/null)" \
  || { echo "design-gate: profile.sh current --plain failed" >&2; exit 2; }
grep -q '^pack-design=' <<<"$plain" || {
  echo "design-gate: profile.sh current --plain gave no pack-design line" >&2
  exit 2; }
plain_get() { sed -n "s/^$1=//p" <<<"$plain" | head -1; }
missing=()
for k in "${NEEDED[@]}"; do
  [ "$(plain_get "$k")" = on ] || missing+=("$k")
done
source="$(plain_get source)"; profile="$(plain_get profile)"

# ---- 21st: CLI present, then signed in ---------------------------------------
cli_hint=""; auth=in
if ! command -v 21st >/dev/null 2>&1; then
  cli_hint="    21st needs the CLI: npm i -g @21st-dev/cli   then   21st login"
else
  auth="$(twentyfirst_auth_state)"
fi

# ---- verdict -----------------------------------------------------------------
if [ "${#missing[@]}" -gt 0 ] || [ -n "$cli_hint" ]; then
  echo "design toolchain: INCOMPLETE"
  [ "${#missing[@]}" -gt 0 ] && echo "  off: ${missing[*]}"
  [ -n "$cli_hint" ] && echo "$cli_hint"
  if [ "$source" = flag ]; then
    echo "  → relaunch this conversation with a design profile:  cc <name> web"
  else
    echo "  → run:  bash ~/.claude/lib/profile.sh set web   (or: enable design)"
    echo "    then /reload-plugins"
  fi
  exit 10
fi
case "$auth" in
  out)
    echo "design toolchain: SIGN-IN REQUIRED — 21st CLI installed, not signed in"
    echo "  ask the user to run in this session:  ! 21st login  (browser flow)"
    echo "  then re-run this gate before any 21st step — never skip 21st silently"
    exit 12 ;;
  unknown:*)
    echo "design toolchain: READY BUT UNVERIFIED — 21st could not answer:" \
      "${auth#unknown:}"
    echo "  a CLI runtime/PATH problem (node under nvm?), not a sign-in problem"
    exit 11 ;;
esac
echo "design toolchain: READY — packs design + gstack-design + ui-ux-pro-max" \
  "on ($profile)"
exit 0
```

Run: `make test suite=lib/tests/design-tool-gate.test.sh` → `PASS=14 FAIL=0` (T1-T8 = 12 expects + T9 ×2).

- [ ] **Step 3: Prose** (as r1 Task 5 Step 5): `lib/design-gate.md` 28-30, 40-45, 59-63, 72-84, 104-108, 114-118, 196-216 → source of truth `current --plain`; required set = `NEEDED=` in the script; remedy `profile.sh set web` (or `enable design`) + `/reload-plugins`, or `cc <name> web` under a flag; 21st CLI required; no `claude` call. `skills/feat/SKILL.md:77`, `skills/bugfix/SKILL.md:61`, `skills/feat/test-prompts.json:3`: "to run `/profile design`" → "the remedy line it printed". `agents/plugin-advisor.md:167` likewise. Verify: `grep -rn '/profile design\|GATE-BLOCK\|show design --plain\|skill_status' lib/design-gate.md skills/feat skills/bugfix agents/plugin-advisor.md` → nothing.

- [ ] **Step 4: Commit**

```bash
git add lib/design-tool-gate.sh lib/tests/design-tool-gate.test.sh lib/design-gate.md skills/feat/SKILL.md skills/feat/test-prompts.json skills/bugfix/SKILL.md agents/plugin-advisor.md
git commit -m "feat(design-gate): the gate reads profile.sh current --plain; remedy is set web / enable design + reload, or a relaunch under --settings"
```

---

### Task 7: Plugin gate, probe, advisor, `/profile`, onboard, plugin-check

**Files:** rewrite `skills/profile/SKILL.md` (r1 Task 6 Step 1 text, plus the union note already there) and `skills/profile/test-prompts.json`; modify `lib/plugin-gate.md:18-19` (EXTERNAL check → "`PROFILE` block holds a `profile=` line"), `:24-26` (toggle-script bullet → `profile-sh=UNAVAILABLE`), `:60-90` (APPLY GATE: r1 text, stop at first rc ≠ 0, no rollback loop); `agents/plugin-probe.md:17-26` (two probes: `profile.sh -C "$PWD" current --plain`, `claude plugin list`), `:63` (`profile-sh: available|UNAVAILABLE`), `:72-74` (`PROFILE :` block verbatim, `PLUGINS :`; EXTERNAL deleted), `:83` (CHECKPOINT line: `profile-sh=` instead of `toggle-script=`); `agents/plugin-advisor.md:22` (input field list without EXTERNAL), `:272-328` (r1 "WRITING A PROFILE OR A PACK" table); `skills/onboard/SKILL.md:424` → `bash $HOME/.claude/lib/profile.sh -C "$PWD" current --plain 2>/dev/null | grep -q '^pack-gstack-dev=on'`, `:608` → same with `^pack-gstack-browser=on` (that check decides on live browser tools); `skills/plugin-check/SKILL.md:16`.

Verify: `grep -rn 'toggle-external\|toggle-script\|claude plugin enable\|profile.sh reset\|\.active-profile\|apply <name>\|EXTERNAL' lib/plugin-gate.md agents/plugin-probe.md agents/plugin-advisor.md skills/profile skills/onboard/SKILL.md skills/plugin-check/SKILL.md` → nothing (an `EXTERNAL` word used in another sense is fine; read the hits).

```bash
git add skills/profile lib/plugin-gate.md agents/plugin-probe.md agents/plugin-advisor.md skills/onboard/SKILL.md skills/plugin-check/SKILL.md
git commit -m "docs(plugin-gate): probe reads current --plain, advisor emits profile.sh set/enable, /profile rewritten for packs"
```

---

### Task 8: Hooks, doctor, Makefile, link.sh

**Files:** `hooks/statusline.sh:8, 23-34`, `hooks/session-start.sh:64-90, 292`, `lib/detect-plugins.sh:27-33`, `doctor.sh:116-124, 129-159`, `lib/doctor-vendored.sh`, `lib/doctor-skills.sh:37-62`, `lib/tests/doctor-vendored.test.sh`, `link.sh:78-85`, `Makefile:1, 32-45, 62-72`, new `lib/tests/statusline.test.sh`.

- [ ] **Step 1: Statusline test (failing)** — r1 text, with the fake `profile.sh` asserting `"$2" = "$FAKE_DIR"` and the statusline input `{"cwd": "<cwd>", "workspace": {"project_dir": "<FAKE_DIR>"}}`; cases local, flag `(conv)`, default, failing (`exit 2`), missing → `profile: ? |`.

- [ ] **Step 2: `hooks/statusline.sh`**: line 8 keeps `DIR` (`.cwd`, used for FOLDER and BRANCH at lines 9, 15-17: unchanged display); add right after it `PROJ=$(printf '%s' "$INPUT" | jq -r '.workspace.project_dir // .cwd // "."' 2>/dev/null)` (same input variable and fallback shape as line 8); lines 23-34 →

```bash
# Profile of this project and conversation: `profile.sh current --plain`
# (two jq calls) on the session's project dir. `(conv)` = a --settings
# conversation. Any failure → "?".
_plain="$(bash "$REPO/lib/profile.sh" -C "$PROJ" current --plain 2>/dev/null)" || _plain=""
PROFILE="$(sed -n 's/^profile=//p' <<<"$_plain" | head -1)"
[ -n "$PROFILE" ] || PROFILE="?"
[ "$(sed -n 's/^source=//p' <<<"$_plain" | head -1)" = flag ] && PROFILE="$PROFILE (conv)"
```

- [ ] **Step 3: `lib/detect-plugins.sh:27-33`** — reuse the banner's block when given, SIGPIPE-safe:

```bash
detect_gstack() {
  # gstack = the three packs; "on" = pack-gstack-dev on for this project and
  # conversation. PROFILE_PLAIN (session-start) avoids a second profile.sh run.
  local plain="${PROFILE_PLAIN:-}"
  [ -n "$plain" ] || plain="$(bash "$HOME/.claude/lib/profile.sh" -C "$PWD" \
    current --plain 2>/dev/null)" || return 1
  grep -q '^pack-gstack-dev=on' <<<"$plain"
}
```

`hooks/session-start.sh`: BEFORE the loop at line 70, compute `PROFILE_PLAIN="$(bash "$HOME/.claude/lib/profile.sh" -C "$PWD" current --plain 2>/dev/null)" || PROFILE_PLAIN=""; export PROFILE_PLAIN`; after line 90 build `PROFILE_ROW` from it (`flag` → `profile: <n> (conv)`, `local` → `profile: <n> (local)`, `default` → `profile: none (full), try /plugin-check`, else `profile: ? (profile.sh failed)`); replace line 292 with `printf "│  🎛 %-46s│\n" "$PROFILE_ROW"` (🎛 is a width-1 glyph where the other icons are width-2, hence 46, and `%-Ns` pads by bytes: keep the row ASCII) and check the right border aligns with the `🩺 make doctor` row (`bash hooks/session-start.sh | tail -4`). `unset PROFILE_PLAIN` at the end.

- [ ] **Step 4: doctor, its libs, link.sh, Makefile**

`doctor.sh:116-124` → the Packs section, pipefail-safe (counters stay in the parent shell):

```bash
echo "── Packs ──"
_pc="$(bash "$REPO/lib/pack-census.sh" --installed 2>&1)" && _pc_rc=0 || _pc_rc=$?
while read -r _w; do [ -n "$_w" ] && warn "${_w#WARN }"; done < <(grep '^WARN' <<<"$_pc" || true)
while read -r _r; do [ -n "$_r" ] && fail "${_r#RED }"; done < <(grep '^RED' <<<"$_pc" || true)
[ "$_pc_rc" -eq 0 ] && pass "$(tail -1 <<<"$_pc")"
unset _pc _pc_rc _w _r
```

(`pass`/`warn`/`fail`: use doctor.sh's helper names as defined at its top, lines ~10-14.) `doctor.sh:129-159`: delete the `.active-profile` resolution; call `check_vendored_skills "$REPO" "$HOME/.claude"`; then a Profiles section with three checks (the fragment invariants are in the census now): `~/.bashrc` sources `lib/cc.sh` (`grep -q 'lib/cc\.sh'`, else warn with the guarded line), `~/.bashrc` still has `alias cc=` or `dtach_claude` (warn: "remove them, the alias shadows cc()"), the working `settings.json` `enabledPlugins` equals `git -C "$REPO" show HEAD:settings.json | jq .enabledPlugins` (else warn "user-scope residue: `<diff>`; restore per MIGRATION 2.1.0 step 1"), and `settings.json` `model` is `opus` (else warn). Also, in the Packs section's RED handler nothing more is needed: the census line already says `rm skills/<x> (a flat link)`.

`lib/doctor-vendored.sh`: `check_vendored_skills <repo> <claude_home>` loses the profile parameter; delete `_dv_profile_has`, `_dv_valid_profile_name`, the parked branch of `_dv_check_link`, the header lines describing them; remedy "symlink missing/wrong — run: make link". `lib/tests/doctor-vendored.test.sh`: drop the parked / noprofile / traversal cases and the `active.profile` fixture. `lib/doctor-skills.sh:37-62`: the python glob adds `skills_dir + "/pack-*/skills/*/SKILL.md"`. `doctor.sh:590, 646` loops add `"$REPO"/skills/pack-*/skills/*/SKILL.md`.

`link.sh:78-85`: `EXTERNAL_SKILLS=(observability-and-instrumentation deprecation-and-migration ci-cd-and-automation brainstorming writing-plans subagent-driven-development test-driven-development requesting-code-review using-git-worktrees writing-skills)`; comment: the design and scroll skills are pack symlinks now.

`Makefile`: line 1 drops `profile-reset`; the `test` recipe's export line becomes `@export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null; unset CLAUDE_PROFILE CLAUDE_PROFILE_SETTINGS; \`; targets 62-72:

```make
profile: ## profile.sh on a project (usage: make profile cmd="set design" dir=/path/to/project; default: this repo)
	@bash lib/profile.sh -C "$(or $(dir),$(CURDIR))" $(cmd)
profile-list: ## List pack profiles (lib/profiles/*.json)
	@bash lib/profile.sh list
profile-current: ## Effective profile of a project (dir=…; default: this repo)
	@bash lib/profile.sh -C "$(or $(dir),$(CURDIR))" current
```

Run: `make test suite="lib/tests/statusline.test.sh lib/tests/doctor-vendored.test.sh"` → green; `bash doctor.sh 2>&1 | sed -n '/── Packs/,/── Profiles/p'` → one pass line, WARNs for uninstalled targets only, the Profiles warns for the bashrc (expected until the user step), doctor runs to its summary.

- [ ] **Step 5: Commit**

```bash
git add hooks/statusline.sh hooks/session-start.sh lib/detect-plugins.sh doctor.sh lib/doctor-vendored.sh lib/doctor-skills.sh lib/tests/doctor-vendored.test.sh lib/tests/statusline.test.sh link.sh Makefile
git commit -m "feat(hooks,doctor): statusline and banner read profile.sh current --plain once; doctor runs the pack census and checks cc.sh sourcing, user-scope residue and the opus default"
```

---

### Task 9: Installers write `skills-external/` only

**Files:** `install-plugins.sh` (Step 2 `./setup` guard at 351 + delete 361-367 + ok message 372; Step 8d 819-820, 860-906; hints 1001, 1057, 1074; Step 11 1264-1291 deleted; summary 1308, 1321-1322), `update-all.sh` (87-89, 94 guard, 117-120, 406-424, 455-473, 547), `plugins.lock.json:31`.

- [ ] **Step 1: gstack guard** (both installers), before `./setup`:

```bash
if [ -d "$HOME/.claude/skills/gstack" ] && [ ! -L "$HOME/.claude/skills/gstack" ]; then
  (cd "$GSTACK_DIR" && ./setup) && _gstack_setup_ok=1 || warn "gstack ./setup failed"
else
  warn "gstack: ~/.claude/skills/gstack is not the helper tree yet — run 'make link' first, then 'make plugin' (setup would write skill dirs into skills/)"
fi
```

Delete the `toggle-external.sh disable gstack` / status lines; ok message → `ok "GStack ready (packs pack-gstack-dev / -browser / -design; profile.sh set <profile>)"`.

- [ ] **Step 2: impeccable** (`install-plugins.sh` 819-906, `update-all.sh` 406-473): `IMP_SKILL_DIR="$REPO/skills/impeccable"` (the same directory the CLI writes through the `~/.claude/skills` symlink; spelled through `$REPO` so the census's `$HOME/.claude/skills/<pack skill>` pattern no longer matches a legitimate line) and `IMP_HOME="$REPO/skills-external/impeccable"` replaces `IMP_PARKED`; "already present" tests read `$IMP_HOME/SKILL.md`; after a successful install the park logic becomes

```bash
    cd "$REPO" && rm -rf skills-external/impeccable && mv "$IMP_SKILL_DIR" skills-external/impeccable
```

(literal relative path inside the repo; the installer `cd`s to `$REPO` at its top — check with `grep -n '^cd ' install-plugins.sh`, hence the explicit `cd "$REPO" &&` anyway). `IMP_WAS_PARKED` and its branch disappear; comments 804-806 say "moved to skills-external/impeccable (pack-design links it)".

- [ ] **Step 3: Hints, Step 11, summary, lock note**: 1001 and 1057 `toggle-external.sh enable higgsfield` → `bash lib/profile.sh enable higgsfield` then `/reload-plugins`; 1074 → "`skills/pack-design` (`21st-ui-build`, `21st-cli-use`) and `skills/pack-extras` link it"; Step 11 (1264-1291) deleted; 1308, 1321-1322 → `packs: bash lib/profile.sh set <profile> | enable <pack>, then /reload-plugins`; `plugins.lock.json:31` note → `profile.sh enable higgsfield`; `plugins.lock.json:92` and `install-plugins.sh:804` (impeccable notes citing `~/.claude/skills/impeccable`) → "`skills-external/impeccable`, linked by pack-design"; `install-plugins.sh:1328` (a third `~/.claude/skills/<x>/` echo next to 1326-1327) → the pack path; `update-all.sh:547` → "linked by pack-design / pack-extras". After this step `bash lib/pack-census.sh` prints no RED on `install-plugins.sh`, `update-all.sh` or `plugins.lock.json`.

- [ ] **Step 4: Verify and commit**

```bash
shellcheck install-plugins.sh update-all.sh && bash -n install-plugins.sh && bash -n update-all.sh
bash lib/pack-census.sh    # the census scans root *.sh: no RED citer left
git add install-plugins.sh update-all.sh plugins.lock.json
git commit -m "chore(install): installers fill skills-external only; impeccable moves to skills-external/impeccable; gstack setup needs the helper tree first; no default-profile step"
```

No live `make plugin` in this task.

---

### Task 10: Routing census, long-name rows, row → skill check

**Files:** `lib/skill-routing-census.py:26-30`, `mods/model-router/routing.json`, `lib/tests/effort-routing.test.sh`.

- [ ] **Step 1:** `ROOT_SUFFIXES` gains `"pack-*/skills/*/SKILL.md"`. Run `python3 -I lib/skill-routing-census.py` → no new FAIL.
- [ ] **Step 2:** For every rowed skill now in a pack (21st-ui-review, 21st-ai, 21st-ui-explore → extras; web-validate; seo, geo; site-motion, frontend-design, emil-design-eng, design-motion-principles, 21st-ui-build, 21st-cli-use → design; the five scroll names → scroll3d) ADD `"pack-<n>:<skill>": "<same phase>"` next to the short row (a typed `/pack-seo:seo` yields the long key; `Skill(seo)` may yield the short one). `21st-registry` and `21st-design-sync` rows stay (parked skills in `skills-external/`, no pack).
- [ ] **Step 3:** `lib/tests/effort-routing.test.sh`: after the skill → row loop (145-158) add a row → skill loop: every key of `routing.json` `skills` (short form, or the part after `pack-<n>:`) must resolve to `skills/<k>/SKILL.md`, `skills/pack-*/skills/<k>` (link or dir) or `skills-external/<k>/SKILL.md`; a long key `pack-<n>:<k>` must resolve to `skills/pack-<n>/skills/<k>`. Run: `make test suite="lib/tests/effort-routing.test.sh lib/tests/model-routing.test.sh"` → green.

The router's `skillDesc` reads `~/.claude/skills/<name>/SKILL.md` to decorate its confirm question; a pack skill gets no description (the documented fallback). Accepted, no mod change.

```bash
git add lib/skill-routing-census.py mods/model-router/routing.json lib/tests/effort-routing.test.sh
git commit -m "chore(routing): skill census globs pack skills; long-name rows for pack skills; every row resolves to a skill"
```

---

### Task 11: Docs, full suite

**Files:** `CLAUDE.global.md:272-280`, `README.md:159, 180, 188, 243, 384-398, 426-441, 486-495`, `USAGE.md:126, 174` + a paragraph after 217, `MIGRATION.md:190, 198` + section 2.1.0, `ARCHITECTURE.md:17, 33`, `CHANGELOG.md`, `rules/web-building.md:67-68`.

- [ ] **Step 1:** r1 Task 11 Step 1 text for CLAUDE.global.md and Step 2 for README / USAGE / ARCHITECTURE / CHANGELOG / web-building, with the `make profile` lines now `make profile cmd="set X" dir=/path` and `make profile-current dir=/path`.
- [ ] **Step 2: MIGRATION 2.1.0** (replaces r1's):

```markdown
### 2.1.0 — profiles and packs

Run on every machine that pulls this version (the live tree may still be in
an old profile; nothing below deletes a real directory).

1. `git pull`, then restore the user-scope plugins the old `profile.sh` had
   toggled: `git show HEAD:settings.json | jq .enabledPlugins > /tmp/ep.json
   && jq --slurpfile ep /tmp/ep.json '.enabledPlugins = $ep[0]' settings.json
   > /tmp/settings.next.json && cp /tmp/settings.next.json settings.json`
   (never `git checkout -- settings.json`: it would drop your UI writes).
2. Old layout: `find skills skills-disabled -maxdepth 1 -type l` lists the
   flat links; remove the ones `make doctor` names as duplicates (every
   `skills-disabled/` link, and in `skills/` everything except model-router
   (the tracked link to `mods/model-router`), darwin-skill,
   the seven superpowers and the agent-skills trio). If
   `skills-disabled/impeccable` is a directory: `mv skills-disabled/impeccable
   skills-external/impeccable`. Then `rmdir skills-disabled; rm -f
   .active-profile`.
3. `make link` (link.sh no longer links the design and scroll skills flat),
   `make plugin` (fills `skills-external/`; impeccable ends in
   `skills-external/impeccable`).
4. `~/.bashrc`: delete `dtach_claude()` and `alias cc='dtach_claude'` (the
   alias would shadow the function and drop the profile argument); add
   `[ -f "$HOME/.claude/lib/cc.sh" ] && . "$HOME/.claude/lib/cc.sh"`. New
   shell. `cc <name>` behaves as before; `cc <name> web` starts a conversation
   under `lib/profiles/web.json`.
5. Per project: `bash ~/.claude/lib/profile.sh set <profile>` then
   `/reload-plugins`. `lib/toggle-external.sh` is gone (`profile.sh enable
   higgsfield` replaces it).
6. `make doctor` until no warn; `make test`.
```

- [ ] **Step 3: Full suite, doctor**

```bash
make test        # all suites green
bash doctor.sh   # no fail; warns only for steps 4 of MIGRATION not done yet
```

(The zero-citer check is the census, inside `make test`; no ad-hoc grep.)

```bash
git add CLAUDE.global.md README.md USAGE.md MIGRATION.md ARCHITECTURE.md CHANGELOG.md rules/web-building.md
git commit -m "docs: profiles and packs (README, USAGE, MIGRATION 2.1.0 with the machine cleanup, ARCHITECTURE, CHANGELOG, global routing)"
```

---

### Task 12: Proof

Scratch `$HOME/.cache/claude-tmp/p5/t12` (literal in every call). Steps as r1 Task 12: two concurrent conversations in one project (`--settings dev.json` / `web.json` → different packs, higgsfield tools 0 vs 158); two projects with different local profiles (qa / seo); `enable seo` + `/reload-plugins` then `/seo …` and `/pack-seo:seo …` with `--max-turns 1 --tools ""`; plus the timing: `for i in 1 2 3 4 5; do /usr/bin/time -f %e bash lib/profile.sh current --plain >/dev/null; done` on this repo (record the median; spec target 50 ms). Record everything in `$HOME/.cache/claude-tmp/p5/FACTS.md`, this plan's § Facts and CHANGELOG. Interactive, the user: `/context` under `cc t full`, `cc t dev`, `cc t web` after the `.bashrc` step; `cc <name> web` on a real project (statusline `(conv)`, `/profile current` → `[conv web]`).

---

### Task 13: Listing budget (last)

- [ ] **Step 1: Measure** the ctxprobe bench (LRN-175) on `full` and `dev` at the default budget and at 40000 / 50000 / 60000; pick the smallest value with 0 name-only on `full`.
- [ ] **Step 2: Commit through the index, never the working file**

```bash
cd /home/bchanot/Documents/claude && S="$HOME/.cache/claude-tmp/p5"; mkdir -p "$S"
git show HEAD:settings.json | jq '.env.SLASH_COMMAND_TOOL_CHAR_BUDGET = "<value>"' > "$S/settings.index.json"
test -s "$S/settings.index.json" && git show HEAD:settings.json | diff - "$S/settings.index.json"   # expected: -1/+2 lines (ENABLE_STOP_REVIEW gains a comma, one key added)
git update-index --cacheinfo 100644,"$(git hash-object -w "$S/settings.index.json")",settings.json
git diff --cached --stat   # settings.json | 3 ++-   (-1/+2: one key added, the previous env line gains a comma)
git commit -m "feat(settings): SLASH_COMMAND_TOOL_CHAR_BUDGET=<value>: 0 name-only skills on full (+<n>k tokens), measured"
jq '.env.SLASH_COMMAND_TOOL_CHAR_BUDGET = "<value>"' settings.json > "$S/settings.work.json" && test -s "$S/settings.work.json" && cp "$S/settings.work.json" settings.json
git status --short settings.json   # ` M settings.json` (UI writes only)
```

CHANGELOG gets the per-profile numbers.

---

## Challenge summary (r1 → r2)

BLOCKER (correctness 1, robustness 1): the live tree is in `backend`, impeccable is a real dir under `skills-disabled/` → Task 2 Step 0 snapshot, Step 4 moves impeccable from either location and refuses a duplicate, Step 5 enumerates symlinks with `find -type l` and stops on any real dir, rollback = `layout-before.txt`.

MAJOR → change: user-scope residue `ui-ux-pro-max:false` (cor 6, rob 3) → Task 2 Step 7 + doctor warn (Task 8) + MIGRATION step 1 · doctor pipeline aborts under pipefail (cor 4, rob 2) → process substitution, counters in the parent · ~30 jq per `current` (rob 10, simp 4) → `lib/profile-state.jq`, two jq calls, T20 timing, `PROFILE_PLAIN` reused by `detect_gstack` · Task 13 `$S` undefined + `git checkout -- settings.json` (cor 9, rob 9, simp 5) → index-only recipe, literal scratch path everywhere · test precedence order (cor 2) → T6-project before `set devx` · test precondition (cor 3) → the current sanitised 21st check kept · old-path citers incomplete (cor 5, rob 18, cor 23) → Task 2 Step 8 list widened; census matches `~/` and `$HOME/` forms and scans root `*.sh` · plugin-gate sites (cor 8) → all four named in Task 7 · `$PWD` drift (cor 10, rob 6) → `find_root` walk-up in profile.sh, statusline `.workspace.project_dir // .cwd`, T19 · inherited `CLAUDE_PROFILE*` (cor 11, rob 5) → `unset` in every suite and the Makefile recipe · other machine (rob 4, cor 7) → MIGRATION steps 1-2, census says `rm skills/<x> (a flat link)`, `.active-profile` removed in Task 2 · transition window (rob 7) → Tasks 2-4 = one commit C1, snapshot + rollback · worktree (rob 8) → Global Constraint "no worktree" · profile census lost (simp 1) → fragment invariants in `lib/pack-census-fragments.jq`, doctor Profiles loop dropped · two citer censuses (simp 2) → one `check_citers` with the contract scope, Task 11 grep deleted · gstack-removed dead code (simp 3) → list created in Task 2, `.sh` reduced to a `mapfile`, suite deleted, census RED when the list is missing.

MINOR → change: router canary measures nothing + typed long slash never routed (cor 12, rob 17) → C1 dropped, long rows unconditional, row → skill test (simp 6, cor 22a) · SC1003 / SC2088 / widths / PASS counts / .gitignore anchors / `.gitignore` not scanned by `--include` / `\.profile` pattern / Task 13 diff shape / onboard :608 pack / banner overflow / `make profile` scope / `-e .git` / Review Focus names (cor 13-21, 24, 25) → fixed in place · T8-real install dependency (rob 16) → `--installed` flag, WARN in `make test` · Task 1 pack left behind (rob 11) → OFF pack via `--settings` + trap · `alias cc` (rob 12) → doctor warn, guarded source line · SIGPIPE in detect_gstack (rob 15) → here-string · unused knobs (simp 7) → `DESIGN_GATE_REPO_OVERRIDE`, `PACKS :`, `CC_LIB_DIR` dropped.

Deferred, human-ack: none. Not done, said why: `.git/info/exclude` for `settings.local.json` (rob 14): onboarded projects ignore it already; the Claude Code write race is documented in `/profile`, not solved. A hardcoded credential in a dotfile (rob 19, outside scope) was reported to the user (location withheld), no edit.

Lenses returned: correctness / robustness / simplicity.

## Confirmation pass (r2 → r3, correctness, FATAL(4) on r2)

BLOCKER 1 (the Step 5 keep list dropped `skills/model-router`, the tracked link that loads the router) → `model-router` added to the keep list in Global Constraints, Task 2 Step 5 (with an explicit "must NOT be in the list" check) and MIGRATION step 2. BLOCKER 2 (the census matched its own pattern line and the test's fixture strings; permanent legitimate citers in the installers) → bracketed-letter patterns, fixture strings moved to `lib/tests/fixtures/pack-census-old-citers.sh`, `IMP_SKILL_DIR` spelled through `$REPO`, `plugins.lock.json:92`, `install-plugins.sh:804` and `:1328` added to Task 9. MAJOR 3 (census RED on files later tasks rewrite) → Task 2 Step 9 and Task 4 Step 2 expectations corrected: `pack-census.test.sh` T11-real red from C1 until Task 11, every other suite green. MAJOR 4 (`-f "$REPO/…jq"` resolved against the fixture) → `FRAG_JQ` next to the script. MINOR 5-11 fixed in place: `$m` printed whole, `-nHo` on `.gitignore`, the stray `: > "$REMOVED.absent"` line and the amending notes removed, lines wrapped ≤ 80 bytes, `find_root` stops below `$HOME`, banner `%-46s` and a comma instead of `·`, design-gate precondition lines 20-27, statusline keeps `DIR` and adds `PROJ`, `.gstack/` named as kept, `--stat` shape `3 ++-`. Verified green by the confirmation run (no finding): profile-state.jq and profile.sh under jq 1.8.1 (profile.test.sh 51/52 before the width fix, 13 ms for `current`), cc.test.sh 18/18, the Step 7 restore dry run, the Task 13 index recipe, the doctor snippet under pipefail, the gstack setup guard. These r3 fixes were not re-challenged (one confirmation pass, per the challenge doctrine); the gate reviewer reads them as the human check.
