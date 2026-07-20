#!/usr/bin/env bash
# lib/tests/fast-libs.test.sh — fast-libs.sh verbs + ctx7-reminder hook (BDR-078)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
L="$ROOT/lib/fast-libs.sh"
H="$ROOT/hooks/ctx7-reminder.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# --- detect: JS fast-libs matched, stable deps ignored ---
mkdir -p "$tmp/js"
cat > "$tmp/js/package.json" <<'EOF'
{"dependencies":{"react":"^19","express":"^5","@tanstack/react-query":"^5"},
 "devDependencies":{"vite":"^6","lodash":"^4"}}
EOF
check T1-js-detect "$(bash "$L" detect "$tmp/js" | tr '\n' ' ')" \
  "@tanstack/react-query react vite "

# react-icons must NOT ride the react match (anchored full-key)
mkdir -p "$tmp/near"
printf '{"dependencies":{"react-icons":"^5","express":"^5"}}' \
  > "$tmp/near/package.json"
check T2-near-miss "$(bash "$L" detect "$tmp/near" >/dev/null 2>&1; echo $?)" 1

# --- detect: python manifest + stable-tech project (exit 1) ---
mkdir -p "$tmp/py"
printf 'fastapi==0.115\nrequests>=2\n' > "$tmp/py/requirements.txt"
check T3-py-detect "$(bash "$L" detect "$tmp/py")" "fastapi"
mkdir -p "$tmp/cpp"
check T4-none "$(bash "$L" detect "$tmp/cpp" >/dev/null 2>&1; echo $?)" 1

# --- cache-status: missing / fresh / stale ---
check T5-missing "$(bash "$L" cache-status "$tmp/js" || true)" missing
mkdir -p "$tmp/js/.ctx7-cache"; touch "$tmp/js/.ctx7-cache/react-core.md"
check T6-fresh "$(bash "$L" cache-status "$tmp/js")" fresh
touch -d '10 days ago' "$tmp/js/.ctx7-cache/react-core.md"
check T7-stale "$(bash "$L" cache-status "$tmp/js" || true)" stale

# --- hook: fires once per session, silent on stable projects ---
hook() { printf '{"prompt":"add a hook","session_id":"%s","cwd":"%s"}' \
  "$1" "$2" | TMPDIR="$tmp" bash "$H"; }
check H1-fires "$(hook s1 "$tmp/js" | grep -c 'Fast-moving')" 1
check H2-once "$(hook s1 "$tmp/js" | wc -l)" 0
check H3-cpp-quiet "$(hook s2 "$tmp/cpp" | wc -l)" 0
check H4-notif-quiet \
  "$(printf '{"prompt":"<task-notification>x","session_id":"s3","cwd":"%s"}' \
    "$tmp/js" | TMPDIR="$tmp" bash "$H" | wc -l)" 0

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
