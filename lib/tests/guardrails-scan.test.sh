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

echo "== clean fixture"
out=$(scan "$GOOD"); rc=$?
check "clean exit code" "$rc" 0
check "clean has no FAIL or WARN" \
  "$(printf '%s\n' "$out" | grep -c ' 0 FAIL, 0 WARN')" 1

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

echo "== a11y"
mutant img-alt FAIL A11Y-IMG-ALT "edit $TSX 's/ alt=\"Company logo\"//'"
mutant field-label FAIL A11Y-FIELD-LABEL "edit $TSX '/<label htmlFor=\"email\">/d'"
mutant click-keyboard FAIL A11Y-CLICK-NO-KEYBOARD "edit $TSX 's/ onKeyDown={go}//'"
mutant tabindex-positive WARN A11Y-TABINDEX-POSITIVE \
  "edit $TSX 's/tabIndex={0}/tabIndex={2}/'"
mutant focus-css-warn WARN A11Y-FOCUS-OUTLINE \
  "printf 'a:focus { outline: none; }\n' > src/styles.css"
mutant focus-css-fail FAIL A11Y-FOCUS-OUTLINE \
  "printf 'a:focus { outline: none; }\n' > src/styles.css; edit $TSX 's/outline-none focus-visible:ring-2 focus-visible:ring-blue-500/x/'"
mutant focus-tailwind FAIL A11Y-FOCUS-OUTLINE \
  "edit $TSX 's/outline-none focus-visible:ring-2 focus-visible:ring-blue-500/outline-none/'"

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
benign comment-with-img-tag \
  "printf '%s\n' '// the <img> below is decorative' >> $TSX"
benign dialog-overlay-click \
  "printf '%s\n' '<div role=\"dialog\" aria-label=\"x\" onClick={go}>y</div>' >> $TSX"
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
ENVKEY='printf "SUPABASE_SERVICE_ROLE_KEY=%s.%s.signaturepart\n" "$(b64 "{\"alg\":\"HS256\"}")" "$(b64 "{\"role\":\"service_role\"}")" > .env.worker'
benign env-worker-ignored "printf '.env.*\n' >> .gitignore; $ENVKEY"
mutant env-worker-tracked FAIL SB-SERVICE-ROLE-LITERAL "$ENVKEY"

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
IMG="A11Y-IMG-ALT:$TSX"
cp -R "$GOOD" "$WORK/cm"; edit "$WORK/cm/$TSX" 's/ alt="Company logo"//'
out=$(scan "$WORK/cm" --assert-absent "$IMG"); rc=$?
check "positive control: the oracle fails while the hit is there" "$rc" 1
check "a failing oracle never prints the marker" \
  "$(printf '%s\n' "$out" | grep -c GUARDRAILS-CLEAR)" 0
out=$(scan "$GOOD" --assert-absent "$IMG"); rc=$?
check "the oracle passes once the hit is gone" "$rc" 0
check "a passing oracle prints the marker" \
  "$(printf '%s\n' "$out" | grep -c '^GUARDRAILS-CLEAR 1$')" 1
out=$(scan "$GOOD" --domain api --assert-absent "$IMG"); rc=$?
check "an unscanned domain proves nothing" "$rc" 1
check "the control failure is named" \
  "$(printf '%s\n' "$out" | grep -c '^  CONTROL ')" 1
mkdir "$WORK/cm-empty"
scan "$WORK/cm-empty" --assert-absent "$IMG" >/dev/null
check "an empty tree proves nothing" "$?" 1
scan "$GOOD" --assert-absent HOST-SPEND-CAP:. >/dev/null 2>&1
check "a MANUAL rule cannot be asserted (exit 2)" "$?" 2
scan "$GOOD" --assert-absent A11Y-IMG-ALT >/dev/null 2>&1
check "an item without a path is a usage error" "$?" 2
scan "$WORK/cm" --json > "$WORK/cm-before.json"
out=$(scan "$GOOD" --baseline "$WORK/cm-before.json"); rc=$?
check "baseline lists the fixed hit" \
  "$(printf '%s\n' "$out" | grep -c '^  FIXED A11Y-IMG-ALT ')" 1
check "baseline with no new hit exits 0 with the marker" \
  "$rc:$(printf '%s\n' "$out" | grep -c '^GUARDRAILS-NO-NEW$')" "0:1"
scan "$GOOD" --json > "$WORK/clean-before.json"
out=$(scan "$WORK/cm" --baseline "$WORK/clean-before.json"); rc=$?
check "baseline lists a new hit" \
  "$(printf '%s\n' "$out" | grep -c '^  NEW   A11Y-IMG-ALT ')" 1
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
1. every image in the contact form has an alt
   CHECK: python3 -B '$SCAN' '$1' --assert-absent '$IMG'
   EXPECT: GUARDRAILS-CLEAR
   EVIDENCE: pending
## FILE SCOPE
$TSX
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
check "json is valid and counts FAIL" \
  "$(scan --json "$GOOD" | python3 -B -c 'import json,sys; print(json.load(sys.stdin)["summary"]["FAIL"])')" 0
out=$(scan --domain a11y "$GOOD")
check "domain filter keeps a11y" \
  "$(printf '%s\n' "$out" | grep -c '^\[a11y\]')" 1
check "domain filter drops supabase" \
  "$(printf '%s\n' "$out" | grep -c '^\[supabase\]')" 0
cp -R "$GOOD" "$WORK/excl"
edit "$WORK/excl/$TSX" 's/ alt="Company logo"//'
scan "$WORK/excl" >/dev/null 2>&1; check "mutated copy fails" "$?" 1
scan --exclude src/components "$WORK/excl" >/dev/null 2>&1
check "--exclude drops the finding" "$?" 0
mkdir "$WORK/empty"
out=$(scan "$WORK/empty")
check "empty project marks hosting not applicable" \
  "$(printf '%s\n' "$out" | grep -c 'not applicable: hosting')" 1
mkdir "$WORK/linked"; ln -s "$GOOD" "$WORK/linked/escape"
out=$(scan "$WORK/linked")
check "symlinked directory is not followed" \
  "$(printf '%s\n' "$out" | grep -c '(0 files)')" 1

echo "---"
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
