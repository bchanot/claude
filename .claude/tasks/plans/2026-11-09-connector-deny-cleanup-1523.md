# Connector deny cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the dead claude.ai Higgsfield connector denies from five profile fragments, the census rule that enforced them, and every prose citer, keeping the generic `deniedMcpServers` mechanism of `lib/profile.sh`.

**Architecture:** Two tasks. Task 1 changes data and its checker together (the five JSON fragments, the census rule in `lib/pack-census-fragments.jq`, its caller `lib/pack-census.sh`, its suite `lib/tests/pack-census.test.sh`): they are coupled, a partial change turns the census red. Task 2 rewrites the prose that describes profiles by connector state.

**Tech Stack:** bash, jq 1.8, markdown. Tests: `make test suite=lib/tests/pack-census.test.sh`, then full `make test`.

**Spec:** contract `.claude/tasks/contracts/2026-11-09-connector-deny-cleanup-1523.md` (REQUEST verbatim, CLARIFICATIONS `[gated 2026-11-09]`: delete the census connector rule entirely, correct CHANGELOG `[Unreleased]` in place, delete the union note in skills/profile/SKILL.md).

## Global Constraints

- Branch `chore/connector-deny-cleanup` off develop (cleanup, no new behavior). Never commit on develop. Never `gitflow.sh finish`.
- Do NOT modify `lib/profile.sh`, `lib/profile-state.jq`, `lib/tests/profile.test.sh` (generic mechanism, contract criterion 3).
- Foreign code style: keep each file's existing style, inline, no new helper.
- Max 80 chars/line in `lib/pack-census.sh` (T12-width lock); shellcheck clean.
- No em-dash in new prose. Profile description lines in `lib/profiles/README.md` keep the exact shape `- **name**: text` (parsed by `profile.sh list`).
- In files other than CHANGELOG.md, `.claude/`, `skills-external/`: no occurrence of `claude.ai higgsfield`, `claude.ai Higgsfield AI`, `DENY_PROFILES`, `higgsfield connectors`, `connecteurs higgsfield`; in `lib/profiles/README.md`, `skills/profile/SKILL.md`, `lib/tests/pack-census.test.sh`: no `connectors present`, `connectors denied`, `deny set` (contract criterion 2).
- Full suite command: `GATES_TIMEOUT=600 PATH="$HOME/.bun/bin:$PATH" make test` (LRN-271: needs bun, > 120 s).
- Line numbers in this plan are PRE-EDIT; they shift after an earlier edit in the same file. Match on the quoted old text, never on the number.

## Review Focus

- The identical-fragment check still compares the deny set (`dn` stays in `lib/pack-census-fragments.jq:6` and :13-16); a future fragment with a deny must not be reported identical to one without. No test exercises it today (pre-existing); not added (YAGNI, contract scope).
- jq program structure after deleting the rule block: the generator list must stay well-formed (every item separated by `,`); verified by T1 green and T11 real-repo green.
- `profile.sh list` output after the README edit: three description lines lose their connector clause; run `bash lib/profile.sh list` and check 9 lines (format `printf '%-10s %s'`: padded name, then text) and no line containing `(no line in lib/profiles/README.md)`.
- The new production state (no fragment denies anything, `managed_connectors` empty) is not covered by lib/tests/profile.test.sh (frozen, its fixtures always deny X/Y): smoke the read-only verbs on the real repo in Task 1 Step 7.
- A project already holding the two denies in `.claude/settings.local.json` (none on this machine) keeps them; `profile.sh unset` will not strip them any more. Documented in the CHANGELOG bullet, no code.
- `dn` unused warning: jq has none; nothing to do.

---

### Task 1: Fragments and census without the connector rule

**Files:**
- Modify: `lib/tests/pack-census.test.sh:4`, `:29-33`, `:89`, `:92`
- Modify: `lib/pack-census-fragments.jq:1-4`, `:10`, `:28-33`
- Modify: `lib/pack-census.sh:12-15`, `:38`, `:78`
- Modify: `lib/profiles/audit.json`, `lib/profiles/dev.json`, `lib/profiles/minimal.json`, `lib/profiles/qa.json`, `lib/profiles/seo.json` (drop `deniedMcpServers`)

**Interfaces:**
- Consumes: nothing.
- Produces: `lib/pack-census.sh` called as before (`[--repo <dir>] [--installed]`), no `--arg deny` to the jq program; `frag()` test helper with 3 params `name alpha beta`.

- [ ] **Step 1: Write the failing test (fixture without denies)**

In `lib/tests/pack-census.test.sh` replace lines 29-33:

```bash
frag() { # name alpha beta deny(yes|no) — the two real connector names
  local d=""; [ "$4" = yes ] && d=', "deniedMcpServers": [{"serverName": "claude.ai higgsfield"}, {"serverName": "claude.ai Higgsfield AI"}]'
  printf '{"enabledPlugins": {"model-router@skills-dir": true, "pack-alpha@skills-dir": %s, "pack-beta@skills-dir": %s, "security-guidance@claude-code-plugins": true, "example-skills@anthropic-agent-skills": false, "brightdata-plugin@synced": false}%s}\n' \
    "$2" "$3" "$d" > "$FX/lib/profiles/$1.json"; }
frag full true false no; frag dev false false yes
```

with:

```bash
frag() { # name alpha beta
  printf '{"enabledPlugins": {"model-router@skills-dir": true, "pack-alpha@skills-dir": %s, "pack-beta@skills-dir": %s, "security-guidance@claude-code-plugins": true, "example-skills@anthropic-agent-skills": false, "brightdata-plugin@synced": false}}\n' \
    "$2" "$3" > "$FX/lib/profiles/$1.json"; }
frag full true false; frag dev false false
```

Line 89 `frag full true true no` becomes `frag full true true`; line 92 `frag full true false no` becomes `frag full true false`.

Line 4 `# fragment invariants (same key set, fixed values, deny set, full = manifest` becomes `# fragment invariants (same key set, fixed values, full = manifest`.

- [ ] **Step 2: Run the suite, verify it fails**

Run: `make test suite=lib/tests/pack-census.test.sh`
Expected: FAIL on T1-green-rc, T1-green, T2-off-dangling-rc and T3-on-dangling-test-rc (the fixture `dev.json` now denies nothing while the census still requires both denies on `dev`: `RED lib/profiles/dev.json: must deny both higgsfield connectors`, and that RED persists across the census runs those cases make).

- [ ] **Step 3: Remove the rule from the jq program**

`lib/pack-census-fragments.jq` lines 1-4 (the header, ending `# and WARN lines for a pack id with no manifest.`) become:

```jq
# lib/pack-census-fragments.jq — fragment invariants (lib/pack-census.sh).
# $m = manifests [{id,on}]; inputs = lib/profiles/*.json. Prints RED lines,
# and WARN lines for a pack id with no manifest.
```

Delete line 10:

```jq
| ($deny | split(" ") | map(. + ".json")) as $deny_files
```

Delete lines 28-33 (the whole generator item, including its trailing comma):

```jq
  ( (["claude.ai higgsfield", "claude.ai Higgsfield AI"] | sort) as $both
    | if (($deny_files | index($f)) != null) and (($g | dn) != $both)
      then "RED lib/profiles/\($f): must deny both higgsfield connectors"
      elif (($deny_files | index($f)) == null) and (($g | dn) | length) > 0
      then "RED lib/profiles/\($f): must deny no connector"
      else empty end ),
```

Keep `def dn` (line 6) and its use in the identical-fragment check.

- [ ] **Step 4: Remove the deny list from the caller**

`lib/pack-census.sh` lines 12-15:

```bash
#   2. fragments lib/profiles/*.json: same key set as full.json; model-router
#      + security-guidance true, example-skills + brightdata false
#      everywhere; the two higgsfield connectors denied on exactly
#      DENY_PROFILES; full.json packs = manifest defaults.
```

become:

```bash
#   2. fragments lib/profiles/*.json: same key set as full.json; model-router
#      + security-guidance true, example-skills + brightdata false
#      everywhere; full.json packs = manifest defaults.
```

Delete line 38: `DENY_PROFILES="audit dev minimal qa seo"   # spec § 2`.

Line 78 `  out="$(jq -rn --arg deny "$DENY_PROFILES" --argjson m "$(manifests_json)" \` becomes:

```bash
  out="$(jq -rn --argjson m "$(manifests_json)" \
```

- [ ] **Step 5: Run the suite, verify fixtures and T11 pass**

Run: `make test suite=lib/tests/pack-census.test.sh`
Expected: T1..T10, T13, T14, T12 pass. T11 still passes too (the real fragments carry denies and no rule forbids them any more). Note it: removing the rule alone does not flag the dead data, so Step 6 is driven by contract criterion 1, not by T11.

- [ ] **Step 6: Drop the denies from the five fragments**

For each of `audit dev minimal qa seo` (jq round-trip is byte-identical on these files, checked on full.json):

```bash
for p in audit dev minimal qa seo; do
  f="lib/profiles/$p.json"
  jq 'del(.deniedMcpServers)' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
for f in lib/profiles/*.json; do jq -e 'has("deniedMcpServers") | not' "$f" >/dev/null || echo "still: $f"; done
```

Expected: no `still:` line; `git diff --stat lib/profiles` shows 5 files, 9 deletions and 1 change each (the `},` before the block becomes `}`).

- [ ] **Step 7: Run the suite and the real census**

Run: `make test suite=lib/tests/pack-census.test.sh && bash lib/pack-census.sh | tail -1 && shellcheck lib/pack-census.sh`
Expected: suite green (T11 `PACKS OK 9 packs 55 skills`), last census line `PACKS OK 9 packs 55 skills`, shellcheck silent. Also `bash lib/profile.sh list` prints 9 profiles.

Smoke the read-only verbs on the real repo (no write): `bash lib/profile.sh current --plain` (rc 0, `profile=full`), `bash lib/profile.sh show dev` (contains `connectors denied: none`), `bash lib/profile.sh diff dev` (no line starting `connectors denied:`).

- [ ] **Step 8: Commit**

```bash
git add lib/tests/pack-census.test.sh lib/pack-census-fragments.jq lib/pack-census.sh lib/profiles/audit.json lib/profiles/dev.json lib/profiles/minimal.json lib/profiles/qa.json lib/profiles/seo.json
git commit -m "chore(profiles): drop the dead higgsfield connector denies and their census rule"
```

### Task 2: Prose citers

**Files:**
- Modify: `lib/profiles/README.md:3-13`, `:17`, `:19`, `:21`, `:27-31`
- Modify: `skills/profile/SKILL.md:25-27`, `:37-38`, `:61-63`
- Modify: `USAGE.md:242`
- Modify: `CHANGELOG.md:62`, `:63`, end of `[Unreleased]` `### Changed` (after the `skillOverrides` bullet, before `### Removed`)

**Interfaces:**
- Consumes: Task 1 done (profiles carry no deny).
- Produces: none (docs).

- [ ] **Step 1: Write the failing check (contract criterion 2)**

```bash
a='claude\.ai higgsfield|claude\.ai Higgsfield AI|DENY_PROFILES|higgsfield connectors|connecteurs higgsfield'
b='connectors present|connectors denied|deny set'
docs='lib/profiles/README.md skills/profile/SKILL.md lib/tests/pack-census.test.sh'
git grep -n -E "$a" -- ':!.claude' ':!skills-external' ':!CHANGELOG.md'; git grep -n -E "$b" -- $docs
```

Expected now: hits in lib/profiles/README.md, skills/profile/SKILL.md, USAGE.md (the check fails).

- [ ] **Step 2: lib/profiles/README.md**

Lines 3-13 become:

```markdown
A profile is a literal Claude Code settings fragment: `enabledPlugins`
(every pack `pack-<n>@skills-dir` and managed plugin, explicit), optional
`deniedMcpServers` (claude.ai connectors to deny), optional
`model`. Per project: `bash ~/.claude/lib/profile.sh set <name>` writes it
into `.claude/settings.local.json`, then `/reload-plugins`. Per
conversation: `cc <session> <name>` (lib/cc.sh) runs
`claude --settings lib/profiles/<name>.json`; that conversation is frozen
(no reload brings a pack back; relaunch instead). No profile = the manifest
defaults = `full`.
```

(Only the parenthetical of line 5 changes, line 11 is cut after `full`, and the union sentence of lines 11-13 goes; lines 6-10 stay byte-identical.)

Line 17 becomes `- **full**: every pack except higgsfield and extras; ui-ux-pro-max on. The default.`
Line 19 becomes `- **minimal**: no pack, no design plugin; the smallest listing.`
Line 21 becomes `- **design**: design, scroll3d, gstack-design, gstack-browser, ui-ux-pro-max.`

Lines 27-31 (invariants) become:

```markdown
Invariants (checked by `lib/pack-census.sh`): the same key set in every
fragment; `model-router@skills-dir` and `security-guidance@claude-code-plugins`
true everywhere; `example-skills@anthropic-agent-skills` and
`brightdata-plugin@synced` false everywhere; `full` equal to the manifest
defaults.
```

- [ ] **Step 3: skills/profile/SKILL.md**

Lines 25-27 become:

```markdown
`lib/profiles/<name>.json` holds `enabledPlugins` (every pack and managed
plugin, explicit), optional `deniedMcpServers` (claude.ai connectors to
deny) and optional `model`. Descriptions: `lib/profiles/README.md`.
```

(Field order kept; only the parenthetical changes.)

Lines 37-38 (`- No profile: the manifest defaults, which equal \`full\` with the connectors` / `present.`) become `- No profile: the manifest defaults, which equal \`full\`.`

Delete lines 61-63 (the bullet starting `- \`deniedMcpServers\` is a union across settings files`).

- [ ] **Step 4: USAGE.md:242**

Delete exactly this sentence and the space before it: ` \`cc x web\` sur un projet en \`dev\` garde les connecteurs higgsfield refusés (union); \`set web\` dans le projet les rend.` The line keeps `… reste sans effet. \`cc\` est une fonction de \`lib/cc.sh\`…`.

- [ ] **Step 5: CHANGELOG.md [Unreleased]**

Delete line 62 (`- Known limit: \`cc x web\` on a project in \`dev\` keeps the higgsfield connectors denied …`).

In line 63 replace ` (the stderr line "blocked by enterprise policy: claude.ai higgsfield, claude.ai Higgsfield AI" appeared on the deny profiles dev, qa, seo and minimal: that is \`deniedMcpServers\` working)` with nothing (the sentence continues with `; qa = …`).

Append at the end of `### Changed` (after the `skillOverrides` bullet, before the blank line and `### Removed`):

```markdown
- Profiles deny no claude.ai connector: the two higgsfield connectors were removed from the claude.ai account on 2026-11-09, so `deniedMcpServers` leaves `audit`, `dev`, `minimal`, `qa` and `seo`, and the pack census drops its connector rule. A project that ran `profile.sh set` with one of those five profiles before this change keeps the two entries in its `.claude/settings.local.json`, and no profile verb strips them any more: harmless while the connectors stay removed, delete them by hand before reconnecting either one. Reconnecting them for good: revert the `chore(profiles)` commit of this change, which restores the denies and their census rule.
```

- [ ] **Step 6: Run the check and the suites**

Run the Step 1 command: expected no output. Then `grep -c '—' <(git diff develop -- lib/profiles/README.md skills/profile/SKILL.md USAGE.md CHANGELOG.md | grep '^+' | grep -v '^+++')` → `0`. Then `bash lib/profile.sh list` (9 lines). Then `GATES_TIMEOUT=600 PATH="$HOME/.bun/bin:$PATH" make test` → `all suites green`.

- [ ] **Step 7: Commit**

```bash
git add lib/profiles/README.md skills/profile/SKILL.md USAGE.md CHANGELOG.md
git commit -m "docs(profiles): profiles no longer described by connector state"
```
