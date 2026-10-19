# Guardrails evolution: /a11y split, injection and exposure domains

Date: 2026-10-18. Flow: /ship-feature. Contract:
`.claude/tasks/contracts/2026-10-18-guardrails-a11y-split-inj-exp-2210.md`.

## Goal

Three deliverables, one branch (`feature/a11y-split-inj-exp`):

1. Accessibility leaves `/guardrails` and becomes the standalone skill
   `/a11y`: same A11Y-* rules, the Tab-only keyboard walk, its own report
   (`.claude/audits/A11Y.md`) and its own fix loop (the guardrails circuit).
2. `/guardrails` gains two scanner domains, `injection` (rules `INJ-*`)
   and `exposure` (rules `EXP-*`), proven through the existing fix loop.
3. The read-only live probe gains an `exposure` block: source maps served,
   error bodies, sensitive keys in JSON responses.

Decided by the user before the brainstorm: standalone skill, the two domain
names, static rules plus the live probe. Decided at the design gate: the
engine is shared (no duplicate walker), the fix loop mirrors guardrails, the
a11y doctrine moves to a path-scoped rule, web-validate keeps full WCAG,
the security-auditor keeps `--domain api,supabase`.

## Non-goals

- No browser automation in the probe: it observes what a GET returns. XHR
  fired after page load, console output at runtime and DOM state are the
  `/browse` walk's job, done by hand, or out of scope.
- No taint analysis: injection detection is regex over text. The
  security-auditor's semgrep (`p/owasp-top-ten`) keeps taint coverage.
- No widening of the security-auditor's scanner domains (FP flood on every
  /feat and /bugfix gate, LRN-094).
- No change to `/onboard`'s own a11y dispatch, to `/harden` (headers such
  as `X-Powered-By` stay there) or to `/cso`.
- No new MANUAL rule.

## Architecture

### Shared scan engine

`skills/guardrails/scripts/scanner.py` holds everything `scan.py` holds
today except the domain table: argument parsing, the walker call, text and
JSON rendering, `--assert-absent`, `--baseline`, exit codes. A frozen
dataclass `Catalogue(name, domains, rule_domains, manual_rules, marker)`
carries what differs per CLI. `main(argv, catalogue)` is the entry point.

- `skills/guardrails/scripts/scan.py` becomes the guardrails catalogue:
  domains `api, hosting, supabase, messaging, functions, injection,
  exposure` (this order: `injection` and `exposure` last, so the
  empty-project report still starts with `not applicable: hosting`),
  prefixes `API HOST SB MSG FN INJ EXP`, the five MANUAL rules, marker
  `GUARDRAILS`.
- `skills/a11y/scripts/scan.py` inserts `skills/guardrails/scripts` at the
  front of `sys.path`, imports `scanner` and its own `a11y_checks`, and runs
  the catalogue `{"a11y": a11y_checks}`, prefix `A11Y`, marker `A11Y`.
  Markers: `A11Y-CLEAR <n>` and `A11Y-NO-NEW`.
- `skills/a11y/scripts/a11y_checks.py` is today's `checks/a11y.py`, moved
  with `git mv`, its import changed to `from checks.common import Rule,
  blank_markup_comments` (resolved through the inserted path). Rule ids,
  severities and messages stay as they are.
- `checks.common` gains `client_reachable(project, path)`, moved from
  `supabase.py` with its four constants, so `exposure.py` can reuse it.

CLI behaviour of the guardrails scanner is unchanged for every existing
option. `--domain a11y` is now a usage error (exit 2).

### Domain `injection` (`checks/injection.py`)

Applies when the tree has a source file (`SOURCE_EXTS`) or a `.sql` file.
Skips test, spec, fixture and mock paths. One finding per (path, line):
when two rules match the same line the first in this order wins, so a
interpolation inside a raw escape stays INJ-SQL-CONCAT (FAIL).

| Rule | Sev | Catches |
|---|---|---|
| INJ-SQL-CONCAT | FAIL | a SQL statement string built from an expression: untagged template literal with `${`, quoted SQL followed by `+ identifier`, Python f-string, `%` operator or `.format(`, PHP `"… $var"` or `. $var`, Ruby `#{}` (including ActiveRecord `.where("… #{`), Rust `format!(`, Go `fmt.Sprintf(` |
| INJ-SQL-RAW-UNSAFE | WARN | a raw escape fed a non-literal first argument: `$queryRawUnsafe(`, `$executeRawUnsafe(`, `knex.raw(`, `.raw(`, `.extra(`, `sequelize.query(`, `Sequelize.literal(`, `text(` when `sqlalchemy` is imported; WARN: a variable may hold a constant |
| INJ-SQL-DYNAMIC-EXEC | WARN | plpgsql `EXECUTE` whose statement uses `\|\|` and is not `format(…)` (SQL files, comments blanked) |
| INJ-POSTGREST-FILTER | WARN | supabase-js `.or(`, `.filter(`, `.not(`, `.match(`, `.textSearch(` with a template `${` or a `+` concatenation |
| INJ-NOSQL-OPERATOR | WARN | Mongo `$where:` with a string, or `find`/`findOne`/`update*`/`delete*`/`countDocuments` whose filter is `req.body`, `req.query`, `req.params` or one field taken straight from them |
| INJ-SHELL-DB-TOOL | FAIL | `exec`, `execSync`, `spawn`, `spawnSync`, `system`, `popen`, `subprocess.*`, `os.system`, `Command::new`, `shell_exec`, `passthru`, `proc_open` naming psql, mysql, mysqldump, pg_dump, pg_restore, mongosh, mongo, mongodump, redis-cli, sqlite3 or clickhouse-client on a line that also interpolates (`${`, `+ x`, `#{`, `{x}`, `%s`, `$x`); outside PHP an uppercase `$NAME` is an env reference and stays silent |

Silent by design: tagged templates (`sql\`…\``, `prisma.$queryRaw\`…\``),
placeholders (`$1`, `?`, `%s` with a separate tuple), an argv array
(`spawn("psql", ["-c", q])`), test and fixture paths.

### Domain `exposure` (`checks/exposure.py`)

Applies when the tree has a source, markup or config file. Same path skips
as injection for the console rule.

| Rule | Sev | Catches |
|---|---|---|
| EXP-CONSOLE-DATA | WARN | `console.log/info/debug/dir/table` in a client-reachable file whose arguments name data (user, users, profile, session, token, account, customer, order, payment, response, res, data, result, rows, body, headers, props, state, error, err, json, payload, record, item, items); password identifiers are left to API-PASSWORD-LOGGED |
| EXP-SOURCEMAP-PUBLIC | FAIL / WARN | FAIL: `productionBrowserSourceMaps: true` (next.config), `sourcemap: true` (vite.config), `devtool:` of `source-map`, `eval*`, `inline*`, `cheap*` in `webpack.prod*`, `GENERATE_SOURCEMAP=true` in a committed env file that is neither a sample nor named dev, local or test, a real `.map` file (any size, vendored and `.min.` maps excluded) under `public/`, `static/`, `assets/` or `www/`. WARN: the same `devtool:` in another webpack config, `"sourceMap": true` in angular.json |
| EXP-HYDRATED-SENSITIVE | WARN | in a file defining `getServerSideProps`, `getStaticProps`, a Remix `loader`, a SvelteKit `load` or assigning `window.__*__ =`: an object key named token, accessToken, refreshToken, secret, apiKey, api_key, password, passwordHash, password_hash, serviceRole, service_role, privateKey, private_key, ssn, iban, stripeSecret, clientSecret, unless the line is a TS type member (`key: type;`) |
| EXP-MARKUP-COMMENT | WARN | `<!-- … -->` in `.html .htm .astro .php .ejs .hbs .twig .njk .liquid` containing todo, fixme, hack, xxx, debug, password, passwd, secret, token, api key, internal, staging, localhost, admin, remove before, do not commit, temporary |
| EXP-DATA-ATTR-SENSITIVE | WARN | a `data-*` attribute or a hidden input whose name contains secret, api-key, api_key, apikey, password, passwd, jwt, private, credential or service-role; names containing csrf, xsrf, authenticity or nonce are skipped |
| EXP-ERROR-STACK | FAIL | a response built with `.stack` of an error, with the whole error object (`error: err` inside `json(`/`send(`), with `traceback.format_exc` or `getTraceAsString()` |
| EXP-ERROR-MESSAGE | WARN | a response line carrying `err.message`, `error.message`, `e.message`, `str(e)`, `str(exc)`, `repr(e)`, `$e->getMessage()` next to a sending token (`res.`, `Response`, `json(`, `jsonify`, `send(`, `HTTPException`, `detail=`, `echo`) |
| EXP-DEBUG-ON | FAIL | `DEBUG = True` in a settings module not named dev, local or test; `APP_DEBUG=true` or `FLASK_DEBUG=1` in a committed env file that is neither a sample nor named dev, local or test; `app.debug = True` or `debug=True` in `app.run(`; `consider_all_requests_local = true` in `production.rb`; `errorhandler()` mounted in Express |
| EXP-RESPONSE-WIDE | WARN | in a route file: `.from('<users-like>').select('*')`, `select * from <users-like>` in a string, or a Prisma `user/profile/account/customer/member.findUnique/findFirst/findMany({` with no `select:` or `omit:` on the line. Users-like: users, profiles, accounts, customers, members, employees, patients, clients |

Silent by design: `console.log("ready")`, any console call in a server
file, `sourcemap: 'hidden'`, `DEBUG = os.environ…`, a generic error string
in a response, a TS type member named `token`, the fixture's hidden
`name="token"` (no sensitive word), `select *` outside a route file.

### Probe `exposure` (`probe.py`)

Opt-in through an `exposure` object in the plan (`{}` activates the
defaults). Still GET only, same host, shared budget, `--authorized`.

| Probe id | OPEN when |
|---|---|
| `sourcemap:<script path>` | for a script of the base page (`<script src>` on the same host, 10 at most, or the plan's `exposure.scripts`): `<url>.map`, the `SourceMap`/`X-SourceMap` header target or the trailing `sourceMappingURL` target answers 200 with `"sources"` |
| `error-body:<path>` | the GET of `/guardrails-probe-<random>` or of a path in `exposure.error_routes` returns a body with a trace marker: `Traceback (most recent call last)`, `at … (file:N:N)`, `File "…", line N`, `SQLSTATE[`, `syntax error at or near`, `node_modules/`, `/var/www/`, `Stack trace:`, `#N /…php(N)` |
| `fields:<path>` | the GET of a plan route returns JSON 200 whose keys anywhere in the body (1 MB bound; a body that does not parse, too deep included, is SKIPPED) match password, passwd, pwd, hash, salt, secret, token, api_key, apikey, service_role, private_key, ssn, iban, cvv, card_number. Only key names are printed, never values. Sent with `GUARDRAILS_JWT2` as bearer when set, anonymous otherwise |

One shared change, flip-tested: `fetch` keeps the body of a 4xx/5xx
response (today it returns `b""`); headers stay the `HTTPMessage`, whose
`.get` already ignores case (a lowercase-header fixture proves it). A target
the probe could not observe (unreachable page, no same-host script, a script
not served or truncated, an off-host map, a refused or non-JSON route) is
SKIPPED or ERROR, never CLOSED. Exposure runs against a production build or
a staging URL: a dev server's OPEN verdicts are dev artefacts, no proposal.

Plan validation: `exposure` must be an object; `scripts` and
`error_routes` lists; every path in the plan (`routes[].path`,
`cross_user_paths`, `cors_path`, `rate_limit.path`, `scripts`,
`error_routes`) a string starting with `/`, so no request can leave the
named host. A script URL on another host is dropped, never fetched.

### Skill `/a11y`

`skills/a11y/SKILL.md`, frontmatter `name: a11y`, `effort: high`,
`argument-hint: '[project path] [--exclude paths] [--live <url you own>]
[--report-only]'`, description under 1024 characters starting with "Use
when". Steps: model gate, scope, scan, judge, keyboard walk (on `--live`
with `/browse`: Tab through the main flow, note each stop without a
visible focus or unreachable; without a browser tool the report says "not
done"), report `.claude/audits/A11Y.md`, proposals (alt text and label
wording are visible choices, proposed with a value and never applied
silently), approval gate, apply (branch `bugfix/a11y-<date>`, baseline
`.claude/audits/.a11y-baseline.json`, contract `flow: a11y`, oracle
`--assert-absent` with `EXPECT: A11Y-CLEAR`, positive control, `bugfixer`,
gates per `lib/verify-secure-loop.md`), re-pass (`--baseline`,
`A11Y-NO-NEW`, walk replayed on `--live`), commit gate. `references/
checks.md` carries the A11Y rule table, the blind spots (keyboard traps,
focus order, modal focus, contrast) and the oracle table.
`test-prompts.json` has five prompts. Routing row `"a11y": "reflect"`.
Profiles: audit, dev, web, web-full, full, max. Locks: model-routing list,
a loops-light block (contract include, verify-secure include, bugfixer,
`EXPECT: A11Y-CLEAR`, positive control, approval sentence, `A11Y-NO-NEW`).

### Doctrine and routing

- `rules/secure-by-default.md`: title "six domains and every API";
  `## 2. Accessibility` removed; `## 2. Injection` and `## 3. Exposure`
  added (three bullets each); Supabase, SMS and email, Cloud functions
  renumbered 4, 5, 6.
- `rules/a11y.md` (new, lazy): `paths:` on `**/*.tsx .jsx .vue .svelte
  .astro .html .css .scss`, the two accessibility bullets, pointer to
  `/a11y`.
- `/guardrails` description rewritten under 1024 characters; disclaims
  "Headers and TLS → /harden; secrets, CVE, dependencies → /cso; keyboard,
  alt, labels → /a11y".
- `/web-validate` triggers drop the bare "a11y", "accessibility",
  "accessibilité"; keep WCAG, W3C, axe, pa11y; add "keyboard, alt, label
  basics and their fixes → /a11y".
- `CLAUDE.global.md:276` reads "W3C + WCAG conformance → web-validate"
  (same line count, 320 kept).
- Citers: interviewer.md ("six guardrail domains"), bugfixer.md
  description ("/guardrails or /a11y"), verify-secure-loop.md header,
  contract-interview.md flow enum, README, USAGE, CHANGELOG (the
  Unreleased guardrails bullet amended in place, new bullets for `/a11y`,
  the two domains and the probe block).

## Testing

- `lib/tests/guardrails-scan.test.sh`: a11y blocks removed; check-mode,
  contract and CLI tests re-pointed to `INJ-SQL-CONCAT:src/pages/api/
  notes.ts`; `--domain a11y` exits 2; one mutant per INJ and EXP rule;
  benign locks: parameterized query, tagged template, argv DB tool,
  plain-string console, server-file console, hidden source map,
  env-driven DEBUG, generic error message, TS type member.
- `lib/tests/a11y-scan.test.sh` (new) with `lib/tests/fixtures/a11y-good/`:
  clean fixture, the seven A11Y mutants, the two benign locks, check modes
  with `A11Y-CLEAR` / `A11Y-NO-NEW`, gates.sh contract, CLI.
- `lib/tests/guardrails-probe.test.sh`: fixture server gains `/` (two
  same-host scripts and one foreign-host script), `/app.js` with a map,
  `/clean.js` without, `/boom` (500 with a Python traceback), `/api/me`
  (JSON with nested `api_key` and `password_hash`), `/lower` (lowercase
  CORS header names). New plan `exposure.json`: sourcemap OPEN and
  CLOSED, error-body OPEN and CLOSED, fields OPEN and CLOSED, foreign
  script never probed, lowercase CORS OPEN, bad `exposure` shape exits 2.
  The existing `open == 4` assertion stays on the unchanged `plan.json`.
- Censuses: effort-routing, profile-census, skill-routing-census,
  model-routing, loops-light, doctrine-citers; `shellcheck`; one full
  `make test` before the gate.

## Commit discipline

The two pre-existing diffs (`mods/model-router/routing.json` dialog
decisions, `settings.json` env key) never enter a feature commit: the task
that adds the `a11y` row stashes those two files first, commits the row
alone, pops the stash. Never `git add -A`. Derived files
(`.claude/audits/.a11y-baseline.json`, reports) are never staged.

## Accepted limits

Name-based heuristics (EXP-RESPONSE-WIDE, EXP-HYDRATED-SENSITIVE,
EXP-CONSOLE-DATA) miss anodyne names and flag benign ones: they are WARN
and judged in STEP 3. `dist/` is skipped, so only the probe proves a served
map. The error probe sees 404s and user-named routes only; provoking a 500
is fuzzing and stays out. Astro comment stripping is uncertain: the rule
includes `.astro` and the judgment step notes the build behaviour.
