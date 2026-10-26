# Phase 0 — split project CLAUDE.md into `.claude/rules/` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the four path-bound sections of this repo's project CLAUDE.md into `.claude/rules/<name>.md` path rules, prove they load, and give every project the same lever (`/onboard split`, generators born split).

**Architecture:** One bash lib (`lib/project-rules.sh`: `check`, `matches`, `sections`, `extract`, `emit`, all behind an optional `-C <dir>`) is the deterministic oracle for every consumer: the `make test` suite, this repo's own split, the onboarder in `MODE: split`, and the two generators. Judgment (which section is path-scoped, which globs) stays in the `/onboard split` main loop; writes are executed by the sonnet onboarder against an explicit project root. A permanent `InstructionsLoaded` hook logs every loaded instruction file (with session and agent ids) so a path-rule load is a grep, not a guess.

**Tech Stack:** bash 5 (`compgen -G` with globstar/dotglob), awk, jq, shellcheck; markdown skills/agents; Claude Code path-scoped rules (`paths:` frontmatter) and the `InstructionsLoaded` classic hook.

**Spec:** `docs/superpowers/specs/2026-10-26-claude-md-split-design.md`
**Contract:** `.claude/tasks/contracts/2026-10-26-claude-md-split-0042.md`
**Branch:** `feature/claude-md-split`, already started off develop (spec 2c8e4a2, plan r1 420448a). **Implement in place on this checkout, no worktree**: `~/.claude/{lib,agents,skills,hooks,settings.json}` are symlinks into this repo, and Tasks 6, 8 and 11 exercise the live links.

Spec deltas, decided while planning (r2, after the three-lens challenge): a `matches <glob>` subcommand (the split mode's only glob oracle, so the skill never consults `git ls-files`); `emit <skeleton> <out>` (writes a skeleton with the matching globs only); `-C <dir>` on every subcommand (a dispatched agent's cwd is the session's, never the project's); `extract` refuses a glob that matches nothing and a heading that does not occur exactly once; the hook also logs `session_id`, `agent_id`, `agent_type`, `globs` and rotates above 5 MB; the graphify rule drops `.graphify_version` (it lives under `skills/graphify/`, already covered); the onboarder's default-mode PHASE 4 is untouched (the gitignore socle reaches onboarded projects through STEP 2.6 `gitflow init`).

Baseline, taken 2026-10-26 before any edit (`claude -p "/context"` at the repo root, CLAUDE.md unchanged): total 32.2k; Memory files 11.6k, of which project CLAUDE.md 2.1k; Skills 10k; Custom agents 2.6k; System prompt 4.4k; MCP instructions 2.2k.

## Global Constraints

- Our code (strict): max 25 logic lines per function, 80 chars per line, 5 params, 5 locals; `shellcheck *.sh hooks/*.sh lib/*.sh` clean; no `sed -i '` in any file (portability census scans `*.sh`; agent text follows the same rule).
- Subtract-only: section text moves verbatim; nothing deleted from CLAUDE.global.md / rules/; registries (`.claude/memory/*`) are never edited by a task (STEP 7 capitalize owns them). CLAUDE.md keeps its lines 1-3 HTML comment.
- Never write into `rules/` (user scope, every project) except the pointer fix in `rules/README.md`.
- `.gitignore` negations only work with the `.claude/*` file form (BDR-003); the negation line must come AFTER `.claude/*`.
- Hooks never print to stdout (stdout reaches the model) and never block.
- The doctrine-citers census (`lib/tests/doctrine-citers.test.sh`) flags any `CLAUDE.md` followed within 12 chars by a double quote in skills/agents/lib/rules/hooks: new text never writes `CLAUDE.md "…"`; headings in command templates are single-quoted.
- Commit on the feature branch only, one commit per task, message under 50 words, no attribution lines.
- Frontmatter shape is exactly `paths: ["glob", "glob"]` on one line (as `rules/a11y.md`).
- Commands with a shell variable in a path are denied by the permission rules in this repo: write literal paths in every Bash step; agent templates say `<PROJECT_ROOT>` and the executor substitutes the literal.
- Deferred, for the human gate: the pre-commit `.claude/**` exemption lets a rules-only commit land directly on develop/main `[deferred 2026-10-26]` (phase 2, guards, narrows it; split mode always branches first).

## Review Focus

1. A heading inside a fenced code block, or a duplicated heading, must never be moved: `sections` ignores fenced lines, `extract` refuses unless the fence-aware count is exactly 1 (T6, T8e, T8f in Task 1).
2. A literal glob (no `*?[`) that names a missing file must fail `check` and be pruned by `emit`: bash never expands a plain word, so the matcher uses `compgen -G` (T2c, T12b, T12f in Tasks 1 and 9).
3. A glob that matches only under `node_modules/`, `.venv/`, `vendor/`, `target/`, `dist/`, `build/` or `.git/` counts as no match (T2d in Task 1).
4. A dispatched onboarder must act on the project root it was given, never on the session cwd: every lib call carries `-C <PROJECT_ROOT>`, every git call `-C` (Task 8 asserts the scratch repo got the commit and this repo stayed clean).
5. The hook must exit 0 and print nothing when `jq` is absent or the log dir is unwritable (T10f-T10h in Task 2).

---

### Task 1: `lib/project-rules.sh` + its suite (check / matches / sections / extract)

**Files:**
- Create: `lib/project-rules.sh`
- Create: `lib/tests/project-rules.test.sh`

**Interfaces:**
- Produces: `bash lib/project-rules.sh [-C <dir>] check [rules-dir]` (rc 0 + `project-rules: N rule(s) ok`; rc 2 + `<file>: <reason>` lines; `<file>: SKIP <glob>` for a skip-marked file; `<file>: always-on (no frontmatter)` / `(no paths:)` as info); `matches <glob>` (rc 0 + up to 3 hits, rc 1 + `no match: <glob>` on stderr); `sections <file>` (`<chars>\t<line>\t## <heading>` per top-level section, fence-aware); `extract <file> '<heading>' <out.md> '<globs-json>'` (rc 0 moved; rc 2 heading count ≠ 1 / target exists / malformed globs / a glob matches nothing, nothing written). Task 9 adds `emit`.

- [ ] **Step 1: Write the failing suite (T1-T9)**

Create `lib/tests/project-rules.test.sh`:

```bash
#!/usr/bin/env bash
# lib/tests/project-rules.test.sh — lib/project-rules.sh (check / matches /
# sections / extract / emit) and hooks/instructions-loaded.sh. Flip-tests
# on fixtures first (LRN-096), then the real check on this repo's rules.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
PR="$ROOT/lib/project-rules.sh"
FIX=$(mktemp -d); trap 'rm -rf "$FIX"' EXIT
cd "$FIX" || exit 1
mkdir -p .claude/rules src node_modules/x
echo x > src/app.ts
echo n > node_modules/x/a.test.js

# T1 a good rule passes
printf -- '---\npaths: ["src/**"]\n---\n\n# Src\nbody\n' > .claude/rules/good.md
bash "$PR" check >/dev/null; check T1-good-rule-passes "$?" 0

# T2 an unmatched glob fails, culprit named (flip test)
printf -- '---\npaths: ["src/**", "nowhere/**"]\n---\n\n# Bad\n' > .claude/rules/bad.md
out=$(bash "$PR" check); rc=$?
check T2-unmatched-glob-fails "$rc" 2
check T2b-culprit-named \
  "$(printf '%s\n' "$out" | grep -c 'bad.md: glob matches nothing: nowhere/\*\*')" 1
printf -- '---\npaths: ["src/app.tz"]\n---\n\n# Typo\n' > .claude/rules/bad.md
bash "$PR" check >/dev/null; check T2c-literal-typo-fails "$?" 2
printf -- '---\npaths: ["**/*.test.*"]\n---\n\n# Deps\n' > .claude/rules/bad.md
out=$(bash "$PR" check); rc=$?
check T2d-dep-dir-only-is-no-match "$rc" 2
check T2e-dep-dir-culprit \
  "$(printf '%s\n' "$out" | grep -c 'bad.md: glob matches nothing: \*\*/\*.test.\*')" 1
rm .claude/rules/bad.md

# T3 no frontmatter / no paths: = always-on info; a malformed paths: fails
printf '# No front\nbody\n' > .claude/rules/nofm.md
out=$(bash "$PR" check); rc=$?
check T3-no-frontmatter-is-always-on "$rc" 0
check T3b-reported "$(printf '%s\n' "$out" | grep -c 'nofm.md: always-on (no frontmatter)')" 1
check T3c-counted "$(printf '%s\n' "$out" | grep -c '2 rule(s) ok')" 1
printf -- '---\ntitle: x\n---\n\n# No paths\n' > .claude/rules/nofm.md
out=$(bash "$PR" check); rc=$?
check T3d-no-paths-is-always-on "$rc" 0
check T3e-reported "$(printf '%s\n' "$out" | grep -c 'nofm.md: always-on (no paths:)')" 1
printf -- '---\npaths: src/**\n---\n\n# Malformed\n' > .claude/rules/nofm.md
out=$(bash "$PR" check); rc=$?
check T3f-malformed-paths-fails "$rc" 2
check T3g-named \
  "$(printf '%s\n' "$out" | grep -c 'nofm.md: paths: is not a JSON array of strings')" 1
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

# T5 an absent dir is not an error; -C runs from elsewhere
rm -rf .claude/rules
out=$(bash "$PR" check); check T5-absent-dir-ok "$?" 0
check T5b-zero-rules "$(printf '%s' "$out" | grep -c '0 rule(s) ok')" 1
mkdir -p .claude/rules
printf -- '---\npaths: ["src/**"]\n---\n\n# Src\n' > .claude/rules/good.md
out=$(cd / && bash "$PR" -C "$FIX" check); rc=$?
check T5c-dash-C-rc "$rc" 0
check T5d-dash-C-counted "$(printf '%s' "$out" | grep -c '1 rule(s) ok')" 1
bash "$PR" -C /nonexistent-dir check 2>/dev/null; check T5e-dash-C-bad-dir "$?" 2

# T5f matches: hits on stdout, rc 1 and stderr line when none
out=$(bash "$PR" matches 'src/**'); rc=$?
check T5f-matches-rc "$rc" 0
check T5g-matches-hit "$(printf '%s\n' "$out" | grep -c '^src/app.ts$')" 1
err=$(bash "$PR" matches 'nope/**' 2>&1 >/dev/null); rc=$?
check T5h-no-match-rc "$rc" 1
check T5i-no-match-stderr "$err" 'no match: nope/**'
bash "$PR" matches '**/*.test.*' >/dev/null 2>&1; check T5j-dep-only-no-match "$?" 1

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

## Gamma
g1

## Gamma
g2
EOF
out=$(bash "$PR" sections CLAUDE.md)
check T6-four-sections "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" 4
check T6b-beta-line "$(printf '%s\n' "$out" | awk -F'\t' '$3=="## Beta"{print $2}')" 8
check T6c-alpha-chars "$(printf '%s\n' "$out" | awk -F'\t' '$3=="## Alpha"{print $1}')" 19
check T6d-fenced-not-listed "$(printf '%s\n' "$out" | grep -c 'not a heading')" 0

# T7 extract moves the section, writes the frontmatter, demotes the title
bash "$PR" extract CLAUDE.md 'Alpha' .claude/rules/alpha.md '["src/**"]' >/dev/null
check T7-extract-rc "$?" 0
check T7b-rule-frontmatter "$(sed -n '2p' .claude/rules/alpha.md)" 'paths: ["src/**"]'
check T7c-rule-title "$(sed -n '5p' .claude/rules/alpha.md)" '# Alpha'
check T7d-rule-body "$(sed -n '6p' .claude/rules/alpha.md)" 'aaa'
check T7e-trailing-sep-trimmed "$(tail -1 .claude/rules/alpha.md)" 'aaa'
check T7f-section-gone "$(grep -c '^## Alpha' CLAUDE.md)" 0
check T7g-beta-kept "$(grep -c '^## Beta' CLAUDE.md)" 1
check T7h-fenced-line-kept "$(grep -c '^## not a heading' CLAUDE.md)" 1
bash "$PR" check >/dev/null; check T7i-check-passes "$?" 0

# T8 extract refuses: missing heading, existing target, duplicate, fenced-only
bash "$PR" extract CLAUDE.md 'Alpha' .claude/rules/alpha2.md '["src/**"]' 2>/dev/null
check T8-missing-heading-rc "$?" 2
check T8b-nothing-written "$([ -e .claude/rules/alpha2.md ] && echo yes || echo no)" no
bash "$PR" extract CLAUDE.md 'Beta' .claude/rules/alpha.md '["src/**"]' 2>/dev/null
check T8c-existing-target-rc "$?" 2
check T8d-beta-still-there "$(grep -c '^## Beta' CLAUDE.md)" 1
bash "$PR" extract CLAUDE.md 'Gamma' .claude/rules/gamma.md '["src/**"]' 2>/dev/null
check T8e-duplicate-heading-rc "$?" 2
check T8e2-both-gammas-kept "$(grep -c '^## Gamma' CLAUDE.md)" 2
bash "$PR" extract CLAUDE.md 'not a heading' .claude/rules/nah.md '["src/**"]' 2>/dev/null
check T8f-fenced-only-rc "$?" 2
check T8g-nothing-written "$(ls .claude/rules | tr '\n' ' ')" 'alpha.md good.md '

# T9 extract refuses malformed globs and a glob that matches nothing
bash "$PR" extract CLAUDE.md 'Beta' .claude/rules/beta.md 'src/**' 2>/dev/null
check T9-bad-globs-rc "$?" 2
bash "$PR" extract CLAUDE.md 'Beta' .claude/rules/beta.md '["nowhere/**"]' 2>/dev/null
check T9b-unmatched-glob-rc "$?" 2
check T9c-nothing-written "$([ -e .claude/rules/beta.md ] && echo yes || echo no)" no
check T9d-beta-still-there "$(grep -c '^## Beta' CLAUDE.md)" 1

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
# /onboard split mode, the onboarder and the scaffolder. Every subcommand
# takes an optional leading `-C <dir>` (a dispatched agent's cwd is the
# session's, never the project's):
#   check [rules-dir]   every path rule parses and every glob matches ≥1
#                       path; rc 2 with the culprit named
#   matches <glob>      rc 0 + the first hits, rc 1 none
#   sections <file>     chars, line, heading per top-level ## section
#   extract <file> <heading> <out> <globs-json>   move one section to a rule
#   emit <skeleton> <out>   the rule with the matching globs only (rc 1
#                           when none matches, nothing written)
# Globs match the WORKING TREE (compgen -G with globstar and dotglob,
# through symlinks), dependency dirs excluded: the engine matches the path
# the model reads, tracked or not; a typo matches nothing either way. A
# frontmatter line `# static-check: skip` exempts a rule whose files only
# exist mid-run. A rule without frontmatter or without `paths:` is an
# always-on rule: reported, never failed.

_RULES_DEP_DIRS='(^|/)(node_modules|\.venv|venv|vendor|target|dist|build|\.git)/'

_rules_frontmatter() {  # <file> → frontmatter body on stdout, rc 1 if none
  awk 'NR == 1 && $0 != "---" { exit 1 }
       NR > 1 && $0 == "---" { found = 1; exit }
       NR > 1 { print }
       END { exit found ? 0 : 1 }' "$1"
}

# <frontmatter text> → one glob per line. rc 1: no paths: line (always-on);
# rc 2: a paths: value that is not a non-empty JSON array of strings.
_rules_globs() {
  local line arr
  line=$(printf '%s\n' "$1" | grep -E '^paths:') || return 1
  arr=${line#paths:}
  printf '%s' "$arr" \
    | jq -e 'type == "array" and length > 0 and all(type == "string")' \
      >/dev/null 2>&1 || return 2
  printf '%s' "$arr" | jq -r '.[]'
}

_rules_hits() {  # <glob> → matching paths outside dependency dirs, rc 1 none
  ( shopt -s globstar dotglob; compgen -G "$1" ) 2>/dev/null \
    | grep -Ev "$_RULES_DEP_DIRS"
}

_rules_matching() {  # <globs, one per line> → JSON array of the matching ones
  local g out=""
  while IFS= read -r g; do
    [ -n "$g" ] && _rules_hits "$g" >/dev/null && out="$out, \"$g\""
  done <<< "$1"
  [ -n "$out" ] || return 1
  printf '[%s]\n' "${out#, }"
}

_rules_check_file() {  # <rule.md> → rc 0 ok or always-on, rc 1 with culprits
  local fm globs skip=0 g bad=0
  fm=$(_rules_frontmatter "$1") \
    || { echo "$1: always-on (no frontmatter)"; return 0; }
  globs=$(_rules_globs "$fm")
  case $? in
    1) echo "$1: always-on (no paths:)"; return 0 ;;
    2) echo "$1: paths: is not a JSON array of strings"; return 1 ;;
  esac
  printf '%s\n' "$fm" | grep -qx '# static-check: skip' && skip=1
  while IFS= read -r g; do
    if [ "$skip" = 1 ]; then echo "$1: SKIP $g"; continue; fi
    _rules_hits "$g" >/dev/null || { echo "$1: glob matches nothing: $g"; bad=1; }
  done <<< "$globs"
  [ "$bad" = 0 ]
}

project_rules_check() {  # [rules-dir] → rc 0 all ok, rc 2 with culprits named
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

project_rules_matches() {  # <glob> → rc 0 + the first 3 hits, rc 1 none
  _rules_hits "$1" | head -3
  [ "${PIPESTATUS[0]}" -eq 0 ] || { echo "no match: $1" >&2; return 1; }
}

project_rules_sections() {  # <file> → chars, line, heading per ## section
  [ -f "$1" ] || { echo "project-rules: $1 not found" >&2; return 2; }
  awk '
    /^```/ { fence = !fence }
    /^## / && !fence { if (h != "") printf "%d\t%d\t%s\n", c, l, h
                       h = $0; l = NR; c = 0 }
    h != "" { c += length($0) + 1 }
    END { if (h != "") printf "%d\t%d\t%s\n", c, l, h }' "$1"
}

_rules_heading_count() {  # <file> <heading> → fence-aware count of "## h"
  awk -v h="## $2" '/^```/ { fence = !fence }
                    !fence && $0 == h { n++ }
                    END { print n + 0 }' "$1"
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

_rules_globs_all_match() {  # <globs-json> → rc 0 valid and every glob matches
  local globs g
  globs=$(_rules_globs "paths: $1") || {
    echo "project-rules: globs must be a JSON array of strings: $1" >&2
    return 1; }
  while IFS= read -r g; do
    _rules_hits "$g" >/dev/null \
      || { echo "project-rules: glob matches nothing: $g" >&2; return 1; }
  done <<< "$globs"
}

project_rules_extract() {  # <file> <heading> <out.md> <globs-json>
  local src="$1" heading="$2" out="$3" globs="$4" tmp
  [ "$(_rules_heading_count "$src" "$heading")" = 1 ] || {
    echo "project-rules: heading must occur exactly once: ## $heading" >&2
    return 2; }
  [ -e "$out" ] && { echo "project-rules: $out exists" >&2; return 2; }
  _rules_globs_all_match "$globs" || return 2
  mkdir -p "$(dirname "$out")"
  { printf -- '---\npaths: %s\n---\n\n# %s\n' "$globs" "$heading"
    _rules_section_body "$src" "$heading"; } > "$out"
  tmp=$(mktemp)
  _rules_without_section "$src" "$heading" > "$tmp" && cat "$tmp" > "$src"
  rm -f "$tmp"
  echo "project-rules: moved '## $heading' to $out"
}

project_rules_emit() {  # <skeleton.md> <out.md> → the rule, matching globs only
  local fm globs kept
  fm=$(_rules_frontmatter "$1") \
    || { echo "project-rules: $1: no frontmatter" >&2; return 2; }
  globs=$(_rules_globs "$fm") \
    || { echo "project-rules: $1: no valid paths: array" >&2; return 2; }
  kept=$(_rules_matching "$globs") \
    || { echo "project-rules: $1: no glob matches, not emitted" >&2; return 1; }
  [ -e "$2" ] && { echo "project-rules: $2 exists" >&2; return 2; }
  mkdir -p "$(dirname "$2")"
  { printf -- '---\npaths: %s\n---\n' "$kept"
    awk 'body { print } NR > 1 && $0 == "---" { body = 1 }' "$1"; } > "$2"
  echo "project-rules: emitted $2 paths: $kept"
}

_project_rules_main() {
  set -uo pipefail
  if [ "${1:-}" = "-C" ]; then
    cd "${2:?dir}" 2>/dev/null || { echo "project-rules: no dir $2" >&2; return 2; }
    shift 2
  fi
  case "${1:-}" in
    check)    project_rules_check "${2:-.claude/rules}" ;;
    matches)  project_rules_matches "${2:?glob}" ;;
    sections) project_rules_sections "${2:?file}" ;;
    extract)  project_rules_extract "${2:?file}" "${3:?heading}" "${4:?out}" \
                                    "${5:?globs-json}" ;;
    emit)     project_rules_emit "${2:?skeleton}" "${3:?out}" ;;
    *) echo "usage: project-rules.sh [-C dir] check [rules-dir] | matches" \
            "<glob> | sections <file> | extract <file> <heading> <out>" \
            "<globs-json> | emit <skeleton> <out>" >&2; return 2 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then _project_rules_main "$@"; fi
```

- [ ] **Step 4: Run the suite, verify T1-T9 pass**

Run: `bash lib/tests/project-rules.test.sh`
Expected: `PASS=… FAIL=0`, exit 0.

- [ ] **Step 5: shellcheck, 80 columns, census, make test on the new suite**

Run: `shellcheck lib/project-rules.sh lib/tests/project-rules.test.sh; awk 'length > 80 {print FILENAME": "FNR": "length}' lib/project-rules.sh; make test suite=lib/tests/project-rules.test.sh | tail -1; make test suite=lib/tests/doctrine-citers.test.sh | tail -1; make test suite=lib/tests/portability-census.test.sh | tail -1`
Expected: no shellcheck output, no awk output, `all suites green` three times.

- [ ] **Step 6: Commit**

```bash
git add lib/project-rules.sh lib/tests/project-rules.test.sh
git commit -m "feat(rules): lib/project-rules.sh check/matches/sections/extract + suite"
```

---

### Task 2: InstructionsLoaded proof hook

**Files:**
- Create: `hooks/instructions-loaded.sh`
- Modify: `settings.json` (hooks block, after the `"SessionStart": [ … ],` block, before `"PreToolUse": [`)
- Modify: `lib/tests/project-rules.test.sh` (append T10 before the tally)

**Interfaces:**
- Produces: one JSON line per loaded instruction file in `~/.claude/logs/instructions-loaded.jsonl` (`ts, session_id, agent_id, agent_type, cwd, file_path, memory_type, load_reason, globs, trigger_file_path`); `CLAUDE_INSTRUCTIONS_LOG=<path>` overrides the log path (tests); the log rotates to `<log>.1` above 5 MB.

- [ ] **Step 1: Append the failing hook tests (T10) to the suite**

Insert before the `echo "PASS=$pass FAIL=$fail"` line of `lib/tests/project-rules.test.sh`:

```bash
# T10 the hook appends one jq line, prints nothing, never fails
HOOK="$ROOT/hooks/instructions-loaded.sh"
LOG="$FIX/il.jsonl"
IN='{"hook_event_name":"InstructionsLoaded","session_id":"s1","agent_id":"a1","agent_type":"general-purpose","cwd":"/p","file_path":"/p/.claude/rules/x.md","memory_type":"Project","load_reason":"path_glob_match","globs":["src/**"],"trigger_file_path":"/p/src/a.ts"}'
out=$(printf '%s' "$IN" | CLAUDE_INSTRUCTIONS_LOG="$LOG" bash "$HOOK"); rc=$?
check T10-hook-rc "$rc" 0
check T10b-stdout-empty "$out" ""
check T10c-one-line "$(wc -l < "$LOG" | tr -d ' ')" 1
check T10d-reason-kept "$(jq -r '.load_reason' "$LOG")" path_glob_match
check T10e-ids-kept "$(jq -r '[.session_id, .agent_id, .globs[0]] | join(",")' "$LOG")" 's1,a1,src/**'
out=$(printf '%s' "$IN" | CLAUDE_INSTRUCTIONS_LOG=/proc/nowhere/il.jsonl bash "$HOOK"); rc=$?
check T10f-unwritable-log-rc0 "$rc" 0
check T10g-unwritable-log-stdout-empty "$out" ""
out=$(printf '%s' "$IN" | CLAUDE_INSTRUCTIONS_LOG="$LOG" PATH=/nonexistent bash "$HOOK"); rc=$?
check T10h-no-jq-rc0 "$rc" 0
check T10i-no-jq-stdout-empty "$out" ""
check T10j-no-jq-nothing-appended "$(wc -l < "$LOG" | tr -d ' ')" 1
head -c 5300000 /dev/zero | tr '\0' 'x' > "$LOG"
printf '%s' "$IN" | CLAUDE_INSTRUCTIONS_LOG="$LOG" bash "$HOOK"
check T10k-rotated "$([ -e "$LOG.1" ] && echo yes || echo no)" yes
check T10l-fresh-log-one-line "$(wc -l < "$LOG" | tr -d ' ')" 1
```

- [ ] **Step 2: Run the suite, verify T10 fails**

Run: `bash lib/tests/project-rules.test.sh | tail -3`
Expected: `FAIL T10-hook-rc` (hook missing), exit 1.

- [ ] **Step 3: Write the hook**

Create `hooks/instructions-loaded.sh`:

```bash
#!/usr/bin/env bash
# hooks/instructions-loaded.sh — InstructionsLoaded hook: one JSON line per
# instruction file the engine loads, into
# ~/.claude/logs/instructions-loaded.jsonl. The proof channel for
# path-scoped rules (BDR-125 phase 0): a rule that loaded shows
# `load_reason: path_glob_match`, the file that triggered it, and the
# session or sub-agent that loaded it. Never blocks, never prints to
# stdout (stdout reaches the model), exits 0 whatever happens. Rotates to
# <log>.1 above 5 MB. CLAUDE_INSTRUCTIONS_LOG overrides the path (tests).
log="${CLAUDE_INSTRUCTIONS_LOG:-$HOME/.claude/logs/instructions-loaded.jsonl}"
command -v jq >/dev/null 2>&1 || exit 0
mkdir -p "$(dirname "$log")" 2>/dev/null || exit 0
if [ -f "$log" ] && [ "$(wc -c < "$log")" -gt 5242880 ]; then
  mv -f "$log" "$log.1" 2>/dev/null
fi
jq -c --arg ts "$(date -u +%FT%TZ)" '{ts: $ts, session_id, agent_id,
  agent_type, cwd, file_path, memory_type, load_reason, globs,
  trigger_file_path}' >> "$log" 2>/dev/null
exit 0
```

- [ ] **Step 4: Register it in `settings.json`**

In `settings.json`, after the `"SessionStart": [ … ],` block (the `],` that closes it, just before `"PreToolUse": [`), insert:

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

Verify: `jq -r '.hooks.InstructionsLoaded[0].hooks[0].command' settings.json` prints `bash ~/.claude/hooks/instructions-loaded.sh`.

- [ ] **Step 5: Run the suite, verify T10 passes**

Run: `bash lib/tests/project-rules.test.sh | tail -1 && shellcheck hooks/instructions-loaded.sh && make test suite=lib/tests/curated-config-guard.test.sh | tail -1`
Expected: `FAIL=0`, no shellcheck output, `all suites green`.

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

`templates/gitignore/standard.gitignore`: after the line `!.claude/deploy/` add the line `!.claude/rules/` (it stays after `.claude/*`; reconcile appends missing lines at the end of a project's file, which is after any existing `.claude/*`).

`.gitignore`: add `!.claude/rules/` directly after `!.claude/settings.json` (line 126), so the block reads:

```
.claude/*
!.claude/tasks/
!.claude/memory/
!.claude/audits/
!.claude/settings.json
!.claude/rules/
```

- [ ] **Step 4: Verify**

Run: `make test suite=lib/gitflow-test.sh 2>&1 | tail -1; git check-ignore -q .claude/rules/probe.md; echo "ignored-rc=$?"`
Expected: `all suites green`; `ignored-rc=1` (not ignored; `git check-ignore` needs no existing file).

- [ ] **Step 5: Commit**

```bash
git add .gitignore templates/gitignore/standard.gitignore lib/gitflow-test.sh
git commit -m "chore(gitignore): un-ignore .claude/rules/ here and in the gitflow socle"
```

---

### Task 4: split this repo's CLAUDE.md (dogfood `extract`)

**Files:**
- Modify: `CLAUDE.md` (four sections leave, a pointer section arrives; lines 1-3 comment stays)
- Create: `.claude/rules/rules-maintenance.md`, `.claude/rules/graphify-vendored.md`, `.claude/rules/mods.md`, `.claude/rules/transient-artifacts.md`
- Modify: `lib/tests/project-rules.test.sh` (append T11 before the tally)

**Interfaces:**
- Consumes: `lib/project-rules.sh extract` / `check` (Task 1).

- [ ] **Step 1: Append the failing real-repo test (T11)**

Insert before the `echo "PASS=$pass FAIL=$fail"` line of `lib/tests/project-rules.test.sh`:

```bash
# T11 the real rules of this repo pass the check (4 rules, 1 skip-marked)
out=$(bash "$PR" -C "$ROOT" check); rc=$?
[ "$rc" -eq 0 ] || printf '%s\n' "$out"
check T11-repo-rules-pass "$rc" 0
check T11b-four-rules "$(printf '%s\n' "$out" | grep -c '4 rule(s) ok')" 1
check T11c-transient-skipped \
  "$(printf '%s\n' "$out" | grep -c 'transient-artifacts.md: SKIP docs/superpowers/\*\*')" 1
```

Run: `bash lib/tests/project-rules.test.sh | tail -4`
Expected: `FAIL T11b-four-rules: got[0] want[1]` (0 rules yet).

- [ ] **Step 2: Move the four sections with `extract`**

From the repo root, in this order (headings are exact, copied from CLAUDE.md; the transient rule is extracted with the one glob that matches mid-run, `docs/superpowers/**`, since `.audit/` does not exist at rest):

```bash
bash lib/project-rules.sh extract CLAUDE.md 'rules/ maintenance' .claude/rules/rules-maintenance.md '["rules/**", "CLAUDE.global.md"]'
bash lib/project-rules.sh extract CLAUDE.md 'Machine-owned: the vendored graphify skill' .claude/rules/graphify-vendored.md '["skills/graphify/**", "install-plugins.sh"]'
bash lib/project-rules.sh extract CLAUDE.md 'mods/ — function-hooks plugins (Claude Code mods)' .claude/rules/mods.md '["mods/**", "skills/model-router/**", "lib/tests/mods.test.sh"]'
bash lib/project-rules.sh extract CLAUDE.md 'Transient planning artifacts' .claude/rules/transient-artifacts.md '["docs/superpowers/**"]'
```

Expected: four `project-rules: moved '## …' to .claude/rules/….md` lines. `git diff --stat CLAUDE.md` shows about 90 deletions and no insertion.

- [ ] **Step 3: Transient rule: second glob + skip marker**

Edit `.claude/rules/transient-artifacts.md` so its frontmatter reads exactly:

```
---
paths: ["docs/superpowers/**", ".audit/**"]
# static-check: skip
---
```

- [ ] **Step 4: The pointer section in CLAUDE.md**

Append to CLAUDE.md:

```markdown

## Path-scoped rules
Project rules live in `.claude/rules/<name>.md` and load on Read of a file
matching their `paths:` (never at session start): rules-maintenance,
graphify-vendored, mods, transient-artifacts. Check: `bash
lib/project-rules.sh check` (runs in `make test`).
```

The whole file must then read (lines 1-3 are the existing comment, untouched):

```markdown
<!-- PROJECT SCOPE ONLY (claude-config repo). The user-scope GLOBAL memory is
     ./CLAUDE.global.md, deployed as ~/.claude/CLAUDE.md by link.sh — edit
     THAT file for cross-project doctrine. -->

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

- [ ] **Step 5: Verify**

Run: `bash lib/project-rules.sh check; bash lib/tests/project-rules.test.sh | tail -1; git status --short .claude/rules CLAUDE.md; git diff HEAD --stat -- CLAUDE.md; wc -c .claude/rules/*.md`
Expected: `transient-artifacts.md: SKIP docs/superpowers/**`, `… SKIP .audit/**`, `project-rules: 4 rule(s) ok`; `FAIL=0`; four `??` entries under `.claude/rules/` plus ` M CLAUDE.md`; the four rule files sum to roughly the 4,960 chars the sections held (T7 proves `extract` is verbatim; the sizes are the sanity check).

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md .claude/rules lib/tests/project-rules.test.sh
git commit -m "refactor(claude-md): four sections become .claude/rules path rules (phase 0)"
```

---

### Task 5: citers of the moved sections

**Files:**
- Modify: `rules/README.md:8-9`
- Modify: `doctor.sh:76`

- [ ] **Step 1: Repoint `rules/README.md`**

Replace lines 8-9:

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

Line 7 (`User-scope rules, deployed to …`) stays.

- [ ] **Step 2: Fix the stale doctor comment**

`doctor.sh:76`: replace `(the 29-line project CLAUDE.md instead of` with `(the project CLAUDE.md instead of`.

- [ ] **Step 3: Census grep**

Run:
```bash
grep -rnE 'CLAUDE\.md \(project scope\)|29-line project CLAUDE\.md|Machine-owned: the vendored|§ ?Transient planning|"rules/ maintenance"|"mods/ — function-hooks"' rules/ doctor.sh skills/ agents/ lib/ hooks/ README.md ARCHITECTURE.md --include='*.md' --include='*.sh' | grep -v 'skills-external\|skills/graphify/\|lib/tests/project-rules'
```
Expected: no output. (`lib/gitflow.sh:21` mentions transient planning artifacts in a comment about the purge, not as a citation: leave it. `install-plugins.sh` GUARDED_CONFIGS keeps `CLAUDE.md`: leave it. `ARCHITECTURE.md` is the doc pipeline's, STEP 8.)

- [ ] **Step 4: make test + commit**

Run: `make test suite=lib/tests/doctrine-citers.test.sh | tail -1`
Expected: `all suites green`.

```bash
git add rules/README.md doctor.sh
git commit -m "chore(citers): rules/README and doctor point at .claude/rules after the split"
```

---

### Task 6: `/onboard split` RED pressure test (orchestrator dispatch, no code)

**Files:** none modified. Scratch: `/tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/split-red/` (a git repo on branch `develop` holding `CLAUDE.md` = `git show develop:CLAUDE.md`, plus `rules/x.md`, `mods/m/plugin.json`, `.gitignore` with `.claude/*`).

- [ ] **Step 1: Assert in-place links, build the scratch repo**

Run (one line, literal paths): `readlink -f ~/.claude/lib ~/.claude/skills ~/.claude/agents ~/.claude/hooks ~/.claude/settings.json` → every line under `/home/bchanot/Documents/claude/`.

```bash
mkdir -p /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/split-red/rules /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/split-red/mods/m && git show develop:CLAUDE.md > /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/split-red/CLAUDE.md && echo r > /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/split-red/rules/x.md && echo '{}' > /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/split-red/mods/m/plugin.json && printf '.claude/*\n!.claude/memory/\n' > /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/split-red/.gitignore && git -C /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/split-red init -q -b develop && git -C /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/split-red add -A && git -C /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/split-red commit -qm init
```

- [ ] **Step 2: Dispatch the RED probe (sonnet)**

`Agent(subagent_type="general-purpose", model="sonnet", effort="medium")` with: "Probe of a skill's text, not a real run. Read `/home/bchanot/.claude/skills/onboard/SKILL.md` as if you had been invoked as `/onboard split` in the project `<scratch path>`. Treat the MODEL GATE as passed and never call `mcp__model-router__route`; do not dispatch agents, do not run `claude`, do not write outside the scratch. Follow the skill's text for what it tells you to do first, up to the first point where it would stop for the user or dispatch an agent, then stop. Report: the steps you ran in order, whether any step had you classify the CLAUDE.md sections into path-scoped rules, and what you would have shown the user."

Expected (RED): the report names the plugin check / archetype detection; no classification table, no `.claude/rules/` written. Record one line for the Task 7 commit message ("RED: current skill runs archetype detection on `split`").

If the probe DOES produce a split with the current skill: stop, the mode is unnecessary as designed; re-plan.

---

### Task 7: `/onboard split` mode + onboarder `MODE: split`

**Files:**
- Modify: `skills/onboard/SKILL.md` (frontmatter lines 4-5, after `## REQUEST` ~line 20, STEP 3 draft-update line ~201, RULES lines ~1037 and ~1041, append § SPLIT MODE after FINAL OUTPUT)
- Modify: `agents/onboarder.md` (after `## ROLE`; RULES line 170; a new section at the end)

**Interfaces:**
- Consumes: `project-rules.sh -C <root> sections|matches|extract|check` (Task 1).
- Produces: the onboarder `MODE: split` contract: INPUTS `PROJECT_ROOT`, `TABLE` rows `<heading> | <name> | <globs-json>`; OUTPUT rules written, check result, commit hash, or `STOP: <row> — <reason>` with the rollback done.

- [ ] **Step 1: Skill frontmatter**

Line 4 `description:` — replace `Do NOT use for repos created via /init-project.` with `Default flow: do NOT use it for repos created via /init-project.` and append inside the quoted string, before the closing `'`: ` `split` mode (any repo): "onboard split", "split the project instructions", "découpe le fichier CLAUDE", "path-scoped rules".`
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

- [ ] **Step 3: STEP 3 draft update and the RULES lines**

STEP 3 (~line 201): replace `Après réponses : **mettre à jour le brouillon CLAUDE.md** avec les infos obtenues.` with `Après réponses : **mettre à jour le brouillon CLAUDE.md** avec les infos obtenues, et les placeholders `<!-- TODO(/onboard STEP 3): … -->` des `.claude/rules/*.md` émis en PHASE 5b (Docker, tests, CI : leurs réponses vont dans la règle, pas dans CLAUDE.md).`

RULES: replace `- NO skipping STEP 0, 1, 2 — ils sont obligatoires.` with `- NO skipping STEP 0, 1, 2 — ils sont obligatoires (split mode runs its own steps, § SPLIT MODE).` and replace `- Si `CLAUDE.md` existe : le lire, ne pas l'écraser sans fusion après STEP 3.` with `- Si `CLAUDE.md` existe : le lire, ne pas l'écraser sans fusion après STEP 3 (default flow; split mode edits it on the approved table).`

- [ ] **Step 4: § SPLIT MODE appended at the end of the skill**

```markdown

---

## SPLIT MODE — `/onboard split` (BDR-125 phase 0)

Move the path-bound sections of an existing project `CLAUDE.md` into
`.claude/rules/<name>.md` path rules (loaded on Read of a matching file),
so the always-on context of that project shrinks. Judgment here, writes by
the onboarder, `lib/project-rules.sh` as the only glob oracle. The MODEL
GATE above has run. `mcp__model-router__route(phase="plan")` first.
`<ROOT>` below is the project root as a literal absolute path.

S1 — PRECONDITIONS. `CLAUDE.md` at `<ROOT>`, else print `nothing to split —
run /onboard` and stop. `git -C <ROOT> status --porcelain` empty (whole
tree) and the current branch is `develop` (or `main` when no `develop`
exists), else stop and say why: the split branches off develop, and an
in-flight feature branch or dirty file would be classified on one version
and extracted on another. `.claude/rules/` already holding rules → list
them, continue (new rules add to them).

S2 — BASELINE. `claude -p "/context"` from `<ROOT>` (refused → ask the user
to run `! claude -p "/context"`); note the `Memory files` total and the
project CLAUDE.md row.

S3 — BRANCH. `cd <ROOT> && bash ~/.claude/lib/gitflow.sh start chore
claude-md-split`. A project without gitflow (no `develop`):
`git -C <ROOT> switch -c chore/claude-md-split`, and say so. Everything
after this step reads the branched file.

S4 — CLASSIFY. `bash ~/.claude/lib/project-rules.sh -C <ROOT> sections
CLAUDE.md` lists every `##` section with its size. For each one decide:
- always-on: project overview, stack, build/test/lint commands, folder
  structure, conventions that apply everywhere, exceptions to global rules,
  workflow expectations, key dependencies, anything needed before a file is
  read (how to run the project), even when it names a folder;
- path-scoped: one module or folder, Docker, migrations, CI, a tool's
  gotchas, a vendored or machine-owned area. Propose `<name>` (kebab, the
  section's subject) and globs (a folder → `dir/**`, a tool → its config
  files) and verify EVERY proposed glob with `bash
  ~/.claude/lib/project-rules.sh -C <ROOT> matches '<glob>'` (rc 0) before
  showing it. A heading containing `'` or `|` is not split by this mode
  (say so; the user renames it first).

S5 — GATE (mandatory stop). Print the table, then end the turn:

```
SPLIT — <project> CLAUDE.md (<chars> chars, <n> sections) on chore/claude-md-split
| # | section | chars | verdict | rule file | paths |
| 1 | Stack | 420 | keep | | |
| 2 | Docker | 1,340 | move | docker.md | ["Dockerfile*", "docker-compose*"] |
...
Moves <k> sections, <m> chars (<p>% of the file). Approve, edit a row, or "keep everything".
```
"keep everything" ends the mode with no change (`bash
~/.claude/lib/gitflow.sh delete chore/claude-md-split`). An edited row's
globs are re-verified with `matches` before they enter the TABLE. The
approved rows are the TABLE handed to the onboarder, verbatim.

S6 — EXECUTE. `mcp__model-router__route(phase="orchestrate")` with the
dispatch: `Agent(subagent_type="onboarder")`, prompt = `MODE: split`,
`PROJECT_ROOT: <ROOT>`, `TABLE:` the approved rows, one per line as
`<heading> | <name> | <globs-json>` (LRN-126: every field crosses the
prompt). It pre-flights every row, then extracts, writes the pointer
section, secures the gitignore negation, runs `check`, commits, and
verifies the rules are tracked. A `STOP:` report comes back here with the
rollback already done (nothing committed): fix the row, re-dispatch the
WHOLE table (nothing was moved). A `STOP:` after a commit cannot happen
(the commit is the last step).

S7 — AFTER. `claude -p "/context"` again from `<ROOT>`; append to that
project's `.claude/memory/journal.md` under today's date: `CLAUDE.md
split: <k> sections → .claude/rules/ (<names>), always-on <before> →
<after>`. Tell the user the proof step: a fresh session in that project
that Reads one file per rule, then `jq -c 'select(.memory_type=="Project"
and (.file_path|contains("/.claude/rules/")))'
~/.claude/logs/instructions-loaded.jsonl | tail`. Never `finish`: the
merge is the user's signal.

FINAL OUTPUT:
```
SPLIT COMPLETE: <project>
RULES   : <k> files under .claude/rules/ (<names>)
CLAUDE.md: <before chars> → <after chars>
CONTEXT : <before> → <after> (Memory files)
BRANCH  : chore/claude-md-split (<hash>) — merge on your signal
PROOF   : pending — fresh session + the jq filter above
```
```

- [ ] **Step 5: Onboarder: mode header, RULES exemption, `MODE: split` section**

In `agents/onboarder.md`, insert right after the `## ROLE` paragraph (before the `---` that precedes `## INPUTS`):

```markdown
Two modes. No `MODE:` line in the brief → the generator below (PHASES 1-6).
`MODE: split` → only § MODE: split at the end of this file runs.
```

RULES line 170: replace `- NO destructive writes: never overwrite CLAUDE.md if it exists without asking (print path + STOP, let orchestrator decide).` with `- NO destructive writes: never overwrite CLAUDE.md if it exists without asking (print path + STOP, let orchestrator decide). MODE: split edits it by design, row by row, on the approved TABLE.`

Append at the end of the file:

```markdown

---

## MODE: split (dispatched by `/onboard split`)

INPUTS: `PROJECT_ROOT` (absolute; written as a literal path in every
command below, never through a variable), `TABLE` = the approved rows, one
per line, `<heading> | <name> | <globs-json>` (heading without `## `). No
BRIEF; PHASES 1-6 do not run. `PR` below stands for
`bash ~/.claude/lib/project-rules.sh -C <PROJECT_ROOT>`.

S0 — PREFLIGHT (no write before every row passes):
- `git -C <PROJECT_ROOT> status --porcelain` is empty, else STOP.
- gitignore: `git -C <PROJECT_ROOT> check-ignore -q .claude/rules/probe.md`
  rc 0 means the rules would be ignored → append the negation (portable,
  lands after any `.claude/*` line):
  `printf '!.claude/rules/\n' >> <PROJECT_ROOT>/.gitignore`
  then re-run `check-ignore`; still rc 0 → STOP: "ignore form cannot be
  negated (BDR-003: use the `.claude/*` file form)", and `git -C
  <PROJECT_ROOT> checkout -- .gitignore`.
- per row: `PR sections CLAUDE.md` lists `## <heading>` exactly once;
  `<PROJECT_ROOT>/.claude/rules/<name>.md` does not exist; every glob of
  `<globs-json>` passes `PR matches '<glob>'` (rc 0). Any failure → STOP
  with the row and the reason (nothing written yet besides the gitignore
  line, which the STOP reverts).

S1 — EXTRACT, per row (single quotes around the heading):
```bash
bash ~/.claude/lib/project-rules.sh -C <PROJECT_ROOT> extract CLAUDE.md '<heading>' .claude/rules/<name>.md '<globs-json>'
```
rc ≠ 0 (should not happen after S0) → ROLLBACK: `git -C <PROJECT_ROOT>
checkout -- CLAUDE.md .gitignore`, delete every `.claude/rules/<name>.md`
this run wrote, then STOP with the row and the lib's message.

S2 — POINTER. If CLAUDE.md has no `## Path-scoped rules` section, append:
```markdown

## Path-scoped rules
Project rules live in `.claude/rules/<name>.md` and load on Read of a file
matching their `paths:` (never at session start): <name>, <name>.
```
Else add the new names to its list. Collapse runs of blank lines left by
the extraction (never more than one).

S3 — CHECK, COMMIT, VERIFY TRACKED.
```bash
bash ~/.claude/lib/project-rules.sh -C <PROJECT_ROOT> check
```
rc ≠ 0 → ROLLBACK as in S1, STOP with the culprit lines. rc 0 →
```bash
git -C <PROJECT_ROOT> add CLAUDE.md .claude/rules .gitignore
git -C <PROJECT_ROOT> commit -m "chore(claude-md): split <k> section(s) into .claude/rules/"
git -C <PROJECT_ROOT> ls-files --error-unmatch .claude/rules/<name>.md   # per row
```
A rule `ls-files` cannot find → report it as `STOP: <name> not tracked
after commit` (the commit stays; the orchestrator decides).

OUTPUT:
```
SPLIT DONE: <k> rule(s) — <name>.md (<globs>), …
CLAUDE.md: <lines before> → <lines after> lines
CHECK    : project-rules: <k> rule(s) ok
COMMIT   : <hash> — all rules tracked
```
or `STOP: <row> — <reason> (rollback done, nothing committed)`.
```

- [ ] **Step 6: Locks still hold**

Run: `for s in model-routing effort-routing loops-heavy plan-challenger security-auditor doctrine-citers portability-census; do make test suite=lib/tests/$s.test.sh | tail -1; done`
(If the loop form is refused by the permission rules, run the seven `make test suite=…` commands one by one.)
Expected: `all suites green` seven times.

- [ ] **Step 7: Commit**

```bash
git add skills/onboard/SKILL.md agents/onboarder.md
git commit -m "feat(onboard): split mode classifies CLAUDE.md sections, onboarder MODE: split executes (RED: current skill ran archetype detection on split)"
```

---

### Task 8: `/onboard split` GREEN pressure test (orchestrator dispatch, no code)

- [ ] **Step 1: Fresh scratch repo `split-green/`**

Same one-liner as Task 6 Step 1 with `split-red` replaced by `split-green` everywhere (no `git clean`: a fresh directory).

- [ ] **Step 2: Dispatch the GREEN probe (sonnet, its own prompt)**

`Agent(subagent_type="general-purpose", model="sonnet", effort="medium")` with: "Probe of a skill's text, not a real run. Read `/home/bchanot/.claude/skills/onboard/SKILL.md` as if you had been invoked as `/onboard split` in the project `<split-green path>` (a git repo on `develop`, clean). Treat the MODEL GATE as passed and never call `mcp__model-router__route`; treat S2 (the `claude -p` baseline) as done with the value 2.1k; do not dispatch agents; do not write anything, not even the branch (report the command you would run instead). Follow the skill's text up to the mandatory stop, then stop. Report: the steps you ran in order, the classification table you would print, and the exact `matches` commands you ran."

Expected (GREEN): the report says it took MODE DISPATCH → § SPLIT MODE, ran S1, S3 (reported, not run), S4 with `matches` calls, and printed the S5 table (at least `rules/ maintenance` → move with `rules/**` and `Health Stack` → keep), then stopped. A probe that writes files, skips the gate, or runs archetype detection = not green: fix the skill text, re-run.

- [ ] **Step 3: Executor dry run (onboarder, MODE: split) on the scratch**

Dispatch `Agent(subagent_type="onboarder")` with `MODE: split`, `PROJECT_ROOT: <split-green path>`, `TABLE:` two rows: `rules/ maintenance | rules-maintenance | ["rules/**"]` and `mods/ — function-hooks plugins (Claude Code mods) | mods | ["mods/**"]`.
Expected: `SPLIT DONE: 2 rule(s)` with `all rules tracked`; `git -C <split-green path> log --oneline -1` shows the split commit; `.gitignore` there ends with `!.claude/rules/`; `bash lib/project-rules.sh -C <split-green path> check` prints `2 rule(s) ok`; and THIS repo is untouched: `git status --porcelain` empty here and `git log --oneline -1` unchanged.

- [ ] **Step 4: Record**

No commit. The orchestrator notes RED/GREEN outcomes for STEP 7 capitalize (EVAL entry).

---

### Task 9: generators born split (skeletons, `emit`, onboarder PHASE 5b, scaffolder PHASE 3b)

**Files:**
- Create: `templates/project-rules/docker.md`, `templates/project-rules/testing.md`, `templates/project-rules/ci.md`
- Modify: `templates/project-CLAUDE.md:4` (header comment)
- Modify: `agents/onboarder.md` (new PHASE 5b after PHASE 5)
- Modify: `agents/scaffolder.md` (new PHASE 3b between PHASE 3 and PHASE 4)
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
check T12g-ci-not-written "$([ -e .claude/rules/ci.md ] && echo yes || echo no)" no
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
<!-- TODO(/onboard STEP 3): image — base image + version; multi-stage? what the final stage holds. -->
<!-- TODO(/onboard STEP 3): compose — services, volumes, ports, the env file it reads (.env, never a secret in the image). -->
<!-- TODO(/onboard STEP 3): commands — docker compose up --build / down -v, where they differ from the native run. -->
```

`templates/project-rules/testing.md`:
```markdown
---
paths: ["tests/**", "test/**", "**/*.test.*", "**/*.spec.*", "**/conftest.py"]
---

# Testing conventions

<!-- Generated by /init-project or /onboard: loads on Read of a test file. -->
<!-- TODO(/onboard STEP 3): layout — where tests live, one file per module? naming (test_x.py / x.test.ts). -->
<!-- TODO(/onboard STEP 3): fixtures and factories — shared setup, what is mocked, what hits a real service. -->
<!-- TODO(/onboard STEP 3): rules — a bug fix ships its regression test; no sleep-based waits; coverage target if any. -->
```

`templates/project-rules/ci.md`:
```markdown
---
paths: [".github/workflows/**", ".gitlab-ci.yml", ".circleci/**"]
---

# CI

<!-- Generated by /init-project or /onboard: loads on Read of a pipeline file. -->
<!-- TODO(/onboard STEP 3): jobs — lint, test, build, deploy; which run on PR vs main; required checks. -->
<!-- TODO(/onboard STEP 3): secrets — names only (never values), where they are set. -->
<!-- TODO(/onboard STEP 3): runtime versions pinned here must match the Stack section of CLAUDE.md. -->
```

`templates/project-CLAUDE.md` line 4: after `# Global rules: ~/.claude/CLAUDE.md — this file extends or overrides them.` add the line `# Path-scoped rules: .claude/rules/<name>.md (paths: frontmatter), loaded on Read of a matching file.`

- [ ] **Step 3: Onboarder PHASE 5b**

In `agents/onboarder.md`, after the PHASE 5 block (after `**Do NOT overwrite existing content.**` and before the `---` that precedes PHASE 6), add:

```markdown

## PHASE 5b — PATH-SCOPED RULES (born split)

For each of `docker`, `testing`, `ci`:
```bash
bash ~/.claude/lib/project-rules.sh -C <PROJECT_ROOT> emit ~/.claude/templates/project-rules/<name>.md .claude/rules/<name>.md
```
- rc 0 → written with the globs that match this tree; its stub comments
  are `<!-- TODO(/onboard STEP 3): … -->` placeholders the orchestrator's
  STEP 3 fills (list them in OUTPUT beside the CLAUDE.md placeholders).
  Fill now only what the BRIEF already settles (`docker` commands from
  `build_cmd`, `testing` layout from `test_cmd`); never duplicate the
  always-on Build/Test sections.
- rc 1 → no match, nothing written, skip silently.
- rc 2 → the file exists: keep it, never overwrite.
Then `bash ~/.claude/lib/project-rules.sh -C <PROJECT_ROOT> check` must print
`N rule(s) ok`. The `!.claude/rules/` negation comes from the gitflow socle
at /onboard STEP 2.6 (`gitflow init` reconciles it); PHASE 4 stays as is.
```

- [ ] **Step 4: Scaffolder PHASE 3b**

In `agents/scaffolder.md`, after the PHASE 3 block (its last stack line, before the `---` that precedes `## PHASE 4`), add:

```markdown

## PHASE 3b — PATH-SCOPED RULES (born split)

After PHASE 3 wrote the files and BEFORE PHASE 4 installs dependencies
(installed packages must not match the globs). For each of `docker`,
`testing`, `ci`, one uniform loop:
```bash
bash ~/.claude/lib/project-rules.sh -C <PROJECT_ROOT> emit ~/.claude/templates/project-rules/<name>.md .claude/rules/<name>.md
```
rc 0 → fill its stubs from the DESIGN (image, compose services, test
layout, pipeline jobs), no placeholders left; rc 1 → nothing matched,
skipped (a plain scaffold yields `docker.md` when Docker is relevant, and
`testing.md` only when the stack scaffolds a test file). Then
`bash ~/.claude/lib/project-rules.sh -C <PROJECT_ROOT> check` prints
`N rule(s) ok`. The `.gitignore` negation `!.claude/rules/` comes from the
gitflow socle at STEP 5f (`gitflow init` reconciles it before the root
commit); do not add `.claude` lines to the stack `.gitignore` yourself.
```

- [ ] **Step 5: Verify**

Run: `bash lib/tests/project-rules.test.sh | tail -1; mkdir -p /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/gen-all/.github/workflows /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/gen-all/tests /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/gen-all/test /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/gen-all/.circleci && cd /tmp/claude-1000/-home-bchanot-Documents-claude/ea0efe5f-67aa-4f89-9e2a-ba0ac8695999/scratchpad/gen-all && touch Dockerfile docker-compose.yml compose.yaml .dockerignore .gitlab-ci.yml tests/a test/b a.test.ts b.spec.ts conftest.py .github/workflows/ci.yml .circleci/config.yml && bash /home/bchanot/Documents/claude/lib/project-rules.sh check /home/bchanot/Documents/claude/templates/project-rules; make -C /home/bchanot/Documents/claude test suite=lib/tests/doctrine-citers.test.sh | tail -1`
Expected: `FAIL=0`; `project-rules: 3 rule(s) ok` (every skeleton glob is syntactically sound); `all suites green`.

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
- [x] **Phase 0, no mod: split project CLAUDE.md** (this repo + the lever, feature/claude-md-split, 2026-10-26; merge on user signal). Four rules under `.claude/rules/` (rules-maintenance, graphify-vendored, mods, transient-artifacts `# static-check: skip`), `lib/project-rules.sh` check/matches/sections/extract/emit (`-C <dir>`) + suite, `hooks/instructions-loaded.sh` (log `~/.claude/logs/instructions-loaded.jsonl`, session + agent ids), `!.claude/rules/` here + socle, `/onboard split` + onboarder `MODE: split`, generators emit docker/testing/ci from `templates/project-rules/`. Baseline 2026-10-26 `/context`: 32.2k total, Memory files 11.6k, project CLAUDE.md 2.1k.
  - [ ] Proof, this repo: `/context` after the merge; one fresh session Reading one file per rule → 4 Project `path_glob_match` lines; one sub-agent Read → does a path rule load inside a sub-agent (decides what the per-repo pass may move). Results in the journal.
  - [ ] User step: `claude mcp remove -s user higgsfield` (user-scope MCP, no toggle ownership, no doctor check; phase 5 `.mcp.json` owns it).
  - [ ] Phase 2 folds: narrow the pre-commit `.claude/**` exemption so a rules-only commit cannot land on develop/main (deferred 2026-10-26).
- [ ] **Phase 0b, per-repo pass** (after phase 0 merges; via `/onboard split`, one `chore/claude-md-split` per repo off develop, approval per repo, never an automatic merge; `/context` before/after in that repo's journal). Order by size: faunosteo 52,322 chars (on feature/v1-1-clients-animals with 5 dirty files: finish or stash first, S1 refuses otherwise), zenquality 23,378, game 14,918 (on feature/replay-hint), robin_petier 12,895, config 4,990, integration_alphalink 4,249. None has `.claude/rules/` yet; all use the `.claude/*` file form (BDR-003). Sections a sub-agent needs stay always-on unless the phase 0 sub-agent proof says path rules load there.
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
Expected: the project CLAUDE.md row well under the 2.1k baseline (about 200 tokens); Memory files total about 1.9k lower than 11.6k. Record both for the journal.

- [ ] **Step 2: Main-session loads**

The hook needs a session started AFTER Task 2 landed in `settings.json`. Note the start time, then run a headless session that reads one file per rule: `date -u +%FT%TZ; claude -p "Read rules/a11y.md, install-plugins.sh, mods/model-router/.claude-plugin/plugin.json and docs/superpowers/specs/2026-10-26-claude-md-split-design.md, then answer with the single word done." 2>/dev/null | tail -1`, then
`jq -c 'select(.memory_type=="Project" and (.file_path|contains("/.claude/rules/")) and .ts >= "<start>") | {file_path, trigger_file_path, load_reason}' ~/.claude/logs/instructions-loaded.jsonl`.
Expected: exactly four lines with `load_reason: path_glob_match`, one per `.claude/rules/*.md`. Zero lines → the event does not fire as a classic hook on this CLI: report it, the proof falls back to `/context` inside the same `-p` session listing the rule under Memory files, and the finding goes to STEP 7 as a BLK.

- [ ] **Step 3: Sub-agent loads**

Dispatch `Agent(subagent_type="general-purpose", model="sonnet", effort="low")`: "Read `rules/a11y.md` and `install-plugins.sh` in /home/bchanot/Documents/claude, then reply with the single word done." Then
`jq -c 'select(.agent_id != null and (.file_path|contains("/.claude/rules/")) and .ts >= "<start>") | {agent_type, file_path, load_reason}' ~/.claude/logs/instructions-loaded.jsonl`.
Expected: two lines (rules-maintenance, graphify-vendored) with an `agent_id` → path rules load inside sub-agents. Zero lines → they do not: record it (journal + STEP 7 LRN), and the per-repo pass keeps sub-agent-needed sections always-on; whether this repo's two hazards (graphify untrack-then-merge, mods `[ -L ]` guard) return as always-on one-liners is the user's call at the next gate.

---

## Self-review

- Spec coverage: §1 rules → Task 4; `.gitignore` + socle → Task 3; §2 check/sections/extract (+ matches, emit, -C) + suite → Task 1 (emit Task 9), hook + settings → Task 2, proof → Task 11; §3 skill + onboarder split + RED/GREEN → Tasks 6-8; §4 skeletons + generators + template header → Task 9; §5 citers → Task 5 (ARCHITECTURE.md is STEP 8's), TODO → Task 10, higgsfield user step → Task 10 TODO line + STEP 7 journal; §6 testing → every task's verify step + Task 10 Step 2; §7 pre-commit exemption → deferred, Task 10 TODO line.
- Placeholder scan: none. Every code step carries its content.
- Type consistency: `extract` arg order `<file> <heading> <out> <globs-json>` is the same in the lib, the suite, Task 4 and the onboarder S1; `emit <skeleton> <out>` the same in the lib, T12, PHASE 5b and PHASE 3b; `-C <dir>` precedes the subcommand everywhere; the skip marker string `# static-check: skip` is identical in the lib grep, T4 and Task 4 Step 3; the `check` success line `project-rules: N rule(s) ok` is what T3c, T5b, T5d, T11b and the agents quote; the `matches` stderr line `no match: <glob>` is what T5i expects.
- Review Focus: 1 → T6d/T8e/T8f, 2 → T2c/T12b/T12f, 3 → T2d/T5j, 4 → Task 8 Step 3 assertions, 5 → T10f-T10j. All pinned.
