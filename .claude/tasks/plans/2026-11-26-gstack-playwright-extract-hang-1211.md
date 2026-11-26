# PLAN — bugfix gstack Playwright extraction hang (2026-11-26)

STATUS: PARKED, not built (user decision 2026-11-26: test on the Mac first,
no code). Challenge: correctness CONCERNS(1), robustness CONCERNS(3),
simplicity SOLID. Findings that stopped the build: the local bump leaves
package.json + bun.lock modified on every host, so `git submodule update
--remote` is refused there (T7, BDR-088), toward an upstream that already
pins Playwright ^1.65; three silent no-op paths on the target host (bun
install failed, version unparsed, version safe); no errexit test on the
bump path; reuse the awk version reader at lib/gstack-playwright.sh:210.
Zero-code path to try first: `make update`, answer y to the gstack prompt.
PRIOR wording to fix if revived: BLK-008 records no Node version.

## Diagnosis
BUG: on a macOS arm64 work machine, `make install` / `make plugin` freezes in
gstack `./setup` at "Installing Playwright Chromium..." (chromium v1208,
Chrome for Testing 145.0.7632.6). Each run prints "Removing unused browser
at .../chromium-1208" first: the previous install never completed.

ROOT CAUSE (leading hypothesis, NOT confirmed on the Mac): the gstack
submodule (pinned 11de390) pins `playwright ^1.58.2`. Playwright < 1.60.0
hangs forever at archive extraction on Node 24.16.0+ (yauzl stream
regression, upstream gstack issue #1703, fixed in Playwright 1.60.0). Our
installer already bumps gstack's Playwright before `./setup`
(`gstack_bump_playwright_if_unsupported`, lib/gstack-playwright.sh:108),
but only when the pinned version lacks a build for a too-new Ubuntu: on
macOS the function returns at once (`[ -r /etc/os-release ] || return 0`,
then empty ostag), so the Mac stays on 1.58.2.

EVIDENCE: issue #1703 names the same revision, same symptom, macOS arm64
host. PRIOR: BLK-008 records the same extraction hang on this Linux box
(Node 24.22, rev 1208), where the bump to >= 1.61 fixed it.
`./setup` rebuilds the browse binary when package.json or bun.lock is newer
than it (setup:383-386), and `bun add` rewrites both, so a bump cannot leave
the binary on the old revision.

COUNTER-EVIDENCE: the user's paste ends at the 90% row; the known bug hangs
after the 100% row. A network stall on the work machine stays possible; this
fix does nothing for it. Mac's Node version unknown.

BLAST RADIUS: every host whose installed gstack Playwright is < 1.60.0 and
that is not a too-new Ubuntu (macOS, Debian, Ubuntu <= 24.04).

## Fix plan (honors BDR-029: local bump before ./setup, non-fatal)

### lib/gstack-playwright.sh
1. Header comment: "OS-support bump" becomes "OS-support and
   extraction-fix bump"; add `BLK-008` stays, no new ID invented.
2. New constant after the colour constants:
       # Playwright below this hangs at browser-archive extraction on
       # Node 24.16+ (gstack issue #1703). One place for the threshold.
       _GSPW_EXTRACT_FIX_MIN="1.60.0"
3. New function `gstack_pw_version <gstack_dir>`: prints the installed
   version read from `<gstack_dir>/node_modules/playwright-core/package.json`
   (first `"version": "X.Y.Z"` line, digits and dots only), prints nothing
   when the file is unreadable or has no such line. Always returns 0.
   No pipe into `head` (SIGPIPE under the callers' pipefail): one `sed -n`
   with `p` then `q`, capture guarded with `|| true`.
4. New function `gstack_pw_extract_safe <version>`: returns 0 when
   major.minor >= the major.minor of `_GSPW_EXTRACT_FIX_MIN`, 1 when older.
   Empty or non-numeric major/minor returns 0 (unknown version: never edit
   the submodule on a guess). Integer compares only, bash 3.2-safe
   (parameter expansion, `case` for the digit check, no arrays, no `[[ =~`).
   Called only from `if` / `&&` context.
5. New function `_gspw_bump_reason <gstack_dir> <ostag>`: prints why the
   installed Playwright must be bumped, nothing when it need not. Always
   returns 0. Order:
   - ostag non-empty and `gstack_pw_supports` fails ->
     `lacks <ostag> support`
   - else version not extract-safe ->
     `<version> hangs at browser extraction (fixed in 1.60.0)` (threshold
     printed from the constant)
6. `gstack_bump_playwright_if_unsupported` (name kept: callers and T6 cite
   it) becomes:
   - `[ -d "$gstack_dir" ] || return 0` (the `/etc/os-release` test leaves;
     `gstack_pw_ostag` already prints nothing without that file)
   - `ostag="$(gstack_pw_ostag)"`, no return on empty
   - bun PATH fallback unchanged
   - info line: `checking gstack's Playwright (OS support, extraction fix)...`
   - `_gspw_bump_install` unchanged, non-zero -> return 0
   - `why="$(_gspw_bump_reason "$gstack_dir" "$ostag")"`; empty -> return 0
   - info: `gstack's Playwright $why — bumping to latest (local submodule edit)...`
   - `_gspw_bump_add_latest` unchanged, non-zero -> return 0
   - `why` recomputed; empty -> ok line `gstack Playwright bumped to
     <version> (browse binary rebuilt by ./setup)`; non-empty -> warn
     `Playwright bump left it: $why — gstack browser may stay unavailable`
   - `return 0` on every path (bare statement under inherited errexit);
     every capture guarded, no bare `&&` list as a last statement.
   Function comment updated: OS-gated no more; bumps for OS support or the
   extraction-fix floor.
7. Limits: 80 columns, <= 25 logic lines per function, <= 5 locals.
   No destructive word in the lib (existing T8 greps for rm, mv, unlink,
   truncate, rmdir, git checkout/reset/clean/stash).

### install-plugins.sh (comment only, lines 346-350)
Reword the comment above the call: the bump runs when gstack's pinned
Playwright lacks a build for this OS or is older than the extraction fix
(1.60.0), on any OS. No code change.

### lib/tests/gstack-playwright.test.sh (header says T1..T17 -> T1..T25)
Add after T17, before the final PASS line. A stub `bun` in "$tmp/stubbin"
(first on PATH inside each case's subshell): appends its arguments to
"$BUN_LOG"; on `add playwright@latest` it rewrites
`node_modules/playwright-core/package.json` in its cwd to the version in
"$BUN_ADD_SETS" when that variable is non-empty; exits 0. A helper
`mk_gstack <dir> <version> <lib text>` builds a fixture
(`node_modules/playwright-core/package.json` with `"version": "<version>"`,
`node_modules/playwright-core/lib/index.js` holding <lib text>). A helper
`run_bump <dir> <ostag> <add sets>` runs, in a subshell with the stub on
PATH and `gstack_pw_ostag() { printf '%s' "<ostag>"; }` overriding the
real one, `gstack_bump_playwright_if_unsupported <dir>` and prints
`rc=<rc>` after its output.
- T18 `gstack_pw_version`: fixture 1.58.2 -> `1.58.2`; dir without
  node_modules -> empty.
- T19 `gstack_pw_extract_safe` return codes joined in one string for
  1.58.2, 1.59.1, 1.60.0, 1.63.0, 2.0.0, "", garbage -> `1100000`.
- T20 no os-release host (ostag empty), 1.58.2, add sets 1.65.0: log holds
  `add playwright@latest`, output holds `bumped to 1.65.0`, `rc=0`.
- T21 ostag empty, 1.63.0: log holds no `add`, `rc=0`.
- T22 ostag `ubuntu24.04`, lib text holding the tag, 1.58.2, add sets
  1.65.0: add called (version reason on a supported Ubuntu).
- T23 ostag `ubuntu26.04`, lib text without the tag, 1.63.0, add sets
  empty: add called and the warn line holds `lacks ubuntu26.04 support`
  (OS reason preserved, bump that did not help is reported).
- T24 ostag empty, 1.58.2, add sets empty (bump changes nothing): warn line
  holds `hangs at browser extraction`, `rc=0`.
- T25 errexit safety: a script with `set -euo pipefail` that sources the
  lib, overrides `gstack_pw_ostag` to print nothing, puts the stub on PATH,
  calls the function as a BARE statement on a dir with no node_modules,
  then echoes REACHED -> last line `REACHED`, log holds no `add`.

## Edge cases
- `bun` absent: `_gspw_bump_install` fails both installs -> silent return 0
  (unchanged behaviour).
- macOS has no `timeout`: `_gspw_run_timeout` already runs unbounded there.
- Version line with a pre-release suffix (`1.60.0-beta`): digits-and-dots
  capture gives `1.60.0`.
- Already bumped tree (1.63.0 here): no `add`, idempotent.

## Out of scope (user decisions 2026-11-26)
No time bound on `./setup` (later, after the Mac result). No Node-version
gate. The submodule pin does not move. Not verified on the Mac: the user
runs `make plugin` there.
