# CONTRACT — gstack-playwright-lib
- date: 2026-09-13 | flow: feat | branch: feature/gstack-playwright-lib
- status: active

## REQUEST (verbatim — IMMUTABLE)

Message 1:
> l'installation de chromium, c'est une version fix ou en latest ? Il faudrait mettre en lateste, et d'ailleurs son update est pris en compt dans l'update ? quelq version a besoin gstack ? Ca serait pas plus simple d'installer perplexity a la place ?

Message 2 (after the assistant proposed fix A + fix B):
> les deux

Message 3 (answer to the scope question on fix B, after the "654 Mo orphelins"
premise was proven wrong):
> Check read-only dans doctor.sh

## CLARIFICATIONS

Q: "mettre en latest" — pin Chromium to latest?
A: Not actionable as asked. Playwright downloads the browser revision its own
   version pins (1.61.1 → chromium 1228); the CDP client is coupled to that
   build. "Latest" = track the latest Playwright, which is what BDR-029's bump
   already does. No change to the pinning mechanism is in scope.

Q: Volet B — purge the orphan Playwright revisions?
A: Superseded by evidence. `~/.cache/ms-playwright/.links/` registers THREE
   playwright installs (gstack 1.61.1 → rev 1228; gsd-pi nvm 1.61.0 → 1228;
   gsd-pi ~/.local 1.63.0 → 1243). Every directory on disk is referenced;
   zero bytes reclaimable. Playwright already GCs correctly on every
   `install` (`_deleteStaleBrowsers`, unions across all registered installs).
   User chose: read-only report in doctor.sh, NO deletion anywhere.

## ACCEPTANCE CRITERIA

1. `lib/gstack-playwright.sh` exists, is source-safe (sourcing prints nothing
   and runs no side effect), and its verb dispatcher works when executed.
   CHECK: out=$( . lib/gstack-playwright.sh; echo READY ); [ "$out" = READY ] && bash lib/gstack-playwright.sh 2>&1 | grep -q 'usage:' && echo LIB_OK
   EXPECT: LIB_OK
   EVIDENCE: MET exit=0 marker-found :: LIB_OK

2. The bump logic lives ONLY in the lib: `install-plugins.sh` no longer
   defines `gstack_bump_playwright_if_unsupported`, sources the lib instead,
   and still calls it BEFORE gstack `./setup` (BDR-029 behavior unchanged:
   OS-gated, idempotent, non-fatal).
   CHECK: grep -q '^gstack_bump_playwright_if_unsupported() {' install-plugins.sh && exit 1; grep -q 'lib/gstack-playwright.sh' install-plugins.sh || exit 1; c=$(grep -n 'gstack_bump_playwright_if_unsupported' install-plugins.sh | grep -v ':[[:space:]]*#' | tail -1 | cut -d: -f1); s=$(grep -n '&& \./setup)' install-plugins.sh | head -1 | cut -d: -f1); [ -n "$c" ] && [ -n "$s" ] && [ "$c" -lt "$s" ] && echo EXTRACT_OK
   EXPECT: EXTRACT_OK
   EVIDENCE: MET exit=0 marker-found :: EXTRACT_OK

3. `update-all.sh` delegates the gstack submodule update to the lib
   (`gstack_submodule_update_with_bump`) instead of calling
   `git submodule update --remote` bare, so the bump is re-applied after every
   successful update.
   CHECK: grep -q 'gstack_submodule_update_with_bump' update-all.sh && grep -q 'lib/gstack-playwright.sh' update-all.sh && ! grep -qE '^[[:space:]]*if git submodule update --remote skills-external/gstack' update-all.sh && echo WIRED_OK
   EXPECT: WIRED_OK
   EVIDENCE: MET exit=0 marker-found :: WIRED_OK

4. [gated 2026-09-15] `gstack_submodule_update_with_bump` NEVER modifies the
   submodule working tree. On a successful `git submodule update --remote` it
   re-applies the bump; on failure it returns non-zero, touches nothing, and
   emits git's own message plus a hint naming the local Playwright bump when
   `package.json`/`bun.lock` are the dirty files. The conflict-RECOVERY branch
   of the earlier revision (discard, retry, backup, restore) is withdrawn: it
   could leave the bump discarded and un-reapplied, regressing a working
   browser into BLK-008, which the pre-existing behavior never did.
   CHECK: sed 's/#.*//' lib/gstack-playwright.sh | grep -qE 'git [^|;]*(checkout|reset|clean|stash)' && exit 1; bash lib/tests/gstack-playwright.test.sh 2>&1 | grep -q 'update-conflict' && bash lib/tests/gstack-playwright.test.sh 2>&1 | grep -qE '^PASS=[0-9]+ FAIL=0$' && echo NONDESTRUCTIVE_OK
   EXPECT: NONDESTRUCTIVE_OK
   EVIDENCE: MET exit=0 marker-found :: NONDESTRUCTIVE_OK

5. `doctor.sh` prints a Playwright-browsers section: total cache size, one line
   per browser directory naming the registered playwright install(s) that
   reference it, plus counts of unreferenced directories and broken links.
   CHECK: bash doctor.sh 2>/dev/null | grep -qi 'playwright browsers' && bash lib/gstack-playwright.sh browsers-report | grep -qE 'chromium-[0-9]+' && bash lib/gstack-playwright.sh browsers-report | grep -qi 'unreferenced' && echo REPORT_OK
   EXPECT: REPORT_OK
   EVIDENCE: MET exit=0 marker-found :: REPORT_OK

6. The report is provably read-only: no destructive verb anywhere in the lib,
   and the cache directory listing is identical before and after a report run.
   CHECK: sed 's/#.*//' lib/gstack-playwright.sh | grep -qwE '(rm|rmdir|unlink|truncate|mv)' && exit 1; b=$(ls -la ~/.cache/ms-playwright ~/.cache/ms-playwright/.links 2>/dev/null | cksum); bash lib/gstack-playwright.sh browsers-report >/dev/null 2>&1; a=$(ls -la ~/.cache/ms-playwright ~/.cache/ms-playwright/.links 2>/dev/null | cksum); [ "$b" = "$a" ] && echo READONLY_OK
   EXPECT: READONLY_OK
   EVIDENCE: MET exit=0 marker-found :: READONLY_OK

7. `lib/tests/gstack-playwright.test.sh` exists, passes, and covers at least:
   bump skipped when the OS tag is already supported; bump fired when it is
   not; submodule-update conflict recovery; browsers-report on a fixture cache
   holding a referenced revision, an unreferenced one and a broken link.
   CHECK: bash lib/tests/gstack-playwright.test.sh | tail -1 | grep -qE '^PASS=[0-9]+ FAIL=0$' && echo TESTS_OK
   EXPECT: TESTS_OK
   EVIDENCE: MET exit=0 marker-found :: TESTS_OK

8. shellcheck clean on every touched shell file.
   CHECK: shellcheck lib/gstack-playwright.sh lib/tests/gstack-playwright.test.sh install-plugins.sh update-all.sh doctor.sh >/dev/null 2>&1 && echo SHELLCHECK_OK
   EXPECT: SHELLCHECK_OK
   EVIDENCE: MET exit=0 marker-found :: SHELLCHECK_OK

9. [gated 2026-09-15] (judgement) No new dependency; the report degrades
   silently when `~/.cache/ms-playwright` is absent, when its `.links`
   directory is absent, when `PLAYWRIGHT_BROWSERS_PATH` is `0` or not a
   directory, or when no playwright install is registered — doctor must stay
   green on a machine that never installed a browser. The lib's printers are
   named `_gspw_ok`/`_gspw_warn`/`_gspw_info` and it defines NO bare
   `ok`/`warn`/`info`/`pass`/`fail`: doctor.sh sources the lib before every
   check, so bare names would override its own printers and silently
   disconnect its `ERRORS`/`WARNS` counters.

## FILE SCOPE

- lib/gstack-playwright.sh            (new)
- lib/tests/gstack-playwright.test.sh (new)
- install-plugins.sh                  (remove inline fn, source + call lib)
- update-all.sh                       (call bump + conflict recovery)
- doctor.sh                           (new read-only report section)

Out of scope: the gstack submodule itself, the pinning mechanism, any
deletion of cached browsers, the `GSTACK_CHROMIUM_NO_SANDBOX` layer
(LRN-040 layer 2, unchanged).
