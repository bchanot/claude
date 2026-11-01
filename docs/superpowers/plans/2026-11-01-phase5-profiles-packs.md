# Phase 5 Profiles and Packs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the global symlink profile system with skills-dir packs switched per project (`.claude/settings.local.json`) and per conversation (`claude --settings lib/profiles/<n>.json`), and delete the old mechanism.

**Architecture:** Nine packs `skills/pack-<n>/` (manifest + tracked relative symlinks into `skills-external/`, five real skill dirs moved in). Eleven profiles `lib/profiles/<n>.json` are literal settings fragments. `lib/profile.sh` (bash + jq) merges a fragment into the project's local settings and reports the effective state; `lib/cc.sh` launches a conversation with a fragment as `--settings`; gates, hooks and doctor read `profile.sh current --plain`.

**Tech Stack:** bash 5, jq 1.8, python3 (census), Claude Code CLI 2.1.316 (skills-dir plugins, `enabledPlugins`, `deniedMcpServers`, `/reload-plugins`), `make test` suites `lib/tests/*.test.sh`.

**Spec:** `docs/superpowers/specs/2026-11-01-phase5-profiles-packs-design.md`. Facts: scratchpad `p5/FACTS.md` (copied in § Facts below). Contract: `.claude/tasks/contracts/2026-11-01-phase5-profiles-packs-1300.md`.

## Global Constraints

- Branch `feature/phase5-profiles-packs` (already started). Every commit on it; `gitflow finish` only on the user's signal. Never commit `settings.json` UI writes (`theme`, `switchModelsOnFlag`, `model`): stage files by name, never `git add -A`.
- Recursive delete only on a literal relative path inside the repo (CLAUDE.md § Destructive tools). `skills-disabled/` is gitignored: its 24 entries are untracked symlinks, removed with `rm` on literal paths, then `rmdir skills-disabled`.
- Nothing writes the user scope: no `claude plugin enable|disable`, no edit of `~/.claude/settings.json` by a script.
- Shell: `shellcheck` clean, 80 columns, 25 logic lines per function (strict code: our repo).
- Every rule, label, path or heading changed → patch every citer in the same commit (`make test` doctrine-citers census).
- Pack ids: `pack-<n>@skills-dir`; the manifest `name` equals the folder name. Managed plugin ids: `model-router@skills-dir`, `ui-ux-pro-max@ui-ux-pro-max-skill`, `security-guidance@claude-code-plugins`, `pr-review-toolkit@claude-code-plugins`, `example-skills@anthropic-agent-skills`, `brightdata-plugin@synced`.
- Connector names: `claude.ai higgsfield`, `claude.ai Higgsfield AI`.
- `impeccable` is NOT a tracked dir (spec § 1 says `git mv`; wrong): `impeccable skills install --scope=global` writes `skills/impeccable/` through the `~/.claude/skills` symlink, gitignored. The pack holds a symlink `../../../skills-external/impeccable`; the installer moves the fresh install there (Task 9). The skill resolves its scripts by `<skill-base-dir>`, so the move is safe.
- `skills/gstack/` (no SKILL.md, the shared helper tree linked by `lib/gstack-links.sh`) stays as is, outside the packs.
- Headless canaries run in the scratchpad `p5/`, never in the repo; they use `claude -p … --output-format stream-json --verbose` and read the `init` message (`plugins[]`, `skills[]`, `tools[]`, `mcp_servers[]`).

## Review Focus

1. `deniedMcpServers` is a UNION across settings files (docs; spike 3 measured one file at a time). A conversation `cc x web` over a project set to `dev` keeps the higgsfield connectors denied. `current` must model the union and print `custom`; Task 3's T-union test pins it, and `/profile` + USAGE say "to get the connectors back, `profile.sh set web` in the project".
2. A pack id present in a profile with no `skills/pack-<n>/` dir: `set` writes it, the CLI ignores it, `current` reports it from the local value. Task 3 T-missing pins `show` marking `missing` and `set` still writing.
3. A dangling pack symlink (installer not run) must not hide the pack's other skills. Task 1 canary C3 measures it; if it does, Task 2's census becomes red for ON packs with a dangling target (already the rule) and Task 9's installers run before `make test` in MIGRATION.
4. `settings.local.json` holding keys `profile.sh` does not manage (`permissions`, a `/model` write) must survive `set`/`unset` byte-for-byte except the managed keys. Task 3 T-keep pins it.
5. `hooks/statusline.sh` now runs `profile.sh current --plain` on every refresh: a missing `jq`, an unreadable `~/.claude.json` or a project with no `.claude/` must print a line, never an error. Task 7 T-statusline-nojq pins it.

## Facts (measured 2026-11-01, CLI 2.1.316, headless)

- A dir `~/.claude/skills/<pack>/` holding `.claude-plugin/plugin.json` loads as plugin `<name>@skills-dir` (`name` from the manifest). Nested `skills/<s>/SKILL.md` are listed ONCE as `<pack>:<s>`; `Skill(<s>)`, `Skill(<pack>:<s>)`, typed `/<s>` and `/<pack>:<s>` all resolve.
- Absent from every `enabledPlugins`: ON unless the manifest says `"defaultEnabled": false`. `.claude/settings.local.json` true/false obeyed; `--settings` false beats local true.
- `/reload-plugins` works in `-p` (stream-json input) and reloads skills + hooks of a pack after a local settings edit; a pack `.mcp.json` server needs a new session. In a `--settings` conversation the flag value is read once: neither an edit of the flag file nor a local true comes back through `/reload-plugins`.
- Connectors load under `-p`. `deniedMcpServers:[{serverName:"claude.ai <Name>"}]` per project drops the named ones (199 → 192 tools); `disableClaudeAiConnectors:true` drops all nine (26 tools), any-source-true. Both work via `--settings`. A `serverUrl` wildcard matches nothing. `--strict-mcp-config` drops connectors and project `.mcp.json` servers. The `/mcp` toggle writes `disabledMcpServers` per project in `~/.claude.json`.
- Tool budget of a bare project: 199 = 28 builtin + 1 model-router + 151 `claude.ai higgsfield` + 7 `Higgsfield AI` + 8 Claude Docs + 4 Indeed.
- model-router (`mods/model-router/hooks/register.ts`): `skillRow` matches `e.skill` (from `tool.call Skill` and `skill.prompt`) by EXACT key in `routing.json` `skills`; `typedSkill` takes the text after `/` up to a space. No `pack:` prefix handling.

## File Structure

| Path | Responsibility |
|---|---|
| `skills/pack-<n>/.claude-plugin/plugin.json` (9, new) | pack identity + `defaultEnabled` |
| `skills/pack-<n>/skills/<s>` (new) | tracked relative symlink, or the moved real dir (seo, geo, web-validate, site-motion) |
| `lib/profiles/<n>.json` (11, new) + `lib/profiles/README.md` | profile fragments + descriptions; `*.profile` deleted |
| `lib/profile.sh` (rewrite) | CLI: list, show, current, set, unset, enable, disable, diff; jq merge; no claude call |
| `lib/cc.sh` (new) | `cc <name> [profile]` launcher function |
| `lib/design-tool-gate.sh` (rewrite core) | reads `current --plain`; keeps the 21st sign-in probe |
| `lib/pack-census.sh` (new) | the pack census `make test` and doctor share |
| `lib/tests/profile.test.sh`, `cc.test.sh`, `pack-census.test.sh`, `design-tool-gate.test.sh` | hermetic suites |
| `hooks/session-start.sh`, `hooks/statusline.sh`, `doctor.sh`, `Makefile`, `.gitignore` | consumers |
| `lib/plugin-gate.md`, `lib/design-gate.md`, `agents/plugin-probe.md`, `agents/plugin-advisor.md`, `skills/profile/SKILL.md` | prose consumers |
| `install-plugins.sh`, `update-all.sh`, `lib/higgsfield-skills.sh`, `lib/gstack-removed.sh`, 21st installer | write `skills-external/` only |
| `lib/skill-routing-census.py`, `mods/model-router/routing.json` | pack glob; long-name rows if Task 1 says so |
| `CLAUDE.global.md`, `README.md`, `USAGE.md`, `MIGRATION.md`, `ARCHITECTURE.md`, `CHANGELOG.md` | docs |
| `settings.json` `env.SLASH_COMMAND_TOOL_CHAR_BUDGET` | last task |

---

### Task 1: Canaries that decide two design points (no repo change)

**Files:**
- Create (scratchpad only): `p5/t1/run.sh`, results appended to `p5/FACTS.md` and to this plan's § Facts.
- Modify (temporarily, reverted in the same task): `mods/model-router/routing.json`

**Interfaces:**
- Produces: FACT-ROUTER = `short` | `long` (the name model-router sees for a pack skill); FACT-DANGLING = `kept` | `hidden` (sibling skills of a dangling symlink). Task 2 and Task 10 read them.

- [ ] **Step 1: Build the scratch pack and project**

```bash
S=/tmp/claude-1000/-home-bchanot-Documents-claude/a1113f35-c77c-47c4-95de-a37231ae0306/scratchpad/p5
mkdir -p "$S/t1/proj" "$HOME/.claude/skills/pack-t1/.claude-plugin" \
  "$HOME/.claude/skills/pack-t1/skills/t1-alpha" "$S/t1/ext-beta"
printf '{"name":"pack-t1","version":"0.0.1","description":"canary"}\n' \
  > "$HOME/.claude/skills/pack-t1/.claude-plugin/plugin.json"
printf -- '---\nname: t1-alpha\ndescription: canary alpha\n---\nReply exactly T1-ALPHA-OK and stop.\n' \
  > "$HOME/.claude/skills/pack-t1/skills/t1-alpha/SKILL.md"
printf -- '---\nname: t1-beta\ndescription: canary beta\n---\nReply exactly T1-BETA-OK.\n' \
  > "$S/t1/ext-beta/SKILL.md"
ln -s "$S/t1/ext-beta" "$HOME/.claude/skills/pack-t1/skills/t1-beta"
ln -s /nonexistent/t1-gamma "$HOME/.claude/skills/pack-t1/skills/t1-gamma"
cd "$S/t1/proj" && git init -q && printf '# t1\n' > CLAUDE.md
```

(`~/.claude/skills` is the repo's `skills/` symlink: `skills/pack-t1` is untracked and gitignored by nothing, so it must be removed in Step 5.)

- [ ] **Step 2: C3 dangling symlink canary**

```bash
cd "$S/t1/proj" && claude -p 'say hi' --model haiku --output-format stream-json --verbose \
  2>"$S/t1/c3.err" | head -1 > "$S/t1/c3.jsonl"
python3 -I -c '
import json,sys; d=json.loads(open(sys.argv[1]).readline())
sk=[s for s in d["skills"] if s.startswith("pack-t1:")]; print("SKILLS", sk)
print("FACT-DANGLING", "kept" if "pack-t1:t1-alpha" in sk and "pack-t1:t1-beta" in sk else "hidden")' "$S/t1/c3.jsonl"
```

Expected: `SKILLS ['pack-t1:t1-alpha', 'pack-t1:t1-beta']` and `FACT-DANGLING kept` (a dangling entry has no SKILL.md to read). If `hidden`, record it: Task 2's census treats any dangling target as red (not only on ON packs) and MIGRATION says "run `make plugin` before `make test`".

- [ ] **Step 3: C1 router canary, temporary row**

```bash
cd /home/bchanot/Documents/claude
python3 -I - <<'EOF'
import json
p='mods/model-router/routing.json'; d=json.load(open(p))
d['skills']['t1-alpha']='mechanical'
json.dump(d,open(p,'w'),indent=2); open(p,'a').write('\n')
EOF
cd "$S/t1/proj"
printf '%s\n' \
 '{"type":"user","message":{"role":"user","content":"/t1-alpha"}}' \
 '{"type":"user","message":{"role":"user","content":"/route show"}}' \
 | claude -p --model haiku --input-format stream-json --output-format stream-json --verbose \
   2>"$S/t1/c1.err" > "$S/t1/c1.jsonl"
grep -o '"result":"[^"]*' "$S/t1/c1.jsonl" | head -3
grep -o 'skill [a-z0-9:-]*' "$S/t1/c1.jsonl" | sort -u
```

Expected: the first result holds `T1-ALPHA-OK`; `/route show` names the route label `skill t1-alpha` (FACT-ROUTER=short) or `skill pack-t1:t1-alpha` (FACT-ROUTER=long). No label at all → repeat with `Skill(pack-t1:t1-alpha)` typed as a prompt (`"content":"Use the Skill tool on pack-t1:t1-alpha"`) and read the label again; still nothing → FACT-ROUTER=`unknown`, Task 10 then adds BOTH names per row.

- [ ] **Step 4: Record the facts**

Append to `$S/FACTS.md` under `## Task 1 canaries` the two FACT lines with the command and the raw label line, and replace the two placeholders `FACT-ROUTER=?` / `FACT-DANGLING=?` in this plan's § Facts (last bullet below) with the values.

- [ ] **Step 5: Revert the temporary row and remove the scratch pack**

```bash
cd /home/bchanot/Documents/claude && git checkout -- mods/model-router/routing.json
rm skills/pack-t1/skills/t1-beta skills/pack-t1/skills/t1-gamma
rm skills/pack-t1/skills/t1-alpha/SKILL.md skills/pack-t1/.claude-plugin/plugin.json
rmdir skills/pack-t1/skills/t1-alpha skills/pack-t1/skills skills/pack-t1/.claude-plugin skills/pack-t1
git status --short   # expected: only ` M settings.json`
```

No commit: nothing in the repo changed.

- Facts from this task: `FACT-ROUTER=?` · `FACT-DANGLING=?`

---

### Task 2: Packs on disk, flat links removed, pack census

**Files:**
- Create: `skills/pack-{design,scroll3d,seo,web-validate,gstack-dev,gstack-browser,gstack-design,higgsfield,extras}/.claude-plugin/plugin.json`
- Create: the symlinks listed in Step 2; `git mv` four dirs
- Create: `lib/pack-census.sh`, `lib/tests/pack-census.test.sh`
- Modify: `.gitignore` (lines 3-62 gstack block, 64-75 external block, 98-107 21st/higgsfield globs, 118-119 skills-disabled)
- Delete (untracked): the flat symlinks in `skills/`, `skills-disabled/`

**Interfaces:**
- Produces: `bash lib/pack-census.sh [--repo <dir>]` → prints one line per finding, `PACKS OK <n packs> <m skills>` on success, rc 0; rc 1 with `RED <reason>` lines; rc 0 with `WARN <reason>` lines for dangling targets on OFF packs. Doctor (Task 7) and the test call it.
- Produces: pack folder names (`pack-design`…) that Task 3's fragments and Task 5's gate use.

- [ ] **Step 1: Write the failing census test**

`lib/tests/pack-census.test.sh`:

```bash
#!/usr/bin/env bash
# lib/tests/pack-census.test.sh — the pack layout `skills/pack-<n>/` is
# consistent: one manifest per pack whose name is the folder, every skill
# entry resolves (dangling allowed only on a pack OFF by manifest → WARN),
# no skill listed twice across packs and core, the nine retired gstack
# skills absent, no citer left on a moved skill's old path. Hermetic on a
# fixture; then the same census on the real repo.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
check_has() { case "$2" in *"$3"*) pass=$((pass+1));; *) fail=$((fail+1));
  printf 'FAIL %s: [%s] does not contain [%s]\n' "$1" "$2" "$3";; esac; }

FX="$(mktemp -d)"; trap 'rm -rf "$FX"' EXIT
mk_pack() { # name defaultEnabled skill...
  local n="$1" d="$2"; shift 2
  mkdir -p "$FX/skills/pack-$n/.claude-plugin" "$FX/skills/pack-$n/skills"
  printf '{"name":"pack-%s","version":"1.0.0","defaultEnabled":%s}\n' "$n" "$d" \
    > "$FX/skills/pack-$n/.claude-plugin/plugin.json"
  for s in "$@"; do
    mkdir -p "$FX/skills-external/$s"; touch "$FX/skills-external/$s/SKILL.md"
    ln -s "../../../skills-external/$s" "$FX/skills/pack-$n/skills/$s"
  done
}
mkdir -p "$FX/skills/core-a" "$FX/lib"; touch "$FX/skills/core-a/SKILL.md"
printf 'gs-dead\n' > "$FX/lib/gstack-removed.list"
mk_pack alpha true a1 a2
mk_pack beta false b1

out="$(bash "$ROOT/lib/pack-census.sh" --repo "$FX" 2>&1)"; rc=$?
check T1-green-rc "$rc" 0
check_has T1-green "$out" "PACKS OK 2 packs 3 skills"

# dangling on an OFF pack → WARN, rc 0
rm -r "$FX/skills-external/b1"
out="$(bash "$ROOT/lib/pack-census.sh" --repo "$FX" 2>&1)"; rc=$?
check T2-off-dangling-rc "$rc" 0
check_has T2-off-dangling "$out" "WARN pack-beta: b1 target missing (pack OFF, installer not run)"

# dangling on an ON pack → RED, rc 1
rm -r "$FX/skills-external/a2"
out="$(bash "$ROOT/lib/pack-census.sh" --repo "$FX" 2>&1)"; rc=$?
check T3-on-dangling-rc "$rc" 1
check_has T3-on-dangling "$out" "RED pack-alpha: a2 target missing"
mkdir -p "$FX/skills-external/a2"; touch "$FX/skills-external/a2/SKILL.md"

# manifest name ≠ folder → RED
sed -i.bak 's/"pack-alpha"/"pack-alpho"/' "$FX/skills/pack-alpha/.claude-plugin/plugin.json"
out="$(bash "$ROOT/lib/pack-census.sh" --repo "$FX" 2>&1)"; rc=$?
check T4-name-rc "$rc" 1
check_has T4-name "$out" "RED pack-alpha: manifest name is pack-alpho"
mv "$FX/skills/pack-alpha/.claude-plugin/plugin.json.bak" "$FX/skills/pack-alpha/.claude-plugin/plugin.json"

# a skill both flat and in a pack → RED
mkdir -p "$FX/skills/a1"; touch "$FX/skills/a1/SKILL.md"
out="$(bash "$ROOT/lib/pack-census.sh" --repo "$FX" 2>&1)"; rc=$?
check T5-dup-rc "$rc" 1
check_has T5-dup "$out" "RED a1 listed twice: skills/a1 and pack-alpha"
rm -r "$FX/skills/a1"

# a retired gstack skill in a pack → RED
ln -s "../../../skills-external/a1" "$FX/skills/pack-alpha/skills/gs-dead"
out="$(bash "$ROOT/lib/pack-census.sh" --repo "$FX" 2>&1)"; rc=$?
check T6-retired-rc "$rc" 1
check_has T6-retired "$out" "RED pack-alpha: gs-dead is a retired gstack skill"
rm "$FX/skills/pack-alpha/skills/gs-dead"

# a citer of a moved skill's old path → RED
mkdir -p "$FX/skills/pack-alpha/skills/moved" "$FX/hooks"; touch "$FX/skills/pack-alpha/skills/moved/SKILL.md"
printf 'Read ~/.claude/skills/moved/SKILL.md\n' > "$FX/hooks/x.sh"
out="$(bash "$ROOT/lib/pack-census.sh" --repo "$FX" 2>&1)"; rc=$?
check T7-citer-rc "$rc" 1
check_has T7-citer "$out" "RED hooks/x.sh cites ~/.claude/skills/moved"

# real repo: green (packs built in this task)
out="$(bash "$ROOT/lib/pack-census.sh" 2>&1)"; rc=$?
check T8-real-rc "$rc" 0
check_has T8-real "$out" "PACKS OK 9 packs"

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run it, expect every check to fail**

Run: `make test suite=lib/tests/pack-census.test.sh`
Expected: `FAIL T1-green-rc` … (no `lib/pack-census.sh`), suite red.

- [ ] **Step 3: Write `lib/pack-census.sh`**

```bash
#!/usr/bin/env bash
# ============================================================
# lib/pack-census.sh — consistency census of the pack layout
#
# Packs are skills-dir plugins `skills/pack-<n>/` (manifest
# `.claude-plugin/plugin.json`, entries `skills/<s>` = tracked relative
# symlink into skills-external/ or a real dir). Shared by `make test`
# (lib/tests/pack-census.test.sh) and doctor.sh.
#
# Prints RED/WARN lines, then `PACKS OK <p> packs <s> skills` when no RED.
# Exit: 0 clean or WARN only · 1 any RED.
# Usage: pack-census.sh [--repo <dir>]
# ============================================================
set -euo pipefail

REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ "${1:-}" = "--repo" ] && REPO="$2"
SKILLS="$REPO/skills"
REMOVED="$REPO/lib/gstack-removed.list"
red=0; packs=0; skills=0
declare -A seen

red() { echo "RED $*"; red=1; }

pack_on() { # $1 pack dir → 0 when ON by manifest (absent key = ON)
  jq -e '.defaultEnabled != false' "$1/.claude-plugin/plugin.json" >/dev/null
}

check_manifest() { # $1 pack dir
  local n m; n="$(basename "$1")"; m="$1/.claude-plugin/plugin.json"
  [ -f "$m" ] || { red "$n: no .claude-plugin/plugin.json"; return; }
  jq -e . "$m" >/dev/null 2>&1 || { red "$n: manifest is not JSON"; return; }
  local name; name="$(jq -r '.name // ""' "$m")"
  [ "$name" = "$n" ] || red "$n: manifest name is $name"
}

check_entry() { # $1 pack dir, $2 entry path
  local n s; n="$(basename "$1")"; s="$(basename "$2")"
  if [ ! -e "$2/SKILL.md" ]; then
    if pack_on "$1"; then red "$n: $s target missing"
    else echo "WARN $n: $s target missing (pack OFF, installer not run)"; fi
  fi
  if [ -f "$REMOVED" ] && grep -qx "$s" "$REMOVED"; then
    red "$n: $s is a retired gstack skill"
  fi
  if [ -n "${seen[$s]:-}" ]; then red "$s listed twice: ${seen[$s]} and $n"
  else seen[$s]="$n"; fi
  skills=$((skills+1))
}

check_citers() { # $@ pack skill names: one grep, a hit per file and name
  local args=() n hit
  for n in "$@"; do args+=(-e "~/.claude/skills/$n/" -e "~/.claude/skills/$n\b"); done
  hit="$(grep -rno --include='*.sh' --include='*.md' --include='*.py' \
    --include='*.json' "${args[@]}" "$REPO/hooks" "$REPO/lib" "$REPO/agents" \
    "$REPO/skills" "$REPO/rules" "$REPO/CLAUDE.global.md" "$REPO/README.md" \
    "$REPO/USAGE.md" "$REPO/ARCHITECTURE.md" 2>/dev/null \
    | grep -v "/skills/pack-" | sed 's#:[0-9]*:#\t#' | sort -u || true)"
  [ -n "$hit" ] || return 0
  while IFS=$'\t' read -r f m; do red "${f#"$REPO"/} cites ${m%/}"; done <<<"$hit"
}

for d in "$SKILLS"/*/; do
  d="${d%/}"; s="$(basename "$d")"
  case "$s" in pack-*) continue ;; esac
  [ -f "$d/SKILL.md" ] && seen[$s]="skills/$s"
done
names=()
for p in "$SKILLS"/pack-*/; do
  p="${p%/}"; packs=$((packs+1)); check_manifest "$p"
  for e in "$p"/skills/*; do
    [ -e "$e" ] || [ -L "$e" ] || continue
    check_entry "$p" "$e"; names+=("$(basename "$e")")
  done
done
[ "${#names[@]}" -gt 0 ] && check_citers "${names[@]}"
[ "$red" -eq 0 ] && echo "PACKS OK $packs packs $skills skills"
exit "$red"
```

`grep -rn` does not follow the symlinked entries of `skills/` (only `-R` would), so `skills-external/` content is not scanned through them. The main loop is one function over 25 logic lines if folded into `main`; keep it top-level as written.

`lib/gstack-removed.list` does not exist yet: Task 9 extracts it from `lib/gstack-removed.sh`. Until then the census skips the retired check on the real repo (T6 uses the fixture). Note the test's T1 expects `3 skills` for a1, a2, b1.

- [ ] **Step 4: Build the packs**

```bash
cd /home/bchanot/Documents/claude
mk() { mkdir -p "skills/pack-$1/.claude-plugin" "skills/pack-$1/skills"
  printf '{\n  "name": "pack-%s",\n  "version": "1.0.0",\n  "description": "%s",\n  "author": { "name": "bchanot" },\n  "defaultEnabled": %s\n}\n' \
    "$1" "$2" "$3" > "skills/pack-$1/.claude-plugin/plugin.json"; }
mk design   "Design and UI skills: impeccable, Emil design eng, frontend-design, motion, 21st build + CLI, site-motion." true
mk scroll3d "Scroll-driven and Three.js world skills (Mengto set)." true
mk seo      "SEO and GEO audit skills." true
mk web-validate "W3C and WCAG conformance skill." true
mk gstack-dev "gstack engineering skills: review, investigate, codex, cso, health, freeze, retro, spec, skillify, office-hours, plan reviews, document-release." true
mk gstack-browser "gstack browser tooling: browse, scrape, qa, benchmark, canary." true
mk gstack-design "gstack design pipeline: design-review, design-consultation, design-html, plan-design-review." true
mk higgsfield "Higgsfield media generation skills (paid runs). OFF by default: profile.sh enable higgsfield." false
mk extras   "Occasional skills: diagram, make-pdf, 21st-ai, 21st-ui-explore, 21st-ui-review. OFF by default." false
ext() { ln -s "../../../skills-external/$2" "skills/pack-$1/skills/$2"; }
gst() { ln -s "../../../skills-external/gstack/$2" "skills/pack-$1/skills/$2"; }
for s in impeccable emil-design-eng frontend-design design-motion-principles 21st-ui-build 21st-cli-use; do ext design "$s"; done
git mv skills/site-motion skills/pack-design/skills/site-motion
for s in scroll-world-storytelling build-threejs-scroll-worlds scroll-scrubbed-visual-sequence scroll-scrubbed-word-reveal scroll-progress-timeline; do ext scroll3d "$s"; done
git mv skills/seo skills/pack-seo/skills/seo
git mv skills/geo skills/pack-seo/skills/geo
git mv skills/web-validate skills/pack-web-validate/skills/web-validate
for s in review investigate codex cso health freeze unfreeze retro spec skillify office-hours plan-eng-review plan-ceo-review plan-devex-review document-release; do gst gstack-dev "$s"; done
for s in browse open-gstack-browser setup-browser-cookies scrape qa qa-only benchmark canary; do gst gstack-browser "$s"; done
for s in design-review design-consultation design-html plan-design-review; do gst gstack-design "$s"; done
for s in higgsfield-brandkit higgsfield-generate higgsfield-marketplace-cards higgsfield-product-photoshoot higgsfield-soul-id higgsfield-video-explainer higgsfield-websites higgsfield-youtube-thumbnail; do ext higgsfield "$s"; done
gst extras diagram; gst extras make-pdf
for s in 21st-ai 21st-ui-explore 21st-ui-review; do ext extras "$s"; done
# impeccable: move today's global install under skills-external (Task 9 makes the installer do it)
mv skills/impeccable skills-external/impeccable
```

- [ ] **Step 5: Remove the flat links and `skills-disabled/` (untracked symlinks, literal paths)**

```bash
cd /home/bchanot/Documents/claude
rm skills/emil-design-eng skills/frontend-design skills/design-motion-principles skills/21st-ui-build skills/21st-cli-use
rm skills/scroll-world-storytelling skills/build-threejs-scroll-worlds skills/scroll-scrubbed-visual-sequence skills/scroll-scrubbed-word-reveal skills/scroll-progress-timeline
rm skills/review skills/investigate skills/codex skills/cso skills/health skills/freeze skills/unfreeze skills/retro skills/spec skills/skillify skills/office-hours skills/plan-eng-review skills/plan-ceo-review skills/plan-devex-review skills/document-release
rm skills/browse skills/open-gstack-browser skills/setup-browser-cookies skills/scrape skills/qa skills/qa-only skills/benchmark skills/canary
rm skills/design-review skills/design-consultation skills/design-html skills/plan-design-review
rm skills-disabled/21st-ai skills-disabled/21st-design-sync skills-disabled/21st-registry skills-disabled/21st-ui-explore skills-disabled/21st-ui-review
rm skills-disabled/gstack__benchmark-models skills-disabled/gstack__careful skills-disabled/gstack__connect-chrome skills-disabled/gstack__context-restore skills-disabled/gstack__context-save skills-disabled/gstack__design-shotgun skills-disabled/gstack__document-generate skills-disabled/gstack__landing-report skills-disabled/gstack__learn skills-disabled/gstack__pair-agent skills-disabled/gstack__plan-tune
rm skills-disabled/higgsfield-brandkit skills-disabled/higgsfield-generate skills-disabled/higgsfield-marketplace-cards skills-disabled/higgsfield-product-photoshoot skills-disabled/higgsfield-soul-id skills-disabled/higgsfield-video-explainer skills-disabled/higgsfield-websites skills-disabled/higgsfield-youtube-thumbnail
rmdir skills-disabled
ls skills-disabled 2>&1 | head -1   # expected: No such file or directory
```

The eleven `gstack__*` names above are the ones `ls skills-disabled` printed on 2026-11-01; run `ls skills-disabled` first and use its exact names (an `rm` on a name that is not there fails loudly, which is fine).

- [ ] **Step 6: `.gitignore`**

Replace the block from the line `# GStack skill symlinks — auto-created by gstack setup` (line 3) through the line `skills/darwin-skill` (line 84, end of the "External skill symlinks" / superpowers blocks) with:

```gitignore
# gstack's shared helper tree (bin/, browse/dist/, ETHOS.md…), linked by
# lib/gstack-links.sh; no SKILL.md inside. The gstack skills themselves live
# in packs skills/pack-gstack-*/ as tracked symlinks into the submodule.
skills/gstack

# Core external skills linked flat by link.sh (symlinks, machine-owned)
skills/ci-cd-and-automation
skills/deprecation-and-migration
skills/observability-and-instrumentation
skills/brainstorming
skills/writing-plans
skills/subagent-driven-development
skills/test-driven-development
skills/requesting-code-review
skills/using-git-worktrees
skills/writing-skills
skills/darwin-skill
```

Replace lines 86-89 (the impeccable block) with:

```gitignore
# Impeccable — `impeccable skills install --scope=global` writes
# skills/impeccable/ through the ~/.claude/skills symlink; install-plugins.sh
# moves it to skills-external/impeccable (pack-design links it). Machine-owned.
skills/impeccable
skills-external/impeccable/
```

Delete lines 98-107 (the `skills/21st-*` and `skills/higgsfield-*` blocks with their comments) and lines 118-119 (`# Staging area used by lib/toggle-external.sh…` + `skills-disabled/`). Keep `skills-external/21st-*/`, `skills-external/higgsfield-*/` and the other `skills-external/` lines.

- [ ] **Step 6b: Patch the citers of the moved paths**

Tests that hardcode the old paths (red after the move otherwise): `lib/tests/seo-geo-contract.test.sh:16` (`skills/seo/SKILL.md`, `skills/geo/SKILL.md`), `lib/tests/model-routing.test.sh:34` (`skills/web-validate/SKILL.md`) and `:169-176` (seo, geo), `lib/seo-data/seo-data.test.sh:542-554` (`$REPO/skills/seo/SKILL.md`), `lib/tests/doctrine-citers.test.sh:190, 196` (`skills/impeccable/*` → `skills-external/impeccable/*`): replace `skills/seo/` by `skills/pack-seo/skills/seo/`, `skills/geo/` by `skills/pack-seo/skills/geo/`, `skills/web-validate/` by `skills/pack-web-validate/skills/web-validate/`. Prose citers the census flags: `agents/client-handover-writer.md:272, 429` (`~/.claude/skills/seo/SKILL.md` → `~/.claude/skills/pack-seo/skills/seo/SKILL.md`), `:682` (`~/.claude/skills/web-validate/SKILL.md` → `~/.claude/skills/pack-web-validate/skills/web-validate/SKILL.md`), `agents/plugin-advisor.md:222` (`~/.claude/skills/impeccable` → `~/.claude/skills/pack-design/skills/impeccable`). Run: `make test suite="lib/tests/seo-geo-contract.test.sh lib/tests/model-routing.test.sh lib/seo-data/seo-data.test.sh lib/tests/doctrine-citers.test.sh"` → green.

- [ ] **Step 7: Run the census and the suite**

Run: `bash lib/pack-census.sh && make test suite=lib/tests/pack-census.test.sh`
Expected: `PACKS OK 9 packs 55 skills` (7+5+2+1+15+8+4+8+5), `PASS=18 FAIL=0`. A `WARN pack-higgsfield: … (pack OFF, installer not run)` line is acceptable when `skills-external/higgsfield-*` are absent on this machine. A RED on a citer of a moved skill (`~/.claude/skills/seo/`…) names the file: patch that citer to the pack path `~/.claude/skills/pack-seo/skills/seo/` in this task (Task 9 covers the installers and CLAUDE.global.md, but a RED here is fixed here).

- [ ] **Step 8: Headless check that the packs load**

```bash
cd "$S/t1/proj" && claude -p 'say hi' --model haiku --output-format stream-json --verbose 2>/dev/null | head -1 > "$S/t2.jsonl"
python3 -I -c '
import json,sys; d=json.loads(open(sys.argv[1]).readline())
print(sorted(p["name"] for p in d["plugins"] if p["name"].startswith("pack-")))
print(len(d["skills"]), [s for s in d["skills"] if s.startswith("pack-seo:") or s == "pack-design:emil-design-eng"])' "$S/t2.jsonl"
```

Expected: the seven ON packs listed (`pack-design`, `pack-gstack-browser`, `pack-gstack-design`, `pack-gstack-dev`, `pack-scroll3d`, `pack-seo`, `pack-web-validate`), no `pack-higgsfield`/`pack-extras`, and `['pack-design:emil-design-eng', 'pack-seo:geo', 'pack-seo:seo']` (a relative symlink entry and two moved real dirs both list).

- [ ] **Step 9: Commit**

```bash
git add .gitignore lib/pack-census.sh lib/tests/pack-census.test.sh lib/tests/seo-geo-contract.test.sh lib/tests/model-routing.test.sh lib/seo-data/seo-data.test.sh lib/tests/doctrine-citers.test.sh agents/client-handover-writer.md agents/plugin-advisor.md skills/pack-design skills/pack-scroll3d skills/pack-seo skills/pack-web-validate skills/pack-gstack-dev skills/pack-gstack-browser skills/pack-gstack-design skills/pack-higgsfield skills/pack-extras
git status --short | grep -v '^ M settings.json'   # expect: only A/R lines for the above
git commit -m "feat(packs): nine skills-dir packs under skills/pack-*, flat links and skills-disabled removed, pack census"
```

The old profile suites (`profile-census`, `profile-default`, `profile-set-managed`, `design-tool-gate`, `gstack-links`, `design-toolchain-reminder`, `higgsfield`, `toggle-external-repo-resolution`) are red from this commit until Tasks 3, 5, 8 and 9 rewrite or delete them; `make test` is green again at the end of Task 9. Run single suites until then.

---

### Task 3: Profile fragments and `lib/profile.sh`

**Files:**
- Create: `lib/profiles/{full,max,minimal,dev,backend,design,web,web-full,seo,qa,audit}.json`, `lib/profiles/README.md`
- Delete: `lib/profiles/*.profile` (11 files, `git rm`)
- Rewrite: `lib/profile.sh`
- Create: `lib/tests/profile.test.sh`; delete `lib/tests/profile-default.test.sh`, `lib/tests/profile-set-managed.test.sh`, `lib/tests/profile-census.test.sh` (`git rm`)

**Interfaces:**
- Consumes: pack folder names from Task 2 (`pack-<n>`), manifest `defaultEnabled`.
- Produces: `bash lib/profile.sh [-C <dir>] list|show <n>|current [--plain]|set <n>|unset|enable <x>|disable <x>|diff <n>`; env overrides `PROFILE_REPO_OVERRIDE`, `PROFILE_USER_SETTINGS`, `PROFILE_CLAUDE_JSON`; reads `CLAUDE_PROFILE_SETTINGS` / `CLAUDE_PROFILE` (Task 4 exports them). `current --plain` lines, in this order: `profile=<name|custom>`, `source=flag|local|default`, `flag=<CLAUDE_PROFILE|->`, then `pack-<n>=on|off` for every pack sorted by id, then `plugin:<id>=on|off` for every managed plugin sorted by id, then `connector:<name>=denied` per denied name, `connector:*=denied` when `disableClaudeAiConnectors` is true anywhere, then `model=<m|->`, `model-source=flag|local|project|user|-`, `mcp-off=-|<a,b>|unknown`. Exit 2 on every refusal, nothing written.

- [ ] **Step 1: Write the fragments**

Run once (not kept in the repo):

```bash
cd /home/bchanot/Documents/claude && python3 -I - <<'EOF'
import json, pathlib
PACKS = ["design","scroll3d","seo","web-validate","gstack-dev","gstack-browser",
         "gstack-design","higgsfield","extras"]
DENY = [{"serverName": "claude.ai higgsfield"}, {"serverName": "claude.ai Higgsfield AI"}]
# name: (packs on, ui-ux-pro-max, pr-review-toolkit, deny connectors)
P = {
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
    ep.update({"ui-ux-pro-max@ui-ux-pro-max-skill": ui,
               "security-guidance@claude-code-plugins": True,
               "pr-review-toolkit@claude-code-plugins": pr,
               "example-skills@anthropic-agent-skills": False,
               "brightdata-plugin@synced": False})
    d = {"enabledPlugins": ep}
    if deny: d["deniedMcpServers"] = DENY
    pathlib.Path(f"lib/profiles/{name}.json").write_text(json.dumps(d, indent=2) + "\n")
EOF
git rm -q lib/profiles/audit.profile lib/profiles/backend.profile lib/profiles/design.profile lib/profiles/dev.profile lib/profiles/full.profile lib/profiles/max.profile lib/profiles/minimal.profile lib/profiles/qa.profile lib/profiles/seo.profile lib/profiles/web-full.profile lib/profiles/web.profile
ls lib/profiles   # 11 .json
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
defaults = `full` with the connectors present.

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

Managed plugins in every fragment: `model-router@skills-dir` and
`security-guidance@claude-code-plugins` true everywhere;
`example-skills@anthropic-agent-skills` and `brightdata-plugin@synced` false
everywhere; `ui-ux-pro-max@ui-ux-pro-max-skill` and
`pr-review-toolkit@claude-code-plugins` per profile. Add your own profile as
another `<name>.json` with the same key set and a line above.
```

- [ ] **Step 2: Write the failing suite `lib/tests/profile.test.sh`**

```bash
#!/usr/bin/env bash
# lib/tests/profile.test.sh — lib/profile.sh on a fixture repo: fragments,
# the four precedence levels, the deniedMcpServers union, set/unset/enable/
# disable merge semantics, refusals (rc 2, nothing written), /mcp toggle
# reading. Hermetic: PROFILE_REPO_OVERRIDE + PROFILE_USER_SETTINGS +
# PROFILE_CLAUDE_JSON; no claude binary involved.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
check_has() { case "$2" in *"$3"*) pass=$((pass+1));; *) fail=$((fail+1));
  printf 'FAIL %s: [%s] does not contain [%s]\n' "$1" "$2" "$3";; esac; }
check_not() { case "$2" in *"$3"*) fail=$((fail+1));
  printf 'FAIL %s: [%s] unexpectedly contains [%s]\n' "$1" "$2" "$3";; *) pass=$((pass+1));; esac; }

FX="$(mktemp -d)"; trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/lib/profiles" "$FX/skills" "$FX/proj/.claude" "$FX/home"
cp "$ROOT/lib/profile.sh" "$FX/lib/"
mk_pack() { mkdir -p "$FX/skills/pack-$1/.claude-plugin"
  printf '{"name":"pack-%s","defaultEnabled":%s}\n' "$1" "$2" \
    > "$FX/skills/pack-$1/.claude-plugin/plugin.json"; }
mk_pack a true; mk_pack b false   # pack-c has no dir (missing)
frag() { # name pack-a pack-b pack-c ui deny(yes|no) [model]
  local d="" m=""
  [ "$6" = yes ] && d=', "deniedMcpServers": [{"serverName": "claude.ai X"}, {"serverName": "claude.ai Y"}]'
  [ -n "${7:-}" ] && m=", \"model\": \"$7\""
  printf '{"enabledPlugins": {"model-router@skills-dir": true, "pack-a@skills-dir": %s, "pack-b@skills-dir": %s, "pack-c@skills-dir": %s, "ui@mk": %s}%s%s}\n' \
    "$2" "$3" "$4" "$5" "$d" "$m" > "$FX/lib/profiles/$1.json"; }
# fullx: a on, ui on, no deny · devx: a on, ui off, deny · minix: all off, deny, model haiku
frag fullx true false false true no
frag devx true false false false yes
frag minix false false false false yes haiku
printf -- '- **fullx**: everything\n- **devx**: dev only\n- **minix**: nothing\n' > "$FX/lib/profiles/README.md"
printf '{"enabledPlugins": {"ui@mk": true}}\n' > "$FX/home/settings.json"
printf '{}\n' > "$FX/home/claude.json"
printf '# proj\n' > "$FX/proj/CLAUDE.md"

P() { PROFILE_REPO_OVERRIDE="$FX" PROFILE_USER_SETTINGS="$FX/home/settings.json" \
      PROFILE_CLAUDE_JSON="$FX/home/claude.json" bash "$FX/lib/profile.sh" -C "$FX/proj" "$@"; }
plain() { P current --plain | tr '\n' ' '; }
local_json() { cat "$FX/proj/.claude/settings.local.json"; }

# list / show
out="$(P list)"; check_has T1-list "$out" "dev only"; check_has T1-list-name "$out" "devx"
out="$(P show devx)"; check_has T2-show-on "$out" "pack-a@skills-dir"
check_has T2-show-missing "$out" "off  missing (no skills/pack-c/)"
check_has T2-show-deny "$out" "connectors denied: claude.ai X, claude.ai Y"

# default: manifests + user settings = fullx
out="$(plain)"
check_has T3-default-profile "$out" "profile=fullx source=default flag=- "
check_has T3-default-packs "$out" "pack-a=on pack-b=off pack-c=off plugin:model-router@skills-dir=on plugin:ui@mk=on "
check_has T3-default-tail "$out" "model=- model-source=- mcp-off=-"
out="$(P current)"; check_has T3-human "$out" "profile: fullx [default]"

# set keeps the other keys, writes the managed ones
printf '{"permissions": {"allow": ["Bash(ls)"]}, "model": "sonnet"}\n' > "$FX/proj/.claude/settings.local.json"
out="$(P set devx)"; rc=$?
check T4-set-rc "$rc" 0
check_has T4-set-hint "$out" "/reload-plugins"
check T4-keep-perm "$(jq -c .permissions "$FX/proj/.claude/settings.local.json")" '{"allow":["Bash(ls)"]}'
check T4-keep-model "$(jq -r .model "$FX/proj/.claude/settings.local.json")" sonnet
check T4-deny "$(jq -c '[.deniedMcpServers[].serverName]' "$FX/proj/.claude/settings.local.json")" '["claude.ai X","claude.ai Y"]'
out="$(plain)"
check_has T5-local "$out" "profile=devx source=local "
check_has T5-conn "$out" "connector:claude.ai X=denied connector:claude.ai Y=denied model=sonnet model-source=local "

# precedence: project settings.json over user; local over project; flag over local
printf '{"enabledPlugins": {"pack-b@skills-dir": true}}\n' > "$FX/proj/.claude/settings.json"
out="$(plain)"; check_has T6-project "$out" "pack-b=on "
check_has T6-custom "$out" "profile=custom "
P disable b >/dev/null; out="$(plain)"; check_has T6-local-over-project "$out" "pack-b=off "
check_has T6-devx-again "$out" "profile=devx "
printf '{"enabledPlugins": {"pack-b@skills-dir": true}}\n' > "$FX/flag.json"
out="$(CLAUDE_PROFILE_SETTINGS="$FX/flag.json" CLAUDE_PROFILE=x plain)"
check_has T6-flag "$out" "profile=custom source=flag flag=x pack-a=on pack-b=on "
rm "$FX/proj/.claude/settings.json"

# union of deniedMcpServers: flag fullx over local devx keeps the denies → custom
out="$(CLAUDE_PROFILE_SETTINGS="$FX/lib/profiles/fullx.json" CLAUDE_PROFILE=fullx plain)"
check_has T7-union "$out" "profile=custom source=flag flag=fullx "
check_has T7-union-denied "$out" "connector:claude.ai X=denied "

# refusals: invalid local JSON, outside a project root, unknown profile
cp "$FX/proj/.claude/settings.local.json" "$FX/before.json"
printf '{"enabledPlugins": \n' > "$FX/proj/.claude/settings.local.json"
cp "$FX/proj/.claude/settings.local.json" "$FX/broken.json"
out="$(P set devx 2>&1)"; rc=$?
check T8-invalid-rc "$rc" 2; check_has T8-invalid-msg "$out" "not valid JSON"
check T8-invalid-untouched "$(cmp -s "$FX/broken.json" "$FX/proj/.claude/settings.local.json" && echo same)" same
cp "$FX/before.json" "$FX/proj/.claude/settings.local.json"
mkdir -p "$FX/nowhere"
out="$(PROFILE_REPO_OVERRIDE="$FX" PROFILE_USER_SETTINGS="$FX/home/settings.json" \
       PROFILE_CLAUDE_JSON="$FX/home/claude.json" bash "$FX/lib/profile.sh" -C "$FX/nowhere" set devx 2>&1)"; rc=$?
check T9-root-rc "$rc" 2; check_has T9-root-msg "$out" "not a project root"
check T9-root-nothing "$(ls "$FX/nowhere")" ""
out="$(P set nope 2>&1)"; rc=$?
check T10-unknown-rc "$rc" 2; check_has T10-unknown-list "$out" "fullx"

# enable / disable, three spellings
P enable b >/dev/null; check T11-enable "$(jq -r '.enabledPlugins["pack-b@skills-dir"]' "$FX/proj/.claude/settings.local.json")" true
P disable pack-b >/dev/null; check T11-disable "$(jq -r '.enabledPlugins["pack-b@skills-dir"]' "$FX/proj/.claude/settings.local.json")" false
P enable pack-b@skills-dir >/dev/null; check T11-enable-id "$(jq -r '.enabledPlugins["pack-b@skills-dir"]' "$FX/proj/.claude/settings.local.json")" true
out="$(P enable zzz 2>&1)"; rc=$?; check T11-unknown "$rc" 2
out="$(CLAUDE_PROFILE_SETTINGS="$FX/flag.json" CLAUDE_PROFILE=x P enable a 2>&1)"
check_has T11-flag-note "$out" "relaunch: cc <name> <profile>"
P disable b >/dev/null

# unset: managed keys gone, permissions kept; model removed only when it is the profile's
P unset >/dev/null
check T12-unset-ep "$(jq -c '.enabledPlugins // "gone"' "$FX/proj/.claude/settings.local.json")" '"gone"'
check T12-unset-deny "$(jq -c '.deniedMcpServers // "gone"' "$FX/proj/.claude/settings.local.json")" '"gone"'
check T12-unset-perm "$(jq -c .permissions "$FX/proj/.claude/settings.local.json")" '{"allow":["Bash(ls)"]}'
check T12-unset-model-kept "$(jq -r .model "$FX/proj/.claude/settings.local.json")" sonnet
P set minix >/dev/null
check T12-minix-model "$(jq -r .model "$FX/proj/.claude/settings.local.json")" haiku
P unset >/dev/null
check T12-minix-model-gone "$(jq -r '.model // "gone"' "$FX/proj/.claude/settings.local.json")" gone

# /mcp toggle in ~/.claude.json; unreadable → unknown; disableClaudeAiConnectors any-source
printf '{"projects": {"%s": {"disabledMcpServers": ["foo", "bar"]}}}\n' "$FX/proj" > "$FX/home/claude.json"
out="$(P current)"; check_has T13-mcp-off "$out" "profile: custom (off: foo,bar) [default]"
out="$(plain)"; check_has T13-mcp-off-plain "$out" "mcp-off=foo,bar"
printf '{broken\n' > "$FX/home/claude.json"
out="$(plain)"; rc=$?; check T14-unknown-rc "$rc" 0; check_has T14-unknown "$out" "mcp-off=unknown"
printf '{}\n' > "$FX/home/claude.json"
printf '{"enabledPlugins": {"ui@mk": true}, "disableClaudeAiConnectors": true}\n' > "$FX/home/settings.json"
out="$(plain)"; check_has T15-all-denied "$out" "connector:*=denied"; check_has T15-custom "$out" "profile=custom "
printf '{"enabledPlugins": {"ui@mk": true}}\n' > "$FX/home/settings.json"

# a profile naming a missing pack still writes
P set devx >/dev/null; check T16-missing-written "$(jq -r '.enabledPlugins["pack-c@skills-dir"]' "$FX/proj/.claude/settings.local.json")" false

# diff
out="$(P diff fullx)"; check_has T17-diff "$out" "connectors denied: claude.ai X, claude.ai Y → "
out="$(P diff devx)"; check T17-nodiff "$out" "no difference from devx"

# shellcheck + 80 columns
check T18-shellcheck "$(shellcheck "$ROOT/lib/profile.sh" >/dev/null 2>&1 && echo ok)" ok
check T18-width "$(LC_ALL=C awk 'length($0) > 80' "$ROOT/lib/profile.sh" | wc -l | tr -d ' ')" 0

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
```

- [ ] **Step 3: Run it, expect failures**

Run: `make test suite=lib/tests/profile.test.sh`
Expected: most checks FAIL (the old `profile.sh` has no `-C`, no `--plain` on `current`), suite red.

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
# `current` reads, highest first: $CLAUDE_PROFILE_SETTINGS (the --settings
# file lib/cc.sh exports), <dir>/.claude/settings.local.json,
# <dir>/.claude/settings.json, ~/.claude/settings.json. A pack absent from
# all takes its manifest `defaultEnabled` (absent key = on); a managed
# plugin absent from all is off. `enabledPlugins` and `model`: per key,
# highest wins. `deniedMcpServers`: the UNION of every file.
# `disableClaudeAiConnectors`: true if any file says so. Then
# ~/.claude.json `projects[<dir>].disabledMcpServers` (the /mcp toggle).
# `--plain` = one `key=value` per line: the single truth for the gates,
# hooks and statusline (supersedes `show --plain`, BDR-024).
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
USER_SETTINGS="${PROFILE_USER_SETTINGS:-$HOME/.claude/settings.json}"
CLAUDE_JSON="${PROFILE_CLAUDE_JSON:-$HOME/.claude.json}"
LOCAL_REL=".claude/settings.local.json"
PROJECT="$PWD"

die() { echo "profile: $*" >&2; exit 2; }
usage() {
  sed -n '/^# Usage:/,/^#$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,2\}//' >&2
  exit 2
}

# ---- inputs ----------------------------------------------------------
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
pack_default() { # $1 id → true | false | missing (manifest defaultEnabled)
  local m="$SKILLS_DIR/${1%@skills-dir}/.claude-plugin/plugin.json"
  [ -f "$m" ] || { echo missing; return 0; }
  jq -r 'if .defaultEnabled == false then "false" else "true" end' "$m"
}
defaults_json() { # {id: bool} for every managed id; a missing pack = false
  local id
  for id in $(managed_ids); do
    case "$id" in
      pack-*@skills-dir) printf '%s\t%s\n' "$id" "$(pack_default "$id")" ;;
      *@skills-dir) printf '%s\ttrue\n' "$id" ;;
      *) printf '%s\tfalse\n' "$id" ;;
    esac
  done | jq -Rn '[inputs | split("\t") | {key: .[0], value: (.[1] == "true")}]
                 | from_entries'
}

# ---- effective state --------------------------------------------------
have_flag() {
  [ -n "${CLAUDE_PROFILE_SETTINGS:-}" ] && [ -f "$CLAUDE_PROFILE_SETTINGS" ]
}
flag_json() {
  if have_flag; then jq -c . "$CLAUDE_PROFILE_SETTINGS" 2>/dev/null || echo '{}'
  else echo '{}'; fi
}
mcp_off() { # the /mcp toggle for this project: "-", "a,b" or unknown
  [ -f "$CLAUDE_JSON" ] || { echo "-"; return 0; }
  jq -r --arg p "$PROJECT" '.projects[$p].disabledMcpServers // []
    | if length == 0 then "-" else join(",") end' "$CLAUDE_JSON" 2>/dev/null \
    || echo unknown
}
source_of() { # $1 local JSON → flag | local | default
  if have_flag; then echo flag
  elif [ "$(jq -r '(.enabledPlugins // {} | length)
                   + (.deniedMcpServers // [] | length)' <<<"$1")" -gt 0 ]
  then echo local
  else echo default; fi
}
effective() { # → JSON {plugins, denied, all_denied, model, model_source,
              #         source, mcp_off}
  local f l p u
  f="$(flag_json)"
  l="$(json_or_empty "$PROJECT/$LOCAL_REL")" || l='{}'
  p="$(json_or_empty "$PROJECT/.claude/settings.json")" || p='{}'
  u="$(json_or_empty "$USER_SETTINGS")" || u='{}'
  jq -n --argjson u "$u" --argjson p "$p" --argjson l "$l" --argjson f "$f" \
    --argjson d "$(defaults_json)" --arg src "$(source_of "$l")" \
    --arg off "$(mcp_off)" '
    def ep: (.enabledPlugins // {});
    def dn: [(.deniedMcpServers // [])[] | .serverName];
    def src(k): if ($f | has(k)) then "flag" elif ($l | has(k)) then "local"
                elif ($p | has(k)) then "project"
                elif ($u | has(k)) then "user" else "-" end;
    { plugins: (($d + ($u|ep) + ($p|ep) + ($l|ep) + ($f|ep))
                | with_entries(select(.key as $k | $d | has($k)))),
      denied: (($u|dn) + ($p|dn) + ($l|dn) + ($f|dn) | unique),
      all_denied: ([$u, $p, $l, $f]
                   | any(.disableClaudeAiConnectors == true)),
      model: ($f.model // $l.model // $p.model // $u.model // "-"),
      model_source: src("model"), source: $src, mcp_off: $off }'
}
match_profile() { # $1 effective JSON → profile name | custom
  local n
  for n in $(profile_names); do
    if jq -e --argjson e "$1" '
         ($e.plugins == .enabledPlugins)
         and (($e.denied | sort)
              == ([(.deniedMcpServers // [])[] | .serverName] | sort))
         and ($e.all_denied | not)' "$(profile_file "$n")" >/dev/null
    then echo "$n"; return 0; fi
  done
  echo custom
}

# ---- output ------------------------------------------------------------
print_plain() { # $1 effective JSON, $2 profile name
  printf 'profile=%s\nsource=%s\nflag=%s\n' "$2" "$(jq -r .source <<<"$1")" \
    "${CLAUDE_PROFILE:--}"
  jq -r '.plugins | to_entries | sort_by(.key)[]
    | select((.key | startswith("pack-")) and (.key | endswith("@skills-dir")))
    | (.key | sub("@skills-dir$"; "")) + "="
      + (if .value then "on" else "off" end)' <<<"$1"
  jq -r '.plugins | to_entries | sort_by(.key)[]
    | select(((.key | startswith("pack-")) and (.key | endswith("@skills-dir")))
             | not)
    | "plugin:" + .key + "=" + (if .value then "on" else "off" end)' <<<"$1"
  jq -r '.denied[] | "connector:" + . + "=denied"' <<<"$1"
  jq -r 'select(.all_denied) | "connector:*=denied"' <<<"$1"
  jq -r '"model=" + .model, "model-source=" + .model_source,
         "mcp-off=" + .mcp_off' <<<"$1"
}
print_human() { # $1 effective JSON, $2 profile name
  local src off
  src="$(jq -r .source <<<"$1")"; off="$(jq -r .mcp_off <<<"$1")"
  [ "$src" = flag ] && src="conv ${CLAUDE_PROFILE:-?}"
  if [ "$off" != "-" ]; then echo "profile: custom (off: $off) [$src]"
  else echo "profile: $2 [$src]"; fi
  echo "  on : $(jq -r '[.plugins | to_entries[] | select(.value) | .key
    | sub("@skills-dir$"; "")] | if length == 0 then "none"
    else join(" ") end' <<<"$1")"
  echo "  off: $(jq -r '[.plugins | to_entries[] | select(.value | not) | .key
    | sub("@skills-dir$"; "")] | if length == 0 then "none"
    else join(" ") end' <<<"$1")"
  echo "  connectors denied: $(jq -r 'if .all_denied then "all"
    elif (.denied | length) == 0 then "none"
    else (.denied | join(", ")) end' <<<"$1")"
  echo "  model: $(jq -r '.model + " (" + .model_source + ")"' <<<"$1")"
}

# ---- commands ----------------------------------------------------------
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
  local eff name
  eff="$(effective)"; name="$(match_profile "$eff")"
  if [ "${1:-}" = "--plain" ]; then print_plain "$eff" "$name"
  else print_human "$eff" "$name"; fi
}
require_project_root() {
  [ -f "$PROJECT/CLAUDE.md" ] || [ -d "$PROJECT/.git" ] \
    || die "not a project root (no CLAUDE.md and no .git): $PROJECT"
}
read_local() {
  json_or_empty "$PROJECT/$LOCAL_REL" \
    || die "$LOCAL_REL is not valid JSON — nothing written"
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
  name="$(CLAUDE_PROFILE_SETTINGS='' match_profile \
          "$(CLAUDE_PROFILE_SETTINGS='' effective)")"
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
  out="$(jq -r --argjson e "$(effective)" '
    def onoff: if . then "on" else "off" end;
    (.enabledPlugins | to_entries[] | select($e.plugins[.key] != .value)
     | .key + ": " + ($e.plugins[.key] | onoff) + " → " + (.value | onoff)),
    (([(.deniedMcpServers // [])[] | .serverName] | sort) as $want
     | ($e.denied | sort) as $have
     | if $want == $have then empty
       else "connectors denied: " + ($have | join(", ")) + " → "
            + ($want | join(", ")) end),
    (if (.model // "-") != $e.model
     then "model: " + $e.model + " → " + (.model // "-") else empty end)' "$f")"
  if [ -n "$out" ]; then echo "$out"; else echo "no difference from $1"; fi
}

# ---- main ---------------------------------------------------------------
command -v jq >/dev/null 2>&1 || die "jq is required"
while [ $# -gt 0 ]; do
  case "$1" in
    -C) [ -n "${2:-}" ] || usage
        PROJECT="$(cd "$2" 2>/dev/null && pwd)" || die "no such dir: $2"
        shift 2 ;;
    *) break ;;
  esac
done
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

Note for the implementer: `CLAUDE_PROFILE_SETTINGS='' effective` in `cmd_unset` relies on bash passing a temporary environment to a function call (bash does, outside POSIX mode). `cmd_show`'s `missing` tag is padded to the column the test checks (`%-42s` then two spaces).

- [ ] **Step 5: Run the suite until green**

Run: `make test suite=lib/tests/profile.test.sh`
Expected: `PASS=52 FAIL=0` (count the checks; adjust the number here to what the file holds, never the other way round).

- [ ] **Step 6: Delete the old suites, run the real-profile checks**

```bash
git rm -q lib/tests/profile-default.test.sh lib/tests/profile-set-managed.test.sh lib/tests/profile-census.test.sh
bash lib/profile.sh list
bash lib/profile.sh show web
bash lib/profile.sh current            # expected: profile: full [default] (this repo has no local enabledPlugins)
bash lib/profile.sh current --plain | head -4
for n in $(ls lib/profiles/*.json); do jq -e '.enabledPlugins | length == 15' "$n" >/dev/null || echo "BAD $n"; done
```

- [ ] **Step 7: Commit**

```bash
git add lib/profile.sh lib/profiles lib/tests/profile.test.sh
git commit -m "feat(profile): profiles are settings fragments; profile.sh set/unset/enable/disable merge the local settings, current --plain is the single truth"
```

---

### Task 4: `lib/cc.sh` launcher

**Files:**
- Create: `lib/cc.sh`, `lib/tests/cc.test.sh`

**Interfaces:**
- Consumes: `lib/profiles/<n>.json` (Task 3), `bash lib/profile.sh list`.
- Produces: shell function `cc <name> [profile]` (sourced from `~/.bashrc`, user step in Task 11's MIGRATION); exports `CLAUDE_PROFILE`, `CLAUDE_PROFILE_SETTINGS` (empty strings without a profile), `TMPDIR=$HOME/.cache/claude-tmp`; env override `CC_LIB_DIR` (default `$HOME/.claude/lib`) for the test.

- [ ] **Step 1: Write the failing test**

`lib/tests/cc.test.sh`:

```bash
#!/usr/bin/env bash
# lib/tests/cc.test.sh — lib/cc.sh `cc <name> [profile]`: unknown profile →
# list + rc 2 and no session; a profile → claude --settings <fragment> with
# CLAUDE_PROFILE / CLAUDE_PROFILE_SETTINGS / TMPDIR exported through
# systemd-run + dtach; no profile → plain claude, TMPDIR still set. Hermetic:
# PATH shims for systemd-run, dtach and claude; HOME and CC_LIB_DIR in a
# fixture.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
check_has() { case "$2" in *"$3"*) pass=$((pass+1));; *) fail=$((fail+1));
  printf 'FAIL %s: [%s] does not contain [%s]\n' "$1" "$2" "$3";; esac; }

FX="$(mktemp -d)"; trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/bin" "$FX/home/.claude" "$FX/lib/profiles"
cp "$ROOT/lib/cc.sh" "$ROOT/lib/profile.sh" "$FX/lib/"
printf '{"enabledPlugins": {"x@skills-dir": true}}\n' > "$FX/lib/profiles/webx.json"
printf -- '- **webx**: web fixture\n' > "$FX/lib/profiles/README.md"
# systemd-run shim: drop its own options, exec the command that follows
cat > "$FX/bin/systemd-run" <<'EOF'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do case "$1" in --*) shift ;; *) break ;; esac; done
echo "systemd-run" >> "$CC_LOG"; exec "$@"
EOF
# dtach shim: drop `-c <socket> -e <key>`, exec the rest
cat > "$FX/bin/dtach" <<'EOF'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do case "$1" in -c|-e) shift 2 ;; *) break ;; esac; done
echo "dtach" >> "$CC_LOG"; exec "$@"
EOF
# claude shim: record argv and the three variables
cat > "$FX/bin/claude" <<'EOF'
#!/usr/bin/env bash
{ echo "claude argv: $*"; echo "CLAUDE_PROFILE=${CLAUDE_PROFILE-unset}"
  echo "CLAUDE_PROFILE_SETTINGS=${CLAUDE_PROFILE_SETTINGS-unset}"
  echo "TMPDIR=${TMPDIR-unset}"; } >> "$CC_LOG"
EOF
chmod +x "$FX/bin/"*
export CC_LOG="$FX/log" HOME="$FX/home" CC_LIB_DIR="$FX/lib"
PATH="$FX/bin:$PATH"
# shellcheck disable=SC1091
. "$FX/lib/cc.sh"

# unknown profile: list + rc 2, no session
: > "$CC_LOG"
out="$(cc s1 nope 2>&1)"; rc=$?
check T1-unknown-rc "$rc" 2
check_has T1-unknown-msg "$out" "cc: unknown profile 'nope'"
check_has T1-unknown-list "$out" "webx"
check T1-no-session "$(cat "$CC_LOG")" ""

# with a profile
: > "$CC_LOG"
cc s2 webx; rc=$?
check T2-rc "$rc" 0
log="$(cat "$CC_LOG")"
check_has T2-chain "$log" "systemd-run"
check_has T2-dtach "$log" "dtach"
check_has T2-argv "$log" "claude argv: --settings $FX/lib/profiles/webx.json"
check_has T2-profile "$log" "CLAUDE_PROFILE=webx"
check_has T2-settings "$log" "CLAUDE_PROFILE_SETTINGS=$FX/lib/profiles/webx.json"
check_has T2-tmpdir "$log" "TMPDIR=$FX/home/.cache/claude-tmp"
check T2-tmpdir-exists "$([ -d "$FX/home/.cache/claude-tmp" ] && echo yes)" yes

# without a profile: plain claude, variables empty, TMPDIR set
: > "$CC_LOG"
cc s3; rc=$?
check T3-rc "$rc" 0
log="$(cat "$CC_LOG")"
check_has T3-argv "$log" "claude argv: "
check_has T3-profile-empty "$log" "CLAUDE_PROFILE="$'\n'
check_has T3-tmpdir "$log" "TMPDIR=$FX/home/.cache/claude-tmp"

# .env sourcing still happens before claude
printf 'CC_ENV_CANARY=1\n' > "$FX/home/.claude/.env"
cat > "$FX/bin/claude" <<'EOF'
#!/usr/bin/env bash
echo "canary=${CC_ENV_CANARY-unset}" >> "$CC_LOG"
EOF
: > "$CC_LOG"; cc s4 webx
check_has T4-env "$(cat "$CC_LOG")" "canary=1"

check T5-shellcheck "$(shellcheck "$ROOT/lib/cc.sh" >/dev/null 2>&1 && echo ok)" ok
printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run it, expect failure**

Run: `make test suite=lib/tests/cc.test.sh`
Expected: `cp: cannot stat 'lib/cc.sh'` then FAILs; suite red.

- [ ] **Step 3: Write `lib/cc.sh`**

```bash
#!/usr/bin/env bash
# ============================================================
# lib/cc.sh — `cc <name> [profile]`: a named dtach session running claude,
# optionally under a per-conversation profile.
#
# Sourced from ~/.bashrc (user step, MIGRATION.md):
#   . "$HOME/.claude/lib/cc.sh"
#
# With a profile, claude starts with `--settings lib/profiles/<profile>.json`
# and the session exports CLAUDE_PROFILE + CLAUDE_PROFILE_SETTINGS, which
# `profile.sh current` reads (source=flag). That conversation is frozen:
# `/reload-plugins` re-reads neither the flag file nor a local value the
# flag overrides; to change packs, start another `cc <name> <profile>`.
# Without a profile: today's behaviour (manifest defaults, local settings).
# TMPDIR goes to ~/.cache/claude-tmp either way (BLK-021).
# ============================================================

cc() {
  local name="${1:-claude-$(date +%H%M%S)}" profile="${2:-}"
  local lib="${CC_LIB_DIR:-$HOME/.claude/lib}" settings=""
  if [ -n "$profile" ]; then
    settings="$lib/profiles/$profile.json"
    if [ ! -f "$settings" ]; then
      echo "cc: unknown profile '$profile'. Known:" >&2
      bash "$lib/profile.sh" list >&2
      return 2
    fi
  fi
  mkdir -p "$HOME/.cache/claude-tmp" "$HOME/.dtach"
  # shellcheck disable=SC2016  # the inner shell expands $HOME, not this one
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

`systemd-run --scope` runs the command in the caller's environment, so the three variables reach `claude`; the test proves it through the shims, and the user's first real `cc <name> web` (Task 12) proves it on the machine.

- [ ] **Step 4: Run the suite**

Run: `make test suite=lib/tests/cc.test.sh`
Expected: `PASS=17 FAIL=0`.

- [ ] **Step 5: Commit**

```bash
git add lib/cc.sh lib/tests/cc.test.sh
git commit -m "feat(cc): cc <name> [profile] launcher runs claude --settings lib/profiles/<profile>.json and exports CLAUDE_PROFILE*"
```

---

### Task 5: Design gate on `current --plain`

**Files:**
- Rewrite: `lib/design-tool-gate.sh` (keep `ensure_claude_on_path`? no: drop it, `claude` is no longer called; keep `ensure_21st_on_path` lines 93-111 and `twentyfirst_auth_state` 114-143 verbatim)
- Rewrite: `lib/tests/design-tool-gate.test.sh`
- Modify: `lib/design-gate.md` (lines 26-30, 40-45, 55-66, 72-84, 104-108, 114-118, 196-216), `skills/feat/SKILL.md:76-78`, `skills/bugfix/SKILL.md:60-62`, `skills/feat/test-prompts.json:3`, `agents/plugin-advisor.md:167`

**Interfaces:**
- Consumes: `bash lib/profile.sh -C <dir> current --plain` (Task 3): keys `pack-design`, `pack-gstack-design`, `plugin:ui-ux-pro-max@ui-ux-pro-max-skill`, `source`, `profile`.
- Produces: `design-tool-gate.sh` (no argument) with the same exit codes 0 / 10 / 11 / 12 / 2 and these first lines: `design toolchain: READY — packs design + gstack-design + ui-ux-pro-max on (<profile>)`; `design toolchain: INCOMPLETE`; `design toolchain: SIGN-IN REQUIRED — 21st CLI installed, not signed in`; `design toolchain: READY BUT UNVERIFIED — 21st could not answer`. Env: `DESIGN_GATE_PROFILE_SH` (default `$REPO/lib/profile.sh`), `DESIGN_GATE_REPO_OVERRIDE`, `TWENTYFIRST_TOKEN` / `API_KEY_21ST`.

- [ ] **Step 1: Write the failing suite**

`lib/tests/design-tool-gate.test.sh` (replace the file):

```bash
#!/usr/bin/env bash
# lib/tests/design-tool-gate.test.sh — lib/design-tool-gate.sh reads
# `profile.sh current --plain` (fake, driven by $WORK/plain.txt) and the 21st
# sign-in state (fake `21st` driven by FAKE_21ST_MODE). Cases: READY (0);
# a pack off, source=local → INCOMPLETE (10) with the profile.sh remedy;
# source=flag → INCOMPLETE with the relaunch remedy; 21st absent → 10 with
# the npm hint; signed out → 12; whoami garbage → 11.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL $1 — $2"; }
if command -v 21st >/dev/null 2>&1; then
  echo "precondition: a system-wide 21st is on PATH; the fake would be shadowed" >&2; exit 1
fi
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home" "$WORK/repo/lib"
export WORK
cat > "$WORK/bin/profile.sh" <<'EOF'
#!/usr/bin/env bash
cat "$WORK/plain.txt"
EOF
cat > "$WORK/bin/21st" <<'EOF'
#!/usr/bin/env bash
case "${FAKE_21ST_MODE:-in}" in
  in)      echo "Logged in as fake@example.com" ;;
  out)     echo "Not logged in" ;;
  garbage) echo "boom"; exit 3 ;;
esac
EOF
chmod +x "$WORK/bin/"*
plain() { # design gstack-design ui source
  printf 'profile=%s\nsource=%s\nflag=-\npack-design=%s\npack-gstack-design=%s\nplugin:ui-ux-pro-max@ui-ux-pro-max-skill=%s\nmodel=-\n' \
    "$5" "$4" "$1" "$2" "$3" > "$WORK/plain.txt"
}
gate_run() { # $1 mode, $2 extra PATH prefix (empty = no 21st)
  local p="$2"; [ -n "$p" ] && p="$p:"
  env -u TWENTYFIRST_TOKEN -u API_KEY_21ST HOME="$WORK/home" \
    PATH="${p}/usr/bin:/bin" FAKE_21ST_MODE="$1" WORK="$WORK" \
    DESIGN_GATE_PROFILE_SH="$WORK/bin/profile.sh" \
    bash "$ROOT/lib/design-tool-gate.sh"
}
expect() { # name rc-want out-must-contain
  if [ "$rc" = "$2" ] && case "$out" in *"$3"*) true;; *) false;; esac
  then ok "$1"; else bad "$1" "rc=$rc out=[$out]"; fi
}

plain on on on local web
out="$(gate_run in "$WORK/bin")"; rc=$?
expect T1-ready 0 "READY — packs design + gstack-design + ui-ux-pro-max on (web)"

plain off on on local dev
out="$(gate_run in "$WORK/bin")"; rc=$?
expect T2-incomplete-local 10 "INCOMPLETE"
expect T2-remedy-local 10 "bash ~/.claude/lib/profile.sh set web"
expect T2-names 10 "off: pack-design"

plain on off off flag dev
out="$(gate_run in "$WORK/bin")"; rc=$?
expect T3-remedy-flag 10 "relaunch this conversation with a design profile:  cc <name> web"
expect T3-names 10 "off: pack-gstack-design plugin:ui-ux-pro-max@ui-ux-pro-max-skill"

plain on on on local web
out="$(gate_run in "")"; rc=$?
expect T4-no-cli 10 "21st needs the CLI: npm i -g @21st-dev/cli   then   21st login"

out="$(gate_run out "$WORK/bin")"; rc=$?
expect T5-signed-out 12 "SIGN-IN REQUIRED"
expect T5-ask 12 "! 21st login"

out="$(gate_run garbage "$WORK/bin")"; rc=$?
expect T6-unverified 11 "READY BUT UNVERIFIED — 21st could not answer: whoami: rc=3 boom"

out="$(TWENTYFIRST_TOKEN=x FAKE_21ST_MODE=out HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" \
       WORK="$WORK" DESIGN_GATE_PROFILE_SH="$WORK/bin/profile.sh" bash "$ROOT/lib/design-tool-gate.sh")"; rc=$?
expect T7-token 0 "READY"   # a token short-circuits whoami; the CLI itself stays required

printf 'nonsense\n' > "$WORK/plain.txt"
out="$(gate_run in "$WORK/bin" 2>&1)"; rc=$?
expect T8-bad-plain 2 "design-gate: profile.sh current --plain gave no pack-design line"

if shellcheck "$ROOT/lib/design-tool-gate.sh" >/dev/null 2>&1; then ok T9-shellcheck; else bad T9-shellcheck "findings"; fi
echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run it, expect failure**

Run: `make test suite=lib/tests/design-tool-gate.test.sh`
Expected: T1, T2… FAIL (the old gate reads `show design --plain`), suite red.

- [ ] **Step 3: Rewrite `lib/design-tool-gate.sh`**

Keep lines 93-143 of the current file (`ensure_21st_on_path`, `ensure_21st_on_path` call, `twentyfirst_auth_state`) byte for byte; replace everything else with:

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
# Remedy on 10: source=flag → relaunch `cc <name> web` (the --settings
# conversation is frozen); otherwise `profile.sh set web` (or `enable
# design`) then /reload-plugins. The CLI is a global npm install either way.
# Usage: design-tool-gate.sh        (no argument; env DESIGN_GATE_PROFILE_SH)
# ============================================================
set -euo pipefail

REPO="${DESIGN_GATE_REPO_OVERRIDE:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." \
  && pwd)}"
PROFILE_SH="${DESIGN_GATE_PROFILE_SH:-$REPO/lib/profile.sh}"
NEEDED=(pack-design pack-gstack-design
  "plugin:ui-ux-pro-max@ui-ux-pro-max-skill")

# ---- 21st CLI on PATH + sign-in state (kept from the previous version) ----
<lines 93-143 of the current file go here, unchanged>

# ---- packs and plugin from profile.sh ------------------------------------
plain="$(bash "$PROFILE_SH" -C "$PWD" current --plain 2>/dev/null)" \
  || { echo "design-gate: profile.sh current --plain failed" >&2; exit 2; }
grep -q '^pack-design=' <<<"$plain" \
  || { echo "design-gate: profile.sh current --plain gave no pack-design line" >&2; exit 2; }
plain_get() { sed -n "s/^$1=//p" <<<"$plain" | head -1; }
missing=()
for k in "${NEEDED[@]}"; do
  [ "$(plain_get "$k")" = on ] || missing+=("$k")
done
source="$(plain_get source)"; profile="$(plain_get profile)"

# ---- 21st: CLI present, then signed in -----------------------------------
cli_hint=""; auth=in
if ! command -v 21st >/dev/null 2>&1; then
  cli_hint="    21st needs the CLI: npm i -g @21st-dev/cli   then   21st login"
else
  auth="$(twentyfirst_auth_state)"
fi

# ---- verdict ---------------------------------------------------------------
if [ "${#missing[@]}" -gt 0 ] || [ -n "$cli_hint" ]; then
  echo "design toolchain: INCOMPLETE"
  [ "${#missing[@]}" -gt 0 ] && echo "  off: ${missing[*]}"
  [ -n "$cli_hint" ] && echo "$cli_hint"
  if [ "$source" = flag ]; then
    echo "  → relaunch this conversation with a design profile:  cc <name> web"
  else
    echo "  → run:  bash ~/.claude/lib/profile.sh set web   (or: enable design)" \
      "  then /reload-plugins"
  fi
  exit 10
fi
case "$auth" in
  out)
    echo "design toolchain: SIGN-IN REQUIRED — 21st CLI installed, not signed in"
    echo "  ask the user to run in this session:  ! 21st login  (browser flow," \
      "saves a local token)"
    echo "  then re-run this gate before any 21st step — never skip 21st silently"
    exit 12 ;;
  unknown:*)
    echo "design toolchain: READY BUT UNVERIFIED — 21st could not answer:" \
      "${auth#unknown:}"
    echo "  a CLI runtime/PATH problem (node under nvm?), not a sign-in problem;" \
      "fix it, then re-run"
    exit 11 ;;
esac
echo "design toolchain: READY — packs design + gstack-design + ui-ux-pro-max" \
  "on ($profile)"
exit 0
```

- [ ] **Step 4: Run the suite until green**

Run: `make test suite=lib/tests/design-tool-gate.test.sh`
Expected: `PASS=14 FAIL=0`.

- [ ] **Step 5: Patch the prose**

`lib/design-gate.md`:
- 28-30: "Source of truth for activation is `profile.sh current --plain` (the packs and plugins of THIS project and conversation), never a per-tool toggle. The gate's job: confirm the design packs are on, and if not, point at ONE remedy: `bash ~/.claude/lib/profile.sh set web` (or `enable design`) then `/reload-plugins`, or `cc <name> web` when the conversation runs a `--settings` profile."
- 40-45: "Tier does NOT change WHAT gets checked. Every non-trivial design tier needs the same three: `pack-design` (impeccable, emil-design-eng, frontend-design, design-motion-principles, 21st-ui-build, 21st-cli-use, site-motion), `pack-gstack-design` (design-review, design-consultation, design-html, plan-design-review) and the `ui-ux-pro-max` plugin, plus the `21st` CLI signed in."
- 59-63: "It reads `profile.sh current --plain` for the three keys and `21st whoami` for the sign-in state. It never calls `claude` and never reads `disabledMcpServers`. The required set lives in `NEEDED=` at the top of the script."
- 72-84: the block becomes
  ```
      🎨 DESIGN DETECTED — the design toolchain isn't fully active.
      off: <pack-design pack-gstack-design plugin:ui-ux-pro-max@…>
      <21st needs the CLI …, when printed>
      → <the remedy line the script printed>
  ```
  "**off** → packs or the plugin: the remedy is `profile.sh set web` (or `enable design`) then `/reload-plugins` in a conversation without `--settings`; in a `--settings` conversation the pack cannot come back (the flag is read once), so the remedy is to relaunch `cc <name> web`. **21st CLI** → required, never silent: `npm i -g @21st-dev/cli` then `21st login`."
- 104-108 and 114-118: replace `claude plugin list` by "re-run the gate" and `/profile design` by "the remedy line".
- 196-216: delete the `# GATE-BLOCK:` and `skill_status()` sentences; the IMPORTANT list becomes: remedy is a profile or a pack (`set web`, `enable design`, or relaunch), never a user-scope write; 21st CLI required; the required set is `NEEDED=` in the script; the check is instant (no `claude` call); never on pure backend tasks.

`skills/feat/SKILL.md:77` and `skills/bugfix/SKILL.md:61`: "  to run `/profile design`" → "  the remedy line it printed (`profile.sh set web` + `/reload-plugins`, or relaunch `cc <name> web`)". `skills/feat/test-prompts.json:3`: same wording. `agents/plugin-advisor.md:167`: "points the user at `/profile design`" → "prints the remedy (`profile.sh set web` then `/reload-plugins`, or a relaunch under a design profile)".

Verify: `grep -rn '/profile design\|GATE-BLOCK\|show design --plain\|skill_status' lib/design-gate.md skills/feat skills/bugfix agents/plugin-advisor.md` → no output.

- [ ] **Step 6: Commit**

```bash
git add lib/design-tool-gate.sh lib/tests/design-tool-gate.test.sh lib/design-gate.md skills/feat/SKILL.md skills/feat/test-prompts.json skills/bugfix/SKILL.md agents/plugin-advisor.md
git commit -m "feat(design-gate): the gate reads profile.sh current --plain; remedy is set web / enable design + reload, or a relaunch under --settings"
```

---

### Task 6: Plugin gate, probe, advisor, `/profile`, onboard, plugin-check

**Files:**
- Rewrite: `skills/profile/SKILL.md`, `skills/profile/test-prompts.json`
- Modify: `lib/plugin-gate.md:17-20, 60-90`, `agents/plugin-probe.md:17-26, 60-63, 72-74`, `agents/plugin-advisor.md:272-328`, `skills/onboard/SKILL.md:424, 608`, `skills/plugin-check/SKILL.md:16`

**Interfaces:**
- Consumes: `profile.sh current --plain`, `set`, `enable`; `lib/profiles/README.md` names.
- Produces: the PROBE REPORT fields `PROFILE :` (the whole `--plain` block, verbatim) and `PACKS :` (one line `pack-x=on|off …`); the advisor's PROPOSED CHANGES are `bash $HOME/.claude/lib/profile.sh set <n>` or `enable <pack>` lines; the gate applies them one by one and stops at the first rc ≠ 0 (each write is atomic, so there is nothing to roll back).

- [ ] **Step 1: `skills/profile/SKILL.md`**

Replace the whole file:

```markdown
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

- Never write the user scope (`~/.claude/settings.json`); never run
  `claude plugin enable|disable`. A pack need found mid-skill is proposed to
  the user (`set <n>` or `enable <pack>` + `/reload-plugins`, or a relaunch
  under `--settings`), written only on consent (lib/plugin-gate.md).
- `deniedMcpServers` is a union across settings files: a `cc x web` over a
  project set to `dev` keeps the connectors denied; `set web` in the
  project brings them back for the next session.
- `max` turns on `pack-extras` (diagram, make-pdf, 21st-ai, 21st-ui-explore,
  21st-ui-review); `pack-higgsfield` is on in `max` only, else `enable
  higgsfield` for a named media ask.
```

`skills/profile/test-prompts.json`: replace `lib/profiles/*.profile` by `lib/profiles/*.json`, `set design` stays, and the `current` prompt expects "profile: <name> [local|default|conv …]" instead of a match percentage.

- [ ] **Step 2: `lib/plugin-gate.md`**

Lines 17-20 (`CHECKPOINT toggle-script=UNAVAILABLE` bullet) → "`CHECKPOINT profile-sh=UNAVAILABLE` → print `⚠️ profile.sh unavailable — recommendations will be advisory only, no auto-activation.` and SKIP step 5 (apply) entirely." Lines 60-90 (APPLY GATE from "yes → apply" to the end) become:

```markdown
2. "yes" → run the advisor's commands in order, each one `bash
   "$HOME/.claude/lib/profile.sh" -C <PROJECT_ROOT> set <name>` or `enable
   <pack>`. Each call writes `.claude/settings.local.json` atomically or
   refuses (rc 2, nothing written), so there is nothing to roll back: stop at
   the first non-zero rc, print its stderr, and continue with the current
   config. "customize" → user picks. "no" → proceed with current config.
3. After a successful write print `✅ Applied N change(s) — run
   /reload-plugins to load the packs in this session (connectors and model:
   next session).` In a `--settings` conversation (`PROFILE :` block says
   `source=flag`) the advisor emits no enable for a pack the flag turns off;
   it says `relaunch: cc <name> <profile>` instead.

**Never auto-activate without showing the list and getting confirmation.
Never write the user scope.**
```

- [ ] **Step 3: `agents/plugin-probe.md`**

Lines 17-26 become:

```bash
# Packs, managed plugins, connectors, model: the effective state of THIS
# project and conversation (lib/profile.sh, no claude call)
bash "$HOME/.claude/lib/profile.sh" -C "$PWD" current --plain 2>/dev/null || echo "profile-unavailable"

# Marketplace plugins actually installed (ids, enabled state)
claude plugin list 2>/dev/null || echo "plugin-list-unavailable"
```

Line 63 → `[ -f "$HOME/.claude/lib/profile.sh" ] && echo "profile-sh: available" || echo "profile-sh: UNAVAILABLE"`. Lines 72-74 become `PROFILE       : <current --plain block, verbatim>` and `PLUGINS       : <claude plugin list output>`; delete `EXTERNAL`.

- [ ] **Step 4: `agents/plugin-advisor.md:272-328`**

Replace the "TOGGLING EXTERNAL TOOLS" section through the `reset` sentence with:

```markdown
## WRITING A PROFILE OR A PACK

Everything switches through `lib/profile.sh`, per project, never the user
scope. Emit the exact command; never write files directly.

| Signal | Profile | Command |
|---|---|---|
| public website, no SEO focus | `web` | `bash $HOME/.claude/lib/profile.sh set web` |
| audit-only: SEO + GEO + W3C + WCAG | `seo` | `… set seo` |
| public website end-to-end | `web-full` | `… set web-full` |
| backend / API / library | `backend` | `… set backend` |
| heavy UI, no dev | `design` | `… set design` |
| typical dev session | `dev` | `… set dev` |
| browser QA only | `qa` | `… set qa` |
| comprehensive audit | `audit` | `… set audit` |
| narrow session | `minimal` | `… set minimal` |
| one pack on top | — | `bash $HOME/.claude/lib/profile.sh enable <design|scroll3d|seo|web-validate|gstack-dev|gstack-browser|gstack-design|higgsfield|extras>` |

Read `PROFILE :` first: when it says `source=flag`, a pack it turns off
cannot be enabled in this conversation; recommend `relaunch: cc <name>
<profile>` instead of an `enable`. No profile = `full` (manifest defaults);
`unset` returns to it. Every write needs `/reload-plugins` to load the
packs; connectors and model apply to the next session.
```

- [ ] **Step 5: onboard and plugin-check**

`skills/onboard/SKILL.md:424` and `:608`: replace the line with `bash $HOME/.claude/lib/profile.sh -C "$PWD" current --plain 2>/dev/null | grep -q '^pack-gstack-dev=on'`. `skills/plugin-check/SKILL.md:16`: "toggles via `claude plugin enable/disable`" → "writes the project's `.claude/settings.local.json` through `lib/profile.sh` (`set <profile>` / `enable <pack>`), never the user scope".

Verify: `grep -rn 'toggle-external\|claude plugin enable\|profile.sh reset\|\.active-profile\|apply <name>' lib/plugin-gate.md agents/plugin-probe.md agents/plugin-advisor.md skills/profile skills/onboard/SKILL.md skills/plugin-check/SKILL.md` → no output.

- [ ] **Step 6: Commit**

```bash
git add skills/profile lib/plugin-gate.md agents/plugin-probe.md agents/plugin-advisor.md skills/onboard/SKILL.md skills/plugin-check/SKILL.md
git commit -m "docs(plugin-gate): probe reads current --plain, advisor emits profile.sh set/enable, /profile rewritten for packs"
```

---

### Task 7: Hooks, doctor, Makefile, link.sh

**Files:**
- Modify: `hooks/statusline.sh:23-34, 84`, `hooks/session-start.sh:64-90, 292`, `lib/detect-plugins.sh:27-33`, `doctor.sh:116-124, 129-159`, `lib/doctor-vendored.sh` (drop the profile parameter), `lib/doctor-skills.sh:37-62`, `lib/tests/doctor-vendored.test.sh`, `link.sh:78-85`, `Makefile:1, 62-72`, `.gitignore:187-188`
- Create: `lib/tests/statusline.test.sh`

**Interfaces:**
- Consumes: `profile.sh -C <dir> current --plain`, `lib/pack-census.sh`.
- Produces: statusline segment `profile: <name>` / `profile: <name> (conv)`; session-start row `│  🎛 profile: <name> (local)` or `│  🎛 profile: none (full) · /plugin-check proposes one`; doctor sections "Packs" (census) and "Profiles" (fragments parse + name only existing packs + `~/.bashrc` sources `lib/cc.sh` + tracked `settings.json` `model` is `opus`); `make profile-current`, `make profile-list`, `make profile cmd="…"`.

- [ ] **Step 1: Statusline test (failing)**

`lib/tests/statusline.test.sh`:

```bash
#!/usr/bin/env bash
# lib/tests/statusline.test.sh — hooks/statusline.sh profile segment comes
# from `profile.sh current --plain` for the cwd the harness passes; a
# --settings conversation shows "(conv)"; profile.sh failing or missing
# prints "profile: ?" and never breaks the line.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check_has() { case "$2" in *"$3"*) pass=$((pass+1));; *) fail=$((fail+1));
  printf 'FAIL %s: [%s] does not contain [%s]\n' "$1" "$2" "$3";; esac; }
FX="$(mktemp -d)"; trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/hooks" "$FX/lib" "$FX/proj"
cp "$ROOT/hooks/statusline.sh" "$FX/hooks/"
printf '{"effortLevel": "high"}\n' > "$FX/settings.json"
cat > "$FX/lib/profile.sh" <<'EOF'
#!/usr/bin/env bash
[ "$2" = "$FAKE_DIR" ] || { echo "wrong -C: $2" >&2; exit 2; }
printf 'profile=%s\nsource=%s\n' "$FAKE_PROFILE" "$FAKE_SOURCE"
EOF
sl() { printf '{"cwd": "%s"}\n' "$FX/proj" | FAKE_DIR="$FX/proj" bash "$FX/hooks/statusline.sh"; }
out="$(FAKE_PROFILE=web FAKE_SOURCE=local sl)"; check_has T1-local "$out" "profile: web |"
out="$(FAKE_PROFILE=dev FAKE_SOURCE=flag sl)"; check_has T2-conv "$out" "profile: dev (conv) |"
out="$(FAKE_PROFILE=full FAKE_SOURCE=default sl)"; check_has T3-default "$out" "profile: full |"
chmod -x "$FX/lib/profile.sh"; printf 'exit 2\n' > "$FX/lib/profile.sh"
out="$(sl 2>&1)"; check_has T4-failing "$out" "profile: ? |"
rm "$FX/lib/profile.sh"; out="$(sl 2>&1)"; check_has T5-missing "$out" "profile: ? |"
printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
```

Run: `make test suite=lib/tests/statusline.test.sh` → red (the statusline reads `.active-profile`).

- [ ] **Step 2: `hooks/statusline.sh`**

Replace lines 23-34 with:

```bash
# Profile of this project and conversation: `profile.sh current --plain`
# (jq only, ~40 ms). `(conv)` = a --settings conversation. Any failure → "?".
_plain="$(bash "$REPO/lib/profile.sh" -C "$DIR" current --plain 2>/dev/null)" || _plain=""
PROFILE="$(sed -n 's/^profile=//p' <<<"$_plain" | head -1)"
[ -n "$PROFILE" ] || PROFILE="?"
[ "$(sed -n 's/^source=//p' <<<"$_plain" | head -1)" = flag ] && PROFILE="$PROFILE (conv)"
```

`DIR` is read from `.cwd` at line 8 (keep). The output at line 84 stays `profile: ${PROFILE}`. Run the suite → `PASS=5 FAIL=0`.

- [ ] **Step 3: `hooks/session-start.sh` and `lib/detect-plugins.sh`**

`lib/detect-plugins.sh:27-33` becomes:

```bash
detect_gstack() {
  # gstack = the three packs; "on" means pack-gstack-dev is on for this
  # project and conversation (profile.sh current --plain, no claude call).
  bash "$HOME/.claude/lib/profile.sh" -C "$PWD" current --plain 2>/dev/null \
    | grep -q '^pack-gstack-dev=on'
}
```

`hooks/session-start.sh`: after line 90 (`INACTIVE_STR=…`) add

```bash
# Profile row: the project's local profile, the conversation's --settings
# one, or none (manifest defaults = full) with the /plugin-check pointer.
_plain="$(bash "$HOME/.claude/lib/profile.sh" -C "$PWD" current --plain 2>/dev/null)" || _plain=""
_pname="$(sed -n 's/^profile=//p' <<<"$_plain" | head -1)"
case "$(sed -n 's/^source=//p' <<<"$_plain" | head -1)" in
  flag)    PROFILE_ROW="profile: ${_pname} (conv)" ;;
  local)   PROFILE_ROW="profile: ${_pname} (local)" ;;
  default) PROFILE_ROW="profile: none (full) · /plugin-check proposes one" ;;
  *)       PROFILE_ROW="profile: ? (profile.sh failed)" ;;
esac
unset _plain _pname
```

and replace line 292 (`💡 /plugin-check  before starting a new project`) with `printf "│  🎛 %-44s│\n" "$PROFILE_ROW"` (the neighbouring rows use `%-44s` after a double-width icon). Check the box width by eye (`bash hooks/session-start.sh | tail -5`): the row must close at the same column as `│  🩺 make doctor  full diagnostic                  │`.

- [ ] **Step 4: `doctor.sh`, `lib/doctor-vendored.sh`, `lib/doctor-skills.sh`, `link.sh`**

- `doctor.sh:116-124` (gstack per-skill symlink count) becomes a Packs section:
  ```bash
  echo "── Packs ──"
  if _pc="$(bash "$REPO/lib/pack-census.sh" 2>&1)"; then
    pass "$(printf '%s\n' "$_pc" | tail -1)"
    printf '%s\n' "$_pc" | grep '^WARN' | while read -r _w; do warn "${_w#WARN }"; done
  else
    printf '%s\n' "$_pc" | grep '^RED' | while read -r _r; do fail "${_r#RED }"; done
  fi
  unset _pc
  ```
  (`pass`/`warn`/`fail` are doctor.sh's existing helpers, check their names at the top of the file and use those.)
- `doctor.sh:129-159`: delete the `.active-profile` resolution (136-158) and call `check_vendored_skills "$REPO" "$HOME/.claude"` unconditionally. Add after it a Profiles section:
  ```bash
  echo "── Profiles ──"
  for _pf in "$REPO"/lib/profiles/*.json; do
    if ! jq -e '.enabledPlugins | type == "object"' "$_pf" >/dev/null 2>&1; then
      fail "$(basename "$_pf"): not a JSON object with enabledPlugins"; continue
    fi
    for _id in $(jq -r '.enabledPlugins | keys[] | select(startswith("pack-"))' "$_pf"); do
      [ -d "$REPO/skills/${_id%@skills-dir}" ] || warn "$(basename "$_pf") names $_id: no skills/${_id%@skills-dir}/"
    done
  done
  grep -q 'lib/cc\.sh' "$HOME/.bashrc" 2>/dev/null \
    && pass "~/.bashrc sources lib/cc.sh (cc <name> [profile])" \
    || warn "~/.bashrc does not source lib/cc.sh — add: . \"\$HOME/.claude/lib/cc.sh\" (and drop the old dtach_claude + alias cc)"
  _m="$(jq -r '.model // "-"' "$REPO/settings.json" 2>/dev/null)"
  [ "$_m" = opus ] && pass "settings.json model is opus" || warn "settings.json model is $_m (tracked default is opus; a /model write must not be committed)"
  unset _pf _id _m
  ```
- `lib/doctor-vendored.sh`: `check_vendored_skills <repo> <claude_home>` loses its third parameter; delete `_dv_profile_has` (148-154), `_dv_valid_profile_name` (156-165), the `<profile_file>` / `parked by profile` branch of `_dv_check_link` (214-241) and the header lines 12-38 that describe them; the remedy string becomes "symlink missing/wrong — run: make link". `lib/tests/doctor-vendored.test.sh`: delete the cases `parked-skill`, `noprofile-skill`, the traversal case and the `active.profile` fixture; every listed name is expected linked. Run: `make test suite=lib/tests/doctor-vendored.test.sh` → green.
- `lib/doctor-skills.sh:37-62`: the python glob `skills_dir + "/*/SKILL.md"` gains a second glob `skills_dir + "/pack-*/skills/*/SKILL.md"` (same loop, both lists concatenated). `doctor.sh:590` (DMI loop) and `:646` (CRLF loop): add `"$REPO"/skills/pack-*/skills/*/SKILL.md` to the same `for` list.
- `link.sh:78-85`: `EXTERNAL_SKILLS=(observability-and-instrumentation deprecation-and-migration ci-cd-and-automation brainstorming writing-plans subagent-driven-development test-driven-development requesting-code-review using-git-worktrees writing-skills)` (the 8 design/scroll names leave: they are pack symlinks now). The comment above it says so.
- `Makefile`: line 1 `.PHONY` drops `profile-reset`; lines 62-72 become `profile` (unchanged), `profile-list` (`## List pack profiles (lib/profiles/*.json)`), `profile-current` (`## Effective profile of this project and conversation`); `profile-reset` deleted.
- `.gitignore:187-188` (`# Profile cache…` + `.active-profile`): delete.

Run: `bash doctor.sh 2>&1 | sed -n '/── Packs/,/── Profiles/p;/── Profiles/,+6p'` → the census line, no fail; the Profiles section with the bashrc warn (expected until the user step).

- [ ] **Step 5: Commit**

```bash
git add hooks/statusline.sh hooks/session-start.sh lib/detect-plugins.sh doctor.sh lib/doctor-vendored.sh lib/doctor-skills.sh lib/tests/doctor-vendored.test.sh lib/tests/statusline.test.sh link.sh Makefile .gitignore
git commit -m "feat(hooks,doctor): statusline and banner read profile.sh current --plain; doctor runs the pack census and checks profiles, cc.sh sourcing and the opus default"
```

---

### Task 8: Retire the toggling libs and their suites

**Files:**
- Delete (`git rm`): `lib/toggle-external.sh`, `lib/tests/toggle-external-repo-resolution.test.sh`
- Modify: `lib/gstack-removed.sh` (keep lines 1-53: header, `GSTACK_REMOVED`, `gstack_is_removed`, `gstack_skills`; delete `gstack_parked_names`, `gstack_park`, `gstack_unpark` 55-85; header lines 6 and 24 reworded), `lib/tests/gstack-removed.test.sh` (keep the denylist and `gstack_skills` cases; delete the `gstack on`, park/unpark and toggle-external cases), `lib/tests/higgsfield.test.sh` (keep the sync and CLI-probe cases; delete the toggle, park and "0 mentions in profile.sh / *.profile" cases 321-323; the spec said delete the file, keeping the sync coverage is the better reading of "installers write skills-external only"), `lib/higgsfield-skills.sh:8, 41` (comments: "linked on demand by pack-higgsfield (`profile.sh enable higgsfield`)")
- Create: `lib/gstack-removed.list` (the 9 names, one per line, generated from `GSTACK_REMOVED` once: `bash -c '. lib/gstack-removed.sh; printf "%s\n" "${GSTACK_REMOVED[@]}"' > lib/gstack-removed.list`) and a check in `lib/tests/gstack-removed.test.sh` that the list equals the array.

- [ ] **Step 1: Add the list-equals-array check to `lib/tests/gstack-removed.test.sh`** (failing until the list exists):

```bash
want="$(printf '%s\n' "${GSTACK_REMOVED[@]}" | sort)"
got="$(sort "$ROOT/lib/gstack-removed.list" 2>/dev/null)"
check T-list-matches-array "$got" "$want"
```

- [ ] **Step 2: Apply the deletions and trims, generate the list**

```bash
git rm -q lib/toggle-external.sh lib/tests/toggle-external-repo-resolution.test.sh
bash -c '. lib/gstack-removed.sh; printf "%s\n" "${GSTACK_REMOVED[@]}"' > lib/gstack-removed.list
```

Then edit `lib/gstack-removed.sh`, the two suites and `lib/higgsfield-skills.sh` as listed.

- [ ] **Step 3: Run the three suites and the census**

Run: `make test suite="lib/tests/gstack-removed.test.sh lib/tests/higgsfield.test.sh lib/tests/pack-census.test.sh"`
Expected: all green; the census now applies the retired check on the real repo (`T8-real` still `PACKS OK 9 packs`).

- [ ] **Step 4: Commit**

```bash
git add -u lib/toggle-external.sh lib/tests/toggle-external-repo-resolution.test.sh
git add lib/gstack-removed.sh lib/gstack-removed.list lib/tests/gstack-removed.test.sh lib/tests/higgsfield.test.sh lib/higgsfield-skills.sh
git commit -m "chore(packs): retire lib/toggle-external.sh and the park/unpark helpers; retired gstack list as a file for the census"
```

---

### Task 9: Installers write `skills-external/` only

**Files:**
- Modify: `install-plugins.sh` (Step 2 lines 351-372: gstack `./setup` precondition and the toggle-external park; Step 8d lines 819-820, 860-906: impeccable moves to `skills-external/impeccable`; lines 1001, 1057, 1074 higgsfield/21st hints; Step 11 lines 1264-1291 deleted; summary lines 1308, 1321-1322), `update-all.sh` (87-89, 117-120: gstack status/disable; 406-424, 455-473: impeccable; 547: comment), `plugins.lock.json:31`
- Verify: `lib/tests/pack-census.test.sh`, `shellcheck install-plugins.sh update-all.sh`

- [ ] **Step 1: gstack `./setup` precondition (install-plugins.sh Step 2)**

Before line 351 `(cd "$GSTACK_DIR" && ./setup)`: upstream setup plants `~/.claude/skills/gstack -> submodule` plus per-skill real dirs under `~/.claude/skills/` unless `~/.claude/skills/gstack` is already a real dir that resolves elsewhere (the helper tree link.sh builds). Guard it:

```bash
if [ -d "$HOME/.claude/skills/gstack" ] && [ ! -L "$HOME/.claude/skills/gstack" ]; then
  (cd "$GSTACK_DIR" && ./setup) && _gstack_setup_ok=1 || warn "gstack ./setup failed"
else
  warn "gstack: ~/.claude/skills/gstack is not the helper tree yet — run 'make link' first, then 'make plugin' (setup would write per-skill dirs into skills/)"
fi
```

Lines 361-367 (`toggle-external.sh disable gstack` + status) are deleted; the ok message at 372 becomes `ok "GStack ready (skills in packs pack-gstack-dev / -browser / -design; profile.sh set <profile>)"`. `update-all.sh:87-89, 117-120`: same deletion; the `./setup` at 94 gets the same guard.

- [ ] **Step 2: impeccable (install-plugins.sh Step 8d, update-all.sh 406-473)**

`IMP_SKILL_DIR="$HOME/.claude/skills/impeccable"` stays (where the CLI writes); line 820 becomes `IMP_HOME="$REPO/skills-external/impeccable"` (where it lives). The "already present" tests (860, 903) read `$IMP_HOME/SKILL.md`. After a successful install (line 888 block) replace the park logic 896-899 with the move:

```bash
    # The CLI can only write ~/.claude/skills/impeccable; the skill lives in
    # skills-external/impeccable, linked by skills/pack-design/skills/impeccable.
    rm -rf skills-external/impeccable
    mv "$IMP_SKILL_DIR" skills-external/impeccable
```

(`rm -rf` on a literal relative path inside the repo; the installer already `cd "$REPO"`s at its top — verify with `grep -n '^cd ' install-plugins.sh`, else prefix the two lines with `cd "$REPO" &&`.) The `IMP_WAS_PARKED` variable and its branch disappear. Same change in `update-all.sh` 421-424 and 455-462. The comments 804-806 say "writes ~/.claude/skills/impeccable/ … then moved to skills-external/impeccable (pack-design)".

- [ ] **Step 3: Hints, Step 11, summary**

- 1001 and 1057: "`bash lib/toggle-external.sh enable higgsfield`" → "`bash lib/profile.sh enable higgsfield` then `/reload-plugins`"; 1074: "`toggle-external.sh` / `profile.sh` symlink it in" → "`skills/pack-design` (`21st-ui-build`, `21st-cli-use`) and `skills/pack-extras` link it".
- Step 11 (1264-1291, "apply the default profile"): delete the whole step; the manifests are the default. Renumber nothing (steps are labels).
- Summary 1308, 1321-1322: `toggle: lib/toggle-external.sh enable …` → `packs: bash lib/profile.sh set <profile> | enable <pack>, then /reload-plugins`.
- `plugins.lock.json:31` note: replace "`toggle-external.sh enable higgsfield`" by "`profile.sh enable higgsfield`".
- `update-all.sh:547`: comment "linked per profile" → "linked by pack-design / pack-extras".

- [ ] **Step 4: Verify**

```bash
shellcheck install-plugins.sh update-all.sh
grep -n 'toggle-external\|skills-disabled\|active-profile\|IMP_PARKED' install-plugins.sh update-all.sh plugins.lock.json   # → nothing
make test suite=lib/tests/pack-census.test.sh
bash -n install-plugins.sh && bash -n update-all.sh
```

No live run of `make plugin` in this task (it installs packages); the user runs it after the merge (Task 12).

- [ ] **Step 5: Commit**

```bash
git add install-plugins.sh update-all.sh plugins.lock.json
git commit -m "chore(install): installers fill skills-external only; impeccable moves to skills-external/impeccable; gstack setup needs the helper tree first; no default-profile step"
```

---

### Task 10: Routing census and rows

**Files:**
- Modify: `lib/skill-routing-census.py:26-30`, `mods/model-router/routing.json` (only if FACT-ROUTER = `long` or `unknown`), `lib/tests/effort-routing.test.sh` (only if rows are added)

**Interfaces:**
- Consumes: FACT-ROUTER from Task 1.

- [ ] **Step 1: Census glob**

`lib/skill-routing-census.py:26-30`: add `"pack-*/skills/*/SKILL.md"` to `ROOT_SUFFIXES` (under `~/.claude/skills`). Run: `python3 -I lib/skill-routing-census.py` → the pack skills appear in its count (55 more than before, minus the ones it already saw as flat links); no new FAIL collision. A WARN between `pack-seo:seo` and `seo` cannot happen: `dedup_by_skill_name` keys on the basename.

- [ ] **Step 2: Rows (conditional)**

FACT-ROUTER = `short` → nothing to do; `skillRow` keeps matching `seo`, `geo`, `web-validate`, `site-motion`, the design and scroll names. FACT-ROUTER = `long` or `unknown` → for every rowed skill now in a pack (21st-ui-review, 21st-ai, 21st-ui-explore → extras; web-validate; seo, geo; site-motion, frontend-design, emil-design-eng, design-motion-principles, 21st-ui-build, 21st-cli-use → design; the 5 scroll names → scroll3d) ADD a second row `"pack-<n>:<skill>": "<same phase>"` next to the short one (keep both: `Skill(<s>)` may still report the short name). `lib/tests/effort-routing.test.sh:145-158` enumerates tracked SKILL.md by basename and expects a row per name: unchanged by added rows. Run: `make test suite="lib/tests/effort-routing.test.sh lib/tests/model-routing.test.sh"` → green.

The router's `skillDesc` (register.ts:2604) reads `~/.claude/skills/<name>/SKILL.md` to decorate its confirm question; for a pack skill it finds nothing and the question names the skill alone (its documented fallback). Accepted; no mod change.

- [ ] **Step 3: Commit**

```bash
git add lib/skill-routing-census.py mods/model-router/routing.json
git commit -m "chore(routing): skill census globs pack skills; long-name rows where the harness reports pack:skill"
```

(Drop `routing.json` from the `git add` when Step 2 changed nothing.)

---

### Task 11: Docs, full suite, citer census

**Files:**
- Modify: `CLAUDE.global.md:272-280`, `README.md:159, 180, 188, 243, 384-398, 426-441, 486-495`, `USAGE.md:126, 174` + a "Profils et packs" paragraph after line 217, `MIGRATION.md:190, 198` + a new section "2.1.0 — profiles and packs", `ARCHITECTURE.md:17, 33`, `CHANGELOG.md` (new entry), `rules/web-building.md:67-68` (wording check only)
- Verify: `make test` (full), `bash doctor.sh`

- [ ] **Step 1: CLAUDE.global.md 272-280**

```markdown
- Media generation (image, video, audio, brand kit), explicit ask →
  pack-higgsfield, off by default: `bash ~/.claude/lib/profile.sh enable
  higgsfield` then `/reload-plugins`, then Read the skill under
  `~/.claude/skills/pack-higgsfield/skills/`; `higgsfield generate cost`
  before a paid run. Landing page "with Higgsfield", named ask → the same
  pack's `higgsfield-websites`: an aid inside the Design work rules
  (`rules/web-building.md`), never `website create|deploy|publish`.
gstack packs OFF (`profile.sh current`) → their skills (investigate, qa,
review, health, retro, office-hours…) are gone: use the fallback above,
else say so.
```

- [ ] **Step 2: README, USAGE, MIGRATION, ARCHITECTURE, CHANGELOG**

- README 159: "The installers fill `skills-external/`; the packs under `skills/pack-*/` link it, on or off per project (`bash lib/profile.sh set <profile>`) or per conversation (`cc <name> <profile>`)." 180/188: "Linked per profile" → "pack-gstack-dev / -browser / -design" and "pack-design / pack-extras". 243: `/profile` row → "Set this project's pack profile (`set <n>`, `enable <pack>`), show the effective one (`current`)". 384-398: the five design skills: `21st-ui-build`, `21st-cli-use` in pack-design (on in full, design, web, web-full); `-ui-explore`, `-ui-review`, `-ai` in pack-extras (`max`, or `enable extras`); `-registry`, `-design-sync`, `-video` stay unlinked in `skills-external/`; drop the `toggle-external.sh enable 21st` sentence. 426-441: the block becomes `bash lib/profile.sh enable higgsfield` / `disable higgsfield` + `/reload-plugins`; the pack holds the 8 `higgsfield-*` skills (`skills/pack-higgsfield/skills/`). 486-495: `make profile-reset` line deleted; `make profile-current` text "effective profile of this project and conversation"; doctor sentence: "vendored skills (link.sh's EXTERNAL_SKILLS), packs (census), profiles".
- USAGE 126 and 174: "Changer le profil de packs du projet (`set`), ou l'état effectif (`current`)"; after 217 add a short paragraph: profil par projet (`/profile set web` puis `/reload-plugins`), par conversation (`cc <nom> web`, conversation figée: relancer pour changer), aucun profil = `full`; un `--settings` édité en cours de session est sans effet; `cc x web` sur un projet en `dev` garde les connecteurs higgsfield refusés (union), `set web` dans le projet les rend.
- MIGRATION 190: drop "applies the default profile (11)"; 198: "Default profile: a project with no local profile runs the manifest defaults (= `full`). Check with `bash lib/profile.sh current`." New section at the end of "Upgrading an existing machine":
  ```markdown
  ### 2.1.0 — profiles and packs

  1. `git pull`, `make link` (link.sh no longer links the design and scroll skills flat: they are pack symlinks), `make plugin` (moves impeccable to `skills-external/impeccable`).
  2. `~/.bashrc`: delete the `dtach_claude()` function and `alias cc='dtach_claude'`; add `. "$HOME/.claude/lib/cc.sh"`. Open a new shell. `cc <name>` behaves as before; `cc <name> web` starts a conversation under `lib/profiles/web.json`. `make doctor` warns until this is done.
  3. Per project: `bash ~/.claude/lib/profile.sh set <profile>` then `/reload-plugins`. The old `skills-disabled/` and `.active-profile` are gone; `lib/toggle-external.sh` too (`profile.sh enable higgsfield` replaces it).
  4. `make test` needs the installers to have run (pack symlinks into `skills-external/`); a dangling target on an ON pack is red.
  ```
- ARCHITECTURE 17: drop "+ default profile"; 33: "profiles (lib/profiles/*.json fragments, profile.sh, cc.sh)". Add `skills/pack-<n>/` to the tree with one line: "skills-dir packs: manifest + tracked symlinks into skills-external/".
- CHANGELOG: entry "2.1.0 (unreleased) — Phase 5 profiles and packs": packs, profiles as fragments, `profile.sh` verbs, `cc <name> [profile]`, gate/hook/doctor on `current --plain`, deletions (skills-disabled, toggle-external, .profile, .active-profile), the deniedMcpServers union note, and the listing budget numbers (filled by Task 13).
- `rules/web-building.md:67-68`: "`max`-profile only" stays true (pack-extras is on in `max`); add "(pack-extras; `profile.sh enable extras`)".

- [ ] **Step 3: Full suite, doctor, citer census**

```bash
make test
bash doctor.sh
grep -rn 'skills-disabled\|toggle-external\|\.active-profile\|profile-reset\|\.profile\b' \
  --include='*.sh' --include='*.md' --include='*.py' --include='*.json' --include=Makefile \
  hooks lib agents skills rules templates mods *.sh CLAUDE.global.md README.md USAGE.md ARCHITECTURE.md Makefile plugins.lock.json .gitignore \
  | grep -v '^lib/tests/fixtures/' | grep -v 'skills-external/'
```

Expected: `all suites green`; doctor with no `fail` (the bashrc warn allowed); the grep prints nothing (CHANGELOG, MIGRATION, `.claude/`, `docs/` and the registry fixtures are out of scope by construction).

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.global.md README.md USAGE.md MIGRATION.md ARCHITECTURE.md CHANGELOG.md rules/web-building.md
git commit -m "docs: profiles and packs (README, USAGE, MIGRATION 2.1.0 bashrc step, ARCHITECTURE, CHANGELOG, global routing)"
```

---

### Task 12: Proof — headless canaries and the user's interactive checks

**Files:**
- Create (scratchpad only): `p5/t12/`, results appended to `p5/FACTS.md` and to CHANGELOG (numbers only).

- [ ] **Step 1: Two conversations, one project, different profiles**

```bash
S=/tmp/claude-1000/-home-bchanot-Documents-claude/a1113f35-c77c-47c4-95de-a37231ae0306/scratchpad/p5
mkdir -p "$S/t12/proj" && cd "$S/t12/proj" && git init -q && printf '# t12\n' > CLAUDE.md
for p in dev web; do
  claude -p 'say hi' --model haiku --settings "$HOME/.claude/lib/profiles/$p.json" \
    --output-format stream-json --verbose 2>/dev/null | head -1 > "$S/t12/$p.jsonl" &
done; wait
python3 -I - "$S/t12/dev.jsonl" "$S/t12/web.jsonl" <<'EOF'
import json, sys
for f in sys.argv[1:]:
    d = json.loads(open(f).readline())
    packs = sorted(p["name"] for p in d["plugins"] if p["name"].startswith("pack-"))
    hf = sum(1 for t in d["tools"] if t.startswith("mcp__claude_ai_higgsfield") or t.startswith("mcp__claude_ai_Higgsfield"))
    print(f, packs, "skills", len(d["skills"]), "tools", len(d["tools"]), "higgsfield tools", hf)
EOF
```

Expected: dev → `['pack-gstack-dev']`, higgsfield tools 0; web → the six web packs, higgsfield tools 158; skill counts differ.

- [ ] **Step 2: Two projects, different local profiles**

```bash
for p in qa seo; do
  mkdir -p "$S/t12/$p" && (cd "$S/t12/$p" && git init -q && printf '# %s\n' "$p" > CLAUDE.md && bash "$HOME/.claude/lib/profile.sh" set "$p")
  (cd "$S/t12/$p" && claude -p 'say hi' --model haiku --output-format stream-json --verbose 2>/dev/null | head -1 > "$S/t12/local-$p.jsonl") &
done; wait
# same python as Step 1 on local-qa.jsonl local-seo.jsonl
```

Expected: qa → `pack-gstack-browser`, `pack-web-validate`; seo → `pack-gstack-browser`, `pack-gstack-dev`, `pack-seo`, `pack-web-validate`; both with 0 higgsfield tools.

- [ ] **Step 3: `enable` + `/reload-plugins` without a flag; both slash forms**

```bash
cd "$S/t12/qa" && bash "$HOME/.claude/lib/profile.sh" set minimal >/dev/null
printf '%s\n' \
 '{"type":"user","message":{"role":"user","content":"Use the Skill tool on seo and tell me its first heading, or say UNKNOWN-SKILL."}}' \
 | claude -p --model haiku --max-turns 1 --input-format stream-json --output-format stream-json --verbose 2>/dev/null > "$S/t12/r1.jsonl"
bash "$HOME/.claude/lib/profile.sh" enable seo >/dev/null
printf '%s\n' \
 '{"type":"user","message":{"role":"user","content":"/reload-plugins"}}' \
 '{"type":"user","message":{"role":"user","content":"/seo Do not run anything: answer with the first heading of the skill you just loaded, nothing else."}}' \
 '{"type":"user","message":{"role":"user","content":"/pack-seo:seo Same: first heading only."}}' \
 | claude -p --model haiku --max-turns 1 --tools "" --input-format stream-json --output-format stream-json --verbose 2>/dev/null > "$S/t12/r2.jsonl"
grep -o 'UNKNOWN-SKILL\|Unknown skill[^"]*' "$S/t12/r1.jsonl" | head -2
grep -o '"result":"[^"]\{0,80\}' "$S/t12/r2.jsonl" | head -3
```

Expected: r1 names the skill as unknown; r2's `/reload-plugins` result says `Reloaded: … plugins`, and both `/seo` and `/pack-seo:seo` start the seo skill (the result text comes from the SEO skill's first step, not an unknown-skill error).

- [ ] **Step 4: Record and clean**

Append the four results to `$S/FACTS.md` (`## Task 12 proof`), with the tool and skill counts per profile; put the counts in CHANGELOG (Task 11's entry, "measured" line). `rm -r` nothing: the scratchpad is session-local.

- [ ] **Step 5: Interactive, the user (not the executor)**

Ask the user, in one message, to run once each and paste the numbers: `/context` in a session started with `cc t full`, `cc t dev`, `cc t web` (after the `.bashrc` step), and `cc <name> web` on a real project to confirm the statusline shows `(conv)` and `/profile current` says `[conv web]`. The numbers go to CHANGELOG; nothing else changes.

---

### Task 13: Listing budget (last)

**Files:**
- Modify: `settings.json` (`env.SLASH_COMMAND_TOOL_CHAR_BUDGET` only, staged with `git add -p settings.json` so the UI keys stay out), `CHANGELOG.md` (numbers)

- [ ] **Step 1: Measure**

Re-run the 2026-10-25 ctxprobe bench (its script is referenced in LRN-175; locate with `grep -rn ctxprobe .claude/memory/learnings.md`) on a `full` conversation and a `dev` conversation: count the skills listed name-only at the default budget, then at 40000, 50000, 60000. Pick the smallest value with 0 name-only on `full`.

- [ ] **Step 2: Set and record**

Add `"SLASH_COMMAND_TOOL_CHAR_BUDGET": "<value>"` to `settings.json` `env` (next to `ENABLE_STOP_REVIEW`) without committing the UI writes (`theme`, `switchModelsOnFlag`, a `model` write). `git add -p` is interactive and unavailable, and a `git stash pop` once popped the USER's older stash by mistake (2026-11-01, this plan's own writing): never `stash pop` here, address the entry by name. Procedure, one command per Bash call:

```bash
cp settings.json "$S/settings.ui.json"                      # the working file with the UI writes
git checkout -- settings.json                               # clean tracked copy
jq '.env.SLASH_COMMAND_TOOL_CHAR_BUDGET = "<value>"' settings.json > "$S/settings.env.json"
cp "$S/settings.env.json" settings.json
git diff settings.json                                      # exactly one added env line (jq keeps key order and 2-space indent; a wider diff → stop)
git add settings.json
git commit -m "feat(settings): SLASH_COMMAND_TOOL_CHAR_BUDGET=<value>: 0 name-only skills on full (+<n>k tokens), measured"
jq '.env.SLASH_COMMAND_TOOL_CHAR_BUDGET = "<value>"' "$S/settings.ui.json" > settings.json   # UI writes back, uncommitted
git status --short settings.json                            # ` M settings.json` again
```

CHANGELOG gets the per-profile numbers (name-only before/after, token delta).

---

## Self-review notes

- Spec coverage: § 1 packs → T2; § 2 profiles and verbs → T3; § 3 cc → T4; § 4 gates/hooks/doctor → T5, T6, T7; § 5 budget → T13; § 6 cleanup → T2, T7, T8, T9, T11; registers → ship-feature STEP 7 CAPITALIZE (BDR phase 5 superseding BDR-030/079/101, amending BDR-024/025/109), not a plan task; § 7 proof → T2 S8, T10, T11 S3, T12; § 8 errors → T3 tests T8-T10, T14, T16, T4 T1, T2 census, T5 T8.
- Deviations from the spec, each justified in its task: impeccable is installer-owned (symlink into `skills-external/impeccable`, installer moves it); `skills-disabled/` entries are untracked (plain `rm`); `higgsfield.test.sh` is trimmed, not deleted (keeps the sync coverage); the census excludes `lib/tests/fixtures/` and `docs/`.
- Types: `current --plain` keys are spelled identically in T3 (producer), T5, T6, T7 (consumers): `profile=`, `source=`, `flag=`, `pack-<n>=`, `plugin:<id>=`, `connector:<name>=denied`, `connector:*=denied`, `model=`, `model-source=`, `mcp-off=`.
- Review Focus → tests: 1 → T3 T7-union; 2 → T3 T2-show-missing + T16; 3 → T1 C3 + T2 census; 4 → T3 T4-keep-* + T12-unset-perm; 5 → T7 statusline T4/T5 (failing or missing profile.sh; a missing `jq` makes `profile.sh` die with rc 2, the same path).
