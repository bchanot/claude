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
# T5k a glob with more than a pipe buffer of hits is still a match (no
# SIGPIPE from an early reader); T5m braces are not expanded by compgen
mkdir -p many
seq -f 'many/file-%04.0f-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' 1 3000 \
  | xargs touch
bash "$PR" matches 'many/**' >/dev/null; check T5k-many-hits-rc "$?" 0
check T5l-three-lines "$(bash "$PR" matches 'many/**' | wc -l | tr -d ' ')" 3
bash "$PR" matches 'src/**/*.{ts,tz}' >/dev/null 2>&1
check T5m-brace-glob-no-match "$?" 1

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
check T8g-nothing-written "$(cd .claude/rules && printf '%s ' *)" 'alpha.md good.md '

# T9 extract refuses malformed globs and a glob that matches nothing
bash "$PR" extract CLAUDE.md 'Beta' .claude/rules/beta.md 'src/**' 2>/dev/null
check T9-bad-globs-rc "$?" 2
bash "$PR" extract CLAUDE.md 'Beta' .claude/rules/beta.md '["nowhere/**"]' 2>/dev/null
check T9b-unmatched-glob-rc "$?" 2
check T9c-nothing-written "$([ -e .claude/rules/beta.md ] && echo yes || echo no)" no
check T9d-beta-still-there "$(grep -c '^## Beta' CLAUDE.md)" 1

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
# "$BASH", not bash: the blank PATH applies to the command lookup too (rc 127)
out=$(printf '%s' "$IN" \
  | CLAUDE_INSTRUCTIONS_LOG="$LOG" PATH=/nonexistent "$BASH" "$HOOK"); rc=$?
check T10h-no-jq-rc0 "$rc" 0
check T10i-no-jq-stdout-empty "$out" ""
check T10j-no-jq-nothing-appended "$(wc -l < "$LOG" | tr -d ' ')" 1
head -c 5300000 /dev/zero | tr '\0' 'x' > "$LOG"
printf '%s' "$IN" | CLAUDE_INSTRUCTIONS_LOG="$LOG" bash "$HOOK"
check T10k-rotated "$([ -e "$LOG.1" ] && echo yes || echo no)" yes
check T10l-fresh-log-one-line "$(wc -l < "$LOG" | tr -d ' ')" 1

# T11 the real rules of this repo pass the check (4 rules, 1 skip-marked)
out=$(bash "$PR" -C "$ROOT" check); rc=$?
[ "$rc" -eq 0 ] || printf '%s\n' "$out"
check T11-repo-rules-pass "$rc" 0
check T11b-four-rules "$(printf '%s\n' "$out" | grep -c '4 rule(s) ok')" 1
check T11c-transient-skipped \
  "$(printf '%s\n' "$out" | grep -c 'transient-artifacts.md: SKIP docs/superpowers/\*\*')" 1

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

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
