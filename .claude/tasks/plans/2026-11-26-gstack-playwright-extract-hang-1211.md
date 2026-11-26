# PLAN — bugfix gstack Playwright extraction hang (2026-11-26, revised)

## Diagnosis
BUG: on a macOS arm64 work machine, `make install` / `make plugin` freezes in
gstack `./setup` at "Installing Playwright Chromium..." (chromium v1208,
Chrome for Testing 145.0.7632.6). Each run first prints "Removing unused
browser at .../chromium-1208": the previous install never completed.

ROOT CAUSE (leading hypothesis, NOT confirmed on the Mac): the gstack
submodule (pinned 11de390) pins `playwright ^1.58.2`. Playwright < 1.60.0
hangs forever at archive extraction on Node 24.16.0+ (yauzl stream
regression, upstream gstack issue #1703, fixed in Playwright 1.60.0). Our
installer already bumps gstack's Playwright before `./setup`
(`gstack_bump_playwright_if_unsupported`, lib/gstack-playwright.sh:108),
but only for a too-new Ubuntu: on macOS the function returns at once
(`[ -r /etc/os-release ] || return 0`, then empty ostag).

EVIDENCE: issue #1703 names the same revision and symptom on a macOS arm64
host. PRIOR: BLK-008 is consistent with it (same rev 1208 hang at
extraction on Linux, gone after the bump; no Node version recorded).
`./setup` rebuilds the browse binary when package.json or bun.lock is newer
than it (setup:383-386); `bun add` rewrites both.

COUNTER-EVIDENCE: the user's paste ends at the 90% row; the known bug hangs
after the 100% row. A network stall stays possible; this fix does nothing
for it. Mac's Node version unknown.

WHY NOT the upstream fix: upstream main (v1.104, ^1.65) is 1100 commits
ahead, removed the `cso` and `investigate` skills our doctrine routes to,
and the first upstream commit raising the pin (v1.87.5) changes 1935 files.
Moving the submodule pointer is a migration, tracked apart.

BLAST RADIUS: every host whose installed gstack Playwright is < 1.60.0
(macOS, Debian, Ubuntu <= 24.04) now gets the local bump. Consequence,
accepted (BDR-029, BDR-088): package.json and bun.lock stay locally modified
in the submodule there, so `git submodule update --remote` is refused on
those hosts until the user discards that edit by hand. Until now only
too-new Ubuntu hosts were in that state.

## Fix plan (honors BDR-029: local bump before ./setup, non-fatal;
## honors BDR-088: the lib never touches the submodule tree beyond the bump)

### lib/gstack-playwright.sh
1. Header comment, lines 3-4 become:
       # lib/gstack-playwright.sh — gstack's Playwright: local bump (OS
       # support, extraction-fix floor) + read-only browser-cache report.
   Lines 17-18 keep their BDR/BLK/LRN references unchanged.
2. New constant right after the `_GSPW_NC` line:
       # Playwright below this hangs at browser-archive extraction on
       # Node 24.16+ (gstack issue #1703). The one place for the threshold.
       _GSPW_EXTRACT_FIX_MIN="1.60.0"
3. New function, in the "OS support" section after `gstack_pw_supports`:
       # gstack_pw_version <playwright_core_path> — installed version
       # ("1.58.2"), empty when unreadable. Always returns 0.
       gstack_pw_version() {
         local v
         v=$(awk -F'"' '$2 == "version" { print $4; exit }' \
           "$1/package.json" 2>/dev/null) || true
         printf '%s' "$v"
         return 0
       }
   `_gspw_install_label` (lib:207-213) drops its own awk and calls it:
       version=$(gstack_pw_version "$pw_path")
   keeping the `${version:-?}` fallback. One reader for that field.
4. New function after it, exact text:
       # gstack_pw_extract_safe <version> — 0 when major.minor is at or
       # above _GSPW_EXTRACT_FIX_MIN, 1 when older. Empty, dotless or
       # non-numeric -> 0: never edit the submodule on a guess. Called
       # only from an `if` / `&&` context.
       gstack_pw_extract_safe() {
         local maj mnr min_maj min_mnr
         maj="${1%%.*}"; mnr="${1#*.}"; mnr="${mnr%%.*}"
         min_maj="${_GSPW_EXTRACT_FIX_MIN%%.*}"
         min_mnr="${_GSPW_EXTRACT_FIX_MIN#*.}"; min_mnr="${min_mnr%%.*}"
         case "$1" in *.*) ;; *) return 0 ;; esac
         case "$maj" in ''|*[!0-9]*) return 0 ;; esac
         case "$mnr" in ''|*[!0-9]*) return 0 ;; esac
         [ "$maj" -gt "$min_maj" ] && return 0
         [ "$maj" -lt "$min_maj" ] && return 1
         [ "$mnr" -ge "$min_mnr" ]
       }
   bash 3.2 and BSD userland: no arrays, no `[[ =~ ]]`, no `sort -V`.
5. New function, exact text:
       # _gspw_bump_reason <gstack_dir> <ostag> — why the installed
       # Playwright must be bumped; prints nothing when it need not.
       # Always returns 0.
       _gspw_bump_reason() {
         local pw="$1/node_modules/playwright-core" v
         if [ -n "$2" ] && ! gstack_pw_supports "$pw/lib" "$2"; then
           printf 'lacks %s support' "$2"
           return 0
         fi
         v="$(gstack_pw_version "$pw")"
         if ! gstack_pw_extract_safe "$v"; then
           printf '%s hangs at browser extraction (fixed in %s)' \
             "$v" "$_GSPW_EXTRACT_FIX_MIN"
         fi
         return 0
       }
6. New function:
       # _gspw_bump_report <gstack_dir> <ostag> — outcome line after a
       # bump. Always returns 0.
       _gspw_bump_report() {
         local why v
         why="$(_gspw_bump_reason "$1" "$2")"
         v="$(gstack_pw_version "$1/node_modules/playwright-core")"
         if [ -z "$why" ]; then
           _gspw_ok "gstack Playwright bumped to ${v:-?}"
           return 0
         fi
         _gspw_warn "Playwright bump left it: $why — gstack browser may \
       stay unavailable"
         case "$why" in *hangs*)
           _gspw_warn "./setup is expected to freeze at 'Installing \
       Playwright Chromium' — Ctrl-C it, check the npm registry access, \
       re-run: make plugin" ;;
         esac
         return 0
       }
   The freeze warning prints only when the remaining reason is the version
   one (the OS reason makes ./setup fail fast instead, BLK-008).
7. `gstack_bump_playwright_if_unsupported` (name kept: callers and T6 cite
   it) becomes exactly this flow:
       gstack_bump_playwright_if_unsupported() {
         local gstack_dir="$1" ostag why v rc=0
         [ -d "$gstack_dir" ] || return 0
         ostag="$(gstack_pw_ostag)"
         if ! command -v bun >/dev/null 2>&1; then
           export PATH="$HOME/.bun/bin:$PATH"
         fi
         _gspw_info "checking gstack's Playwright (OS support, \
       extraction fix)..."
         _gspw_bump_install "$gstack_dir" || rc=$?
         if [ "$rc" -eq 1 ]; then
           _gspw_warn "bun install failed in gstack — Playwright not \
       checked (run 'bun install' in $gstack_dir to see why)"
         fi
         [ "$rc" -eq 0 ] || return 0
         why="$(_gspw_bump_reason "$gstack_dir" "$ostag")"
         if [ -z "$why" ]; then
           v="$(gstack_pw_version "$gstack_dir/node_modules/playwright-core")"
           _gspw_info "gstack Playwright ${v:-(version unreadable)}: \
       no bump needed"
           return 0
         fi
         _gspw_info "gstack's Playwright $why — bumping to latest (local \
       submodule edit)..."
         rc=0
         _gspw_bump_add_latest "$gstack_dir" || rc=$?
         [ "$rc" -eq 0 ] || return 0
         _gspw_bump_report "$gstack_dir" "$ostag"
         return 0
       }
   Its header comment: bumps gstack's pinned Playwright when it lacks a
   build for this OS (BDR-029) or is older than the extraction fix, on any
   OS; idempotent, non-fatal, `return 0` on every path.
   `_gspw_bump_install` and `_gspw_bump_add_latest`: code NOT modified. One
   comment-only edit: in the `_gspw_bump_install` header, "1 give up
   silently (both installs failed, matches the pre-existing silent
   behavior)" becomes "1 both installs failed (the caller warns)".
8. Limits: 80 columns, <= 25 logic lines per function, <= 5 locals.
   Every capture guarded; no bare `&&` list as a function's last statement.
   No destructive word in the lib (existing T8 greps for rm, mv, unlink,
   truncate, rmdir, git checkout/reset/clean/stash, comments stripped).

### install-plugins.sh (comment only, lines 346-350)
Reword the comment above the call: the bump runs when gstack's pinned
Playwright lacks a build for this OS or is older than the extraction fix
(1.60.0), on any OS; it leaves package.json and bun.lock modified in the
submodule, which blocks a later `git submodule update --remote` until that
edit is discarded by hand (BDR-029, BDR-088). No code change.

### lib/tests/gstack-playwright.test.sh (header "T1..T17" -> "T1..T27")
Add after T17, before the final PASS line.
Portability (the suite also runs on macOS, BSD userland): the stub and the
helpers write files whole with `printf` or `cat` heredocs, no `sed -i`, no
GNU-only flag; the stub reads its variables as `${VAR:-}`.
Stub: `"$tmp/stubbin/bun"`, an executable script. It appends "$*" as one
line to "$BUN_LOG". On `add playwright@latest`, in its cwd: when
"$BUN_ADD_SETS" is non-empty it rewrites
`node_modules/playwright-core/package.json` to that version, in the SAME
multi-line layout as mk_gstack (the awk reader needs `"version"` first on
its own line); when
"$BUN_ADD_LIB" is non-empty it writes that text to
`node_modules/playwright-core/lib/index.js`. Exits 0, except: when
"$BUN_FAIL_INSTALL" is `1` and the first argument is `install`, exits 1.
All four variables are EXPORTED by the helper before the call
(`_gspw_run_timeout` runs bun as a separate process).
Helper `mk_gstack <dir> <version> <lib text>`: writes
`<dir>/node_modules/playwright-core/package.json` as
`{ "name": "playwright-core", "version": "<version>" }` on separate lines
(one `"version": "..."` line) and `.../lib/index.js` with <lib text>.
Helper `run_bump <dir> <ostag> <add sets> [add lib] [fail install]`: in a
subshell, sets BUN_ADD_SETS="$3", BUN_ADD_LIB="${4:-}",
BUN_FAIL_INSTALL="${5:-}" (set on every call, so nothing leaks between
cases),
truncates "$BUN_LOG" (`: > "$BUN_LOG"`), puts the stub dir first on PATH,
exports the variables, overrides the real one with exactly
`_t_os="$2"; gstack_pw_ostag() { printf '%s' "$_t_os"; }` (a distinct
variable name: the function under test declares a local `ostag`, and
`"$2"` inside the override would be its own unset positional under the
suite's `set -u`),
calls `gstack_bump_playwright_if_unsupported <dir>`, then prints `rc=<rc>`.
- T18 `gstack_pw_version`: fixture 1.58.2 -> `1.58.2`; a dir without
  package.json -> empty.
- T19 `gstack_pw_extract_safe` return codes joined for 1.58.2, 1.59.1,
  1.60.0, 1.63.0, 2.0.0, "", garbage -> `1100000`.
- T20 empty-ostag path (what a host without /etc/os-release yields; the
  real file absence is covered by the Mac run), 1.58.2, add sets 1.65.0: log holds
  `add playwright@latest`; output holds `bumped to 1.65.0`; `rc=0`.
- T21 ostag empty, 1.63.0: log holds `install` AND no `add`; output holds
  `1.63.0: no bump needed`; `rc=0`.
- T22 ostag `ubuntu24.04`, lib text holding that tag, 1.58.2, add sets
  1.65.0: log holds `add` (version reason on a supported Ubuntu).
- T23 ostag `ubuntu26.04`, lib text without the tag, 1.63.0, add sets
  empty, add lib empty: log holds `add`; output holds
  `bump left it: lacks ubuntu26.04 support`; output does NOT hold
  `expected to freeze`.
- T24 ostag `ubuntu26.04`, lib text without the tag, 1.63.0, add lib
  `supports ubuntu26.04`: log holds `add`; output holds
  `bumped to 1.63.0` (the original BDR-029 success path).
- T25 ostag empty, 1.58.2, add sets empty: output holds
  `bump left it: 1.58.2 hangs at browser extraction` AND
  `expected to freeze`; `rc=0`.
- T26 ostag empty, 1.58.2, fail install `1` (5th run_bump argument): output holds
  `bun install failed in gstack`; log holds no `add`; `rc=0`.
- T27 errexit safety, one script with `set -euo pipefail` that sources the
  lib, overrides `gstack_pw_ostag` to print nothing, puts the stub on PATH
  with the variables exported and BUN_FAIL_INSTALL set empty, then calls the function as a BARE statement
  three times, echoing a marker after each: on a dir with no node_modules
  (`REACHED1`), on a 1.58.2 fixture with add sets 1.65.0 (`REACHED2`), on a
  1.58.2 fixture with add sets empty (`REACHED3`). Expect all three markers
  in the output and `add` in the log.

## Edge cases
- `bun` absent: both installs fail -> the new warn line, return 0.
- macOS has no `timeout`: `_gspw_run_timeout` runs the bun calls unbounded
  and silent there (accepted risk: a new possible freeze point before
  `./setup`; the "checking" line names the step).
- Already bumped tree (1.63.0 on this machine): no `add`, one info line.
- `bun add` exiting non-zero after writing node_modules only: the ok line
  no longer claims a rebuild.

## Declined (with reason)
- Manual-discard hint in update-all.sh when the update is refused
  (robustness MAJOR): it would hand out the command that moves gstack to
  an upstream that dropped `cso` and `investigate`. Goes with the gstack
  migration (TODO), not this fix. The consequence is named in BLAST RADIUS
  and in the install-plugins.sh comment.

## Out of scope (user decisions 2026-11-26)
No time bound on `./setup`. No Node-version gate. The submodule pointer
does not move. Not verified on the Mac: the user runs the suite and
`make plugin` there.

## Round 2 — exact pinned bump version (security gate MEDIUM, user-gated)
The bump must install an exact, reviewed Playwright version, never `latest`.

### lib/gstack-playwright.sh
1. New constant right after `_GSPW_EXTRACT_FIX_MIN`:
       # The exact Playwright the bump installs. Reviewed by hand: raise it
       # here, never `latest` (an unreviewed release would reach every
       # machine). 1.65.0 = the version upstream gstack pins.
       _GSPW_BUMP_VERSION="1.65.0"
2. `_gspw_bump_add_latest` is renamed `_gspw_bump_add` (definition, its
   header comment, the one call site). Its bun call becomes
       _gspw_run_timeout "$dir" bun add --exact \
         "playwright@$_GSPW_BUMP_VERSION" || rc=$?
   and its timeout warning becomes
   `bun add playwright@$_GSPW_BUMP_VERSION timed out — skipping Playwright bump`.
   Return codes unchanged (0 ran, 2 timed out).
3. In `gstack_bump_playwright_if_unsupported`, the info line
   `... — bumping to latest (local submodule edit)...` becomes
   `... — bumping to $_GSPW_BUMP_VERSION (local submodule edit)...`.
4. `gstack_pw_extract_safe`: a version field longer than 6 digits makes `[`
   fail and the function report "unsafe", against its own rule. The two
   digit checks become
       case "$maj" in ''|*[!0-9]*|???????*) return 0 ;; esac
       case "$mnr" in ''|*[!0-9]*|???????*) return 0 ;; esac
5. Any other mention of "latest" in the lib's comments about the bump is
   reworded to the pinned version (grep the file for `latest`).

### install-plugins.sh
Comment above the call: no "latest" wording if present; otherwise untouched.

### lib/tests/gstack-playwright.test.sh
- The stub recognises the bump as: first argument `add` AND some argument
  starting with `playwright@` (it must not depend on the version).
- Every expectation `add playwright@latest` becomes
  `add --exact playwright@1.65.0` (T20 at least; the other cases that only
  grep `add` stay).
- T19 gains one input: `99999999999999999999999.1` -> 0; the expected
  string becomes `11000000`.
- New T28: no line of the lib, comments stripped (same `sed 's/#.*//'`
  producer-out-of-the-pipe form as T8), matches `playwright@latest`.
- Header "T1..T27" -> "T1..T28".
