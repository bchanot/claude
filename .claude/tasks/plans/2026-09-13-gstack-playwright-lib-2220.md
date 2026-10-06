# PLAN — gstack-playwright-lib (feat) — REVISION 3

Contract: `.claude/tasks/contracts/2026-09-13-gstack-playwright-lib-2220.md`
Revision 3 (2026-09-15). Rev 1 → 3-lens challenge → rev 2 → confirmation pass
→ rev 3. The conflict-RECOVERY branch is WITHDRAWN at the human gate: it
concentrated 3 BLOCKERs and 4 MAJORs, and its worst case regressed a working
browser into BLK-008, which the pre-existing behavior never did.

## Context

- Chromium is not an apt package. It is the browser revision pinned by the
  installed Playwright (`gstack/setup:483`). gstack: playwright 1.61.1 →
  chromium rev 1228 (`Chrome for Testing 149`).
- `~/.cache/ms-playwright/.links/` registers 3 playwright installs: gstack
  1.61.1 (1228), gsd-pi nvm 1.61.0 (1228), gsd-pi ~/.local 1.63.0 (1243).
  Every dir on disk is referenced → 0 bytes reclaimable. Playwright already
  prunes correctly on every `install` (`_deleteStaleBrowsers`). No pruner is
  written here.
- The gstack submodule is intentionally dirty: `package.json` + `bun.lock`
  carry the BDR-029 bump; `.gitmodules` sets `ignore = dirty`. It also carries
  an untracked `?? bin/bin`.
- `update-all.sh:87` calls `git submodule update --remote` bare, swallows
  stderr, and never re-applies the bump afterwards. THAT is the gap.

## Hard constraints the code must respect

**Inherited errexit.** All three callers run `set -euo pipefail` and source
the lib. `gstack_bump_playwright_if_unsupported` and `gstack_browsers_report`
are called as bare statements, so they MUST `return 0` on every path and every
capture inside them takes `|| true`.
`gstack_submodule_update_with_bump` is the ONE exception: it returns non-zero
on failure and is therefore called ONLY as an `if` condition, keeping
`update-all.sh:87`'s existing `if / else warn` shape. An offline update stays
non-fatal, exactly as today.

**Printer names.** The lib defines `_gspw_ok`, `_gspw_warn`, `_gspw_info` and
NEVER a bare `ok`/`warn`/`info`/`pass`/`fail`. `doctor.sh:22` sources the lib
before every check, so bare names would override `doctor.sh:12-15` and
silently disconnect its `ERRORS`/`WARNS` counters.

**No destructive command in the lib, at all.** No `rm`, `rmdir`, `unlink`,
`truncate`, `mv`, and no `git checkout`/`reset`/`clean`/`stash`. Contract
criteria 4 and 6 both grep for this.

**macOS-safe.** No `timeout` without a `command -v` guard (absent from stock
macOS), no `readlink -f` (absent before Monterey 12.3), no `md5sum`, no
`sed -i` without a suffix, no bash-4-only expansions (`${x,,}`), no `grep -P`.

## Files

1. `lib/gstack-playwright.sh` — NEW. Sourceable lib + verb dispatcher. No
   `set -euo pipefail` at top level (mirrors `lib/detect-plugins.sh`).
   Dispatcher guarded by `[ "${BASH_SOURCE[0]}" = "${0}" ]`, exposing
   `browsers-report` ONLY. Any other argument → `usage:` on stderr, exit 2.
   The write functions stay sourced-only: a CLI verb would expose
   `bun add playwright@latest` as a command-line entry point.

   - `_gspw_ok` / `_gspw_warn` / `_gspw_info <msg>` — fixed-prefix printers.
   - `gstack_pw_ostag [os_release_path]` — prints `ubuntu<VERSION_ID>` for
     Ubuntu, nothing otherwise. The capture takes `|| true`: the moved line
     exits 1 on every non-Ubuntu host and would abort the caller under
     inherited errexit. `return 0` always.
   - `gstack_pw_supports <playwright_core_lib_dir> <ostag>` — 0/1 by grep.
   - `gstack_bump_playwright_if_unsupported <gstack_dir>` — BDR-029 logic,
     parameterized. Prepends `$HOME/.bun/bin` to PATH when `bun` is not
     resolvable (LRN-036). Wraps ALL THREE bun invocations
     (`bun install --frozen-lockfile`, the `bun install` fallback,
     `bun add playwright@latest`) in `timeout 300` when `command -v timeout`
     succeeds, plain otherwise. Exit 124 from any of them → `_gspw_warn` and
     `return 0` WITHOUT attempting the bump: a TERM'd install leaves
     `node_modules` half-written, and the support grep would then read a
     truncated tree. One `_gspw_info` line before the network work so a
     stalled registry is visible. `return 0` on every path (BDR-029
     non-fatal).
   - `gstack_submodule_update_with_bump <repo> [sub_path]`:
     1. `git -C "$repo" submodule update --remote "$sub"`, stderr captured.
     2. exit 0 → `gstack_bump_playwright_if_unsupported "$repo/$sub"` →
        `return 0`.
     3. exit != 0 → `_gspw_warn` with git's own message, verbatim and
        unparsed. Then, when `git -C "$sub" status --porcelain --
        package.json bun.lock` is non-empty, one extra `_gspw_info` hint line
        naming the local Playwright bump and pointing at `make plugin`.
        `return 1`. NOTHING in the working tree is touched.
     No locale pin is needed: git's message is displayed, never parsed for a
     decision. The hint is advisory, so its constant-true condition is
     correct here, unlike the withdrawn recovery branch where it gated a
     destructive step.
   - `_gspw_browser_referenced <playwright_core_path> <dir_name>` — does that
     install require this cache directory? Splits `<dir_name>` into name +
     revision on the LAST `-`, then normalizes `_` → `-` on the name
     (Playwright writes `chromium_headless_shell-1228` while `browsers.json`
     says `chromium-headless-shell`; without this, two live directories are
     reported unreferenced forever). Matches the base `revision` OR any value
     under that browser's `revisionOverrides` (webkit and ffmpeg carry them
     for mac and debian11 and ubuntu20.04 hosts). awk only: no jq, no
     python3, no fallback ladder.
   - `_gspw_install_label <playwright_core_path>` — `<dir-before-node_modules>
     <version>`, e.g. `gstack 1.61.1`, `gsd-pi 1.63.0`.
   - `gstack_browsers_report [cache_dir]` — read-only. Resolves the cache as
     `${1:-${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}}`; the
     documented value `0` means "bundle into node_modules", so `0` and any
     non-directory degrade to the silent no-cache path. Prints the header
     `Playwright browsers`, the total from `du -sh … || true`, one line per
     cache dir matching `*-<digits>` with the installs requiring it, then
     `<N> unreferenced, <M> broken link(s)`. When N or M > 0, one
     `_gspw_warn` naming them and the remedy, phrased without the words `rm`
     or `mv` (criterion 6 word-greps the source): "re-run `playwright
     install`, which prunes stale revisions". A dir whose NAME is listed by
     some install but at another revision counts as `unknown revision`, not
     unreferenced. `return 0` on every path.

2. `install-plugins.sh` — delete the inline function (294-321), source the lib
   next to detect-plugins (line 30), call site at ~370 becomes
   `gstack_bump_playwright_if_unsupported "$GSTACK_DIR"`.

3. `update-all.sh` — source the lib next to detect-plugins (line 19). Line 87
   becomes `if gstack_submodule_update_with_bump "$REPO"; then` and the
   existing `else warn …` arm is KEPT verbatim. No other structural change.

4. `doctor.sh` — source the lib next to detect-plugins (line 22). Add its own
   `── Playwright browsers ──` section (NOT nested under gstack: 2 of the 3
   registered installs are gsd-pi), called as `gstack_browsers_report || true`.

5. `lib/tests/gstack-playwright.test.sh` — NEW, auto-globbed by `make test`.

## Edge cases

- Every public function except the update returns 0 under the callers'
  `set -euo pipefail`, including the all-zero-counts case, which is this
  machine's nominal state and would otherwise kill `doctor.sh` before its
  summary and take `update-all.sh:519` down with it.
- `.links` entry whose target is gone or whose `browsers.json` is unreadable
  → counted as a broken link, never dereferenced further.
- Two installs of the same tool at different versions → both labels listed.
- gstack submodule absent → bump and update both no-op 0.
- Sourcing the lib prints nothing and does not change the caller's options.

## Tests (`lib/tests/gstack-playwright.test.sh`)

Shape of `lib/tests/fast-libs.test.sh` (`check` helper, `PASS=n FAIL=n` last
line, `mktemp -d` + trap). git 2.53 defaults `protocol.file` to `user`, which
blocks submodule clone and fetch. The fixture git calls are not enough: the
`git submodule update --remote` under test runs INSIDE the lib, in a fresh
process. So the test exports, for the whole test process,
`GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.file.allow
GIT_CONFIG_VALUE_0=always`, which the lib's own git inherits. Fixtures use
`git init -b main` with `submodule.<name>.branch = main` set explicitly, so
`--remote` resolves the way production does.

- `T1-ostag-ubuntu` / `T2-ostag-other`: fixture os-release files.
- `T3-errexit-safe`: the bump called as a bare statement under
  `set -euo pipefail` with a non-Ubuntu os-release → the script reaches the
  next line. Regression test for the latent abort.
- `T4-supports-hit` / `T5-supports-miss`: fixture lib dir with and without the
  tag. Proves idempotence both ways without invoking bun.
- `T6-update-success-bumps`: fixture superproject + submodule, an upstream
  commit, bump stubbed by redefining it after sourcing → update succeeds, the
  stub ran once, returns 0.
- `T7-update-conflict-nondestructive`: local edit to the submodule's
  `package.json` plus a conflicting upstream commit → returns non-zero, BOTH
  bump-owned files are byte-identical to before the call, and the hint line
  was printed. Carries the literal `update-conflict` (contract criterion 4).
- `T8-no-destructive-command`: greps the lib source for `git
  checkout|reset|clean|stash` and for `rm|rmdir|unlink|truncate|mv` outside
  comments. Stronger than criterion 6 alone.
- `T9-report-referenced`, `T10-report-underscore-dir`
  (`chromium_headless_shell-1228` against a `chromium-headless-shell` entry),
  `T11-report-unreferenced`, `T12-report-broken-link`,
  `T13-report-revision-override`: fixture cache + `.links` → fixture
  playwright-core dirs with hand-written `browsers.json`.
- `T14-report-zero-counts-exit-0`: everything referenced → exit 0. The nominal
  case, not covered by the absent-dir case.
- `T15-report-no-cache` / `T16-report-browsers-path-zero`: exit 0, nothing on
  stderr.
- `T17-source-safe`: sourcing emits nothing.

## Disposition (STEP 0.6)

- honors **BDR-029** by keeping the bump OS-gated, idempotent, non-fatal, and
  by closing its stated caveat: the bump is now re-applied after every
  successful update, not only at the next `make plugin`.
- honors **LRN-024** by extracting a helper and refactoring the existing
  caller before adding the other callers. Deviations from "code MOVED not
  changed" are named: `|| true` on the ostag capture (a latent abort on every
  non-Ubuntu host, reproduced), and the `timeout` guard.
- honors **LRN-070** by never touching the submodule working tree at all. The
  revision that did (discard, retry, restore) was withdrawn at the gate.
- honors **LRN-071** (recurrent 3x) by returning the update's real status, not
  a non-fatal helper's 0.
- honors **LRN-040** by touching layer 1 only; `GSTACK_CHROMIUM_NO_SANDBOX`
  is untouched.
- honors **LRN-085** by keeping the update idempotent, presence-guarded, no
  `--force`.
- honors **LRN-036** by putting `$HOME/.bun/bin` on PATH inside the lib.
- honors **LRN-002** by grepping the moved function name repo-wide, readers
  included.
- **LRN-038** already seen: the host-platform override is a dead end.
- BDR-029's reference line (`decisions.md:544`) and BLK-008's caveat
  (`blockers.md:118`) describe behavior this plan changes. Registries are
  append-only, so the plan does NOT edit them: the /feat CAPITALIZE step
  owns the superseding entry.
