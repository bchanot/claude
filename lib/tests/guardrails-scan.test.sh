#!/usr/bin/env bash
# lib/tests/guardrails-scan.test.sh — floor of the /guardrails scanner.
# The clean fixture must scan with zero FAIL and zero WARN. Each mutant breaks
# one rule on a copy of it and must raise that rule at the expected severity
# (positive control). Exit codes, JSON, domain filter, symlinks and secret
# redaction are checked too.
# shellcheck disable=SC2016
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCAN="$ROOT/skills/guardrails/scripts/scan.py"
GOOD="$ROOT/lib/tests/fixtures/guardrails-good"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0; LAST_OUT=""; LAST_RC=0

check() { # check <label> <got> <want>
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "  PASS $1"
  else FAIL=$((FAIL+1)); echo "  FAIL $1 (got '$2', want '$3')"; fi
}

scan() { python3 -B "$SCAN" "$@"; }

# edit <file> <sed-expr>: in-place edit without sed -i (BSD/GNU portable).
edit() { sed "$2" "$1" > "$1.new" && mv "$1.new" "$1"; }

# b64 <text>: base64url without padding.
b64() { printf '%s' "$1" | base64 | tr -d '=\n' | tr '+/' '-_'; }

# mutant <label> <SEVERITY> <RULE> <snippet run inside a copy of the fixture>
has() { # has <SEVERITY> <RULE>: the last scan raised it
  printf '%s\n' "$LAST_OUT" | grep -Eq "^ +$1 +$2 " && echo yes || echo no
}

# solo <label> <relative file> <content>: scan a one-file project
solo() {
  local dir="$WORK/$1"
  mkdir -p "$dir/$(dirname "$2")"; printf '%s\n' "$3" > "$dir/$2"
  LAST_OUT=$(scan "$dir"); LAST_RC=$?
}

mutant() {
  local label="$1" sev="$2" rule="$3" snippet="$4" dir
  dir="$WORK/$label"
  cp -R "$GOOD" "$dir" || { check "$label copy" failed ok; return; }
  if ! ( cd "$dir" && eval "$snippet" ) >/dev/null 2>&1; then
    check "$label setup" failed ok; return
  fi
  LAST_OUT=$(scan "$dir"); LAST_RC=$?
  check "$label raises $sev $rule" "$(has "$sev" "$rule")" yes
}

SQL=supabase/migrations/0001_init.sql
TSX=src/components/ContactForm.tsx
NOTIFY=supabase/functions/notify/index.ts
SMS=supabase/functions/sms/index.ts
API=src/pages/api/notes.ts

echo "== clean fixture"
out=$(scan "$GOOD"); rc=$?
check "clean exit code" "$rc" 0
check "clean has no FAIL or WARN" \
  "$(printf '%s\n' "$out" | grep -c ' 0 FAIL, 0 WARN')" 1
check "a11y is not scanned" "$(printf '%s\n' "$out" | grep -c '^\[a11y\]')" 0

echo "== supabase"
mutant rls-missing FAIL SB-RLS-MISSING \
  "edit $SQL '/alter table public.notes enable/d'"
mutant policy-open-write FAIL SB-POLICY-OPEN-WRITE \
  "printf '%s\n' 'create policy \"o\" on public.notes for insert to authenticated with check (true);' >> $SQL"
mutant policy-anon-write FAIL SB-POLICY-ANON-WRITE \
  "printf '%s\n' 'create policy \"a\" on public.notes for insert to anon with check (user_id is not null);' >> $SQL"
mutant policy-not-owner WARN SB-POLICY-NOT-OWNER \
  "printf '%s\n' 'create policy \"n\" on public.notes for select to authenticated using (user_id is not null);' >> $SQL"
mutant policy-public-read WARN SB-POLICY-PUBLIC-READ \
  "printf '%s\n' 'create policy \"p\" on public.notes for select to anon using (true);' >> $SQL"
mutant view-invoker WARN SB-VIEW-INVOKER \
  "printf '%s\n' 'create view public.v as select 1;' >> $SQL"
mutant matview WARN SB-MATVIEW-EXPOSED \
  "printf '%s\n' 'create materialized view public.mv as select 1;' >> $SQL"
mutant definer-search-path WARN SB-DEFINER-SEARCH-PATH \
  "printf '%s\n' 'create function public.f1() returns int language sql security definer as \$\$ select 1 \$\$;' >> $SQL"
mutant definer-execute WARN SB-DEFINER-EXECUTE \
  "printf '%s\n' 'create function public.f2() returns int language sql security definer set search_path = pg_catalog as \$\$ select 1 \$\$;' >> $SQL"
mutant bucket-public WARN SB-BUCKET-PUBLIC \
  "printf '%s\n' \"insert into storage.buckets (id, name, public) values ('a', 'a', true);\" >> $SQL"
mutant edge-no-jwt WARN SB-EDGE-NO-JWT \
  "edit supabase/config.toml 's/verify_jwt = true/verify_jwt = false/'"
mutant service-role-client FAIL SB-SERVICE-ROLE-CLIENT \
  "printf '%s\n' 'const k = process.env.SUPABASE_SERVICE_ROLE_KEY;' > src/components/Admin.tsx"
mutant service-role-literal FAIL SB-SERVICE-ROLE-LITERAL \
  'printf "export const k = \"%s.%s.signaturepart\";\n" "$(b64 "{\"alg\":\"HS256\"}")" "$(b64 "{\"role\":\"service_role\"}")" > src/config.ts'

echo "== api"
mutant public-env FAIL API-PUBLIC-ENV-SECRET \
  "printf 'NEXT_PUBLIC_SERVICE_ROLE_KEY=\n' >> .env.example"
mutant env-not-ignored FAIL API-ENV-NOT-IGNORED \
  "printf 'A=1\n' > .env; rm .gitignore"
mutant secret-literal FAIL API-SECRET-LITERAL \
  'printf "const k = \"sk_live_%s\";\n" "$(printf "a%.0s" 1 2 3 4 5 6 7 8 9 10 11 12)" > src/pay.ts'
check "secret exit code is 1" "$LAST_RC" 1
case "$LAST_OUT" in
  *aaaaaaaaaa*) check "secret is redacted in output" leaked redacted ;;
  *) check "secret is redacted in output" redacted redacted ;;
esac
mutant cors-credentials FAIL API-CORS-WILDCARD \
  "printf '%s\n' 'res.setHeader(\"Access-Control-Allow-Origin\", \"*\"); const o = { credentials: true };' > src/cors.ts"
mutant cors-wildcard WARN API-CORS-WILDCARD \
  "printf '%s\n' 'res.setHeader(\"Access-Control-Allow-Origin\", \"*\");' > src/cors.ts"
mutant route-no-auth WARN API-ROUTE-NO-AUTH \
  "printf '%s\n' 'export function GET() { return new Response(\"hi\"); }' > src/pages/api/open.ts"

echo "== passwords"
LOGIN=src/lib/login.ts
mutant password-column FAIL API-PASSWORD-PLAINTEXT \
  "printf '%s\n' 'create table public.accounts (id uuid primary key, password text);' 'alter table public.accounts enable row level security;' >> $SQL"
mutant password-compare FAIL API-PASSWORD-PLAINTEXT \
  "printf '%s\n' 'if (user.password === password) ok();' > $LOGIN"
mutant password-sql-compare FAIL API-PASSWORD-PLAINTEXT \
  "printf '%s\n' 'const q = \"select 1 from accounts where email = \$1 and password = \$2\";' > $LOGIN"
mutant password-weak-hash FAIL API-PASSWORD-WEAK-HASH \
  "printf '%s\n' 'const d = createHash(\"sha256\").update(password).digest(\"hex\");' > $LOGIN"
mutant password-logged FAIL API-PASSWORD-LOGGED \
  "printf '%s\n' 'console.log(\"login\", email, password);' > $LOGIN"
mutant password-logged-template FAIL API-PASSWORD-LOGGED \
  "printf '%s\n' 'logger.info(\`login \${password}\`);' > $LOGIN"
mutant password-literal WARN API-PASSWORD-LITERAL \
  "printf '%s\n' 'export const db = { user: \"app\", password: \"hunter2hunter2\" };' > src/db.ts"
case "$LAST_OUT" in
  *hunter2hunter2*) check "password literal is redacted" leaked redacted ;;
  *) check "password literal is redacted" redacted redacted ;;
esac
mutant password-literal-yaml WARN API-PASSWORD-LITERAL \
  "printf 'services:\n  db:\n    environment:\n      POSTGRES_PASSWORD: localpass1\n' > docker-compose.yml"

echo "== hosting"
mutant no-rate-limit FAIL HOST-NO-RATE-LIMIT "rm src/middleware.ts"
mutant origin-exposed WARN HOST-ORIGIN-EXPOSED \
  "printf 'app = \"x\"\n' > fly.toml; edit docs/DEPLOY.md 's/Cloudflare/an edge proxy/'"

echo "== messaging"
mutant no-consent FAIL MSG-NO-CONSENT-RECORD \
  "for f in $SQL $NOTIFY $SMS; do edit \$f 's/consent_at/seen_at/g;s/consent_source/seen_src/g'; done"
mutant no-unsubscribe FAIL MSG-NO-UNSUBSCRIBE \
  "for f in $SQL $NOTIFY; do edit \$f 's/[Uu]nsubscrib[A-Za-z_-]*/gone/g'; done"
mutant no-list-unsubscribe WARN MSG-NO-LIST-UNSUBSCRIBE \
  "edit $NOTIFY 's/List-Unsubscribe/X-Mail/g'"
mutant sms-no-stop FAIL MSG-SMS-NO-STOP "edit $SMS 's/ Reply STOP to opt out\.//'"
mutant sms-no-optout-store FAIL MSG-SMS-NO-OPTOUT-STORE \
  "for f in $SQL $SMS $NOTIFY; do edit \$f 's/opt_out_at/x_at/g;s/unsubscribed_at/y_at/g'; done"
mutant send-unchecked WARN MSG-SEND-UNCHECKED \
  "printf '%s\n' 'import nodemailer from \"nodemailer\";' 'export const t = nodemailer.createTransport({});' > src/mailer.ts"

echo "== functions"
mutant no-max-instances FAIL FN-NO-MAX-INSTANCES \
  "edit functions/index.js 's/maxInstances: 10//'"
mutant self-trigger FAIL FN-SELF-TRIGGER \
  "printf '%s\n' 'await db.from(\"notes\").update({ sent: true });' >> $NOTIFY"
mutant self-trigger-guarded WARN FN-SELF-TRIGGER \
  "printf '%s\n' 'await db.from(\"notes\").update({ sent: true });' >> $NOTIFY; edit $SQL 's/for each row execute/for each row when (new.body is not null) execute/'"
mutant self-invoke FAIL FN-SELF-INVOKE \
  "printf '%s\n' 'await fetch(\"https://x.supabase.co/functions/v1/notify\");' >> $NOTIFY"
mutant firebase-loop WARN FN-SELF-TRIGGER \
  "printf '%s\n' 'exports.again = async () => { await db.collection(\"orders\").add({}); };' >> functions/index.js"

mutant key-body FAIL API-SECRET-LITERAL \
  'printf -- "-----BEGIN %s KEY-----\n%s\n" PRIVATE "$(head -c 40 /dev/zero | tr "\0" A)" > src/key.ts'

echo "== injection"
mutant sql-template FAIL INJ-SQL-CONCAT \
  "printf '%s\n' 'const q = \`select id from notes where owner = \${owner}\`;' >> $API"
mutant sql-concat FAIL INJ-SQL-CONCAT \
  "printf '%s\n' 'const q = \"select id from notes where owner = \" + owner;' >> $API"
mutant sql-fstring FAIL INJ-SQL-CONCAT \
  "printf '%s\n' 'cur.execute(f\"delete from notes where id = {note_id}\")' > src/lib/cleanup.py"
mutant sql-php-interpolation FAIL INJ-SQL-CONCAT \
  "printf '%s\n' '<?php \$r = \$db->query(\"select id from notes where owner = \$owner\");' > src/lib/notes.php"
mutant sql-py-concat FAIL INJ-SQL-CONCAT \
  "printf '%s\n' 'cur.execute(\"select id from notes where owner = \" + owner)' > src/lib/cleanup.py"
mutant sql-quoted-value FAIL INJ-SQL-CONCAT \
  "printf '%s\n' \$'const q = \"select id from notes where owner = \\'\" + owner + \"\\'\";' >> $API"
mutant sql-php-dot FAIL INJ-SQL-CONCAT \
  "printf '%s\n' \$'<?php \$r = \$db->query(\"select id from notes where owner = \\'\" . \$owner . \"\\'\");' > src/lib/notes.php"
mutant sql-raw-unsafe WARN INJ-SQL-RAW-UNSAFE \
  "printf '%s\n' 'const rows = await prisma.\$queryRawUnsafe(statement);' >> $API"
mutant sql-sqla-text-var WARN INJ-SQL-RAW-UNSAFE \
  "printf '%s\n' 'import sqlalchemy' 'conn.execute(text(query))' > src/lib/db.py"
mutant shell-db-os-system FAIL INJ-SHELL-DB-TOOL \
  "printf '%s\n' 'os.system(\"psql \" + url)' > src/lib/backup.py"
mutant shell-db-template FAIL INJ-SHELL-DB-TOOL \
  "printf '%s\n' 'exec(\`psql \${db}\`);' > src/lib/backup.ts"
mutant sql-ruby-where-interp FAIL INJ-SQL-CONCAT \
  "printf '%s\n' 'User.where(\"name = #{name}\")' > src/lib/users.rb"
mutant shell-db-php-upper-var FAIL INJ-SHELL-DB-TOOL \
  "printf '%s\n' '<?php shell_exec(\"mysqldump --host=\$Host app\");' > src/lib/dump.php"
mutant concat-in-sqla-text FAIL INJ-SQL-CONCAT \
  "printf '%s\n' 'import sqlalchemy' 'conn.execute(text(f\"select id from notes where owner = {owner}\"))' > src/lib/db.py"
mutant concat-in-objects-raw FAIL INJ-SQL-CONCAT \
  "printf '%s\n' 'User.objects.raw(f\"select id from notes where owner = {name}\")' > src/lib/db.py"
mutant concat-in-knex-raw FAIL INJ-SQL-CONCAT \
  "printf '%s\n' 'knex.raw(base + \" where id = \" + id);' >> $API"
mutant sql-sqla-sa-text WARN INJ-SQL-RAW-UNSAFE \
  "printf '%s\n' 'import sqlalchemy as sa' 'conn.execute(sa.text(q))' > src/lib/db.py"
mutant sql-dynamic-exec WARN INJ-SQL-DYNAMIC-EXEC \
  "printf '%s\n' \"execute 'select count(*) from ' || tbl into n;\" >> $SQL"
mutant postgrest-filter WARN INJ-POSTGREST-FILTER \
  "printf '%s\n' 'const { data } = await supabase.from(\"notes\").select().or(\`owner.eq.\${who}\`);' >> $API"
mutant nosql-operator WARN INJ-NOSQL-OPERATOR \
  "printf '%s\n' 'const doc = await Notes.findOne({ owner: req.body.owner });' >> $API"
mutant shell-db-tool FAIL INJ-SHELL-DB-TOOL \
  "printf '%s\n' 'execSync(\`pg_dump --table=\${table} app > backup.sql\`);' > src/lib/backup.ts"

echo "== exposure"
mutant console-data-public-dir WARN EXP-CONSOLE-DATA \
  "mkdir -p public/js; printf '%s\n' 'console.log(user);' > public/js/app.js"
mutant data-attr-hidden-input WARN EXP-DATA-ATTR-SENSITIVE \
  "printf '%s\n' '<input type=\"hidden\" name=\"api_key\" value={k} />' >> $TSX"
mutant debug-errorhandler FAIL EXP-DEBUG-ON \
  "printf '%s\n' 'app.use(errorhandler());' >> $API"
mutant console-data WARN EXP-CONSOLE-DATA \
  "printf '%s\n' 'console.log(\"saved\", session);' >> $TSX"
mutant sourcemap-next FAIL EXP-SOURCEMAP-PUBLIC \
  "printf '%s\n' 'module.exports = { productionBrowserSourceMaps: true };' > next.config.js"
mutant sourcemap-vite-inline FAIL EXP-SOURCEMAP-PUBLIC \
  "printf '%s\n' 'export default { build: { sourcemap: \"inline\" } };' > vite.config.ts"
mutant sourcemap-webpack-warn WARN EXP-SOURCEMAP-PUBLIC \
  "printf '%s\n' 'module.exports = { devtool: \"eval-source-map\" };' > webpack.config.js"
mutant sourcemap-public-dir FAIL EXP-SOURCEMAP-PUBLIC \
  "mkdir -p public/assets; printf '%s\n' '{\"version\":3,\"sources\":[\"src/app.ts\"],\"mappings\":\"AAAA\"}' > public/assets/app.js.map"
mutant sourcemap-large-map FAIL EXP-SOURCEMAP-PUBLIC \
  "mkdir -p public; { printf '%s' '{\"version\":3,\"sources\":[\"src/app.ts\"],\"mappings\":\"'; head -c 1100000 /dev/zero | tr '\\0' A; printf '%s\n' '\"}'; } > public/app.js.map"
mutant hydrated-sensitive WARN EXP-HYDRATED-SENSITIVE \
  "printf '%s\n' 'export async function getServerSideProps() { return { props: { accessToken: process.env.CRM_TOKEN } }; }' > src/pages/account.tsx"
mutant markup-comment WARN EXP-MARKUP-COMMENT \
  "printf '%s\n' '<!-- staging login: see the internal wiki before release -->' > src/pages/index.html"
mutant data-attr-sensitive WARN EXP-DATA-ATTR-SENSITIVE \
  "printf '%s\n' '<div data-api-key={key}>x</div>' >> $TSX"
mutant error-stack FAIL EXP-ERROR-STACK \
  "printf '%s\n' 'export function onError(err: Error) { return new Response(err.stack, { status: 500 }); }' >> $API"
mutant error-message WARN EXP-ERROR-MESSAGE \
  "printf '%s\n' 'export function onFail(err: Error) { return Response.json({ error: err.message }, { status: 500 }); }' >> $API"
mutant debug-on FAIL EXP-DEBUG-ON \
  "printf '%s\n' 'DEBUG = True' > src/settings.py"
mutant debug-env FAIL EXP-DEBUG-ON \
  "printf '%s\n' 'APP_DEBUG=true' > .env.production"
mutant response-wide WARN EXP-RESPONSE-WIDE \
  "printf '%s\n' 'const { data } = await db.from(\"profiles\").select(\"*\");' >> $API"
mutant response-wide-prisma WARN EXP-RESPONSE-WIDE \
  "printf '%s\n' 'const u = await prisma.user.findUnique({ where: { id } });' >> $API"
mutant response-wide-sql WARN EXP-RESPONSE-WIDE \
  "printf '%s\n' 'const q = \"select * from users where id = \$1\";' >> $API"
mutant error-stack-single-file FAIL EXP-ERROR-STACK \
  "printf '%s\n' 'app.use((err, req, res, next) => res.status(500).send(err.stack));' > server.js"
mutant hydrated-identifier WARN EXP-HYDRATED-SENSITIVE \
  "printf '%s\n' 'export async function getServerSideProps() { const token = await crm(); return { props: { accessToken: token } }; }' > src/pages/account.tsx"
mutant console-next-page WARN EXP-CONSOLE-DATA \
  "printf '%s\n' 'export default function Home({ user }) { console.log(\"render\", user); return null; }' > src/pages/index.tsx"

echo "== residual misses (hydrated chunks, dev configs, Go/py/Drizzle forms)"
raises() { # raises <label> <file> <content> <SEVERITY> <RULE>: one-file mutant
  solo "$1" "$2" "$3"
  check "$1 raises $4 $5" "$(has "$4" "$5")" yes
}
HYD=EXP-HYDRATED-SENSITIVE
raises hydrated-ssr-multiline-params src/pages/account.tsx \
  $'export async function getServerSideProps({\n  req,\n}: Ctx) {\n  return { props: { accessToken: tok } };\n}' WARN $HYD
raises hydrated-loader-oneline app/routes/b.tsx \
  'export const loader = () => json({ token: t });' WARN $HYD
raises hydrated-remix-multiline app/routes/c.tsx \
  $'export async function loader() {\n  const t = await tok();\n  return json({ token: t });\n}' WARN $HYD
raises hydrated-sveltekit-load src/routes/+page.server.ts \
  $'export async function load() {\n  return { token: await t() };\n}' WARN $HYD
raises hydrated-window-state src/state.ts \
  $'window.__STATE__ = {\n  token: t\n};' WARN $HYD
mutant webpack-prod-devtool FAIL EXP-SOURCEMAP-PUBLIC \
  "printf '%s\n' 'module.exports = { devtool: \"eval-source-map\" };' > webpack.prod.js"
raises data-attr-literal-password src/components/D1.tsx \
  'export const D = () => <div data-password="hunter2" />;' WARN EXP-DATA-ATTR-SENSITIVE
raises data-attr-hide-api-key src/components/D2.tsx \
  'export const D = () => <div data-hide-api-key={k} />;' WARN EXP-DATA-ATTR-SENSITIVE
raises data-attr-api-key-input-value src/components/D3.tsx \
  'export const D = () => <div data-api-key-input-value={v} />;' WARN EXP-DATA-ATTR-SENSITIVE
raises hidden-input-multiline src/components/F.tsx \
  $'export const F = () => (\n  <input\n    type="hidden"\n    name="api_key"\n    value={k}\n  />\n);' WARN EXP-DATA-ATTR-SENSITIVE
raises nosql-where-string src/api/m1.ts \
  'db.find({ $where: "this.name == '"'"'" + name + "'"'"'" });' WARN INJ-NOSQL-OPERATOR
raises nosql-where-identifier src/api/m2.ts \
  'db.find({ $where: clause });' WARN INJ-NOSQL-OPERATOR
raises nosql-where-call src/api/m3.ts \
  'db.find({ $where: buildWhere(req.query) });' WARN INJ-NOSQL-OPERATOR
raises sql-concat-go-backtick src/api/a.go \
  $'package a\nfunc q(o string) string { return fmt.Sprintf(`select id from notes where owner = %s`, o) }' FAIL INJ-SQL-CONCAT
raises sql-concat-go-quoted src/api/a2.go \
  $'package a\nfunc q(o string) string { return fmt.Sprintf("select id from notes where owner = %s", o) }' FAIL INJ-SQL-CONCAT
raises sql-concat-py-rf src/api/r.py \
  $'def q(o):\n    return rf"select id from notes where owner = {o}"' FAIL INJ-SQL-CONCAT
raises sql-concat-py-triple src/api/b.py \
  $'def q(owner):\n    return f"""\n    select id from notes\n    where owner = {owner}\n    """' FAIL INJ-SQL-CONCAT
raises raw-drizzle-sql-raw src/api/c.ts \
  'export const r = (w) => db.execute(sql.raw(w));' WARN INJ-SQL-RAW-UNSAFE
raises raw-db-raw src/api/d.ts \
  'export const r = (w) => db.raw(w);' WARN INJ-SQL-RAW-UNSAFE
raises raw-trx-raw src/api/e.ts \
  'export const r = (w) => trx.raw(w);' WARN INJ-SQL-RAW-UNSAFE
raises select-no-argument src/api/u.ts \
  'export const u = () => supabase.from("users").select();' WARN EXP-RESPONSE-WIDE
mkdir -p "$WORK/rollup/public"; printf '%s\n' 'export const a = 1;' > "$WORK/rollup/index.js"
{ printf '%s' '{"version":3,"file":"app.js","sources":["a.ts"],"sourcesContent":["'
  head -c 1100000 /dev/zero | tr '\0' x
  printf '%s' '"],"names":[],"mappings":"AAAA"}'; } > "$WORK/rollup/public/app.js.map"
LAST_OUT=$(scan "$WORK/rollup")
check "rollup-ordered 1 MB map raises FAIL EXP-SOURCEMAP-PUBLIC" \
  "$(has FAIL EXP-SOURCEMAP-PUBLIC)" yes

echo "== benign patterns stay silent"
benign() { # benign <label> <snippet>: a legitimate pattern raises nothing
  local label="$1" snippet="$2" dir="$WORK/$1"
  cp -R "$GOOD" "$dir" || { check "$label copy" failed ok; return; }
  if ! ( cd "$dir" && eval "$snippet" ) >/dev/null 2>&1; then
    check "$label setup" failed ok; return
  fi
  out=$(scan "$dir")
  check "$label raises no FAIL or WARN" \
    "$(printf '%s\n' "$out" | grep -c ' 0 FAIL, 0 WARN')" 1
}
benign large-level-map \
  "mkdir -p public/levels; head -c 1100000 /dev/zero | tr '\\0' x > public/levels/big.map"
benign helper-under-api \
  "mkdir -p src/pages/api/helpers; printf '%s\n' 'export const fmt = () => 1;' > src/pages/api/helpers/format.ts"
benign mailer-test-file \
  "mkdir -p tests; printf '%s\n' 'import nodemailer from \"nodemailer\";' > tests/mailer.test.ts"
benign log-file-skipped \
  'printf "key sk_live_%s\n" "$(printf "a%.0s" 1 2 3 4 5 6 7 8 9 10 11 12)" > app.log'
benign proxy-change-origin \
  "printf '%s\n' 'export default { server: { proxy: { a: { changeOrigin: true } } } };' > vite.config.ts"
benign cli-script-under-api \
  "mkdir -p src/pages/api/bin; printf '%s\n' 'export const run = () => 1;' > src/pages/api/bin/cleanup.ts"
benign key-header-only-in-test \
  "mkdir -p tests; printf '%s\n' \"assert(kinds('-----BEGIN OPENSSH PRIVATE KEY-----'));\" > tests/secrets.test.ts"
benign transactional-mailer \
  "mkdir -p src/lib; printf '%s\n' 'import nodemailer from \"nodemailer\";' 'export const t = nodemailer.createTransport({});' > src/lib/contact-mail.ts"
benign supabase-auth-password \
  "printf '%s\n' 'await sb.auth.updateUser({ password: newPassword });' > src/lib/account.ts"
benign password-confirm-compare \
  "printf '%s\n' 'const same = v.password === v.passwordConfirm;' > src/lib/validate.ts"
benign hashed-column \
  "printf '%s\n' 'create table public.accounts (id uuid primary key, password_hash text);' 'alter table public.accounts enable row level security;' >> $SQL"
benign column-with-bcrypt \
  "printf '%s\n' 'create table public.accounts (id uuid primary key, password text);' 'alter table public.accounts enable row level security;' >> $SQL; printf '%s\n' 'import bcrypt from \"bcrypt\";' > src/lib/hash.ts"
benign password-literal-in-test \
  "mkdir -p tests; printf '%s\n' 'const PASSWORD = \"LocalDev-only-password-1\";' > tests/login.e2e.ts"
benign password-placeholder \
  "printf '%s\n' 'export const db = { password: \"CHANGE_ME_NOW\" };' > src/db.ts"
benign password-validation-rule \
  "printf '%s\n' 'const rules = { password: \"required|min:8\" };' > src/rules.ts"
benign reset-token-sha256 \
  "printf '%s\n' 'const d = createHash(\"sha256\").update(passwordResetToken).digest(\"hex\");' > src/lib/reset.ts"
benign log-with-password-label \
  "printf '%s\n' 'console.log(\"password reset sent to\", email);' > src/lib/reset.ts"
benign i18n-password-label \
  "mkdir -p src/i18n; printf '%s\n' 'export const de = { password: \"Passwort\" };' > src/i18n/de.ts"
benign remix-action-after-loader \
  "mkdir -p app/routes; printf 'export async function loader() {\n  return json({ ok: true });\n}\nexport async function action({ request }) {\n  const form = await request.formData();\n  return json({ password: form.get(\"password\") });\n}\n' > app/routes/a.tsx"
benign comment-names-loader-above-clean-one \
  "mkdir -p app/routes; printf '// getServerSideProps is not used here\nexport async function loader() {\n  return json({ ok: true });\n}\n' > app/routes/n.tsx"
benign webpack-dev-config \
  "printf '%s\n' 'module.exports = { devtool: \"eval-source-map\" };' > webpack.dev.js"
benign webpack-config-dev \
  "printf '%s\n' 'module.exports = { devtool: \"eval-source-map\" };' > webpack.config.dev.js"
benign data-attr-ui-suffixes \
  "printf '%s\n' '<i data-password-toggle=\"true\" data-password-strength=\"3\" data-secret-visible=\"1\" />' > src/components/Toggle.tsx"
benign graphql-bool-exp-variable \
  "printf '%s\n' 'const q = gql\`query(\$where: users_bool_exp) { users(where: \$where) { id } }\`;' > src/lib/g.ts"
benign graphql-capitalised-variable \
  "printf '%s\n' 'const q = gql\`query(\$where: UsersWhere) { users(where: \$where) { id } }\`;' > src/lib/g2.ts"
benign plain-triple-quoted-placeholder \
  "printf '%s\n' 'Q = \"\"\"select id from notes where owner = %s\"\"\"' > src/lib/q.py"
benign sql-raw-literal \
  "printf '%s\n' 'export const n = () => db.execute(sql.raw(\"now()\"));' > src/lib/n.ts"
benign select-with-fields \
  "printf '%s\n' 'export const u = () => supabase.from(\"users\").select(\"id, name\");' >> $API"
ENVKEY='printf "SUPABASE_SERVICE_ROLE_KEY=%s.%s.signaturepart\n" "$(b64 "{\"alg\":\"HS256\"}")" "$(b64 "{\"role\":\"service_role\"}")" > .env.worker'
benign env-worker-ignored "printf '.env.*\n' >> .gitignore; $ENVKEY"
mutant env-worker-tracked FAIL SB-SERVICE-ROLE-LITERAL "$ENVKEY"

benign parameterized-query \
  "printf '%s\n' 'const r = await db.query(\"select id from notes where owner = \$1\", [owner]);' >> $API"
benign tagged-sql-template \
  "printf '%s\n' 'const r = await sql\`select id from notes where owner = \${owner}\`;' >> $API"
benign typed-sql-tag \
  "printf '%s\n' 'const r = await sql<Note[]>\`select id from notes where owner = \${owner}\`;' >> $API"
benign express-raw-webhook \
  "printf '%s\n' 'app.post(\"/hook\", express.raw({ type: \"application/json\" }), onHook);' >> $API"
benign ui-copy-select \
  "printf '%s\n' 'const hint = \`Select a plan from the list, \${name}\`;' >> $TSX"
benign ui-copy-delete \
  "printf '%s\n' 'const label = \"Delete from favorites \" + item.title;' >> $TSX"
benign jquery-not \
  "printf '%s\n' 'const rows = \$(\".row\").not(\".row-\" + id);' >> $TSX"
benign argv-db-tool \
  "printf '%s\n' 'spawnSync(\"pg_dump\", [\"--table\", table, \"app\"]);' > src/lib/backup.ts"
benign format-dynamic-exec \
  "printf '%s\n' \"execute format('select count(*) from %I', tbl) into n;\" >> $SQL"
benign test-path-sql \
  "mkdir -p src/__tests__; printf '%s\n' 'const q = \`select id from notes where owner = \${owner}\`;' > src/__tests__/notes.test.ts"
benign minified-bundle \
  "printf '%s\n' 'const q=\`select id from notes where owner = \${o}\`;' > src/lib/app.min.js"
benign long-line-bundle \
  "head -c 6000 /dev/zero | tr '\\0' x > src/lib/bundle.js; printf '%s\n' ' const q=\`select id from notes where owner = \${o}\`;' >> src/lib/bundle.js"

benign sqla-text-method \
  "printf '%s\n' 'import sqlalchemy' 'label = project.text(path)' > src/lib/db.py"
benign sqla-resp-text \
  "printf '%s\n' 'import sqlalchemy' 'body = resp.text(x)' > src/lib/db.py"
benign shell-db-argv-spawn \
  "printf '%s\n' 'spawn(\"psql\", [\"-f\", file], {env});' > src/lib/backup.ts"
benign shell-db-argv-python \
  "printf '%s\n' 'subprocess.run([\"psql\", f\"--dbname={url}\"])' > src/lib/backup.py"
benign shell-db-env-ref \
  "printf '%s\n' 'execSync(\"psql \$DATABASE_URL -f schema.sql\");' > src/lib/backup.ts"
benign ruby-where-placeholder \
  "printf '%s\n' 'User.where(\"name = ?\", name)' 'User.where(name: value)' > src/lib/users.rb"
benign console-public-minified \
  "mkdir -p public/js; printf '%s\n' 'console.log(user);' > public/js/app.min.js"
benign console-plain-string \
  "printf '%s\n' 'console.log(\"ready\");' >> $TSX"
benign console-string-data \
  "printf '%s\n' 'console.log(\"loading data\");' >> $TSX"
benign console-server-file \
  "printf '%s\n' 'console.log(\"saved\", session);' >> $API"
benign logger-stack \
  "printf '%s\n' 'logger.error(\`notes failed \${res.statusCode}\`, err.stack);' >> $API"
benign client-console-stack \
  "printf '%s\n' 'console.warn(\"load failed\", err.stack);' >> $TSX"
benign vite-hidden-sourcemap \
  "printf '%s\n' 'export default { build: { sourcemap: \"hidden\" } };' > vite.config.ts"
benign vendored-map \
  "mkdir -p static/css; printf '%s\n' '{\"version\":3,\"mappings\":\"AAAA\"}' > static/css/bootstrap.min.css.map"
benign level-map \
  "mkdir -p public/levels; printf '%s\n' 'tiles 10x10' > public/levels/1.map"
benign debug-from-env \
  "printf '%s\n' 'DEBUG = os.environ.get(\"DEBUG\") == \"1\"' > src/settings.py"
benign debug-local-settings \
  "printf '%s\n' 'DEBUG = True' > src/settings_local.py"
benign debug-lowercase-elsewhere \
  "printf '%s\n' '    debug = True' > src/lib/tools.py"
benign errorhandler-dev-guard \
  "printf '%s\n' 'if (process.env.NODE_ENV === \"development\") app.use(errorhandler());' >> $API"
benign errorhandler-dev-guard-multiline \
  "printf '%s\n' 'if (process.env.NODE_ENV === \"development\") {' '  app.use(errorhandler());' '}' >> $API"
benign flask-config-class \
  "printf '%s\n' 'class DevelopmentConfig(Config):' '    DEBUG = True' > src/config.py"
benign error-generic-message \
  "printf '%s\n' 'export function onFail() { return Response.json({ error: \"internal error\" }, { status: 500 }); }' >> $API"
benign ts-type-token \
  "printf '%s\n' 'export async function getServerSideProps() { return { props: {} }; }' 'type Session = { token: string; };' > src/pages/account.tsx"
benign no-semicolon-type \
  "printf '%s\n' 'export async function getServerSideProps() { return { props: {} }; }' 'interface Props {' '  token: string' '}' > src/pages/account.tsx"
benign prisma-multiline-select \
  "printf '%s\n' 'const u = await prisma.user.findUnique({' '  where: { id },' '  select: { id: true },' '});' >> $API"
benign csrf-hidden-input \
  "printf '%s\n' '<input type=\"hidden\" name=\"csrf_secret\" value={csrf} />' >> $TSX"
benign csrf-data-attr \
  "printf '%s\n' '<form data-csrf-secret={csrf}>x</form>' >> $TSX"
# A committed .env.development trips the api domain's API-ENV-NOT-IGNORED by
# design (the fixture's .gitignore lists .env only), so this lock is scoped
# to the exposure domain: a dev env file must raise no EXP finding.
cp -R "$GOOD" "$WORK/env-dev"
printf '%s\n' 'APP_DEBUG=true' 'GENERATE_SOURCEMAP=true' > "$WORK/env-dev/.env.development"
out=$(scan --domain exposure "$WORK/env-dev")
check "a dev env file raises no exposure finding" \
  "$(printf '%s\n' "$out" | grep -c ' 0 FAIL, 0 WARN')" 1

echo "== transactional versus marketing senders"
solo tx-only src/contact.ts 'import nodemailer from "nodemailer";'
check "transactional-only mail exits 0" "$LAST_RC" 0
check "transactional-only mail warns on consent" \
  "$(has WARN MSG-NO-CONSENT-RECORD)" yes
solo marketing-only src/newsletter.ts 'import nodemailer from "nodemailer";'
check "newsletter mail fails on consent" \
  "$(has FAIL MSG-NO-CONSENT-RECORD)" yes

mkdir -p "$WORK/tx-helper/src"
for f in contact mailer; do
  printf '%s\n' 'import nodemailer from "nodemailer";' \
    'const recipient = "owner@example.com";' > "$WORK/tx-helper/src/$f.ts"
done
LAST_OUT=$(scan "$WORK/tx-helper"); LAST_RC=$?
check "contact form plus shared mailer warns" \
  "$(has WARN MSG-NO-CONSENT-RECORD)" yes
check "contact form plus shared mailer exits 0" "$LAST_RC" 0
cp -R "$WORK/tx-helper" "$WORK/tx-bulk"
printf '%s\n' 'create table subscribers (id int);' > "$WORK/tx-bulk/schema.sql"
LAST_OUT=$(scan "$WORK/tx-bulk")
check "a subscribers table makes the same senders fail" \
  "$(has FAIL MSG-NO-CONSENT-RECORD)" yes

echo "== check modes (contract oracle and re-pass baseline)"
INJ="INJ-SQL-CONCAT:$API"
cp -R "$GOOD" "$WORK/cm"; printf '%s\n' 'const q = `select id from notes where owner = ${owner}`;' >> "$WORK/cm/$API"
out=$(scan "$WORK/cm" --assert-absent "$INJ"); rc=$?
check "positive control: the oracle fails while the hit is there" "$rc" 1
check "a failing oracle never prints the marker" \
  "$(printf '%s\n' "$out" | grep -c GUARDRAILS-CLEAR)" 0
out=$(scan "$GOOD" --assert-absent "$INJ"); rc=$?
check "the oracle passes once the hit is gone" "$rc" 0
check "a passing oracle prints the marker" \
  "$(printf '%s\n' "$out" | grep -c '^GUARDRAILS-CLEAR 1$')" 1
out=$(scan "$GOOD" --domain api --assert-absent "$INJ"); rc=$?
check "an unscanned domain proves nothing" "$rc" 1
check "the control failure is named" \
  "$(printf '%s\n' "$out" | grep -c '^  CONTROL ')" 1
mkdir "$WORK/cm-empty"
scan "$WORK/cm-empty" --assert-absent "$INJ" >/dev/null
check "an empty tree proves nothing" "$?" 1
scan "$GOOD" --assert-absent HOST-SPEND-CAP:. >/dev/null 2>&1
check "a MANUAL rule cannot be asserted (exit 2)" "$?" 2
scan "$GOOD" --assert-absent INJ-SQL-CONCAT >/dev/null 2>&1
check "an item without a path is a usage error" "$?" 2
scan "$WORK/cm" --json > "$WORK/cm-before.json"
out=$(scan "$GOOD" --baseline "$WORK/cm-before.json"); rc=$?
check "baseline lists the fixed hit" \
  "$(printf '%s\n' "$out" | grep -c '^  FIXED INJ-SQL-CONCAT ')" 1
check "baseline with no new hit exits 0 with the marker" \
  "$rc:$(printf '%s\n' "$out" | grep -c '^GUARDRAILS-NO-NEW$')" "0:1"
scan "$GOOD" --json > "$WORK/clean-before.json"
out=$(scan "$WORK/cm" --baseline "$WORK/clean-before.json"); rc=$?
check "baseline lists a new hit" \
  "$(printf '%s\n' "$out" | grep -c '^  NEW   INJ-SQL-CONCAT ')" 1
check "baseline with a new hit exits 1 without the marker" \
  "$rc:$(printf '%s\n' "$out" | grep -c GUARDRAILS-NO-NEW)" "1:0"
printf 'not json' > "$WORK/bad.json"
scan "$GOOD" --baseline "$WORK/bad.json" >/dev/null 2>&1
check "an unreadable baseline exits 2" "$?" 2

# contract <dir> <file>: a fix contract whose oracle is the scanner itself
contract() {
  cat > "$2" <<EOF
# CONTRACT — guardrails-oracle-test
## ACCEPTANCE CRITERIA
1. no SQL built from input in the notes route
   CHECK: python3 -B '$SCAN' '$1' --assert-absent '$INJ'
   EXPECT: GUARDRAILS-CLEAR
   EVIDENCE: pending
## FILE SCOPE
$API
EOF
}
contract "$WORK/cm" "$WORK/c-unfixed.md"
bash "$ROOT/lib/gates.sh" run "$WORK/c-unfixed.md" >/dev/null 2>&1
check "gates.sh: the oracle is UNMET before the fix" "$?" 2
contract "$GOOD" "$WORK/c-fixed.md"
bash "$ROOT/lib/gates.sh" run "$WORK/c-fixed.md" >/dev/null 2>&1
check "gates.sh: the oracle is MET after the fix" "$?" 0
check "gates.sh writes the evidence back" \
  "$(grep -c 'EVIDENCE: pending' "$WORK/c-fixed.md")" 0

echo "== cli"
scan "$WORK/does-not-exist" >/dev/null 2>&1; check "bad path exits 2" "$?" 2
scan --domain nope "$GOOD" >/dev/null 2>&1; check "bad domain exits 2" "$?" 2
scan --domain a11y "$GOOD" >/dev/null 2>&1; check "a11y is no longer a guardrails domain (exit 2)" "$?" 2
check "json is valid and counts FAIL" \
  "$(scan --json "$GOOD" | python3 -B -c 'import json,sys; print(json.load(sys.stdin)["summary"]["FAIL"])')" 0
out=$(scan --domain injection "$GOOD")
check "domain filter keeps injection" \
  "$(printf '%s\n' "$out" | grep -c '^\[injection\]')" 1
check "domain filter drops supabase" \
  "$(printf '%s\n' "$out" | grep -c '^\[supabase\]')" 0
cp -R "$GOOD" "$WORK/excl"
printf '%s\n' 'const q = `select id from notes where owner = ${owner}`;' >> "$WORK/excl/$API"
scan "$WORK/excl" >/dev/null 2>&1; check "mutated copy fails" "$?" 1
scan --exclude src/pages "$WORK/excl" >/dev/null 2>&1
check "--exclude drops the finding" "$?" 0
mkdir "$WORK/empty"
out=$(scan "$WORK/empty")
check "empty project marks hosting not applicable" \
  "$(printf '%s\n' "$out" | grep -c 'not applicable: hosting')" 1
mkdir "$WORK/linked"; ln -s "$GOOD" "$WORK/linked/escape"
out=$(scan "$WORK/linked")
check "symlinked directory is not followed" \
  "$(printf '%s\n' "$out" | grep -c '(0 files)')" 1

echo "== text output carries no control characters"
ESCNAME=$(printf 'x\033[31m')
cp -R "$GOOD" "$WORK/esc"
printf 'export default function X({user}){ console.log(user); return null }\n' \
  > "$WORK/esc/src/components/$ESCNAME.tsx"
printf '%s\n' "create policy \"p$(printf '\033[2J')\" on public.notes for insert to authenticated with check (true);" >> "$WORK/esc/$SQL"
out=$(scan "$WORK/esc" 2>&1)
check "text report has no ESC byte" "$(printf '%s' "$out" | grep -c "$(printf '\033')")" 0
check "text report still raises the console finding" \
  "$(printf '%s\n' "$out" | grep -c 'EXP-CONSOLE-DATA')" 1
check "text report still raises the open policy" \
  "$(printf '%s\n' "$out" | grep -c 'SB-POLICY-OPEN-WRITE')" 1
out=$(scan "$WORK/esc" --assert-absent "EXP-CONSOLE-DATA:src/components/$ESCNAME.tsx" 2>&1)
check "assert-absent prints PRESENT with no ESC byte" \
  "$(printf '%s' "$out" | grep -c "$(printf '\033')"):$(printf '%s\n' "$out" | grep -c PRESENT)" 0:1
out=$(scan "$WORK/esc" --baseline "$WORK/clean-before.json" 2>&1)
check "baseline rows have no ESC byte and list the new hit" \
  "$(printf '%s' "$out" | grep -c "$(printf '\033')"):$(printf '%s\n' "$out" | grep -c '^  NEW ')" 0:2
out=$(scan "$WORK/esc" --assert-absent "NOPE$(printf '\033[1m'):x" 2>&1)
check "usage error has no ESC byte" \
  "$(printf '%s' "$out" | grep -c "$(printf '\033')")" 0

echo "== per-variant"
mutant var-rust-format FAIL INJ-SQL-CONCAT \
  "printf '%s\n' 'fn q(o: &str) -> String { format!(\"select id from notes where owner = {}\", o) }' > src/lib/q.rs"
mutant var-django-objects-raw WARN INJ-SQL-RAW-UNSAFE \
  "printf '%s\n' 'rows = Note.objects.raw(statement)' > src/lib/n.py"
mutant var-django-extra WARN INJ-SQL-RAW-UNSAFE \
  "printf '%s\n' 'rows = Note.objects.all().extra(clause)' > src/lib/n2.py"
mutant var-knex-raw-alone WARN INJ-SQL-RAW-UNSAFE \
  "printf '%s\n' 'const r = await knex.raw(statement);' > src/lib/k.ts"
mutant var-execute-raw-unsafe WARN INJ-SQL-RAW-UNSAFE \
  "printf '%s\n' 'await prisma.\$executeRawUnsafe(statement);' > src/lib/x.ts"
mutant var-sequelize-query WARN INJ-SQL-RAW-UNSAFE \
  "printf '%s\n' 'const r = await sequelize.query(statement);' > src/lib/s.ts"
mutant var-sequelize-literal WARN INJ-SQL-RAW-UNSAFE \
  "printf '%s\n' 'const w = Sequelize.literal(clause);' > src/lib/s2.ts"
mutant var-generate-sourcemap FAIL EXP-SOURCEMAP-PUBLIC \
  "printf '%s\n' 'GENERATE_SOURCEMAP=true' > .env.production"
mutant var-vite-sourcemap-true FAIL EXP-SOURCEMAP-PUBLIC \
  "printf '%s\n' 'export default { build: { sourcemap: true } };' > vite.config.ts"
mutant var-angular-sourcemap WARN EXP-SOURCEMAP-PUBLIC \
  "printf '%s\n' '{ \"sourceMap\": true }' > angular.json"
mutant var-rails-local-requests FAIL EXP-DEBUG-ON \
  "mkdir -p config/environments; printf '%s\n' 'config.consider_all_requests_local = true' > config/environments/production.rb"
mutant var-flask-debug-env FAIL EXP-DEBUG-ON \
  "printf '%s\n' 'FLASK_DEBUG=1' > .env.production"
mutant var-flask-app-debug FAIL EXP-DEBUG-ON \
  "printf '%s\n' 'app.debug = True' > src/lib/app.py"
mutant var-shell-db-rust FAIL INJ-SHELL-DB-TOOL \
  "printf '%s\n' 'let o = Command::new(\"psql\").arg(format!(\"-c {}\", q));' > src/lib/sh.rs"
mutant var-shell-db-ruby FAIL INJ-SHELL-DB-TOOL \
  "printf '%s\n' 'system(\"psql -c #{query}\")' > src/lib/sh.rb"
mutant var-error-trace-php FAIL EXP-ERROR-STACK \
  "printf '%s\n' '<?php echo \$e->getTraceAsString();' > src/lib/err.php"
mutant var-error-message-flask WARN EXP-ERROR-MESSAGE \
  "printf '%s\n' 'return jsonify(error=str(e)), 500' > src/lib/err.py"

benign shell-db-psql-empty-options \
  "printf '%s\n' 'execSync(\"psql -c select1\", {});' > src/lib/sh.ts"
benign shell-db-rust-argv \
  "printf '%s\n' 'let o = Command::new(\"psql\").arg(\"-c\").arg(q);' > src/lib/sh.rs"

echo "== regex timing"
cat > "$WORK/timing.py" <<'PY'
import importlib.util, sys, time
sys.path.insert(0, "skills/guardrails/scripts")
from checks import common, exposure, injection
spec = importlib.util.spec_from_file_location(
    "probe", "skills/guardrails/scripts/probe.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
cases = [
    (exposure.DATA_ATTR, "data-secret" * 20000),
    (common.MARKUP_COMMENT, "<!--" * 50000),
    (common.SQL_COMMENT, "/*" * 100000),
    (probe.SCRIPT_SRC, "<script " * 25000),
    (probe.TRACE_MARKERS, b"at a ( " * 28000),
]
slow = 0
for pattern, text in cases:
    start = time.perf_counter()
    pattern.search(text)
    slow += time.perf_counter() - start >= 1.0
JS = injection.CONCAT[injection.JS_EXTS]
PYC = injection.CONCAT[(".py",)]
GO = injection.CONCAT[(".go",)]
unit = "select from "
locked = [
    (JS, "`" + unit * 7000),
    (JS, "'" + unit * 7000),
    (PYC, "f'" + unit * 7000),
    (PYC, 'f"""' + unit * 7000),
    (GO, "fmt.Sprintf(`" + unit * 7000),
    (injection.NOSQL, "$where: " * 10000),
    (exposure.HIDDEN_INPUT, "<input " * 11000),
    (injection.SHELL_DB, "system(psql {} " * 1800),
]
for pattern, text in locked:
    start = time.perf_counter()
    miss = pattern.search(text) is None
    slow += (not miss) or time.perf_counter() - start >= 1.0
rows = [
    (PYC, 'cur.execute("select id from notes where owner = %s" % owner)'),
    (PYC, 'cur.execute("select id from notes where o = {}".format(o))'),
    (JS, "const q = 'select id from notes where owner = ' + owner;"),
    (injection.CONCAT[(".rb",)], 'q = "select id from notes where o = #{o}"'),
    (injection.DYNAMIC_EXEC, "execute tbl || ' where true'"),
    (injection.POSTGREST, "supabase.from('t').filter(`a.eq.${v}`)"),
    (injection.POSTGREST, "supabase.from('t').not('a.eq.' + v)"),
    (injection.POSTGREST, "supabase.from('t').match(`a.eq.${v}`)"),
    (injection.POSTGREST, "supabase.from('t').textSearch(`a.${v}`)"),
    (injection.POSTGREST, "supabase.from('t').or('a.eq.' + v)"),
    (injection.NOSQL, "Notes.find(req.body)"),
    (injection.NOSQL, "Notes.updateOne({ id: req.body.id }, {})"),
    (injection.NOSQL, "Notes.findOneAndUpdate(req.query, {})"),
    (injection.NOSQL, "Notes.deleteMany(req.params)"),
    (injection.NOSQL, "Notes.countDocuments({ a: req.body.a })"),
]
senders = ("return jsonify(", "return JSONResponse(", "raise HTTPException(",
           "raise X(detail=", "echo ", "reply.send(", "ctx.body = ")
for sending in senders:
    rows.append((exposure.ERROR_STACK, sending + "traceback.format_exc())"))
    rows.append((exposure.ERROR_MESSAGE, sending + "str(e))"))
rows += [
    (exposure.ERROR_STACK, "echo $e->getTraceAsString();"),
    (exposure.ERROR_STACK, "res.json({ error: err })"),
    (exposure.ERROR_MESSAGE, "return jsonify(error=repr(e))"),
    (exposure.ERROR_MESSAGE, "echo $e->getMessage();"),
    (exposure.DEBUG_CODE, "app.debug = True"),
]
heads = ("Command::new(", "popen(", "passthru(", "proc_open(", "spawn(",
         "system(")
for head in heads:
    for tail in ('"psql -c #{q}")', '"psql {q}")', '"psql %s" % q)',
                 '"psql " + q)', '"psql ${q}")'):
        rows.append((injection.SHELL_DB, head + tail))
    rows.append((injection.SHELL_DB_PHP, head + '"psql $Q")'))
for pattern, sample in rows:
    slow += pattern.search(sample) is None
loads = "export const load = 1\n" * 45000
start = time.perf_counter()
spans = exposure._hydrated_spans(loads)
miss = all(exposure.HYDRATED.search(loads, b, e) is None for b, e in spans)
slow += (not miss) or time.perf_counter() - start >= 1.0
print("REGEX-FAST" if not slow else "REGEX-SLOW")
PY
FAST="$(cd "$ROOT" && python3 -B "$WORK/timing.py")"
check "adversarial inputs finish each regex under one second" \
  "$(printf '%s\n' "$FAST" | grep -c 'REGEX-FAST')" 1

echo "---"
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
