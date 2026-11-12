# PLAN — extract-hardening (feat, 2026-10-27, r2 after the 3-lens challenge)
Contract: `.claude/tasks/contracts/2026-10-27-extract-hardening-1838.md`

## Files
- `lib/project-rules.sh` — `project_rules_extract` (lines 185-205); one new helper `_rules_out_path_ok` placed right before it.
- `lib/tests/project-rules.test.sh` — new blocks `T9o`..`T9z` after T9k (line ~184), before T10.
- `agents/onboarder.md` — MODE: split S0.3, lines 213-215 (the heading sentence only).

## Approach
1. New helper, same shape as `_rules_heading_line` (stderr message + rc 2). The `..` check is lexical, on the argument string; a symlinked component is not resolved (no GNU-only `realpath -m`), named by a `shortcut:` comment:
   ```bash
   _rules_out_path_ok() {  # <out> → rc 2 when absolute, has a .. part, or exists
     # shortcut: lexical only, a symlinked component is not resolved (no
     # portable realpath -m); upgrade = resolve the parent dir with cd -P
     case "$1" in
       /*) echo "project-rules: out must be relative: $1" >&2; return 2 ;;
       ..|../*|*/..|*/../*)
         echo "project-rules: out must not contain ..: $1" >&2; return 2 ;;
     esac
     if [ -e "$1" ] || [ -L "$1" ]; then
       echo "project-rules: $1 exists" >&2; return 2
     fi
   }
   ```
   `a/../b`, `../b`, `a/..` and `..` each match one of the four patterns; `a/..b` or `..a` do not (ordinary names). Keep the existing `$out exists` wording so T8c reads the same.
2. In `project_rules_extract`, replace line 191 (`[ -e "$out" ] && …`) by `_rules_out_path_ok "$out" || return 2`, same position: after the heading-count check, before `_rules_globs_all_match` (no glob check, no temp file before a refusal).
3. `mkdir -p` checked in the file's one-statement idiom (line 194 form), before `mktemp`:
   ```bash
   mkdir -p "$(dirname "$out")" \
     || { echo "project-rules: cannot create $(dirname "$out")" >&2; return 2; }
   ```
4. The rule write becomes a checked statement. NOT `if ! { …; } > "$out"`: when the redirection of a compound command fails, bash returns 1 before applying `!`, so the failure is missed (probed on bash 5.3.9: `if ! { echo hi; } > /proc/nowhere/x` prints MISSED). The `||` form catches it (probed: rc 2). `printf` and the body are chained with `&&` so a failed printf is not masked by an empty body:
   ```bash
   { printf -- '---\npaths: %s\n---\n\n# %s\n' "$globs" "${hline#* }" \
       && _rules_section_body "$src" "$hline"; } > "$out" \
     || { rm -f "$tmp" "$out"
          echo "project-rules: $out not written, $src untouched" >&2
          return 2; }
   ```
   Then the existing source rewrite block (lines 197-202), unchanged. The three awk helpers are not touched (`##` behaviour byte-identical).
5. Logic-line budget: the helper absorbs the three path refusals; `project_rules_extract` stays ≤ 25 logic lines and 5 locals (`src out globs hline tmp`). Every line ≤ 80 chars (the `||` lines above are ≤ 79). No `# shellcheck disable`.
6. `agents/onboarder.md` S0.3: replace
   `a heading whose leading `#` run is followed by a space starts with `### `; any other leading `#` is a bare `##` title (`#1 priority`);`
   by the lib's case order, refusal first:
   `a heading starting with `# ` or `####` (space or not) is refused by the lib (rc 2): STOP with the row; one starting with `## ` → STOP too (a bare row carries no `## `); one starting with `### ` is a subsection; any other leading `#` is a bare `##` title (`#1 priority`);`
   Nothing else in the file changes. (The lib passes `'## '*` through as written; a row written that way would be looked up as `## ## Foo` at S0.4, so S0.3 stops it, as today's prose does.)

## Edge cases
- Dangling symlink as `<out>`: `-e` false, `-L` true → refused, the link stays.
- `mkdir -p` ENOTDIR: a regular file where the parent dir must be; the stderr line `cannot create` is what distinguishes this guard from the write check (both give rc 2 and an untouched source), so the test asserts it.
- Write failure independent of root: `<out>` with a trailing slash (`.claude/rules/beta.md/`) passes the path helper, `mkdir -p .claude/rules` succeeds, the open fails with EISDIR; nothing is created. The chmod-based case (`ro/`) stays as the second probe, with the LRN-233 root limit.
- `rm -f "$tmp"` on the write-failure path: `$tmp` exists at that point (mktemp ran before the write).
- All refusals rc 2, never 1. Each new refusal is asserted by its stderr reason, not by rc alone (rc 2 is shared).

## Tests (lib/tests/project-rules.test.sh, after T9k, in the `$FIX` root where CLAUDE.md holds `## Beta` once; `src/app.ts` exists there)
```bash
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
```
Lines over 80 chars in the test file follow the file's existing practice (T9e already exceeds it); the width limit in AC6 applies to the lib. `err` reuses the T5h variable (line 78); every use follows its own assignment. No `ls`, no `wc` (SC2012, BSD padding). Suite total: 116 + 23 = 139 checks, FAIL=0, if the count differs the names above are the reference, not the number.

## Follow-ups (TODO.md, not this run; REQUEST is extract-only)
- `emit`: reuse `_rules_out_path_ok`, check `mkdir -p` and the `> "$2"` write rc (today "emitted" rc 0 on failure, `-e` only so a dangling link is followed).
- `extract` rewrite failure mid-`cat` (ENOSPC/EIO after truncation): keep `$tmp` and name it on stderr instead of `rm -f` (today the message "$src not rewritten" can be false).
- `_rules_out_path_ok` shortcut: `..` check is lexical, a symlinked component (`.claude` or `.claude/rules` pointing elsewhere) is not resolved; upgrade = `cd -P` on the parent dir, compare against `$PWD`.
- The main loop writes these three lines under TODO.md at CAPITALIZE; the executor touches no file outside FILE SCOPE.

## Disposition
- honors LRN-233 by: redirection failures caught with `cmd || { …; return 2; }` (the `if ! { …; } > f` form proven blind on bash 5.3.9), `printf && body` chained, one failure-path test per new rc check with its stderr reason, `mktemp` still checked.
- honors LRN-234 by: no glob listing order asserted, no `# shellcheck disable`, the awk helpers untouched so `##` stays byte-identical.
- honors LRN-096 by: every new guard has a flip test that goes red when the guard is removed (reason on stderr, file state), never rc 2 alone.
- honors BDR-128 by: refusals stay in the one oracle, rc 2, culprit named on stderr; `/onboard split` prose follows the lib's case order.
