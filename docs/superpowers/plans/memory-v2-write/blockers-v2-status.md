---
format: 2
type: blockers_registry
entry_prefix: BLK
---

# Status parser fixture: BLK-032..034 as written 2026-10-27 (false-open
# before phase 4a), BLK-008 compound (frozen snapshot), BLK-040..042 shapes.

## BLK-008 — gstack ./setup fails on Ubuntu 26.04 — Playwright chromium unsupported

- **Date**: 2026-06-23
- **Friction**: fresh Ubuntu 26.04, `make install` / `make plugin` → "Failed to install browsers / ERROR: Playwright does not support chromium on ubuntu26.04-x64" → "GStack ./setup failed". Non-fatal in our wrapper (warn only) but gstack's browser (`/browse`, `/qa`, design screenshots) is silently dead once gstack is enabled.
- **Real cause**: Playwright 1.58.2 (pinned in the gstack submodule) registry lists `ubuntu20.04/22.04/24.04` only; 26.04 released later → not in list → `getHostPlatform` errors. Pure OS-newness, not an install bug.
- **Solution**: gated `export PLAYWRIGHT_HOST_PLATFORM_OVERRIDE=ubuntu24.04-x64` (ubuntu >24.04 only) before gstack setup + persisted to `.bashrc` for runtime. Playwright then pulls a Chrome-for-Testing fallback build for ubuntu24.04. Verified on 26.04: `ldd` resolves all libs + real headless render OK.
- **Status**: resolved (commit 211c7d4). Residual: exact rev 1208 launch not in-session-tested (sandbox download hung at extraction); proved via sibling rev 1228 same-platform CfT build. Confirm on next real `make plugin`. Proper upstream fix = gstack bumps Playwright to a version that lists ubuntu26.04. See [[LRN-038]].

- **2026-06-23 UPDATE — Solution REVERTED, status downgraded to UPSTREAM/open** (commit b9c3937): the `PLAYWRIGHT_HOST_PLATFORM_OVERRIDE` solution above does NOT work on 26.04. The fallback build downloads to 100% then HANGS at extraction (chrome binary never appears, no headless-shell download starts; reproduced on real machine + sandbox) → turned a 0.5s fast-fail into an install-blocking hang (user Ctrl+C). Reverted to the fast-fail (non-fatal; gstack OFF by default, browser only for /browse,/qa,screenshots). The earlier "verified ldd + headless render" was an isolated test on a sibling already-extracted build (rev 1228) — it masked the rev-1208 install-path hang. **Real fix = upstream**: gstack bumps Playwright to a version that lists ubuntu26.04. Until then gstack's browser is unavailable on 26.04, install completes cleanly. See [[LRN-038]] correction.

- **2026-06-23 FINAL — RESOLVED** (commit 3b8ffb1): gstack browser now works on Ubuntu 26.04. Two layers fixed: (1) bumped gstack's pinned Playwright 1.58.2 → 1.61 (`bun add playwright@latest` in the submodule; 1.61 ships a native ubuntu26.04 build — chromium rev 1228), automated in the installer (`gstack_bump_playwright_if_unsupported`, idempotent, OS-gated); (2) `GSTACK_CHROMIUM_NO_SANDBOX=1` to work around the AppArmor userns restriction (`sysctl kernel.apparmor_restrict_unprivileged_userns=1`), persisted to `.bashrc` + installer Step 9 (sysctl-gated). Verified end-to-end: `browse goto https://example.com` → "Navigated (200)". Caveat: the Playwright bump is a local submodule edit, reset by `git submodule update`, re-applied by the next install. See [[BDR-029]], [[LRN-040]].

---

## BLK-032 — Main loop pinned on Fable in long sessions: session model Fable 1M + downgrade cap 120k + prompt rule `plan` → inline code on Fable xhigh [resolved]
- **Cause**: `~/.claude/settings.json` `"model": "claude-fable-5-1[1m]"` (every session starts on Fable); model-router never moves main above the session model, moves DOWN only under `downgradeMaxTokens` 120000 (LRN-204 cold read) → a long session (faunosteo R4.x, context > 120k) never reaches `implement`/sonnet; prompt rule `(plan|design|architecture…)` → phase plan = best/xhigh each turn ("plan §B.1.7"). No doctrine ceiling: CLAUDE.md allows inline work "doable in a few tool calls", BDR-115 "pin = default, never ceiling".
- **User policy 2026-10-19**: session model Opus 5.5; sonnet writes, opus decides what to write; Fable only for orchestrator reflection/plans and the important audits (security, functional), other judges opus. → next `/feat`: settings model, `judge` split, ceiling rule in CLAUDE.md, BDR superseding part of BDR-066 / BDR-115. Links [[BDR-066]], [[BDR-107]], [[BDR-115]], [[LRN-204]].

- **Solution (2026-10-23)**: feat A+B (BDR-123) + feat C 786ee13 (feature/router-keyword-cap): keyword prompt rules, `ultrathink` floor, derived `orchestrate` dispatch write effort-only routes (`effortRoute`, `belowRun` pattern) → never lift main above session model; held best-tier run keeps its model (per-axis fall-through); `mainModelSlot` drops `turnFloor`. Fable on main only via skill row, `route` tool, `/route`. Docs d2d590f. Links [[LRN-226]], [[EVAL-048]].

## BLK-033 — Guardrails residuals: probe trusted plan `supabase.url`, redirects free of budget, unread bodies read CLOSED; rules 5 FP / 7 misses [resolved]
- **Friction**: GATE 2 of the a11y split (f586304) left a MEDIUM + 3 LOW on probe.py, opus review left Minors on the rules. Parked in TODO, fixed via `/bugfix` 2026-10-20/21.
- **Cause**: `supabase.url` read from the plan w/o `_http_url` → planted SUPABASE_URL would receive GUARDRAILS_ANON_KEY / JWT2, `file://` read CLOSED; `_SameHost` redirector followed hops w/o charging `session.budget`; `_rows_state` collapsed non-200 / empty / >1 MB / non-JSON into CLOSED (unobserved = CLOSED, breaks LRN-220); plan r2 mapped budget exhaustion on `str(URLError)`, which wraps the reason → never matched. Rules: SENSITIVE_KEY on metadata names (`token_type`, `has_password`), 403 on first map candidate stopped the walk, hydrated scan read whole route file, NOSQL `$where` fired on GraphQL `_bool_exp`; misses: Go backtick Sprintf, `rf`/triple-quoted f-strings, `sql|db|trx.raw`, empty `.select()`, multi-line hidden input, Rust `{}` shell arg, `"sources"` map head.
- **Solution**: 5a98c2c (`_BudgetExhausted(URLError)` + `BUDGET_EXHAUSTED` constant, `_SameHost(session)` charges per hop, `_rows_state` rows|empty|unreadable → SKIPPED, `_map_outcome` full candidate walk, `data:` OPEN w/o decoding, `printable` on remote strings, `_safe_text` in scanner, rule fixes + mutant per language variant) + 633faa2 (checks.md: `IN (…)` placeholder list flagged, judged by hand). Plan r3 after 2 challenge rounds, contract 22 oracles MET, verifier CONFORME, auditor PASS. Suites probe 84, scan 241.
- **Residual** (LOW, parked in TODO): table names not `IDENT.fullmatch`-checked per table (`/` → path walk on the approved host); `printable` lets Unicode bidi/format controls through. Links [[LRN-219]], [[LRN-220]], [[LRN-222]], [[LRN-223]].

## BLK-034 — mods.test.sh red on CLI 2.1.306: whole-output `warning` grep caught the advisory plugin-directory section [resolved]
- **Friction**: `make test suite=lib/tests/mods.test.sh` → `FAIL model-router: validate printed a warning`, pre-existing on develop (git archive baseline), surfaced as feat B criterion 8 (NEED-DECISION, BDR-123 run).
- **Cause**: CLI 2.1.306 `claude plugin validate` prints "Plugin directory checks" section (submission catalogue): `⚠ Found 1 plugin directory warning:` ICON_MISSING, `--json` `directory.findings[].blocking: false`. mods.test.sh:57 grepped whole output for `warning` (also matched hooks notes quoting register.ts identifiers, checkout paths). Prose scraping of a CLI with an exit-code contract: `--strict` → per-file warnings rc 1, directory findings rc only under `--profile directory`.
- **Solution**: 801992a (bugfix/mods-validate-advisory). Helper `validate_strict` = rc of `claude plugin validate --strict`; check_cli + positive control share it; control = scratch manifests `{"name":"warnfix"}` (rc 1) / cleanfix with version+description+author (rc 0) under script-level `mktemp -d`. Plan r3 after 3 lenses + 1 re-challenge (sed range on closing marker killed: CLI prints it only when findings > 0, fail-open to EOF). GATE 0 7/7, verifier ECARTS(2) = out-of-scope routing.json dialog write only, auditor PASS.
- **Residual**: 3 historical contracts carry old scrape as CHECK oracle (`.claude/tasks/contracts/2026-10-08-model-router-w1a-1533.md:22`, `2026-10-08-model-router-floor-1835.md:22`, `2026-10-09-model-router-tiers-1237.md:23`), left unedited; re-run fails on ICON_MISSING, not a model-router regression. Unverified: whether `--strict` escalates `advice[]`. Links [[LRN-225]], [[BDR-123]].

## BLK-040 — accepted with an open check
- **Status**: accepted. Behavioral check OPEN: `x` must ask first.

## BLK-041 — "Use when [triggers]" mid-title bracket
- **Status**: open. `y` pending.

## BLK-042 — no status anywhere
- **Solution**: fail-open guard, `data:` OPEN in prose.
