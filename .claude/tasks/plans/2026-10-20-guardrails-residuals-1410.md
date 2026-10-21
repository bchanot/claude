# FIX PLAN r3 — guardrails residuals after the a11y split (TODO.md lines 5-6)

Base: develop f586304. Analysis: scratchpad `bugfix-analysis.md` (analyzer, read-only).
r1 and r2 challenged by three lenses each; r3 closes every r2 BLOCKER/MAJOR by
a named change (see "Challenge log"). No further challenge round (lib: one
re-challenge); residual MINORs are listed as blind spots in checks.md.

Three executor parts, split by file, sequential on the same branch. Every rule
change ships a mutant (raises); every false-positive fix and every regex
widening ships a benign lock (stays silent); every new or widened repeat ships
a timing case that asserts BOTH `search(text) is None` AND < 1.0 s, sized to
about 0.2 s on this machine (5x margin). Suites: `make test suite=lib/tests/guardrails-probe.test.sh`
(PT), `make test suite=lib/tests/guardrails-scan.test.sh` (ST), full `make test`
once at the end. Rule ids, severities and exit codes never change (BDR-121):
INJ-NOSQL-OPERATOR WARN, INJ-SQL-CONCAT FAIL, INJ-SQL-RAW-UNSAFE WARN.
Shell suites: portable idioms only (`edit()` helper, no `sed -i`, BDR-110).

Shared helper, written in Part 1, reused in Part 2 — `checks/common.py`:
```python
def printable(text):
    """Control characters of a remote string, path or message never reach the tty."""
    return re.sub(r"[\x00-\x1f\x7f-\x9f\udc80-\udcff]", "?", str(text))
```
probe.py deletes `_printable` and does `from checks.common import printable`
(probe.py runs from `scripts/`, the package resolves like scan.py's import).

## Part 1 — probe.py + lib/tests/guardrails-probe.test.sh

A1 `_shape_error`: whenever `supabase` has `tables` or `cross_user_paths`, an
http(s) `url` is required (`"supabase.url must be an http(s) url"`) and
`tables`, when present, must be a list of strings
(`"supabase.tables must be a list of strings"`). `main`: the refusal prints both
urls through `printable` (`refused: pass --authorized to confirm you own <base_url> and <supabase.url> and may probe them`,
the "and …" part only when supabase.url is set); the `usage error:` line goes
through `printable` too. PT: `file:///etc/hosts` url → exit 2 + message; tables
without url → exit 2, no traceback; `"tables": "notes"` → exit 2; refusal on a
supabase url holding an ESC byte → `?` shown, 0 ESC bytes in stderr.
`skills/guardrails/SKILL.md` STEP 5 "Run it" (line ~97): before adding
`--authorized`, show the user the two hosts the plan names (base_url and the
Supabase url, the latter taken from the project's config and therefore
untrusted) and get their go on both; one sentence, single line (loops-light
locks STEP 9-11 strings only).

A2 budget on redirects. probe.py defines
`BUDGET_EXHAUSTED = "request budget exhausted"` and
`class _BudgetExhausted(urllib.error.URLError)`. `_SameHost(session)`:
`Session.__init__` builds `build_opener(_SameHost(self))`; `redirect_request`:
off-host → None (unchanged); `self.session.budget <= 0` →
`raise _BudgetExhausted(BUDGET_EXHAUSTED)`; else decrement and delegate.
`fetch`: the pre-check returns `Response(None, {}, b"", BUDGET_EXHAUSTED)`;
`except _BudgetExhausted` (before the URLError clause) returns the same. So the
error string is one constant everywhere. `_rate_verdict`: when fewer than the
requested count were answered and no 429 was seen → SKIPPED
`"burst cut short (budget or transport), rate limit not confirmed"`, never OPEN.
PT: fixture routes `/hop1` → 302 `/hop2` → 302 `/hop3` → 200 `{"ok": true}`.
Python block on the PT `same_host` pattern (~378-383): `Session()` +
`fetch(s, "GET", BASE + "/hop1")` → status 200 and `s.budget == DEFAULT_BUDGET - 3`;
`Session(budget=2)` + same fetch → `error == probe.BUDGET_EXHAUSTED`; and
`_route_probe(Session(budget=2), BASE, {"path": "/hop1"})` → verdict ERROR.
No new plan file, nothing added to `plan.json`.

A3 rows state. `_verdict` keeps handling the transport error first (ERROR). For
`_table_probe` and `_cross_user_probe`: status 200 → three-way
`_rows_state(resp)` through `_json_body`: `[]` or a non-list JSON → `empty`
(CLOSED, notes unchanged); a non-empty list → `rows` (OPEN); parse failure
(RecursionError, ValueError, empty body, truncated at BODY_CAP) → `unreadable`
→ SKIPPED `f"HTTP {resp.status}: body not readable as JSON rows, not confirmed"`.
Status 401/403/404 → CLOSED as today; any other non-200 → SKIPPED
`f"HTTP {resp.status}: not confirmed"`. PT: fixture route `/rest/v1/deep`
answering 200 with `b"[" * 200000`; plan `deep.json` with
`"supabase": {"url": BASE, "tables": ["deep"]}` run with `GUARDRAILS_ANON_KEY=test-anon`
→ `anon-read:deep` SKIPPED, no `Traceback` in stderr; cross-user on
`/api/guarded` (401) stays CLOSED (lock it).

B1 metadata keys. `METADATA_KEY = re.compile(r"^(?:has|is|needs|requires)_|_(?:type|count|length|url|expires?|expiry|ttl|at)$|^(?:next_page_token|page_token|cursor|csrf_?token|xsrf_?token)$")`
tested on `_snake(k)` before SENSITIVE_KEY; a metadata key is never sensitive.
PT: `/api/me` keeps `next_page_token`; the lock at ~248 becomes
`api_key, password_hash$`; new route `/meta/keys` →
`{"tokenType": "bearer", "has_password": true, "token_expires_in": 3600, "password_changed_at": "2026"}`
→ fields CLOSED (camelCase proves the snake-cased match; `token_expires_in` and
`password_changed_at` are sensitive today).

B2 + B13 `_map_verdict` walks every candidate. Candidates: resolve each through
`_same_host` first; dedupe on the resolved url, else on the raw url. Split a
per-candidate classifier `_map_outcome(session, script_url, url) -> (kind, target, note)`
with kind in `open | negative | note | error` out of the loop (25-line limit).
Per candidate:
- `data:` url (always a line-start `sourceMappingURL` directive since c0fdbec)
  → `open`, note `inline source map in the script`, no decoding (base64 and
  percent-encoded alike; the `"base64," not in url: continue` guard is deleted).
- off-host → `note` `map url on another host, not fetched`.
- transport error (incl. BUDGET_EXHAUSTED) → `error` → return ERROR now (today's behaviour).
- 200 at BODY_CAP → `note` (checked BEFORE the sources test; PT /bigmap.js.map lock stays SKIPPED).
- 200 with `"sources"` → `open`.
- 404, 410, or 200 without sources → `negative`.
- any other status (3xx, 401, 403, 429, 5xx…) → `note` `f"HTTP {status}: map not readable, not confirmed"`.
After the loop: any note → `("SKIPPED", first noted target, its note)`, else CLOSED.
PT, in a NEW plan file `maps2.json` (maps.json already lists 8 of SCRIPT_CAP 10):
`/forbidden.js` (comment → `/forbidden-real.js.map`; `/forbidden.js.map` → 403;
`/forbidden-real.js.map` → 200 with sources) → OPEN; `/pct.js`
(`sourceMappingURL=data:application/json,%7B%22version%22%3A3%7D`) → OPEN;
`/limited.js` (bare map → 429) → SKIPPED. Existing `/err.js` 503 and
`/inline.js` / `/biginline.js` locks stay.

## Part 2 — engine, checks, docs, lib/tests/guardrails-scan.test.sh

A4 scanner.py: one helper `_safe_text(text)` = `"\n".join(printable(l) for l in text.split("\n"))`
applied at the three text print sites (the text report, the check-mode lines,
the usage error); JSON untouched. ST: mutant with an ESC byte in a file name AND
in a supabase policy name (supabase.py:160 echoes it in `f.message`): 0 ESC bytes
in the text report; a `--assert-absent RULE:<ESC-named path>` run prints the
PRESENT row with `?` and 0 ESC bytes; a `--baseline` run 0 ESC bytes; findings
still raise. `SKILL.md` STEP 9 (~187-195): one sentence "pairs come from the
`--json` output, never from the text report". a11y suite stays green untouched.

B3 `_hydrated` scoped by export chunks. One `finditer` of `^export\b` (re.M)
gives chunk starts (plus offset 0, EOF). For each chunk holding a LOADER match,
run `HYDRATED.finditer(text, line_start_of_first_match, chunk_end)`; offsets are
absolute, chunks disjoint, no merge. A `window.__X__ =` match is a LOADER member
and follows the same rule. Findings through `dedupe_lines`. ST mutants (WARN):
Prettier multi-line-params `getServerSideProps` with `}) => {`; one-line
`export const loader = () => json({ token: t });`; multi-line Remix `loader`;
SvelteKit `export async function load()`; multi-line `window.__STATE__ = {\n token: t\n}`.
Benigns: clean `loader` followed by an `action` holding `password: form.get("password")`;
`// getServerSideProps` comment above a clean loader. Timing case: 1 MB of
`export const load = 1\n` through the chunk builder + HYDRATED, < 1.0 s.
checks.md blind spots: a non-exported helper between two exports is still
scanned (false positive as today); a sensitive object built in a helper above
the loader is missed; a fix that moves the key above the loader clears the
oracle, the STEP 3 judge re-reads the whole loader.

B4 `_map_config`: `other = [p for p in _named(project, "webpack") if p not in prod and not DEV_TOKEN.search(p.name)]`.
ST: benigns `webpack.dev.js`, `webpack.config.dev.js` with `devtool: 'eval-source-map'`;
`webpack.config.js` still WARN; mutant `webpack.prod.js` with the same devtool → FAIL.

B5 DATA_ATTR: the sensitive word list becomes one constant `SENSITIVE_WORD`
used by DATA_ATTR and by `UI_ATTR = re.compile(rf"{SENSITIVE_WORD}-(?:toggle|visible|visibility|show|hide|reveal|mask|strength|meter|hint|label|placeholder|confirm|error|required|pattern)$", re.I)`
tested with `search` on the captured name (anchored at its end) → silent.
ST: benigns `data-password-toggle="true"`, `data-password-strength="3"`,
`data-secret-visible`; mutants `data-password="hunter2"`, `data-hide-api-key={k}`,
`data-api-key-input-value={v}` still WARN.

B6 NOSQL `$where`: `\$where\s*:\s*(?!\w{0,64}_(?:bool_)?exp\b|[A-Z]\w{0,64}!?\s*[),])(?:['"`]|\w)`
(bounded repeats; excludes GraphQL `_bool_exp` types and a Capitalised type
followed by `)` or `,`). ST mutants (WARN): `{ $where: "this.name == '" + name + "'" }`,
`{ $where: clause }`, `{ $where: buildWhere(req.query) }`; benign
`$where: users_bool_exp` and `($where: UsersWhere)` in a `.ts` gql template.
Blind spot (checks.md): `$where: PascalCase` or `*_exp` identifiers.
Timing case added (B9).

B7 misses, one mutant each, clean fixture stays 0/0:
- Go: CONCAT `.go` → `fmt\.Sprintf\(\s*(?:\"{DQ}?{STMT}|`\s{0,40}{STMT})`; mutants
  double-quoted and backtick (statement first). Blind spot: a raw literal whose
  statement keyword does not open it.
- RAW JS adds `\b(?:sql|db|trx|knex)\.raw` (non-literal argument → WARN).
- Python `rf""` / `fr""`: first `.py` alternative `\b(?:rf|fr|f)['\"]...`.
- Triple-quoted f-strings: alternative `\b(?:rf|fr|f)(?:\"\"\"|''')\s{0,40}{STMT}`
  (STMT-anchored like the single-quote form, no `{` required). Mutant: multi-line
  `f"""\n    select id from notes\n    where owner = {owner}\n"""`; benign plain
  `"""select … %s"""`. Blind spot: a literal whose first non-blank line holds no
  statement (comment first).
- Supabase `.select()` empty → WIDE `\.select\(\s*(?:['\"]\*['\"]\s*)?\)`.
- HIDDEN_INPUT `<input\b[^>]{0,300}>` (newlines allowed, bounded); mutant with
  `type="hidden"` and `name="api_key"` on separate lines.

B8 docs, one pass. `SKILL.md` judging step (~50-57): bullet "INJ-SQL-CONCAT on
`IN (${placeholders})` where the list is generated `?`/`$n` markers and the
values travel in a separate array: parameterised, confirm by hand and drop it
from the proposals." `references/checks.md`: :41 RAW row adds `sql.raw`,
`db.raw`, `trx.raw`; :44 `$where` row "a string, an identifier or a function
(GraphQL `_bool_exp` and Capitalised types excluded)"; :52 webpack "WARN
elsewhere, dev configs silent"; :59 EXP-RESPONSE-WIDE adds `.select()`;
:141 by-design list adds the generated `?` list, webpack dev configs,
UI-suffixed data-* names, export-chunk scoping, metadata keys in the fields
probe; :226 fields row mentions the metadata exclusion; :232 verdict wording
"SKIPPED is a missing key or a body the probe could not read; ERROR is a
transport failure or an exhausted budget"; sourcemap row: a line-start
`data:` directive is OPEN whatever its encoding; blind spots list (B3, B6, B7
above, 1 MB per-file CONCAT cost ≈ 3 s accepted).

B9 timing lock (ST ~506-528): ADD cases, each asserting `search is None` and
< 1.0 s, sized ≈ 80 KB: JS backtick (`"`" + "select from " * N`), JS `'`-quoted,
py `f'`, py `f"""`, Go `` fmt.Sprintf(` `` raw, NOSQL `$where: ` units,
HIDDEN_INPUT `<input ` units, the B3 chunk case. Units carry no closing keyword
(`select from `) so no alternative matches. Expected ≈ 0.1-0.2 s each here.

B11 `SKILL.md` ~96: after "never `service_role`." add "The fields probe sends
`GUARDRAILS_JWT2` as a bearer when set, so an OPEN there is what a logged-in user sees."

B12 `_large_map`: head counts when `b'"mappings"' in head or b'"sources"' in head`.
ST: mutant 1.1 MB `public/app.js.map` in rollup order (`{"version":3,"file":"app.js","sources":["a.ts"],"sourcesContent":["` + padding, `"mappings"` last) → FAIL;
existing large-level-map benign stays silent.

## Part 3 — B10 per-variant locks (ST, plus minimal regex fixes and their checks.md rows)

Routing-dependent rows get end-to-end mutants: Rust `format!` (`.rs`), Django
`.objects.raw(var)` and `.extra(` alone on their line, `knex.raw(var)` alone
(dedupe), `sqlalchemy.text(` gate, `$executeRawUnsafe`, `sequelize.query`,
`Sequelize.literal`, `GENERATE_SOURCEMAP=true` in `.env.production`, vite
`sourcemap: true`, angular `sourceMap: true` (WARN), Rails
`consider_all_requests_local = true` in `config/environments/production.rb`,
`FLASK_DEBUG=1` in `.env.production`.
Alternation-only rows go in one python table block (`regex.search(sample)`
per row, next to the timing block): CONCAT py `%` and `.format(` tails, JS
`'…' + x`, Ruby `"select … #{}"`; DYNAMIC_EXEC `execute var ||`; POSTGREST
`.filter(` / `.not(` / `.match(` / `.textSearch(` and the `'…' + x` branch;
NOSQL `find(req.body)`, `updateOne({x: req.body.y})`, `findOneAndUpdate`,
`deleteMany`, `countDocuments`; SENDING forms (jsonify, JSONResponse,
HTTPException, `detail=`, `echo`, `reply.send`, `ctx.body`); ERROR_STACK
`traceback.format_exc`, `getTraceAsString()`, `json({ error: err })`;
ERROR_MESSAGE `str(e)`, `repr(e)`, `->getMessage()`; `app.debug = True`;
SHELL_DB heads (`Command::new`, `popen`, `passthru`, `proc_open`, `spawn`,
`system`) and interpolations (`#{`, `{x}`, `%s`, `$var`).
A row that does not match is a real miss: fix the regex minimally, add a benign
lock for the widened form, a timing case if a repeat widens, and update its
checks.md row. More than 5 regex edits in this part → `STATUS : NEED-DECISION`
listing the rows, never widen further.

## Out of scope
settings.json, mods/model-router/routing.json (pre-existing dirty, never staged).
Other domains' missing mutants (api, hosting, supabase, messaging, functions).

## Gated answers [gated 2026-10-20]
- Plan approved (r1), both parts; r2/r3 restructure into three parts by file.
- B1: full METADATA_KEY list; `next_page_token` stops being reported.
- B4 + B5: webpack dev configs and UI-suffixed data-* names are silent, each with a benign lock.
- No new CLI flag (A2 locked through a python block).

## Challenge log
r1 → r2: B6 mutants WARN; A2 URLError → ERROR; A3 three-way; B9 non-matching
shapes; B2 allowlist; B3 spans; B5 anchored; B6 identifier branch kept; B10 own
part; one `printable`; split by file; MINORs (DEV_TOKEN, `_at$`, url required,
two map keys, RAW receivers, checks.md rows, base64 unchanged, dedupe, A4 locks,
snake fixture, route names).
r2 → r3 (all three lenses):
- BLOCKER (c#1, r#1, s#3): `BUDGET_EXHAUSTED` constant + `_BudgetExhausted` subclass mapped in `fetch`; B2 keeps today's transport-error ERROR return.
- MAJOR c#2 / r#2 / s#4: A3 gated on status (200 three-way; 401/403/404 CLOSED; other SKIPPED), error first, `/rest/v1/deep` route only, 401 cross-user lock.
- MAJOR c#3 / s#2 / r#11: triple-quoted alternative = STMT-anchored form, multi-line mutant, blind spot documented.
- MAJOR c#4 / r#4 / s#1: B3 export-chunk scoping (linear), Prettier mutant.
- MAJOR c#5: Part 2 regains webpack.prod FAIL, loader/load/one-line WARN and double-quoted Go mutants.
- MAJOR r#3: SKILL.md STEP 5 shows both hosts before `--authorized`.
- MAJOR r#5 / r#6: timing cases assert non-match, sized ≈ 80 KB, 1 MB cost recorded as residual.
- s#3 accepted in part: `data:` directive → OPEN without decoding (simplicity r1#3 now accepted: the directive is line-anchored, so the payload is observed); the base64 guard is deleted.
- MINORs: tables typed (c#12, r#15); usage error printable (r#16); rate-limit SKIPPED on a cut burst (r#7); cap before sources, dedupe key (c#6, r#8); B5 end-anchored and shared word list (r#12, s#8); B6 bounded + timing (r#13, s#12); B12 OR (r#14, s#9); `expires_in` → `token_expires_in` (c#11); `_map_config` name (c#10); A4 single helper and ESC pair (s#6, c#7); JSON pairs sentence (r#17); docs rows (c#9); Part 3 table split and checks.md rows (s#10, s#11); hops.json dropped (s#5).
