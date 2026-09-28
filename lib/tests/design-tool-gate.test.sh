#!/usr/bin/env bash
# lib/tests/design-tool-gate.test.sh — hermetic suite for the 21st sign-in
# state added to lib/design-tool-gate.sh (contract 2026-09-28-21st-signin-
# gate-1215): a fake `21st` CLI on a fixture PATH drives every whoami answer
# (signed in / signed out / garbage / nonzero rc) through the real gate
# script, with HOME and PATH redirected into the fixture so the machine's
# real CLI is never reachable. A loud precondition proves that redirection
# actually holds before any case runs.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE="$ROOT/lib/design-tool-gate.sh"
PASS=0; FAIL=0

ok()  { echo "PASS $1"; PASS=$((PASS + 1)); }
bad() { echo "FAIL $1 — $2"; FAIL=$((FAIL + 1)); }

# Precondition, loud: the sanitized PATH below and ensure_21st_on_path()'s
# own probes must never resolve a REAL 21st — else CLI_ABSENT_10 (and every
# other case) would silently exercise this machine's CLI instead of the stub.
if PATH=/usr/bin:/bin command -v 21st >/dev/null 2>&1 \
   || [ -e /usr/local/bin/21st ]; then
  echo "FAIL precondition: system-wide 21st present," \
       "CLI_ABSENT case not hermetic"
  FAIL=$((FAIL + 1))
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/repo/lib/profiles" "$WORK/repo/skills" "$WORK/bin" "$WORK/home"

# GATE-BLOCK allowlist: 21st (cli) always, ghost-skill (external) only used
# by INCOMPLETE_WINS to prove a blocking miss still trips the gate.
cat > "$WORK/repo/lib/profiles/design.profile" <<'EOF'
# GATE-BLOCK: 21st ghost-skill
21st                cli
ghost-skill         external
EOF

# Fake profile.sh: `show design --plain` cats whatever the case wrote to
# plain.txt. $WORK is read from the environment at run time (exported
# below), never baked in here — the heredoc is quoted on purpose.
cat > "$WORK/repo/lib/profile.sh" <<'EOF'
#!/usr/bin/env bash
[ "$1" = show ] && [ "$3" = --plain ] && { cat "$WORK/plain.txt"; exit 0; }
exit 1
EOF
chmod +x "$WORK/repo/lib/profile.sh"
export WORK

# Fake 21st CLI: `whoami` answers per $FAKE_21ST_MODE, the real CLI's exact
# sentences for in/out (proven by STUB_CONTROL below), a garbage line at
# rc 0, or the signed-out sentence at a nonzero rc (proves rc wins).
cat > "$WORK/bin/21st" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = whoami ] || exit 1
signedout='Not logged in. Run `21st login`, or set TWENTYFIRST_TOKEN.'
case "${FAKE_21ST_MODE:-in}" in
  in)      echo "Logged in as tester (saved locally)."; exit 0 ;;
  out)     echo "$signedout"; exit 0 ;;
  garbage) echo "Something unexpected"; exit 0 ;;
  fail)    echo "$signedout"; exit 3 ;;
esac
EOF
chmod +x "$WORK/bin/21st"

# gate_run <FAKE_21ST_MODE> <plain, \t and \n escapes> [PATH override]
# -> sets $GATE_OUT / $GATE_RC. TWENTYFIRST_TOKEN and API_KEY_21ST are
# always unset here; TOKEN_READY below sets them explicitly instead.
gate_run() {
  local mode="$1" plain="$2" gate_path="${3:-$WORK/bin:/usr/bin:/bin}"
  printf '%b\n' "$plain" > "$WORK/plain.txt"
  GATE_OUT="$(env -u TWENTYFIRST_TOKEN -u API_KEY_21ST \
    HOME="$WORK/home" PATH="$gate_path" \
    DESIGN_GATE_REPO_OVERRIDE="$WORK/repo" \
    DESIGN_GATE_PROFILE_SH="$WORK/repo/lib/profile.sh" \
    FAKE_21ST_MODE="$mode" bash "$GATE" 2>&1)"
  GATE_RC=$?
}

# ── stub positive control ────────────────────────────────────────────────
if FAKE_21ST_MODE=in "$WORK/bin/21st" whoami | grep -q '^Logged in as ' \
   && FAKE_21ST_MODE=out "$WORK/bin/21st" whoami | grep -q '^Not logged in'
then ok STUB_CONTROL; else bad STUB_CONTROL "stub sentences wrong"; fi

# ── SIGNED_IN_READY: whoami says logged in -> exit 0, READY ────────────────
gate_run in 'cli\t21st'
if [ "$GATE_RC" -eq 0 ] && echo "$GATE_OUT" | grep -q 'toolchain: READY'; then
  ok SIGNED_IN_READY
else
  bad SIGNED_IN_READY "rc=$GATE_RC out=$GATE_OUT"
fi

# ── SIGNED_OUT_12: whoami says not logged in -> exit 12, ask to sign in ────
gate_run out 'cli\t21st'
if [ "$GATE_RC" -eq 12 ] && echo "$GATE_OUT" | grep -q 'SIGN-IN REQUIRED' \
   && echo "$GATE_OUT" | grep -q '21st login' \
   && ! echo "$GATE_OUT" | grep -q 'INCOMPLETE'; then
  ok SIGNED_OUT_12
else
  bad SIGNED_OUT_12 "rc=$GATE_RC out=$GATE_OUT"
fi

# ── TOKEN_READY: a token env wins even while whoami reports signed out ─────
printf 'cli\t21st\n' > "$WORK/plain.txt"
out_t="$(env HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" \
  DESIGN_GATE_REPO_OVERRIDE="$WORK/repo" \
  DESIGN_GATE_PROFILE_SH="$WORK/repo/lib/profile.sh" \
  FAKE_21ST_MODE=out TWENTYFIRST_TOKEN=x bash "$GATE" 2>&1)"; rc_t=$?
out_k="$(env HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" \
  DESIGN_GATE_REPO_OVERRIDE="$WORK/repo" \
  DESIGN_GATE_PROFILE_SH="$WORK/repo/lib/profile.sh" \
  FAKE_21ST_MODE=out API_KEY_21ST=x bash "$GATE" 2>&1)"; rc_k=$?
if [ "$rc_t" -eq 0 ] && [ "$rc_k" -eq 0 ]; then
  ok TOKEN_READY
else
  bad TOKEN_READY "TOKEN rc=$rc_t ($out_t) | API_KEY rc=$rc_k ($out_k)"
fi

# ── CLI_ABSENT_10: 21st off PATH -> exit 10, INCOMPLETE (not sign-in) ──────
gate_run in 'cli\t21st' /usr/bin:/bin
if [ "$GATE_RC" -eq 10 ] && echo "$GATE_OUT" | grep -q 'INCOMPLETE'; then
  ok CLI_ABSENT_10
else
  bad CLI_ABSENT_10 "rc=$GATE_RC out=$GATE_OUT"
fi

# ── INCOMPLETE_WINS: a blocking miss outranks a signed-out 21st ────────────
gate_run out 'cli\t21st\nexternal\tghost-skill'
if [ "$GATE_RC" -eq 10 ] && echo "$GATE_OUT" | grep -q 'INCOMPLETE' \
   && ! echo "$GATE_OUT" | grep -q 'SIGN-IN REQUIRED'; then
  ok INCOMPLETE_WINS
else
  bad INCOMPLETE_WINS "rc=$GATE_RC out=$GATE_OUT"
fi

# ── UNKNOWN_11: whoami answers something else -> surfaced, never guessed ───
gate_run garbage 'cli\t21st'
if [ "$GATE_RC" -eq 11 ] && echo "$GATE_OUT" | grep -q 'whoami: rc=0' \
   && echo "$GATE_OUT" | grep -q 'Something unexpected' \
   && ! echo "$GATE_OUT" | grep -q '21st login' \
   && ! echo "$GATE_OUT" | grep -q 'claude CLI unreachable'; then
  ok UNKNOWN_11
else
  bad UNKNOWN_11 "garbage: rc=$GATE_RC out=$GATE_OUT"
fi

gate_run fail 'cli\t21st'
if [ "$GATE_RC" -eq 11 ] && echo "$GATE_OUT" | grep -q 'whoami: rc=3'; then
  ok UNKNOWN_11
else
  bad UNKNOWN_11 "fail: rc=$GATE_RC out=$GATE_OUT"
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
