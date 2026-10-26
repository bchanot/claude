# Phase 0 — split project CLAUDE.md into `.claude/rules/` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the four path-bound sections of this repo's project CLAUDE.md into `.claude/rules/<name>.md` path rules, prove they load, and give every project the same lever (`/onboard split`, generators born split).

**Architecture:** One bash lib (`lib/project-rules.sh`: `check`, `sections`, `extract`, `emit`) is the deterministic oracle for every consumer: the `make test` suite, this repo's own split, the onboarder in `MODE: split`, and the two generators. Judgment (which section is path-scoped, which globs) stays in the `/onboard split` main loop; writes are executed by the sonnet onboarder. A permanent `InstructionsLoaded` hook logs every loaded instruction file so a path-rule load is a grep, not a guess.

**Tech Stack:** bash 5 (globstar), awk, jq, shellcheck; markdown skills/agents; Claude Code path-scoped rules (`paths:` frontmatter) and the `InstructionsLoaded` classic hook.

**Spec:** `docs/superpowers/specs/2026-10-26-claude-md-split-design.md`
**Contract:** `.claude/tasks/contracts/2026-10-26-claude-md-split-0042.md`
**Branch:** `feature/claude-md-split` (already started off develop, spec committed 2c8e4a2).

Spec delta, decided while planning: a fourth subcommand `emit <skeleton> <out>` (the spec's "emit only skeletons whose globs match" needs a per-glob prune the sonnet generators cannot do by hand; `emit` writes the rule with the matching globs only, so the strict "each glob matches" check still holds).

## Global Constraints

- Our code (strict): max 25 logic lines per function, 80 chars per line, 5 params, 5 locals; `shellcheck *.sh hooks/*.sh lib/*.sh` clean.
- Subtract-only: section text moves verbatim; nothing deleted from CLAUDE.global.md / rules/; registries (`.claude/memory/*`) are never edited by a task (STEP 7 capitalize owns them).
- Never write into `rules/` (user scope, every project) except the one pointer fix in `rules/README.md`.
- `.gitignore` negations only work with the `.claude/*` file form (BDR-003); the negation line must come AFTER `.claude/*`.
- Hooks never print to stdout (stdout reaches the model) and never block.
- Commit on the feature branch only, one commit per task, message under 50 words, no attribution lines.
- Frontmatter shape is exactly `paths: ["glob", "glob"]` on one line (as `rules/a11y.md`).
- Commands with a shell variable in the path are denied by the permission rules in this repo: write literal paths in every Bash step.

## Review Focus

1. A heading inside a fenced code block in CLAUDE.md (` ```\n## x\n``` `) must not be read as a section by `sections`/`extract` (test T6 in Task 1).
2. `extract` on a heading that is absent, or onto a rule file that already exists, must write nothing and exit 2 (test T8 in Task 1).
3. A glob with a typo (`skils/**`) must fail `check` with the culprit named, and the skip marker must only silence globs of its own file (tests T2, T4 in Task 1).
4. `emit` on a project where only some globs of a skeleton match must keep exactly the matching ones; none matching → nothing written, rc 1 (test T12 in Task 7).
5. The hook must exit 0 and print nothing when `jq` is absent or the log dir is unwritable, so a broken log never reaches the model (test T10f in Task 2).

---

### Task 1: `lib/project-rules.sh` + its suite (check / sections / extract)

**Files:**
- Create: `lib/project-rules.sh`
- Create: `lib/tests/project-rules.test.sh`

**Interfaces:**
- Produces: `bash lib/project-rules.sh check [dir]` (rc 0 + `project-rules: N rule(s) ok`; rc 2 + `<file>: <reason>` lines; `<file>: SKIP <glob>` lines for a skip-marked file); `sections <CLAUDE.md>` (`<chars>\t<line>\t## <heading>` per top-level section); `extract <CLAUDE.md> "<heading without ##>" <out.md> '<globs-json>'` (rc 0 moved; rc 2 heading absent / target exists / malformed globs, nothing written). Functions are sourceable (`source lib/project-rules.sh`; main guarded by `BASH_SOURCE`).

- [ ] **Step 1: Write the failing suite (T1-T9)**

Create `lib/tests/project-rules.test.sh`:

```bash
#!/usr/bin/env bash
# lib/tests/project-rules.test.sh — lib/project-rules.sh (check / sections /
# extract / emit) and hooks/instructions-loaded.sh. Flip-tests on fixtures
# first (LRN-096), then the real check on this repo's .claude/rules.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
PR="$ROOT/lib/project-rules.sh"
FIX=$(mktemp -d); trap 'rm -rf "$FIX"' EXIT
cd "$FIX" || exit 1
mkdir -p .claude/rules src
echo x > src/app.ts

# T1 a good rule passes
printf -- '---\npaths: ["src/**"]\n---\n\n# Src\nbody\n' > .claude/rules/good.md
bash "$PR" check >/dev/null; check T1-good-rule-passes "$?" 0

# T2 an unmatched glob fails, culprit named (flip test)
printf -- '---\npaths: ["src/**", "nowhere/**"]\n---\n\n# Bad\n' > .claude/rules/bad.md
out=$(bash "$PR" check); rc=$?
check T2-unmatched-glob-fails "$rc" 2
check T2b-culprit-named \
  "$(printf '%s\n' "$out" | grep -c 'bad.md: glob matches nothing: nowhere/\*\*')" 1
rm .claude/rules/bad.md

# T3 missing frontmatter fails
printf '# No front\nbody\n' > .claude/rules/nofm.md
out=$(bash "$PR" check); rc=$?
check T3-missing-frontmatter-fails "$rc" 2
check T3b-named "$(printf '%s\n' "$out" | grep -c 'nofm.md: no frontmatter')" 1
rm .claude/rules/nofm.md

# T4 the skip marker passes an unmatched glob, and only in its own file
printf -- '---\npaths: ["nowhere/**"]\n# static-check: skip\n---\n\n# T\n' \
  > .claude/rules/skip.md
out=$(bash "$PR" check); rc=$?
check T4-skip-marker-passes "$rc" 0
check T4b-skip-printed "$(printf '%s\n' "$out" | grep -c 'skip.md: SKIP nowhere/\*\*')" 1
printf -- '---\npaths: ["nowhere2/**"]\n---\n\n# U\n' > .claude/rules/other.md
bash "$PR" check >/dev/null; check T4c-skip-is-per-file "$?" 2
rm .claude/rules/skip.md .claude/rules/other.md

# T5 an absent dir is not an error
rm -rf .claude/rules
out=$(bash "$PR" check); check T5-absent-dir-ok "$?" 0
check T5b-zero-rules "$(printf '%s' "$out" | grep -c '0 rule(s) ok')" 1
mkdir -p .claude/rules

# T6 sections lists headings with sizes, fence-aware
cat > CLAUDE.md <<'EOF'
# Proj

## Alpha
aaa

---

## Beta
```
## not a heading
```
bbb
EOF
out=$(bash "$PR" sections CLAUDE.md)
check T6-two-sections "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" 2
check T6b-beta-line "$(printf '%s\n' "$out" | awk -F'\t' '$3=="## Beta"{print $2}')" 8
check T6c-alpha-chars "$(printf '%s\n' "$out" | awk -F'\t' '$3=="## Alpha"{print $1}')" 19

# T7 extract moves the section, writes the frontmatter, demotes the title
bash "$PR" extract CLAUDE.md "Alpha" .claude/rules/alpha.md '["src/**"]' >/dev/null
check T7-extract-rc "$?" 0
check T7b-rule-frontmatter "$(sed -n '2p' .claude/rules/alpha.md)" 'paths: ["src/**"]'
check T7c-rule-title "$(sed -n '5p' .claude/rules/alpha.md)" '# Alpha'
check T7d-rule-body "$(sed -n '6p' .claude/rules/alpha.md)" 'aaa'
check T7e-trailing-sep-trimmed "$(tail -1 .claude/rules/alpha.md)" 'aaa'
check T7f-section-gone "$(grep -c '^## Alpha' CLAUDE.md)" 0
check T7g-beta-kept "$(grep -c '^## Beta' CLAUDE.md)" 1
check T7h-fenced-line-kept "$(grep -c '^## not a heading' CLAUDE.md)" 1
bash "$PR" check >/dev/null; check T7i-check-passes "$?" 0

# T8 extract refuses a missing heading and an existing target, writes nothing
bash "$PR" extract CLAUDE.md "Alpha" .claude/rules/alpha2.md '["src/**"]' 2>/dev/null
check T8-missing-heading-rc "$?" 2
check T8b-nothing-written "$(ls .claude/rules | wc -l | tr -d ' ')" 1
bash "$PR" extract CLAUDE.md "Beta" .claude/rules/alpha.md '["src/**"]' 2>/dev/null
check T8c-existing-target-rc "$?" 2
check T8d-beta-still-there "$(grep -c '^## Beta' CLAUDE.md)" 1

# T9 extract refuses a malformed globs argument
bash "$PR" extract CLAUDE.md "Beta" .claude/rules/beta.md 'src/**' 2>/dev/null
check T9-bad-globs-rc "$?" 2
check T9b-nothing-written "$(ls .claude/rules/beta.md 2>/dev/null | wc -l | tr -d ' ')" 0

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
```

(T6c: the Alpha section spans `## Alpha`, `aaa`, blank, `---`, blank; each line counts its length plus one newline: 9+4+1+4+1 = 19.)

- [ ] **Step 2: Run the suite, verify it fails**

Run: `bash lib/tests/project-rules.test.sh`
Expected: many `FAIL …` lines (the lib does not exist), last line `PASS=0 FAIL=…`, exit 1.

- [ ] **Step 3: Write the lib**

Create `lib/project-rules.sh`:

```bash
#!/usr/bin/env bash
# lib/project-rules.sh — project-scope path rules (.claude/rules/<name>.md),
# BDR-125 phase 0. One deterministic oracle for the make-test suite, the
# /onboard split mode, the onboarder and the scaffolder:
#   check [dir]        frontmatter parses, every glob matches ≥1 path (rc 2)
#   sections <file>    "<chars>\t<line>\t## <heading>" per top-level section
#   extract <file> <heading> <out> <globs-json>   move one section to a rule
#   emit <skeleton> <out>   write the rule with the globs that match (rc 1
#                           when none matches, nothing written)
# Globs match the WORKING TREE (globstar, dotglob, through symlinks): the
# engine matches the path the model reads, tracked or not; a typo matches
# nothing either way. A frontmatter line `# static-check: skip` exempts a
# rule whose files only exist mid-run (docs/superpowers/**).
set -uo pipefail

_rules_frontmatter() {  # <file> → frontmatter body on stdout, rc 1 if none
  awk 'NR == 1 && $0 != "---" { exit 1 }
       NR > 1 && $0 == "---" { found = 1; exit }
       NR > 1 { print }
       END { exit found ? 0 : 1 }' "$1"
}

_rules_globs() {  # <frontmatter text> → one glob per line, rc 1 if no paths:
  local line
  line=$(printf '%s\n' "$1" | grep -E '^paths: *\[.*\] *$') || return 1
  printf '%s\n' "$line" | grep -oE '"[^"]+"' | tr -d '"'
}

_rules_glob_matches() {  # <glob> → rc 0 when ≥1 path exists in the tree
  local -a hits
  shopt -s globstar dotglob nullglob
  # shellcheck disable=SC2206  # the glob MUST expand: that is the test
  hits=( $1 )
  shopt -u globstar dotglob nullglob
  [ "${#hits[@]}" -gt 0 ]
}

_rules_matching() {  # <globs, one per line> → JSON array of the matching ones
  local g out=""
  while IFS= read -r g; do
    [ -n "$g" ] && _rules_glob_matches "$g" && out="$out, \"$g\""
  done <<< "$1"
  [ -n "$out" ] || return 1
  printf '[%s]\n' "${out#, }"
}

_rules_check_file() {  # <rule.md> → rc 0 ok, rc 1 with the culprit lines
  local fm globs skip=0 g bad=0
  fm=$(_rules_frontmatter "$1") || { echo "$1: no frontmatter"; return 1; }
  globs=$(_rules_globs "$fm") || { echo "$1: no paths: array"; return 1; }
  printf '%s\n' "$fm" | grep -qx '# static-check: skip' && skip=1
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    if [ "$skip" = 1 ]; then echo "$1: SKIP $g"; continue; fi
    _rules_glob_matches "$g" || { echo "$1: glob matches nothing: $g"; bad=1; }
  done <<< "$globs"
  [ "$bad" = 0 ]
}

project_rules_check() {  # [dir] → rc 0 all ok, rc 2 with culprits named
  local dir="${1:-.claude/rules}" f n=0 bad=0
  [ -d "$dir" ] || { echo "project-rules: 0 rule(s) ok ($dir absent)"; return 0; }
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    n=$((n + 1))
    _rules_check_file "$f" || bad=1
  done
  [ "$bad" = 0 ] || return 2
  echo "project-rules: $n rule(s) ok"
}

project_rules_sections() {  # <CLAUDE.md> → "<chars>\t<line>\t## <heading>"
  [ -f "$1" ] || { echo "project-rules: $1 not found" >&2; return 2; }
  awk '
    /^```/ { fence = !fence }
    /^## / && !fence { if (h != "") printf "%d\t%d\t%s\n", c, l, h
                       h = $0; l = NR; c = 0 }
    h != "" { c += length($0) + 1 }
    END { if (h != "") printf "%d\t%d\t%s\n", c, l, h }' "$1"
}

_rules_section_body() {  # <file> <heading> → body, trailing ---/blank trimmed
  awk -v h="## $2" '
    /^```/ { fence = !fence }
    !fence && $0 == h { on = 1; next }
    !fence && on && /^## / { exit }
    on { buf[++n] = $0 }
    END { while (n > 0 && (buf[n] == "" || buf[n] == "---")) n--
          for (i = 1; i <= n; i++) print buf[i] }' "$1"
}

_rules_without_section() {  # <file> <heading> → the file minus that section
  awk -v h="## $2" '
    /^```/ { fence = !fence }
    !fence && $0 == h { skip = 1; next }
    !fence && skip && /^## / { skip = 0 }
    !skip { print }' "$1"
}

project_rules_extract() {  # <CLAUDE.md> <heading> <out.md> <globs-json>
  local src="$1" heading="$2" out="$3" globs="$4" tmp
  grep -qxF -- "## $heading" "$src" \
    || { echo "project-rules: heading not found: ## $heading" >&2; return 2; }
  [ -e "$out" ] && { echo "project-rules: $out exists" >&2; return 2; }
  _rules_globs "paths: $globs" >/dev/null \
    || { echo "project-rules: globs must be a JSON array: $globs" >&2; return 2; }
  mkdir -p "$(dirname "$out")"
  { printf -- '---\npaths: %s\n---\n\n# %s\n' "$globs" "$heading"
    _rules_section_body "$src" "$heading"; } > "$out"
  tmp=$(mktemp)
  _rules_without_section "$src" "$heading" > "$tmp" && cat "$tmp" > "$src"
  rm -f "$tmp"
  echo "project-rules: moved \"## $heading\" to $out"
}

project_rules_emit() {  # <skeleton.md> <out.md> → the rule, matching globs only
  local fm globs kept
  fm=$(_rules_frontmatter "$1") \
    || { echo "project-rules: $1: no frontmatter" >&2; return 2; }
  globs=$(_rules_globs "$fm") \
    || { echo "project-rules: $1: no paths: array" >&2; return 2; }
  kept=$(_rules_matching "$globs") \
    || { echo "project-rules: $1: no glob matches, not emitted" >&2; return 1; }
  [ -e "$2" ] && { echo "project-rules: $2 exists" >&2; return 2; }
  mkdir -p "$(dirname "$2")"
  { printf -- '---\npaths: %s\n---\n' "$kept"
    awk 'body { print } NR > 1 && $0 == "---" { body = 1 }' "$1"; } > "$2"
  echo "project-rules: emitted $2 paths: $kept"
}

_project_rules_main() {
  case "${1:-}" in
    check)    project_rules_check "${2:-.claude/rules}" ;;
    sections) project_rules_sections "${2:?CLAUDE.md path}" ;;
    extract)  project_rules_extract "${2:?file}" "${3:?heading}" "${4:?out}" \
                                    "${5:?globs-json}" ;;
    emit)     project_rules_emit "${2:?skeleton}" "${3:?out}" ;;
    *) echo "usage: project-rules.sh check [dir] | sections <file>" \
            "| extract <file> <heading> <out> <globs-json>" \
            "| emit <skeleton> <out>" >&2; return 2 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then _project_rules_main "$@"; fi
```

- [ ] **Step 4: Run the suite, verify T1-T9 pass**

Run: `bash lib/tests/project-rules.test.sh`
Expected: `PASS=33 FAIL=0`, exit 0 (count may differ by one or two; the invariant is `FAIL=0`).

- [ ] **Step 5: shellcheck + make test on the new suite**

Run: `shellcheck lib/project-rules.sh lib/tests/project-rules.test.sh && make test suite=lib/tests/project-rules.test.sh`
Expected: no shellcheck output; `all suites green`.

- [ ] **Step 6: Commit**

```bash
git add lib/project-rules.sh lib/tests/project-rules.test.sh
git commit -m "feat(rules): lib/project-rules.sh check/sections/extract/emit + suite"
```

---

### Task 2: InstructionsLoaded proof hook

**Files:**
- Create: `hooks/instructions-loaded.sh`
- Modify: `settings.json` (hooks block, after `"SessionStart": [...]`, line ~374)
- Modify: `lib/tests/project-rules.test.sh` (append T10 before the tally)

**Interfaces:**
- Produces: one JSON line per loaded instruction file in `~/.claude/logs/instructions-loaded.jsonl` (`ts, cwd, file_path, memory_type, load_reason, trigger_file_path`); `CLAUDE_INSTRUCTIONS_LOG=<path>` overrides the log path (tests).

- [ ] **Step 1: Append the failing hook tests (T10) to the suite**

Insert before the `echo "PASS=$pass FAIL=$fail"` line of `lib/tests/project-rules.test.sh`:

```bash
# T10 the hook appends one jq line, prints nothing, never fails
HOOK="$ROOT/hooks/instructions-loaded.sh"
LOG="$FIX/il.jsonl"
IN='{"hook_event_name":"InstructionsLoaded","cwd":"/p","file_path":"/p/.claude/rules/x.md","memory_type":"Project","load_reason":"path_glob_match","trigger_file_path":"/p/src/a.ts"}'
out=$(printf '%s' "$IN" | CLAUDE_INSTRUCTIONS_LOG="$LOG" bash "$HOOK"); rc=$?
check T10-hook-rc "$rc" 0
check T10b-stdout-empty "$out" ""
check T10c-one-line "$(wc -l < "$LOG" | tr -d ' ')" 1
check T10d-reason-kept "$(jq -r '.load_reason' "$LOG")" path_glob_match
check T10e-trigger-kept "$(jq -r '.trigger_file_path' "$LOG")" /p/src/a.ts
out=$(printf '%s' "$IN" | CLAUDE_INSTRUCTIONS_LOG=/proc/nowhere/il.jsonl bash "$HOOK"); rc=$?
check T10f-unwritable-log-still-rc0 "$rc" 0
check T10g-unwritable-log-stdout-empty "$out" ""
```

- [ ] **Step 2: Run the suite, verify T10 fails**

Run: `bash lib/tests/project-rules.test.sh`
Expected: `FAIL T10-hook-rc` (hook missing), exit 1.

- [ ] **Step 3: Write the hook**

Create `hooks/instructions-loaded.sh`:

```bash
#!/usr/bin/env bash
# hooks/instructions-loaded.sh — InstructionsLoaded hook: one JSON line per
# instruction file the engine loads, into
# ~/.claude/logs/instructions-loaded.jsonl. The proof channel for
# path-scoped rules (BDR-125 phase 0): a rule that loaded shows
# `load_reason: path_glob_match` with the file that triggered it.
# Never blocks, never prints to stdout (stdout reaches the model), exits 0
# whatever happens. CLAUDE_INSTRUCTIONS_LOG overrides the path (tests).
log="${CLAUDE_INSTRUCTIONS_LOG:-$HOME/.claude/logs/instructions-loaded.jsonl}"
command -v jq >/dev/null 2>&1 || exit 0
mkdir -p "$(dirname "$log")" 2>/dev/null || exit 0
jq -c --arg ts "$(date -u +%FT%TZ)" \
  '{ts: $ts, cwd, file_path, memory_type, load_reason, trigger_file_path}' \
  >> "$log" 2>/dev/null
exit 0
```

- [ ] **Step 4: Register it in `settings.json`**

In `settings.json`, after the `"SessionStart": [ ... ],` block (the `],` that closes it, just before `"PreToolUse": [`), insert:

```json
    "InstructionsLoaded": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/instructions-loaded.sh",
            "timeout": 5
          }
        ]
      }
    ],
```

Verify: `jq '.hooks.InstructionsLoaded[0].hooks[0].command' settings.json` prints `"bash ~/.claude/hooks/instructions-loaded.sh"`.

- [ ] **Step 5: Run the suite, verify T10 passes**

Run: `bash lib/tests/project-rules.test.sh && shellcheck hooks/instructions-loaded.sh`
Expected: `FAIL=0`, no shellcheck output.

- [ ] **Step 6: Commit**

```bash
git add hooks/instructions-loaded.sh settings.json lib/tests/project-rules.test.sh
git commit -m "feat(hooks): InstructionsLoaded logger, the proof channel for path rules"
```

---

### Task 3: gitignore negation, here and in the socle

**Files:**
- Modify: `.gitignore:122-126`
- Modify: `templates/gitignore/standard.gitignore` (the `.claude/*` block)
- Modify: `lib/gitflow-test.sh:47` (one more socle assertion)

- [ ] **Step 1: Add the failing socle assertion**

In `lib/gitflow-test.sh`, after line 47 (`chk "socle: !.claude/deploy/" …`), add:

```bash
chk "socle: !.claude/rules/" 'grep -qxF "!.claude/rules/" .gitignore'
```

- [ ] **Step 2: Run gitflow-test, verify the new assertion fails**

Run: `make test suite=lib/gitflow-test.sh 2>&1 | grep -E 'rules|suite'`
Expected: `FAIL socle: !.claude/rules/ …` and `1 suite(s) red`.

- [ ] **Step 3: Patch the socle and this repo's `.gitignore`**

`templates/gitignore/standard.gitignore`: after the line `!.claude/deploy/` add the line `!.claude/rules/` (it must stay after `.claude/*`; reconcile appends missing lines at the end of a project's file, which is after any existing `.claude/*`).

`.gitignore`: after line 122 `.claude/*` and its negations, add `!.claude/rules/` directly after `!.claude/settings.json` (line 126):

```
.claude/*
!.claude/tasks/
!.claude/memory/
!.claude/audits/
!.claude/settings.json
!.claude/rules/
```

- [ ] **Step 4: Verify**

Run: `make test suite=lib/gitflow-test.sh 2>&1 | tail -2 && mkdir -p .claude/rules && touch .claude/rules/.probe && git check-ignore -v .claude/rules/.probe; echo "rc=$?"; rm .claude/rules/.probe`
Expected: `all suites green`; `git check-ignore` prints nothing and `rc=1` (not ignored).

- [ ] **Step 5: Commit**

```bash
git add .gitignore templates/gitignore/standard.gitignore lib/gitflow-test.sh
git commit -m "chore(gitignore): un-ignore .claude/rules/ here and in the gitflow socle"
```

---

### Task 4: split this repo's CLAUDE.md (dogfood `extract`)

**Files:**
- Modify: `CLAUDE.md` (four sections leave, a pointer section arrives)
- Create: `.claude/rules/rules-maintenance.md`, `.claude/rules/graphify-vendored.md`, `.claude/rules/mods.md`, `.claude/rules/transient-artifacts.md`
- Modify: `lib/tests/project-rules.test.sh` (append T11 before the tally)

**Interfaces:**
- Consumes: `lib/project-rules.sh extract` / `check` (Task 1).

- [ ] **Step 1: Append the failing real-repo test (T11)**

Insert before the `echo "PASS=$pass FAIL=$fail"` line of `lib/tests/project-rules.test.sh`:

```bash
# T11 the real rules of this repo pass the check (4 rules, 1 skip-marked)
out=$(cd "$ROOT" && bash "$PR" check); rc=$?
[ "$rc" -eq 0 ] || printf '%s\n' "$out"
check T11-repo-rules-pass "$rc" 0
check T11b-four-rules "$(printf '%s\n' "$out" | grep -c '4 rule(s) ok')" 1
check T11c-transient-skipped \
  "$(printf '%s\n' "$out" | grep -c 'transient-artifacts.md: SKIP docs/superpowers/\*\*')" 1
```

Run: `bash lib/tests/project-rules.test.sh | tail -4`
Expected: `FAIL T11b-four-rules: got[0] want[1]` (0 rules yet).

- [ ] **Step 2: Move the four sections with `extract`**

From the repo root, in this order (headings are exact, copied from CLAUDE.md):

```bash
bash lib/project-rules.sh extract CLAUDE.md "rules/ maintenance" .claude/rules/rules-maintenance.md '["rules/**", "CLAUDE.global.md"]'
bash lib/project-rules.sh extract CLAUDE.md "Machine-owned: the vendored graphify skill" .claude/rules/graphify-vendored.md '["skills/graphify/**", "install-plugins.sh", ".graphify_version"]'
bash lib/project-rules.sh extract CLAUDE.md "mods/ — function-hooks plugins (Claude Code mods)" .claude/rules/mods.md '["mods/**", "skills/model-router/**", "lib/tests/mods.test.sh"]'
bash lib/project-rules.sh extract CLAUDE.md "Transient planning artifacts" .claude/rules/transient-artifacts.md '["docs/superpowers/**", ".audit/**"]'
```

Expected: four `project-rules: moved "## …" to .claude/rules/….md` lines. `git diff --stat CLAUDE.md` shows about 90 deletions and no insertion.

- [ ] **Step 3: Skip marker on the transient rule**

Edit `.claude/rules/transient-artifacts.md`: between the `paths:` line and the closing `---`, insert the line `# static-check: skip`. The file starts:

```
---
paths: ["docs/superpowers/**", ".audit/**"]
# static-check: skip
---

# Transient planning artifacts
```

- [ ] **Step 4: The pointer section in CLAUDE.md**

CLAUDE.md now holds only the title and `## Health Stack`. Append:

```markdown

## Path-scoped rules
Project rules live in `.claude/rules/<name>.md` and load on Read of a file
matching their `paths:` (never at session start): rules-maintenance,
graphify-vendored, mods, transient-artifacts. Check: `bash
lib/project-rules.sh check` (runs in `make test`).
```

The whole file must then read:

```markdown
# claude-config — project instructions

## Health Stack
- shell: `shellcheck *.sh hooks/*.sh lib/*.sh`

## Path-scoped rules
Project rules live in `.claude/rules/<name>.md` and load on Read of a file
matching their `paths:` (never at session start): rules-maintenance,
graphify-vendored, mods, transient-artifacts. Check: `bash
lib/project-rules.sh check` (runs in `make test`).
```

(Remove any run of more than one blank line left by the extraction.)

- [ ] **Step 5: Verify verbatim move and the check**

Run:
```bash
git show HEAD:CLAUDE.md | sed -n '/^## rules\/ maintenance$/,/^## Machine-owned/p' | sed '1d;$d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/old-rules.txt
sed -n '6,$p' .claude/rules/rules-maintenance.md | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/new-rules.txt
diff /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/old-rules.txt /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/new-rules.txt && echo VERBATIM
bash lib/project-rules.sh check
bash lib/tests/project-rules.test.sh | tail -1
git status --short .claude/rules
```
Expected: `VERBATIM`; `transient-artifacts.md: SKIP docs/superpowers/**`, `… SKIP .audit/**`, `project-rules: 4 rule(s) ok`; `PASS=… FAIL=0`; four `??`/`A` entries under `.claude/rules/` (tracked thanks to Task 3).

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md .claude/rules lib/tests/project-rules.test.sh
git commit -m "refactor(claude-md): four sections become .claude/rules path rules (phase 0)"
```

---

### Task 5: citers of the moved sections

**Files:**
- Modify: `rules/README.md:7-9`
- Modify: `doctor.sh:76`

- [ ] **Step 1: Repoint `rules/README.md`**

Replace lines 7-9:

```
Maintenance doctrine (what belongs here, lazy-load `paths:` semantics,
machine-owned files): see `CLAUDE.md` (project scope) at the repo root.
```

with:

```
Maintenance doctrine (what belongs here, lazy-load `paths:` semantics,
machine-owned files): see `.claude/rules/rules-maintenance.md` in the
claude-config repo (project scope, loads on Read under `rules/`).
```

- [ ] **Step 2: Fix the stale doctor comment**

`doctor.sh:76`: replace `(the 29-line project CLAUDE.md instead of` with `(the project CLAUDE.md instead of`.

- [ ] **Step 3: Census grep**

Run:
```bash
grep -rnE 'CLAUDE\.md \(project scope\)|29-line project CLAUDE\.md|Machine-owned: the vendored|§ ?Transient planning|"rules/ maintenance"|"mods/ — function-hooks"' rules/ doctor.sh skills/ agents/ lib/ hooks/ README.md ARCHITECTURE.md --include='*.md' --include='*.sh' | grep -v 'skills-external\|skills/graphify/\|lib/tests/project-rules'
```
Expected: no output. (`lib/gitflow.sh:21` says "transient planning artifacts" in a comment about the purge, not as a citation: leave it. `install-plugins.sh` GUARDED_CONFIGS keeps `CLAUDE.md`: leave it. `ARCHITECTURE.md` is the doc pipeline's, STEP 8.)

- [ ] **Step 4: make test + commit**

Run: `make test suite=lib/tests/doctrine-citers.test.sh | tail -2`
Expected: `all suites green`.

```bash
git add rules/README.md doctor.sh
git commit -m "chore(citers): rules/README and doctor point at .claude/rules after the split"
```

---

### Task 6: `/onboard split` RED pressure test (orchestrator dispatch, no code)

**Files:** none modified. Scratch: `/tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/split-red/` (a git repo holding `CLAUDE.md` = `git show develop:CLAUDE.md`, plus `rules/x.md`, `mods/m/plugin.json`, `.gitignore` with `.claude/*`).

- [ ] **Step 1: Build the scratch repo**

```bash
S=/tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/split-red
mkdir -p "$S/rules" "$S/mods/m" "$S/.claude" && git show develop:CLAUDE.md > "$S/CLAUDE.md" && echo r > "$S/rules/x.md" && echo '{}' > "$S/mods/m/plugin.json" && printf '.claude/*\n!.claude/memory/\n' > "$S/.gitignore" && git -C "$S" init -q && git -C "$S" add -A && git -C "$S" commit -qm init
```

(The denied-variable rule: run it as ONE line with the literal path substituted for `$S`.)

- [ ] **Step 2: Dispatch the RED probe (sonnet)**

`Agent(subagent_type="general-purpose", model="sonnet", effort="medium")` with: "You are executing the skill at `/home/bchanot/.claude/skills/onboard/SKILL.md` with `$ARGUMENTS` = `split`, working directory `<scratch path>`. Read the skill, then do exactly what it tells you for its first three steps, in the scratch directory only; do not dispatch agents, do not run `claude`, do not write outside the scratch. Stop after the third step and report: which steps you ran, whether any step asked you to classify CLAUDE.md sections into path-scoped rules, and what you would have produced."

Expected (RED): the report names MODEL GATE / plugin check / archetype detection; no classification table, no `.claude/rules/` written. Record one line in the plan's commit message of Task 7 ("RED: current skill runs archetype detection on `split`").

If the probe DOES produce a split with the current skill: stop, the mode is unnecessary as designed; re-plan.

---

### Task 7: `/onboard split` mode + onboarder `MODE: split`

**Files:**
- Modify: `skills/onboard/SKILL.md` (frontmatter lines 4-5, after `## REQUEST` ~line 20, RULES line ~1037, append § SPLIT MODE after FINAL OUTPUT)
- Modify: `agents/onboarder.md` (after `## INPUTS`, before `## PHASE 1`; and a new section after PHASE 6)

**Interfaces:**
- Consumes: `project-rules.sh sections|extract|check` (Task 1).
- Produces: the onboarder `MODE: split` contract: INPUTS `PROJECT_ROOT`, `TABLE` rows `<heading> | <name> | <globs-json>`; OUTPUT rules written, check result, commit hash.

- [ ] **Step 1: Skill frontmatter**

Line 4 `description:` — append inside the quoted string, before the closing `'`: ` `split` mode: "split CLAUDE.md", "découpe le CLAUDE.md", "path-scoped rules", "move sections to .claude/rules".`
Line 5: `argument-hint: '[split | optional hints: "Python FastAPI" | "Next.js monorepo" | "force-archetype:wordpress"]'`

- [ ] **Step 2: MODE DISPATCH after `## REQUEST`**

After the `$ARGUMENTS` line of `## REQUEST` and its `---`, insert:

```markdown
## MODE DISPATCH
`$ARGUMENTS` whose first token is `split` → jump to § SPLIT MODE (end of
this file); STEP 0 to FINAL OUTPUT do not run. Anything else → the flow
below, unchanged.

---
```

- [ ] **Step 3: RULES line**

Replace `- NO skipping STEP 0, 1, 2 — ils sont obligatoires.` with `- NO skipping STEP 0, 1, 2 — ils sont obligatoires (split mode runs its own steps, § SPLIT MODE).`

- [ ] **Step 4: § SPLIT MODE appended at the end of the skill**

```markdown

---

## SPLIT MODE — `/onboard split` (BDR-125 phase 0)

Move the path-bound sections of an existing project `CLAUDE.md` into
`.claude/rules/<name>.md` path rules (loaded on Read of a matching file),
so the always-on context of that project shrinks. Judgment here, writes by
the onboarder, `lib/project-rules.sh` as the oracle. The MODEL GATE above
has run. `mcp__model-router__route(phase="plan")` first.

S1 — PRECONDITIONS. `CLAUDE.md` at the project root, else print
`nothing to split — run /onboard` and stop. `git status --porcelain
CLAUDE.md` empty, else stop (an in-flight edit would be lost). `.claude/rules/`
already holding rules → list them, continue (new rules add to them).

S2 — BASELINE. Run `claude -p "/context"` at the root (refused → ask the
user to run `! claude -p "/context"`); note the `Memory files` total and the
project CLAUDE.md row.

S3 — CLASSIFY. `bash ~/.claude/lib/project-rules.sh sections CLAUDE.md`
lists every `##` section with its size. For each one decide:
- always-on: project overview, stack, build/test/lint commands, folder
  structure, conventions that apply everywhere, exceptions to global rules,
  workflow expectations, key dependencies;
- path-scoped: one module or folder, Docker, migrations, CI, a tool's
  gotchas, a vendored or machine-owned area. Propose `<name>` (kebab, the
  section's subject) and globs from `git ls-files` (a folder → `dir/**`,
  a tool → its config files), and verify every proposed glob with
  `git ls-files '<glob>'` (≥1 line) before showing it.
  Sections that are needed before any file is read (how to run the project)
  stay always-on even when they name a folder.

S4 — GATE (mandatory stop). Print the table, then end the turn:

```
SPLIT — <project> CLAUDE.md (<chars> chars, <n> sections)
| # | section | chars | verdict | rule file | paths |
| 1 | Stack | 420 | keep | | |
| 2 | Docker | 1,340 | move | docker.md | ["Dockerfile*", "docker-compose*"] |
...
Moves <k> sections, <m> chars (<p>% of the file). Approve, edit a row, or "keep everything".
```
"keep everything" ends the mode with no change. The approved rows are the
TABLE handed to the onboarder, verbatim.

S5 — BRANCH. `bash ~/.claude/lib/gitflow.sh start chore claude-md-split`.
A project without gitflow (no `develop`): `git switch -c chore/claude-md-split`
and say so.

S6 — EXECUTE. `mcp__model-router__route(phase="orchestrate")` with the
dispatch: `Agent(subagent_type="onboarder")`, prompt = `MODE: split`,
`PROJECT_ROOT: <abs path>`, `TABLE:` the approved rows, one per line as
`<heading> | <name> | <globs-json>` (LRN-126: every field crosses the
prompt). It extracts each row, writes the pointer section, adds the
gitignore negation, runs `check`, commits. A STOP report (heading absent,
target exists, check red) comes back here: fix the row, re-dispatch; rows
already moved stay moved.

S7 — AFTER. `claude -p "/context"` again; append to that project's
`.claude/memory/journal.md` under today's date: `CLAUDE.md split: <k>
sections → .claude/rules/ (<names>), always-on <before> → <after>`. Tell the
user the proof step: a fresh session in that project that Reads one file per
rule, then `grep path_glob_match ~/.claude/logs/instructions-loaded.jsonl |
tail`. Never `finish`: the merge is the user's signal.

FINAL OUTPUT:
```
SPLIT COMPLETE: <project>
RULES   : <k> files under .claude/rules/ (<names>)
CLAUDE.md: <before chars> → <after chars>
CONTEXT : <before> → <after> (Memory files)
BRANCH  : chore/claude-md-split (<hash>) — merge on your signal
PROOF   : pending — fresh session + grep path_glob_match
```
```

- [ ] **Step 5: Onboarder: mode header + `MODE: split` section**

In `agents/onboarder.md`, insert right after `## ROLE`'s paragraph (before the `---` that precedes `## INPUTS`):

```markdown
Two modes. No `MODE:` line in the brief → the generator below (PHASES 1-6).
`MODE: split` → only § MODE: split at the end of this file runs.
```

Append at the end of the file:

```markdown

---

## MODE: split (dispatched by `/onboard split`)

INPUTS: `PROJECT_ROOT` (absolute), `TABLE` = the approved rows, one per
line, `<heading> | <name> | <globs-json>` (heading without `## `). No
BRIEF; PHASES 1-6 do not run.

S1 — EXTRACT. From `${PROJECT_ROOT}`, per row:
```bash
bash ~/.claude/lib/project-rules.sh extract CLAUDE.md "<heading>" .claude/rules/<name>.md '<globs-json>'
```
rc 2 (heading absent, target exists, malformed globs) → STOP and report
the row; rows already moved stay (the orchestrator re-dispatches the rest).

S2 — POINTER. If CLAUDE.md has no `## Path-scoped rules` section, append:
```markdown

## Path-scoped rules
Project rules live in `.claude/rules/<name>.md` and load on Read of a file
matching their `paths:` (never at session start): <name>, <name>.
```
Else add the new names to its list. Collapse runs of blank lines left by
the extraction (never more than one).

S3 — GITIGNORE. When `.gitignore` has the exact line `.claude/*` and no
`!.claude/rules/` line:
```bash
sed -i '\|^\.claude/\*$|a !.claude/rules/' .gitignore
```
(No `.claude/*` line → the rules are not ignored, nothing to add.)

S4 — CHECK + COMMIT.
```bash
bash ~/.claude/lib/project-rules.sh check
```
rc ≠ 0 → STOP, report the culprit lines, do not commit. rc 0 →
```bash
git add CLAUDE.md .claude/rules .gitignore
git commit -m "chore(claude-md): split <k> section(s) into .claude/rules/"
```

OUTPUT:
```
SPLIT DONE: <k> rule(s) — <name>.md (<globs>), …
CLAUDE.md: <lines before> → <lines after> lines
CHECK    : project-rules: <k> rule(s) ok
COMMIT   : <hash>
```
or `STOP: <row> — <reason>`.
```

- [ ] **Step 6: Locks still hold**

Run: `make test suite=lib/tests/model-routing.test.sh && make test suite=lib/tests/effort-routing.test.sh && make test suite=lib/tests/loops-heavy.test.sh && make test suite=lib/tests/plan-challenger.test.sh && make test suite=lib/tests/security-auditor.test.sh && make test suite=lib/tests/doctrine-citers.test.sh`
Expected: `all suites green` six times.

- [ ] **Step 7: Commit**

```bash
git add skills/onboard/SKILL.md agents/onboarder.md
git commit -m "feat(onboard): split mode — classify CLAUDE.md sections, onboarder MODE: split executes (RED: current skill ran archetype detection on 'split')"
```

---

### Task 8: `/onboard split` GREEN pressure test (orchestrator dispatch, no code)

- [ ] **Step 1: Reset the scratch repo**

`git -C /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/split-red checkout -- . && git -C /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/split-red clean -fdq`

- [ ] **Step 2: Dispatch the GREEN probe (sonnet, same prompt as Task 6 Step 2)**

Expected (GREEN): the report says it jumped to § SPLIT MODE, ran S1-S3, and produced the classification table (at least `rules/ maintenance` → move with `rules/**`, `Health Stack` → keep), then stopped at the S4 gate without writing. A probe that writes files or skips the gate = not green: fix the skill text, re-run.

- [ ] **Step 3: Executor dry run (sonnet onboarder, MODE: split) on the scratch**

Dispatch `Agent(subagent_type="onboarder")` with `MODE: split`, `PROJECT_ROOT: <scratch>`, `TABLE:` two rows: `rules/ maintenance | rules-maintenance | ["rules/**"]` and `mods/ — function-hooks plugins (Claude Code mods) | mods | ["mods/**"]`.
Expected: `SPLIT DONE: 2 rule(s)`, a commit in the scratch repo, `.gitignore` there gained `!.claude/rules/`, and `bash lib/project-rules.sh check` run from the scratch root prints `2 rule(s) ok`.

- [ ] **Step 4: Record**

No commit. The orchestrator notes RED/GREEN outcomes for STEP 7 capitalize (EVAL entry).

---

### Task 9: generators born split (skeletons, `emit`, onboarder PHASE 1b + PHASE 4, scaffolder PHASE 1b)

**Files:**
- Create: `templates/project-rules/docker.md`, `templates/project-rules/testing.md`, `templates/project-rules/ci.md`
- Modify: `templates/project-CLAUDE.md:3-4` (header comment)
- Modify: `agents/onboarder.md` (new PHASE 1b after PHASE 1; PHASE 4 gains the negation)
- Modify: `agents/scaffolder.md` (new PHASE 1b after PHASE 1)
- Modify: `lib/tests/project-rules.test.sh` (append T12 before the tally)

**Interfaces:**
- Consumes: `project-rules.sh emit <skeleton> <out>` (Task 1): rc 0 written with matching globs only, rc 1 none matched (nothing written), rc 2 malformed / target exists.

- [ ] **Step 1: Append the failing skeleton tests (T12)**

Insert before the tally line of the suite:

```bash
# T12 skeletons: emit keeps the matching globs only, skips when none match
mkdir -p "$FIX/gen/tests" && cd "$FIX/gen" || exit 1
echo x > Dockerfile; echo y > tests/test_a.py
bash "$PR" emit "$ROOT/templates/project-rules/docker.md" .claude/rules/docker.md >/dev/null
check T12-docker-emitted "$?" 0
check T12b-docker-globs-pruned "$(sed -n '2p' .claude/rules/docker.md)" 'paths: ["Dockerfile*"]'
check T12c-docker-body-kept "$(grep -c '^# Docker' .claude/rules/docker.md)" 1
bash "$PR" emit "$ROOT/templates/project-rules/testing.md" .claude/rules/testing.md >/dev/null
check T12d-testing-emitted "$?" 0
check T12e-testing-globs-pruned "$(sed -n '2p' .claude/rules/testing.md)" 'paths: ["tests/**"]'
bash "$PR" emit "$ROOT/templates/project-rules/ci.md" .claude/rules/ci.md 2>/dev/null
check T12f-ci-not-emitted-rc "$?" 1
check T12g-ci-not-written "$(ls .claude/rules/ci.md 2>/dev/null | wc -l | tr -d ' ')" 0
bash "$PR" emit "$ROOT/templates/project-rules/docker.md" .claude/rules/docker.md 2>/dev/null
check T12h-existing-target-rc "$?" 2
bash "$PR" check >/dev/null; check T12i-emitted-rules-pass-check "$?" 0
cd "$FIX" || exit 1
```

Run: `bash lib/tests/project-rules.test.sh | tail -3`
Expected: `FAIL T12-docker-emitted` (skeleton missing).

- [ ] **Step 2: The three skeletons**

`templates/project-rules/docker.md`:
```markdown
---
paths: ["Dockerfile*", "docker-compose*", "compose*.y*ml", ".dockerignore"]
---

# Docker

<!-- Generated by /init-project or /onboard: loads on Read of a Docker file. -->
<!-- Image: base image + version; multi-stage? what the final stage holds. -->
<!-- Compose: services, volumes, ports, the env file it reads (.env, never a secret in the image). -->
<!-- Commands: docker compose up --build / down -v, where they differ from the native run. -->
```

`templates/project-rules/testing.md`:
```markdown
---
paths: ["tests/**", "test/**", "**/*.test.*", "**/*.spec.*", "**/conftest.py"]
---

# Testing conventions

<!-- Generated by /init-project or /onboard: loads on Read of a test file. -->
<!-- Layout: where tests live, one file per module? naming (test_x.py / x.test.ts). -->
<!-- Fixtures and factories: shared setup, what is mocked, what hits a real service. -->
<!-- Rules: a bug fix ships its regression test; no sleep-based waits; coverage target if any. -->
```

`templates/project-rules/ci.md`:
```markdown
---
paths: [".github/workflows/**", ".gitlab-ci.yml", ".circleci/**"]
---

# CI

<!-- Generated by /init-project or /onboard: loads on Read of a pipeline file. -->
<!-- Jobs: lint, test, build, deploy; which run on PR vs main; required checks. -->
<!-- Secrets: names only (never values), where they are set. -->
<!-- Runtime versions pinned here must match the Stack section of CLAUDE.md. -->
```

`templates/project-CLAUDE.md` line 4: after `# Global rules: ~/.claude/CLAUDE.md — this file extends or overrides them.` add the line `# Path-scoped rules: .claude/rules/<name>.md (paths: frontmatter), loaded on Read of a matching file.`

- [ ] **Step 3: Onboarder PHASE 1b + PHASE 4 negation**

In `agents/onboarder.md`, after the PHASE 1 block (after `For Option C (monorepo sequential): path = ${package_root}/CLAUDE.md.` and before its `---`), add:

```markdown

## PHASE 1b — PATH-SCOPED RULES (born split)

From `${PROJECT_ROOT}`, for each of `docker`, `testing`, `ci`:
```bash
bash ~/.claude/lib/project-rules.sh emit ~/.claude/templates/project-rules/<name>.md .claude/rules/<name>.md
```
- rc 0 → written with the globs that match this tree. Fill its stub comments
  from the BRIEF where known (`docker` from `build_cmd`, `testing` from
  `test_cmd` and `conventions`); unknown → keep the stubs.
- rc 1 → no match, nothing written, skip silently.
- rc 2 → the file exists: keep it, never overwrite.
Then `bash ~/.claude/lib/project-rules.sh check` must print `N rule(s) ok`;
list the emitted rules in OUTPUT.
```

In PHASE 4, replace the three bullets with:

```markdown
- **`.gitignore` exists AND contains `settings.local.json`** → nothing to do for it.
- **`.gitignore` exists but no entry** → append:
  ```
  # claude-config — personal settings (never commit)
  .claude/settings.local.json
  ```
- **`.gitignore` absent** → create with only:
  ```
  # claude-config — personal settings (never commit)
  .claude/settings.local.json
  ```
- Then, whatever the case: when `.gitignore` has the exact line `.claude/*`
  and no `!.claude/rules/` line, add the negation right after it (PHASE 1b
  rules would be ignored otherwise, LRN-066):
  ```bash
  sed -i '\|^\.claude/\*$|a !.claude/rules/' .gitignore
  ```
```

- [ ] **Step 4: Scaffolder PHASE 1b**

In `agents/scaffolder.md`, after PHASE 1 (`Write to CLAUDE.md at project root.`), before its `---`, add:

```markdown

## PHASE 1b — PATH-SCOPED RULES (born split)

Runs AFTER PHASE 3 has written the files (the globs match the scaffolded
tree). For each of `docker` (only when DOCKER_RELEVANT), `testing`, `ci`:
```bash
bash ~/.claude/lib/project-rules.sh emit ~/.claude/templates/project-rules/<name>.md .claude/rules/<name>.md
```
rc 0 → fill its stubs from the DESIGN (image, compose services, test
layout, pipeline jobs); rc 1 → nothing matched, skipped. Then
`bash ~/.claude/lib/project-rules.sh check` prints `N rule(s) ok`. The
`.gitignore` negation `!.claude/rules/` comes from the gitflow socle at
STEP 5f (`gitflow init` reconciles it before the root commit); do not add
`.claude` lines to the stack `.gitignore` yourself.
```

- [ ] **Step 5: Verify**

Run: `bash lib/tests/project-rules.test.sh | tail -1 && cd /tmp && mkdir -p /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/gen-all/.github/workflows && cd /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/gen-all && touch Dockerfile docker-compose.yml compose.yaml .dockerignore .gitlab-ci.yml && mkdir -p tests test .circleci && touch tests/a test/b a.test.ts b.spec.ts conftest.py .github/workflows/ci.yml .circleci/config.yml && bash /home/bchanot/Documents/claude/lib/project-rules.sh check /home/bchanot/Documents/claude/templates/project-rules`
Expected: `PASS=… FAIL=0`; `project-rules: 3 rule(s) ok` (every skeleton glob is syntactically sound).

- [ ] **Step 6: Commit**

```bash
git add templates/project-rules templates/project-CLAUDE.md agents/onboarder.md agents/scaffolder.md lib/tests/project-rules.test.sh
git commit -m "feat(generators): onboarder and scaffolder emit docker/testing/ci path rules from templates/project-rules"
```

---

### Task 10: TODO.md phase 0 bookkeeping + full suite

**Files:**
- Modify: `.claude/tasks/TODO.md:20-30` (the phase 0 item)

- [ ] **Step 1: Update the phase 0 item**

Replace the `- [ ] **Phase 0, no mod: split project CLAUDE.md**` block (lines 20-30) with:

```markdown
- [x] **Phase 0, no mod: split project CLAUDE.md** (this repo + the lever, feature/claude-md-split, 2026-10-26; merge on user signal). Four rules under `.claude/rules/` (rules-maintenance, graphify-vendored, mods, transient-artifacts `# static-check: skip`), `lib/project-rules.sh` check/sections/extract/emit + suite, `hooks/instructions-loaded.sh` (log `~/.claude/logs/instructions-loaded.jsonl`), `!.claude/rules/` here + socle, `/onboard split` + onboarder `MODE: split`, generators emit docker/testing/ci from `templates/project-rules/`. Baseline `/context` 32.2k (project CLAUDE.md 2.1k).
  - [ ] Proof, this repo: `/context` after the merge; one fresh session Reading one file per rule → 4 `path_glob_match` lines in the log, pasted in the journal.
  - [ ] User step: `claude mcp remove -s user higgsfield` (user-scope MCP, no toggle ownership, no doctor check; phase 5 `.mcp.json` owns it).
- [ ] **Phase 0b, per-repo pass** (after phase 0 merges; via `/onboard split`, one `chore/claude-md-split` per repo, approval per repo, never an automatic merge; `/context` before/after in that repo's journal; faunosteo first and measure whether path rules load inside sub-agents before moving anything a sub-agent needs). Order by size: faunosteo 52,322 chars (on feature/v1-1-clients-animals: wait for it or branch off develop and rebase), zenquality 23,378, game 14,918 (on feature/replay-hint), robin_petier 12,895, config 4,990, integration_alphalink 4,249. None has `.claude/rules/` yet; all use the `.claude/*` file form (BDR-003).
```

- [ ] **Step 2: Full suite + shellcheck**

Run: `make test 2>&1 | tail -3 && shellcheck ./*.sh hooks/*.sh lib/*.sh && echo SHELLCHECK-OK`
Expected: `all suites green`, `SHELLCHECK-OK`.

- [ ] **Step 3: Commit**

```bash
git add .claude/tasks/TODO.md
git commit -m "chore(todo): phase 0 done in-repo, per-repo pass queued as phase 0b"
```

---

### Task 11: proof on this branch (orchestrator, no code)

- [ ] **Step 1: `/context` after**

Run from the repo root: `claude -p "/context" 2>/dev/null | grep -E 'Memory files|Documents/claude/CLAUDE.md'`
Expected: the project CLAUDE.md row well under 2.1k (about 150 tokens); Memory files total about 1.9k lower than the 11.6k baseline. Record both numbers for the journal.

- [ ] **Step 2: Logged loads**

The hook needs a session started AFTER Task 2 landed in `settings.json`. Run a headless session that reads one file per rule: `claude -p "Read rules/a11y.md, install-plugins.sh, mods/model-router/.claude-plugin/plugin.json and docs/superpowers/specs/2026-10-26-claude-md-split-design.md, then answer with the single word done." 2>/dev/null | tail -1`, then `grep path_glob_match ~/.claude/logs/instructions-loaded.jsonl | tail -4 | jq -c '{file_path, trigger_file_path}'`.
Expected: four lines, one per `.claude/rules/*.md`. Zero lines → the event does not fire as a classic hook on this CLI: report it, the proof falls back to a transcript check (`/context` in the same session listing the rule under Memory files), and the finding goes to STEP 7 as a BLK.

---

## Self-review

- Spec coverage: §1 rules → Task 4; `.gitignore` + socle → Task 3; §2 check/sections/extract + suite → Task 1, hook + settings → Task 2, proof → Task 11; §3 skill + onboarder split + RED/GREEN → Tasks 6-8; §4 skeletons + generators + template header → Task 9; §5 citers → Task 5 (ARCHITECTURE.md is STEP 8's), TODO → Task 10, higgsfield user step → Task 10 TODO line + STEP 7 journal; §6 testing → every task's verify step + Task 10 Step 2.
- Placeholder scan: none. Every code step carries its content.
- Type consistency: `extract` arg order `<file> <heading> <out> <globs-json>` is the same in the lib, the suite, Task 4 and the onboarder S1; `emit <skeleton> <out>` the same in the lib, T12, PHASE 1b (both agents); the skip marker string `# static-check: skip` is identical in the lib grep, T4 and Task 4 Step 3; the `check` success line `project-rules: N rule(s) ok` is what T5b, T11b and the agents quote.
- Review Focus: 1 → T6/T7h, 2 → T8, 3 → T2/T4c, 4 → T12, 5 → T10f/T10g. All pinned.
