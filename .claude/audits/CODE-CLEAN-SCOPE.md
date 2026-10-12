# CODE-CLEAN SCOPE — approved 2026-10-12 — branch chore/code-clean

Source plan: .claude/tasks/plans/2026-10-12-code-clean-0103.md (r3).
APPROVED: all non-deferred items = A1, B1, B2, B3, B4, B5, B7, B9, B11, B18, B19, B20, C2, C3.
NOT approved / untouched: B13-B17 (no change proposed), C1, C4, C5 (deferred).
Iron law: zero behavior change. No commit. Never switch branch.
Format below: file:line — item — severity — proposed fix (verbatim from the plan).

A1. lib/seo-data/safe_fetch.py:30 — `import gzip` unused (gzip appears only in
    comments at :137 and :153) — warn — delete the import line. The `gzip`
    token in the stdlib-only ALLOWLIST at lib/seo-data/seo-data.test.sh:143
    stays: it is a list of permitted stdlib names, not a usage assertion.

B1. lib/seo-data/seo-data.test.sh (27 sites, SC2015 `[ … ] && ok … || no …`;
    `ok`/`no` never fail) — warn, outside the Health Stack glob — insert on
    line 3, BEFORE `set -u` (a directive after the first command scopes to the
    next command only; r1 had it wrong):
    `# shellcheck disable=SC2015  # A && ok || no is deliberate (ok/no never fail)`
    — the convention of lib/tests/effort-routing.test.sh:8/:9. Prove:
    `shellcheck lib/seo-data/seo-data.test.sh` exits 0. Zero behavior change.

B2. lib/tests/url-guard.test.sh:21,22,33,34,60,61 and
    lib/tests/push-guard.test.sh:108-110 (SC2016: single-quoted `$(…)` /
    backticks are the commands under test) — warn, outside the Health Stack
    glob — file-level `# shellcheck disable=SC2016  # single-quoted forms are
    the commands under test` placed BEFORE the first command (url-guard line
    3, push-guard line 5), as lib/tests/guard-bash.test.sh:5. Prove: shellcheck
    exits 0 on both.

B3. lib/tests/run-review-guards.sh:14 — `cd "$REPO"` unguarded (SC2164);
    under `set -uo pipefail` a failed cd runs every guard in the wrong
    directory — warn — `cd "$REPO" || exit 1`. delta: cd-failure path only
    (silent wrong-dir run → loud exit 1).

B4. hooks/design-toolchain-reminder.sh:51 — one 972-char regex literal — warn
    — split into `pattern='…'` + `pattern+='|…'` lines ≤80 chars, IN THE
    CURRENT ALTERNATIVE ORDER (no regrouping: the sha256 must match). This
    hook runs live on every UserPromptSubmit of every session (settings.json
    wires ~/.claude/hooks → repo hooks/); a syntax error = exit 2 = every
    prompt blocked. Procedure: build on a scratch copy, `bash -n`, then
    `printf '%s' "$pattern" | sha256sum` old vs new must match, then the
    suite lib/tests/design-toolchain-reminder.test.sh run on the copy — the
    suite hardcodes `$H=<root>/hooks/design-toolchain-reminder.sh` (:4), so
    build a mirror tree `$T/hooks/<copy>` + `$T/lib/tests/<suite copy>` and
    run the suite from there, never edit the suite — then land it in ONE
    write. Zero behavior change.

B5. lib/toggle-external.sh:257 — `enable_tool()` 49 logic lines after the
    error-handling exclusion (max 25) — warn — split by case arm:
    `enable_gstack`, `enable_external_single` (the 11-name arm, darwin-skill
    src branch included), `enable_pack` (21st|higgsfield); `enable_tool`
    keeps only the dispatch `case`. Every `ok`/`warn`/`err` string and return
    code unchanged. Lines 1-32 of the file untouched (usage() prints 3-26).
    Coverage: `enable gstack` by lib/tests/gstack-removed.test.sh:43,55; the
    darwin-skill branch has NO suite → golden capture mandatory (see
    EXECUTOR CONSTRAINTS).

B7. lib/profile.sh:321 — `enable_skill()` 41 logic lines — warn — extract the
    three large arms: `enable_gstack_skill`, `enable_linked_skill`
    (external|personal; NOT "managed", a term of art for the MANAGED_*
    allowlists), `enable_plugin_skill` (plugin@*); the plugin / mcp / cli
    arms stay inline. Twin of toggle-external's arms (see C5), kept separate:
    merging changes messages. Golden capture mandatory: the profile suites
    discard output (`>/dev/null 2>&1`).

B9. lib/profile.sh:575 — `cmd_show()` 32 logic lines AND 14 distinct locals
    (max 5; outcome: logic lines ≤25 per function, locals reduced, NOT to
    ≤5 — whichever helper keeps the header still holds prof/file/desc/
    skills/pl/m/c/total) — warn — extract `_show_plain "$prof"` (the `--plain` branch) and
    `_show_grouped "$prof"`; each helper takes `$prof` and iterates
    `read_profile` itself. NO `local -n` (zero namerefs in the repo, bash
    ≥4.3 only). `_show_plain` MUST end with an explicit `return 0`: profile.sh
    runs `set -euo pipefail` and the loop's last `[ … ] && printf` returns 1
    whenever the last entry is not `cli` (dev/qa/seo today) — without it the
    helper's rc 1 kills the script after printing (reproduced), and
    lib/design-tool-gate.sh:202 turns that into `exit 2`. No suite runs the
    real cmd_show (design-tool-gate.test.sh fakes profile.sh) → characterization
    oracle: stdout + rc of `bash lib/profile.sh show <p>` and `show <p>
    --plain` for EVERY lib/profiles/*.profile, captured before and after,
    byte-identical. Grouped mode calls `claude plugin list` / `claude mcp
    list` live via skill_status (:270-297): run both captures with the same
    fixed `CLAUDE_BIN` stub so session state cannot drift between them.
    minimal.profile (0 entries) covers the `Total: 0` branch.

B11. lib/seo-data/google_seo.py:217 — `_cli()` 40 logic lines — warn —
    extract `_build_parser()` (the four sub-parsers; name already used by
    content_quality.py and schema_gen.py) and `_dispatch(args)`; the
    try/except envelope (bad_usage / degraded) stays in `_cli`. The
    `bad_usage` path has no test → golden capture of stdout + rc for one
    bad invocation and each of the 4 verbs in mock mode.

B18. lib/profile.sh:188 (gstack_skills) and lib/toggle-external.sh:167
    (gstack_skills) — `for d in` loops with no `local d`: `d` leaks as a
    global (norm: no global state); no reader of `$d` outside those loops,
    and every caller reads the function through `< <(gstack_skills …)`
    (profile.sh:507, toggle-external.sh:181, :222), so the leak never
    reaches a caller — warn — add `local d` in each. r2 also listed
    toggle-external.sh:70 and :98: FALSE, both already declare `local d`
    (:69, :97); dropped. Same class, same fix, added in r3:
    toggle-external.sh:263 `for entry in` (inside the gstack arm B5 moves
    into enable_gstack — declare `local entry` there) and :344 `for t in`
    (cmd_status → `local t`). Zero behavior change.

B19. lib/toggle-external.sh:119-121 — comment says "this script takes no extra
    `source`" but :50 sources lib/gstack-removed.sh and both fixture suites
    copy it alongside (higgsfield.test.sh:180,
    toggle-external-repo-resolution.test.sh:20) — info — reword the comment.

B20. lib/detect-plugins.sh:4 — header "Sourced by:" omits update-all.sh:19 —
    info — add it.

C2. skills/prune-memory/tests/run-deterministic.sh — hermetic deterministic
    suite (mktemp sandbox, 5 oracles, ALL GREEN today) absent from Makefile
    SUITES — info, delta: `make test` gains one suite block and one new way
    to go red — add the LITERAL tracked path
    `skills/prune-memory/tests/run-deterministic.sh` to Makefile:31 (NOT a
    `skills/*/…` glob: skills/ holds symlinks to vendored and out-of-repo
    trees, a glob would execute unreviewed third-party tests and make the
    suite set machine-dependent). Caveat for the human: the suite executes
    bash blocks extracted from prune-memory SKILL.md headings, so wiring it
    locks that doc's headings under `make test`.

C3. lib/deploy-commit.sh:51-57 and :62-68 — verbatim identical 7-line
    REFUSED block (`diff` empty) in the `pending` and `commit` arms — warn —
    hoist into `_refuse_outside_allowlist "$@"` (`local violations;
    mapfile -t violations …` + the `{ … } >&2; exit 4` block). Define it
    with the other `_` helpers ABOVE line 46 (the script runs `set -uo
    pipefail` without -e: a helper defined after `esac` would give rc 127
    and the arm would carry on to `git add` out-of-scope paths); call it as
    a plain statement so `exit 4` ends the script exactly as today, and
    keep the post-`shift` `"$@"` (:60). stderr text byte-identical — but
    lib/tests/deploy-commit.test.sh runs every rc-4 case with `>/dev/null
    2>&1` (:19, :22, :26, :46) and checks rc + commit count only, and the
    calling skill parses the REFUSED text (deploy-commit.sh:13-15) → golden
    capture of stdout + stderr + rc, before and after, in a mkrepo-style
    sandbox for `pending src.txt`, `commit x src.txt` and one mixed
    in-scope + out-of-scope call.

B17 POLICY (no change proposed; applies to how the items above are written):
B17. Lines > 80 chars: 1273 in 78 shell files, 46 in Python (6 of them
    docstrings), 5 in TypeScript — info — ALL DEFERRED to "enforce on new
    code" (r1 proposed the Python/TS subset; dropped: no formatter tracked so
    it would not hold, 5 of google_seo's lines sit inside B11's `_cli`, and
    the register.ts lines are in a live-loaded mod with a `make test` gate
    that SKIPs when `claude plugin test` is absent). Lines MOVED by B5, B7,
    B9, B11, C3 keep their current length (toggle-external.sh:280, 285-287,
    325, 334; deploy-commit.sh:53, :55; profile.sh:349, 385, 393, 402 are
    >80 today): rewrapping a message string can change output. B17 applies
    only to lines newly written in this run (function headers, calls).

EXECUTOR CONSTRAINTS (apply to every approved item):
- Golden capture BEFORE any edit, diff AFTER: stdout, stderr, rc (and the
  fixture tree where a mv/rm arm is moved) for every moved arm and CLI verb
  — the suites that "cover" B5/B7/B9/B11/C3 discard output or fake the
  script.
- Hook-safe landing for B4 (scratch copy → bash -n → sha256 → suite → one
  write). No edit to register.ts in this run.
- No `local -n`, no new bash ≥4 construct, no new dependency.
- Return codes: toggle-external.sh:40 and profile.sh:49 run `set -euo
  pipefail`. Call every extracted helper (B5, B7, B9) as a PLAIN statement
  — never `helper || …`, `helper && …`, `if helper`, `! helper`: those
  switch errexit OFF inside the helper, so a failed `mv`
  (toggle-external.sh:273, profile.sh:330) that aborts with rc 1 today would
  instead continue and print `ok …` with rc 0, a path no golden capture
  exercises. A plain call keeps `return 1` (toggle-external.sh:305, :326)
  → errexit in the caller → exit 1 through main (:359), as today. C3 uses
  `exit`, not `return`, and is covered by its own placement rule.
- `make test` full run after; shellcheck on every touched file.

BUG TO LOG (executor appends to .claude/audits/BUGS-FOUND.md, never fixes):

BASELINE: make test = 46 suites green before this run (scratchpad make-test-baseline.txt); shellcheck *.sh hooks/*.sh lib/*.sh exit 0.
