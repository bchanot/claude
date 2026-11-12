# CONTRACT — guardrails-residuals
- date: 2026-10-20 | flow: bugfix | branch: develop (bugfix branch at STEP 4)
- status: active
- plan: .claude/tasks/plans/2026-10-20-guardrails-residuals-1410.md (r3, challenged twice)

## REQUEST (verbatim — IMMUTABLE)
User message (typed): "corrige tout les 4 points qui tu as souligne" — point 1 = the MEDIUM
of the security gate (probe `supabase.url` unvalidated) and point 2 = the parked
review Minors and the 4 LOW, both in `.claude/tasks/TODO.md` lines 5-6.

Skill arguments ($ARGUMENTS to /bugfix):
"Guardrails residuals parked in .claude/tasks/TODO.md lines 5-6 after the a11y split merge (f586304). Fix all of them: (1) probe.py `supabase.url` validated through `_http_url` and echoed next to base_url in the `--authorized` refusal (planted SUPABASE_URL would receive GUARDRAILS_ANON_KEY / GUARDRAILS_JWT2; `file://` reads CLOSED); same-host redirects counted against `session.budget`; `_nonempty_rows` catches RecursionError like `_json_body`; scanner.py text output passes `f.path` and `project.root` through a printable filter. (2) review Minors: SENSITIVE_KEY false positives on metadata names (`token_type`, `has_password`, `next_page_token`); 403 on the first map candidate must not stop before header/comment candidates; EXP-HYDRATED-SENSITIVE scoped to the loader/getServerSideProps return, not the whole route file; `webpack.dev.js` and `data-password-toggle` stay silent; GraphQL `$where: users_bool_exp` not INJ-NOSQL-OPERATOR; misses to cover: Go raw-string Sprintf, Drizzle `sql.raw`, `db.raw`, Python `rf""`, Supabase `.select()` with no arg, multi-line JSX hidden input, triple-quoted f-strings; `IN (${placeholders})` named in checks.md judging step; timing lock also covers CONCAT; a mutant per language variant; SKILL.md:96 fields example with bearer JWT2; large `.map` head detection for esbuild/rollup (`"version":3`); URL-encoded `data:` source maps. Suites: lib/tests/guardrails-scan.test.sh, guardrails-probe.test.sh, a11y-scan.test.sh via make test. Working tree has two pre-existing uncommitted files (mods/model-router/routing.json, settings.json) that are not part of this task and must never be staged."

## CLARIFICATIONS
Pass B (STEP 3, 2026-10-20, AskUserQuestion): plan approved; B1 full METADATA_KEY list
(`next_page_token` stops being reported); webpack dev configs and UI-suffixed data-*
names silent with benign locks; no new CLI flag. [gated 2026-10-20]
Analyzer corrections accepted: B12's real miss is the key order of rollup maps (the
`"mappings"` key after `sourcesContent`), not a `"version":3` test; B13 base64 form
was already OPEN, the percent-encoded form was the miss. The judging step named in
the request lives in SKILL.md (checks.md has none): the bullet goes there, the
by-design line in checks.md is amended.
Challenge rulings (r1, r2): a line-start `data:` sourceMappingURL directive is OPEN
whatever its encoding (no decoding); budget exhaustion is one constant
`BUDGET_EXHAUSTED` mapped in `fetch`; hydrated scope = export chunks; triple-quoted
f-strings = STMT-anchored alternative; timing cases assert non-match at ≈ 80 KB.
Executor rulings (Part 1, 2026-10-20): METADATA_KEY alternation `expires?(?:_in)?` so `token_expires_in` is metadata (plan regex missed it); oracle 12 wrapped in a subshell (orchestrator oracle defect). [gated 2026-10-20]
Executor rulings (Part 2, 2026-10-20): oracle 17 gains an `index.js` (a lone .map leaves the exposure domain not applicable, orchestrator oracle defect); SKILL.md Part 1 sentence reworded "Before adding `--authorized`" to match criterion 20's grep; oracle 15 negative grep narrowed to the INJ-NOSQL-OPERATOR row (g.ts under src/api also raises API-ROUTE-NO-AUTH, orchestrator oracle defect).
Severities never change: INJ-NOSQL-OPERATOR WARN, INJ-SQL-CONCAT FAIL, INJ-SQL-RAW-UNSAFE WARN.

## ACCEPTANCE CRITERIA
1. Probe suite green.
   CHECK: make test suite=lib/tests/guardrails-probe.test.sh >/dev/null 2>&1 && echo PT-GREEN
   EXPECT: PT-GREEN
   EVIDENCE: MET exit=0 marker-found :: PT-GREEN
2. Scan suite green.
   CHECK: make test suite=lib/tests/guardrails-scan.test.sh >/dev/null 2>&1 && echo ST-GREEN
   EXPECT: ST-GREEN
   EVIDENCE: MET exit=0 marker-found :: ST-GREEN
3. a11y suite green untouched (shared engine).
   CHECK: make test suite=lib/tests/a11y-scan.test.sh >/dev/null 2>&1 && git diff --quiet develop -- lib/tests/a11y-scan.test.sh && echo A11Y-GREEN
   EXPECT: A11Y-GREEN
   EVIDENCE: MET exit=0 marker-found :: A11Y-GREEN
4. Full suite and shellcheck green.
   CHECK: make test >/dev/null 2>&1 && shellcheck *.sh hooks/*.sh lib/*.sh && echo ALL-GREEN
   EXPECT: ALL-GREEN
   EVIDENCE: MET exit=0 marker-found :: ALL-GREEN
5. A1: a non-http(s) `supabase.url` is a usage error (exit 2) naming it; tables without a url is a usage error too; no traceback.
   CHECK: p=$(mktemp); printf '{"base_url":"http://127.0.0.1:9","supabase":{"url":"file:///etc/hosts","tables":["t"]}}' > "$p"; python3 -B skills/guardrails/scripts/probe.py "$p" --authorized >/dev/null 2>"$p.err"; rc=$?; q=$(mktemp); printf '{"base_url":"http://127.0.0.1:9","supabase":{"tables":["t"]}}' > "$q"; python3 -B skills/guardrails/scripts/probe.py "$q" --authorized >/dev/null 2>"$q.err"; rc2=$?; [ "$rc" -eq 2 ] && [ "$rc2" -eq 2 ] && grep -q 'supabase.url must be an http(s) url' "$p.err" && ! grep -q Traceback "$q.err" && echo A1-URL-GUARDED
   EXPECT: A1-URL-GUARDED
   EVIDENCE: MET exit=0 marker-found :: A1-URL-GUARDED
6. A1: the refusal names the Supabase url next to base_url, control characters replaced.
   CHECK: p=$(mktemp); printf '{"base_url":"http://127.0.0.1:9","supabase":{"url":"https://a.test/\\u001b[2J","tables":["t"]}}' > "$p"; python3 -B skills/guardrails/scripts/probe.py "$p" 2>&1 | grep -q 'confirm you own http://127.0.0.1:9 and https://a.test/?\[2J' && echo A1-REFUSAL-BOTH
   EXPECT: A1-REFUSAL-BOTH
   EVIDENCE: MET exit=0 marker-found :: A1-REFUSAL-BOTH
7. A2: budget exhaustion is one constant reported by `fetch`, before and inside a redirect.
   CHECK: cd skills/guardrails/scripts && python3 -B -c 'import probe; s=probe.Session(budget=0); r=probe.fetch(s,"GET","http://127.0.0.1:9/"); assert r.error==probe.BUDGET_EXHAUSTED, r.error; assert issubclass(probe._BudgetExhausted, Exception); import inspect; assert "session" in inspect.signature(probe._SameHost.__init__).parameters; print("A2-BUDGET-CONST")'
   EXPECT: A2-BUDGET-CONST
   EVIDENCE: MET exit=0 marker-found :: A2-BUDGET-CONST
8. A2: a redirect chain is charged per hop and an exhausted budget mid-chain reads ERROR on a route probe (locked in the probe suite).
   CHECK: grep -q 'DEFAULT_BUDGET - 3' lib/tests/guardrails-probe.test.sh && grep -q 'budget=2' lib/tests/guardrails-probe.test.sh && grep -q '/hop1' lib/tests/guardrails-probe.test.sh && echo A2-HOPS-LOCKED
   EXPECT: A2-HOPS-LOCKED
   EVIDENCE: MET exit=0 marker-found :: A2-HOPS-LOCKED
9. A3: a 200 body the probe cannot read as JSON rows is `unreadable` (→ SKIPPED), an empty list is `empty`, rows are `rows`.
   CHECK: cd skills/guardrails/scripts && python3 -B -c 'import probe; R=probe.Response; print(probe._rows_state(R(200,{},b"["*200000)), probe._rows_state(R(200,{},b"[]")), probe._rows_state(R(200,{},b"[{\"a\":1}]")))' | grep -q '^unreadable empty rows$' && echo A3-THREE-WAY
   EXPECT: A3-THREE-WAY
   EVIDENCE: MET exit=0 marker-found :: A3-THREE-WAY
10. A4: the scanner's text output never carries control characters, in the report, the check-mode rows and the usage error, while the finding still raises.
   CHECK: d=$(mktemp -d); mkdir -p "$d/src/components"; f="$d/src/components/$(printf 'x\033[31m').tsx"; printf 'export default function X({user}){ console.log(user); return null }\n' > "$f"; o=$(python3 -B skills/guardrails/scripts/scan.py "$d" 2>&1); a=$(python3 -B skills/guardrails/scripts/scan.py "$d" --assert-absent "EXP-CONSOLE-DATA:src/components/$(printf 'x\033[31m').tsx" 2>&1); printf '%s\n%s\n' "$o" "$a" | grep -q 'EXP-CONSOLE-DATA' && [ "$(printf '%s%s' "$o" "$a" | grep -c $'\033')" -eq 0 ] && printf '%s\n' "$a" | grep -q 'PRESENT' && echo A4-PRINTABLE
   EXPECT: A4-PRINTABLE
   EVIDENCE: MET exit=0 marker-found :: A4-PRINTABLE
11. B1: metadata keys are never sensitive, matched after snake-casing; real secrets still are.
   CHECK: cd skills/guardrails/scripts && python3 -B -c 'import probe; m=lambda k: bool(probe.METADATA_KEY.search(probe._snake(k))); assert all(m(k) for k in ["tokenType","has_password","next_page_token","token_expires_in","password_changed_at","csrf_token"]); assert not any(m(k) for k in ["password_hash","api_key","access_token","secret"]); print("B1-METADATA")'
   EXPECT: B1-METADATA
   EVIDENCE: MET exit=0 marker-found :: B1-METADATA
12. B2/B13: every map candidate is examined; a line-start `data:` directive is OPEN without decoding; an unconfirmed status is a note, never a negative.
   CHECK: (cd skills/guardrails/scripts && python3 -B -c 'import probe; s=probe.Session(budget=0); k=lambda u: probe._map_outcome(s,"http://h.test/a.js",u)[0]; assert k("data:application/json,%7B%22version%22%3A3%7D")=="open"; assert k("data:application/json;base64,eyJ2ZXJzaW9uIjozfQ==")=="open"; assert k("https://cdn.invalid/a.js.map")=="note"; print("B2-OUTCOMES")') && grep -q 'forbidden-real' lib/tests/guardrails-probe.test.sh && grep -q 'limited.js' lib/tests/guardrails-probe.test.sh && echo B2-WALK-LOCKED
   EXPECT: B2-WALK-LOCKED
   EVIDENCE: MET exit=0 marker-found :: B2-OUTCOMES B2-WALK-LOCKED
13. B3: hydrated scope is the export chunk of the loader: a Remix action after a clean loader is silent, a one-line loader returning a token raises.
   CHECK: d=$(mktemp -d); mkdir -p "$d/app/routes"; printf 'export async function loader() {\n  return json({ ok: true });\n}\nexport async function action({ request }) {\n  const form = await request.formData();\n  return json({ password: form.get("password") });\n}\n' > "$d/app/routes/a.tsx"; printf 'export const loader = () => json({ token: t });\n' > "$d/app/routes/b.tsx"; o=$(python3 -B skills/guardrails/scripts/scan.py "$d" --json 2>/dev/null); printf '%s' "$o" | grep -q 'EXP-HYDRATED-SENSITIVE' && ! printf '%s' "$o" | grep -q 'routes/a.tsx' && echo B3-CHUNK-SCOPED
   EXPECT: B3-CHUNK-SCOPED
   EVIDENCE: MET exit=0 marker-found :: B3-CHUNK-SCOPED
14. B4/B5: a webpack dev config and a UI-suffixed data attribute are silent; a prod config and a value-carrying attribute still raise.
   CHECK: d=$(mktemp -d); mkdir -p "$d/src/components"; printf 'module.exports = { devtool: "eval-source-map" };\n' > "$d/webpack.dev.js"; printf 'module.exports = { devtool: "source-map" };\n' > "$d/webpack.prod.js"; printf 'export const A = () => <div data-password-toggle="true" data-hide-api-key={k} />;\n' > "$d/src/components/A.tsx"; o=$(python3 -B skills/guardrails/scripts/scan.py "$d" 2>/dev/null); printf '%s\n' "$o" | grep -q 'EXP-SOURCEMAP-PUBLIC *webpack.prod.js' && ! printf '%s\n' "$o" | grep -q 'webpack.dev.js' && [ "$(printf '%s\n' "$o" | grep -c 'EXP-DATA-ATTR-SENSITIVE')" -eq 1 ] && echo B4-B5-SILENT
   EXPECT: B4-B5-SILENT
   EVIDENCE: MET exit=0 marker-found :: B4-B5-SILENT
15. B6: `$where` with a string, an identifier or a call is WARN INJ-NOSQL-OPERATOR; a GraphQL `_bool_exp` type is silent.
   CHECK: d=$(mktemp -d); mkdir -p "$d/src/api"; printf 'db.find({ $where: clause });\ndb.find({ $where: buildWhere(req.query) });\n' > "$d/src/api/m.ts"; printf 'const q = gql`query($where: users_bool_exp) { users(where: $where) { id } }`;\n' > "$d/src/api/g.ts"; o=$(python3 -B skills/guardrails/scripts/scan.py "$d" 2>/dev/null); [ "$(printf '%s\n' "$o" | grep -c 'WARN *INJ-NOSQL-OPERATOR *src/api/m.ts')" -eq 2 ] && ! printf '%s\n' "$o" | grep -q 'INJ-NOSQL-OPERATOR *src/api/g.ts' && echo B6-WHERE
   EXPECT: B6-WHERE
   EVIDENCE: MET exit=0 marker-found :: B6-WHERE
16. B7: Go backtick Sprintf, a multi-line triple-quoted f-string, `sql.raw(var)`, `.select()` on users and a multi-line hidden input all raise.
   CHECK: d=$(mktemp -d); mkdir -p "$d/src/api" "$d/src/components"; printf 'package a\nfunc q(o string) string { return fmt.Sprintf(`select id from notes where owner = %%s`, o) }\n' > "$d/src/api/a.go"; printf 'def q(owner):\n    return f"""\n    select id from notes\n    where owner = {owner}\n    """\n' > "$d/src/api/b.py"; printf 'export const r = (w) => db.execute(sql.raw(w));\nexport const u = () => supabase.from("users").select();\n' > "$d/src/api/c.ts"; printf 'export const F = () => (\n  <input\n    type="hidden"\n    name="api_key"\n    value={k}\n  />\n);\n' > "$d/src/components/F.tsx"; o=$(python3 -B skills/guardrails/scripts/scan.py "$d" 2>/dev/null); printf '%s\n' "$o" | grep -q 'FAIL *INJ-SQL-CONCAT *src/api/a.go' && printf '%s\n' "$o" | grep -q 'FAIL *INJ-SQL-CONCAT *src/api/b.py' && printf '%s\n' "$o" | grep -q 'WARN *INJ-SQL-RAW-UNSAFE *src/api/c.ts' && printf '%s\n' "$o" | grep -q 'EXP-RESPONSE-WIDE *src/api/c.ts' && printf '%s\n' "$o" | grep -q 'EXP-DATA-ATTR-SENSITIVE *src/components/F.tsx' && echo B7-MISSES-COVERED
   EXPECT: B7-MISSES-COVERED
   EVIDENCE: MET exit=0 marker-found :: B7-MISSES-COVERED
17. B12: a public map over 1 MB in rollup key order (mappings last) is FAIL.
   CHECK: d=$(mktemp -d); mkdir -p "$d/public"; printf 'export const a = 1;\n' > "$d/index.js"; { printf '{"version":3,"file":"app.js","sources":["a.ts"],"sourcesContent":["'; head -c 1100000 /dev/zero | tr '\0' 'x'; printf '"],"names":[],"mappings":"AAAA"}'; } > "$d/public/app.js.map"; python3 -B skills/guardrails/scripts/scan.py "$d" 2>/dev/null | grep -q 'FAIL *EXP-SOURCEMAP-PUBLIC *public/app.js.map' && echo B12-ROLLUP-MAP
   EXPECT: B12-ROLLUP-MAP
   EVIDENCE: MET exit=0 marker-found :: B12-ROLLUP-MAP
18. B9: the timing lock covers the CONCAT alternatives, NOSQL and HIDDEN_INPUT with non-matching inputs.
   CHECK: awk '/== regex timing/,/REGEX-FAST/' lib/tests/guardrails-scan.test.sh > /tmp/timing-block.$$; grep -q 'injection.CONCAT' /tmp/timing-block.$$ && grep -q 'injection.NOSQL' /tmp/timing-block.$$ && grep -q 'exposure.HIDDEN_INPUT' /tmp/timing-block.$$ && grep -q 'is None' /tmp/timing-block.$$ && grep -q 'export const load' /tmp/timing-block.$$ && rm -f /tmp/timing-block.$$ && echo B9-TIMING-COVERS
   EXPECT: B9-TIMING-COVERS
   EVIDENCE: MET exit=0 marker-found :: B9-TIMING-COVERS
19. B10: per-variant locks exist (routing-dependent mutants plus the sub-pattern table).
   CHECK: grep -q '== per-variant' lib/tests/guardrails-scan.test.sh && [ "$(grep -c '^mutant ' lib/tests/guardrails-scan.test.sh)" -ge 100 ] && grep -q 'Command::new' lib/tests/guardrails-scan.test.sh && grep -q 'getTraceAsString' lib/tests/guardrails-scan.test.sh && echo B10-VARIANTS
   EXPECT: B10-VARIANTS
   EVIDENCE: MET exit=0 marker-found :: B10-VARIANTS
20. B8/B11 docs: the judging bullet, the RAW receivers, the metadata exclusion, the data: wording, the bearer sentence and the both-hosts step are in the skill docs.
   CHECK: grep -q 'placeholders' skills/guardrails/SKILL.md && grep -q 'logged-in user sees' skills/guardrails/SKILL.md && grep -qi 'before adding `--authorized`' skills/guardrails/SKILL.md && grep -q '`--json` output' skills/guardrails/SKILL.md && grep -q 'sql.raw' skills/guardrails/references/checks.md && grep -q '_bool_exp' skills/guardrails/references/checks.md && grep -qi 'metadata' skills/guardrails/references/checks.md && grep -q 'exhausted budget' skills/guardrails/references/checks.md && echo DOCS-SYNCED
   EXPECT: DOCS-SYNCED
   EVIDENCE: MET exit=0 marker-found :: DOCS-SYNCED
21. Pre-existing dirty files never staged or committed.
   CHECK: ! git diff --cached --name-only | grep -Eq '^(settings.json|mods/model-router/routing.json)$' && [ -z "$(git log --oneline develop..HEAD -- settings.json mods/model-router/routing.json)" ] && echo DIRTY-UNTOUCHED
   EXPECT: DIRTY-UNTOUCHED
   EVIDENCE: MET exit=0 marker-found :: DIRTY-UNTOUCHED
22. No new lint or test suppression in the diff (floor-guard clean).
   CHECK: bash lib/floor-guard.sh develop -- . >/dev/null 2>&1 && echo FLOOR-CLEAN
   EXPECT: FLOOR-CLEAN
   EVIDENCE: MET exit=0 marker-found :: FLOOR-CLEAN

## FILE SCOPE
skills/guardrails/scripts/probe.py
skills/guardrails/scripts/scanner.py
skills/guardrails/scripts/checks/common.py
skills/guardrails/scripts/checks/exposure.py
skills/guardrails/scripts/checks/injection.py
skills/guardrails/references/checks.md
skills/guardrails/SKILL.md
lib/tests/guardrails-scan.test.sh
lib/tests/guardrails-probe.test.sh
.claude/tasks/plans/2026-10-20-guardrails-residuals-1410.md
.claude/tasks/contracts/2026-10-20-guardrails-residuals-1455.md
.claude/tasks/TODO.md
.claude/tasks/plans/2026-10-20-guardrails-residuals-part1-report.md [gated 2026-10-20: executor report, orchestrator artifact]
.claude/tasks/plans/2026-10-20-guardrails-residuals-part2-report.md [gated 2026-10-20: executor report, orchestrator artifact]
.claude/tasks/plans/2026-10-20-guardrails-residuals-part3-report.md [gated 2026-10-20: executor report, orchestrator artifact]
