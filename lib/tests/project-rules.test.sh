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
  "$(printf '%s\n' "$out" | grep -c 'nofm.md: paths: must be one line')" 1
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
# T5n a glob that names a dependency dir is a match (vendored area rule)
mkdir -p vendor/lib && echo v > vendor/lib/a.js
bash "$PR" matches 'vendor/**' >/dev/null; check T5n-named-dep-dir-rc "$?" 0
bash "$PR" matches '**/a.js' >/dev/null 2>&1
check T5o-unnamed-dep-dir-still-filtered "$?" 1

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

cp CLAUDE.md "$FIX/orig.md"
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
# T7j subtract-only: one deletion hunk, removed = heading + body + separators
check T7j-one-hunk "$(diff "$FIX/orig.md" CLAUDE.md | grep -c '^[0-9]')" 1
check T7k-no-additions "$(diff "$FIX/orig.md" CLAUDE.md | grep -c '^> ')" 0
check T7l-removed-lines "$(diff "$FIX/orig.md" CLAUDE.md | grep '^< ' | cut -c3- | grep -vE '^(---)?$' | tr '\n' '|')" '## Alpha|aaa|'

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

# T9e a failed source rewrite is rc 2 and leaves no rule behind
TMPDIR=/nonexistent bash "$PR" extract CLAUDE.md 'Beta' .claude/rules/beta.md '["src/**"]' 2>/dev/null
check T9e-no-tmp-rc "$?" 2
check T9f-no-tmp-nothing-written "$([ -e .claude/rules/beta.md ] && echo yes || echo no)" no
check T9g-no-tmp-beta-still-there "$(grep -c '^## Beta' CLAUDE.md)" 1
chmod a-w CLAUDE.md
bash "$PR" extract CLAUDE.md 'Beta' .claude/rules/beta.md '["src/**"]' 2>/dev/null
check T9h-unwritable-src-rc "$?" 2
check T9i-unwritable-src-rule-removed "$([ -e .claude/rules/beta.md ] && echo yes || echo no)" no
chmod u+w CLAUDE.md
check T9j-unwritable-src-beta-still-there "$(grep -c '^## Beta' CLAUDE.md)" 1

# T9k a mid-file H1 ends the section (foreign CLAUDE.md with several parts)
mkdir -p "$FIX/h1/src" && cd "$FIX/h1" || exit 1
echo x > src/a.ts
printf '## A\naaa\n\n# Part Two\nintro\n\n## B\nbbb\n' > CLAUDE.md
check T9k-h1-ends-section "$(bash "$PR" sections CLAUDE.md | awk -F'\t' '$3=="## A"{print $1}')" 10
bash "$PR" extract CLAUDE.md 'A' .claude/rules/a.md '["src/**"]' >/dev/null
check T9l-h1-kept "$(grep -c '^# Part Two' CLAUDE.md)" 1
check T9m-h1-intro-kept "$(grep -c '^intro' CLAUDE.md)" 1
check T9n-rule-body-stops-at-h1 "$(tail -1 .claude/rules/a.md)" aaa
cd "$FIX" || exit 1

# T9o extract refuses an absolute, a .. or a symlinked <out>, before any write,
# each refusal named on stderr
err=$(bash "$PR" extract CLAUDE.md 'Beta' "$FIX/abs.md" '["nowhere/**"]' 2>&1 >/dev/null)
check T9o-absolute-out-rc "$?" 2
check T9o2-absolute-reason-before-globs "$(printf '%s\n' "$err" | grep -c 'must be relative')" 1
check T9p-absolute-nothing-written "$([ -e "$FIX/abs.md" ] && echo yes || echo no)" no
err=$(bash "$PR" extract CLAUDE.md 'Beta' .claude/rules/../escape.md '["src/**"]' 2>&1 >/dev/null)
check T9q-dotdot-out-rc "$?" 2
check T9q2-dotdot-reason "$(printf '%s\n' "$err" | grep -c 'must not contain')" 1
check T9r-dotdot-nothing-written "$([ -e .claude/escape.md ] && echo yes || echo no)" no
bash "$PR" extract CLAUDE.md 'Beta' nope/.. '["src/**"]' 2>/dev/null
check T9r2-trailing-dotdot-rc "$?" 2
check T9r3-trailing-dotdot-no-dir "$([ -e nope ] && echo yes || echo no)" no
mkdir -p "$FIX/sub/src" && cd "$FIX/sub" || exit 1
echo x > src/a.ts
printf '## Beta\nbbb\n' > CLAUDE.md
bash "$PR" extract CLAUDE.md 'Beta' ../escape.md '["src/**"]' 2>/dev/null
check T9s-leading-dotdot-rc "$?" 2
check T9s2-leading-dotdot-nothing-written "$([ -e "$FIX/escape.md" ] && echo yes || echo no)" no
cd "$FIX" || exit 1
ln -s "$FIX/absent.md" .claude/rules/dangling.md
err=$(bash "$PR" extract CLAUDE.md 'Beta' .claude/rules/dangling.md '["src/**"]' 2>&1 >/dev/null)
check T9t-dangling-symlink-rc "$?" 2
check T9t2-dangling-reason "$(printf '%s\n' "$err" | grep -c 'exists')" 1
check T9u-dangling-still-link "$([ -L .claude/rules/dangling.md ] && echo yes || echo no)" yes
rm -f .claude/rules/dangling.md
check T9v-refusals-keep-beta "$(grep -c '^## Beta' CLAUDE.md)" 1

# T9w a failed mkdir (named on stderr) or a failed rule write is rc 2, the
# source untouched and no rule left behind; the trailing-slash case holds as root
touch .claude/rules/notadir
err=$(bash "$PR" extract CLAUDE.md 'Beta' .claude/rules/notadir/beta.md '["src/**"]' 2>&1 >/dev/null)
check T9w-mkdir-fails-rc "$?" 2
check T9w2-mkdir-fails-reason "$(printf '%s\n' "$err" | grep -c '^project-rules: cannot create')" 1
check T9x-mkdir-fails-beta-kept "$(grep -c '^## Beta' CLAUDE.md)" 1
bash "$PR" extract CLAUDE.md 'Beta' .claude/rules/beta.md/ '["src/**"]' 2>/dev/null
check T9x2-eisdir-write-rc "$?" 2
check T9x3-eisdir-beta-kept "$(grep -c '^## Beta' CLAUDE.md)" 1
check T9x4-eisdir-nothing-written "$([ -e .claude/rules/beta.md ] && echo yes || echo no)" no
mkdir .claude/rules/ro && chmod a-w .claude/rules/ro
bash "$PR" extract CLAUDE.md 'Beta' .claude/rules/ro/beta.md '["src/**"]' 2>/dev/null
check T9y-write-fails-rc "$?" 2
check T9z-write-fails-beta-kept "$(grep -c '^## Beta' CLAUDE.md)" 1
check T9z2-write-fails-no-rule "$([ -e .claude/rules/ro/beta.md ] && echo yes || echo no)" no
chmod u+w .claude/rules/ro

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
# "$BASH", not bash: a blank PATH applies to the command lookup too (rc 127); this proves the contract (rc 0, silent, nothing appended), not the jq guard
out=$(printf '%s' "$IN" \
  | CLAUDE_INSTRUCTIONS_LOG="$LOG" PATH=/nonexistent "$BASH" "$HOOK"); rc=$?
check T10h-empty-path-rc0 "$rc" 0
check T10i-empty-path-stdout-empty "$out" ""
check T10j-empty-path-nothing-appended "$(wc -l < "$LOG" | tr -d ' ')" 1
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

# T13 ### subsections: hidden at depth 2, listed at depth 3, extractable,
# a ### moved last gives its parent's --- back, a ## parent takes its ###
mkdir -p "$FIX/d3/src" && cd "$FIX/d3" || exit 1
echo x > src/a.ts
cat > CLAUDE.md <<'EOF'
# Top

## P
intro

### Sub
s1
```
### fenced
```
#### deep
s2

### Sub2
s3

---

## Q
q
EOF
cp CLAUDE.md "$FIX/orig3.md"
fence=$(printf '\140\140\140')
check T13-depth2-unchanged "$(bash "$PR" sections CLAUDE.md | cut -f1,3 | tr '\t\n' ' |')" '74 ## P|7 ## Q|'
out=$(bash "$PR" sections --depth 3 CLAUDE.md)
check T13b-depth3-file-order "$(printf '%s\n' "$out" | cut -f3 | tr '\n' '|')" '## P|### Sub|### Sub2|## Q|'
check T13c-sub-chars-and-line "$(printf '%s\n' "$out" | awk -F'\t' '$3=="### Sub"{print $1 "," $2}')" '44,6'
check T13d-parent-same-as-depth2 "$(printf '%s\n' "$out" | awk -F'\t' '$3=="## P"{print $1}')" 74
bash "$PR" sections --depth 4 CLAUDE.md 2>/dev/null; check T13e-bad-depth-rc "$?" 2
bash "$PR" sections CLAUDE.md --depth 3 2>/dev/null; check T13f-flag-after-file-rc "$?" 2
bash "$PR" extract CLAUDE.md '### Sub' .claude/rules/sub.md '["src/**"]' >/dev/null
check T13g-extract-sub-rc "$?" 0
check T13h-rule-title "$(sed -n '5p' .claude/rules/sub.md)" '# Sub'
check T13i-removed-lines "$(diff "$FIX/orig3.md" CLAUDE.md | grep '^< ' | cut -c3- | grep -vE '^(---)?$' | tr '\n' '|')" "### Sub|s1|$fence|### fenced|$fence|#### deep|s2|"
check T13j-rule-ends-before-sub2 "$(tail -1 .claude/rules/sub.md)" 's2'
cp CLAUDE.md "$FIX/mid3.md"
bash "$PR" extract CLAUDE.md '### Sub2' .claude/rules/sub2.md '["src/**"]' >/dev/null
check T13k-last-child-rc "$?" 0
check T13l-last-child-removed-lines "$(diff "$FIX/mid3.md" CLAUDE.md | grep '^< ' | cut -c3- | tr '\n' '|')" '### Sub2|s3|'
check T13m-parent-separator-kept "$(grep -c '^---$' CLAUDE.md)" 1
check T13n-no-additions "$(diff "$FIX/mid3.md" CLAUDE.md | grep -c '^> ')" 0
check T13o-q-kept "$(grep -c '^## Q' CLAUDE.md)" 1
bash "$PR" extract CLAUDE.md '#### deep' .claude/rules/deep.md '["src/**"]' 2>/dev/null
check T13p-level4-rc "$?" 2
check T13p2-level4-msg "$(bash "$PR" extract CLAUDE.md '#### deep' .claude/rules/deep.md '["src/**"]' 2>&1 >/dev/null | grep -c 'heading level must be ## or ###')" 1
bash "$PR" extract CLAUDE.md '# Top' .claude/rules/top.md '["src/**"]' 2>/dev/null
check T13q-level1-rc "$?" 2
check T13q2-level1-msg "$(bash "$PR" extract CLAUDE.md '# Top' .claude/rules/top.md '["src/**"]' 2>&1 >/dev/null | grep -c 'heading level must be ## or ###')" 1
check T13r-nothing-else-written "$(cd .claude/rules && printf '%s\n' * | wc -l | tr -d ' ')" 2
cp "$FIX/orig3.md" CLAUDE.md
bash "$PR" extract CLAUDE.md 'P' .claude/rules/p.md '["src/**"]' >/dev/null
check T13s-parent-takes-children "$(grep -c '^### Sub' .claude/rules/p.md)" 2
check T13t-parent-extract-q-kept "$(grep -c '^## Q' CLAUDE.md)" 1
printf '## #1 priority\nbody\n' > hash.md
bash "$PR" extract hash.md '#1 priority' .claude/rules/hash.md '["src/**"]' >/dev/null
check T13u-bare-title-starting-with-hash "$?" 0
cd "$FIX" || exit 1

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
