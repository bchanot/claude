#!/usr/bin/env bash
# lib/tests/guardrails-probe.test.sh — floor of the /guardrails live probe.
# A throwaway http.server on 127.0.0.1 serves scripted responses; the probe
# runs against it and each verdict is asserted. Nothing leaves the machine.
# The probe sends read-only methods; this suite proves the OPEN/CLOSED logic,
# the --authorized gate, the same-host redirect guard and the request budget.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROBE="$ROOT/skills/guardrails/scripts/probe.py"
WORK="$(mktemp -d)"
PASS=0; FAIL=0; SRV=""
cleanup() { [ -n "$SRV" ] && kill "$SRV" 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

check() { # check <label> <got> <want>
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "  PASS $1"
  else FAIL=$((FAIL+1)); echo "  FAIL $1 (got '$2', want '$3')"; fi
}

# Fixture server: a fixed map of path -> (status, body, headers). Read-only,
# bound to the loopback, on an OS-chosen port it prints on the first line.
cat > "$WORK/server.py" <<'PY'
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

HITS = {"rl": 0}


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, body=b"", headers=None):
        self.send_response(code)
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        origin = self.headers.get("Origin", "")
        upper = ("Access-Control-Allow-Origin", "Access-Control-Allow-Credentials")
        names = tuple(n.lower() for n in upper) if self.path == "/lower" else upper
        self._send(204, b"", {names[0]: origin, names[1]: "true"})

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/rest/v1/open_table":
            return self._send(200, b'[{"id": 1}]')
        if path == "/rest/v1/closed_table":
            return self._send(200, b'[]')
        if path == "/api/private":
            return self._send(200, b"secret")
        if path == "/api/guarded":
            return self._send(401, b"no")
        if path == "/rl":
            HITS["rl"] += 1
            return self._send(429 if HITS["rl"] > 5 else 200, b"")
        if path == "/nolimit":
            return self._send(200, b"")
        if path == "/":
            return self._send(200, b'<html><script src="/app.js"></script>'
                              b'<script src="/clean.js"></script>'
                              b'<script src=/inline.js></script>'
                              b'<script src="/biginline.js"></script>'
                              b'<script src="/err.js"></script>'
                              b'<script src="https://cdn.invalid/x.js"></script>'
                              b'</html>')
        if path == "/app.js":
            return self._send(200, b"console.log(1);\n//# sourceMappingURL=app.js.map\n")
        if path == "/app.js.map":
            return self._send(200, b'{"version":3,"sources":["src/app.ts"],"mappings":""}')
        if path == "/clean.js":
            return self._send(200, b"console.log(2);\n")
        if path == "/inline.js":
            return self._send(200, b"console.log(3);\n//# sourceMappingURL="
                              b"data:application/json;base64,eyJ2ZXJzaW9uIjozfQ==\n")
        if path == "/biginline.js":
            return self._send(200, b"console.log(4);\n//# sourceMappingURL="
                              b"data:application/json;base64," + b"A" * 20000)
        if path == "/err.js":
            return self._send(200, b"console.log(5);\n//# sourceMappingURL=err.js.map\n")
        if path == "/err.js.map":
            return self._send(503, b"")
        if path == "/api/session":
            return self._send(200, b'{"id": 2, "token": "t", "profile": {"private": false}}',
                              {"Content-Type": "application/json"})
        if path == "/api/clean":
            return self._send(200, b'{"id": 7, "name": "Ada", "role": "member"}',
                              {"Content-Type": "application/json"})
        if path == "/embed.js":
            return self._send(200, b'var s="//# sourceMappingURL=data:'
                              b'application/json;base64,"+btoa(m);\n')
        if path == "/redir.js":
            return self._send(200, b"console.log(6);\n")
        if path == "/redir.js.map":
            return self._send(302, b"", {"Location": "http://other.invalid/m"})
        if path == "/hdr.js":
            return self._send(200, b"console.log(7);\n",
                              {"SourceMap": "/hdr.real.map"})
        if path == "/hdr.real.map":
            return self._send(200, b'{"version":3,"sources":["a.ts"]}')
        if path == "/cmt.js":
            return self._send(200, b"console.log(8);\n//# sourceMappingURL="
                              b"cmt.real.map\n")
        if path == "/cmt.real.map":
            return self._send(200, b'{"version":3,"sources":["b.ts"]}')
        if path == "/offhost.js":
            return self._send(200, b"x();\n//# sourceMappingURL="
                              b"http://other.invalid/o.map\n")
        if path == "/badmap.js":
            return self._send(200, b"z();\n//# sourceMappingURL=http://[x\n")
        if path == "/trunc.js":
            return self._send(200, b"a" * 1_000_001)
        if path == "/bigmap.js":
            return self._send(200, b"y();\n")
        if path == "/bigmap.js.map":
            return self._send(200, b'{"sources":["c.ts"],"x":"' + b"A" * 1_000_001)
        if path == "/api/echo":
            bearer = self.headers.get("Authorization", "")
            body = b'{"id": 1, "password_hash": "x"}' if bearer else b'{"id": 1}'
            return self._send(200, body, {"Content-Type": "application/json"})
        if path == "/api/graphql":
            return self._send(200, b'{"data": {"users": {"edges": [{"node": '
                              b'{"passwordHash": "x"}}]}}}',
                              {"Content-Type": "application/json"})
        if path == "/boom":
            return self._send(500, b"Traceback (most recent call last):\n"
                              b'  File "app.py", line 12, in handler\n')
        if path == "/api/me":
            return self._send(200, b'{"id": 1, "email": "t@t.io", '
                              b'"password_hash": "x", "profile": {"api_key": "y"}, '
                              b'"next_page_token": "abc", "hashtags": []}',
                              {"Content-Type": "application/json"})
        return self._send(404, b"")


srv = HTTPServer(("127.0.0.1", 0), H)
print(srv.server_port, flush=True)
srv.serve_forever()
PY

python3 -B "$WORK/server.py" > "$WORK/port" &
SRV=$!
for _ in $(seq 1 50); do [ -s "$WORK/port" ] && break; sleep 0.1; done
PORT="$(head -1 "$WORK/port")"
if [ -z "$PORT" ]; then echo "  FAIL fixture server did not start"; exit 1; fi
BASE="http://127.0.0.1:$PORT"

probe() { python3 -B "$PROBE" "$@"; }
verdict() { printf '%s\n' "$1" | grep -A1 "$2" | grep -oE 'OPEN|CLOSED|SKIPPED|ERROR' | head -1; }

echo "== authorization gate"
cat > "$WORK/plan.json" <<EOF
{"base_url": "$BASE",
 "supabase": {"url": "$BASE", "tables": ["open_table", "closed_table"],
              "cross_user_paths": ["/rest/v1/open_table"]},
 "routes": [{"path": "/api/private"}, {"path": "/api/guarded"},
            {"path": "/api/public", "public": true}],
 "cors": true}
EOF
probe "$WORK/plan.json" >/dev/null 2>&1
check "refuses without --authorized (exit 2)" "$?" 2

echo "== read-only probes against the fixture"
export GUARDRAILS_ANON_KEY="anon-test-key"
export GUARDRAILS_JWT2="second-user-test-token"
OUT="$(probe --authorized "$WORK/plan.json")"
RC=$?
check "anon read of an open table is OPEN" \
  "$(verdict "$OUT" 'anon-read:open_table')" OPEN
check "anon read of a closed table is CLOSED" \
  "$(verdict "$OUT" 'anon-read:closed_table')" CLOSED
check "cross-user read returning rows is OPEN" \
  "$(verdict "$OUT" 'cross-user:')" OPEN
check "unauth route returning 200 is OPEN" \
  "$(verdict "$OUT" 'no-auth:/api/private')" OPEN
check "unauth route returning 401 is CLOSED" \
  "$(verdict "$OUT" 'no-auth:/api/guarded')" CLOSED
check "public route is not probed" \
  "$(printf '%s\n' "$OUT" | grep -c 'no-auth:/api/public')" 0
check "reflected origin with credentials is OPEN" \
  "$(verdict "$OUT" 'cors-reflect')" OPEN
check "a found OPEN verdict exits 1" "$RC" 1

echo "== skips when a secret is absent"
unset GUARDRAILS_ANON_KEY
OUT="$(probe --authorized "$WORK/plan.json")"
check "anon-read skips without the key" \
  "$(verdict "$OUT" 'anon-read')" SKIPPED
export GUARDRAILS_ANON_KEY="anon-test-key"

echo "== rate limit"
cat > "$WORK/rl.json" <<EOF
{"base_url": "$BASE", "rate_limit": {"path": "/rl", "count": 10}}
EOF
OUT="$(probe --authorized "$WORK/rl.json")"
check "a route that starts sending 429 is CLOSED" \
  "$(verdict "$OUT" 'rate-limit')" CLOSED
cat > "$WORK/nolimit.json" <<EOF
{"base_url": "$BASE", "rate_limit": {"path": "/nolimit", "count": 10}}
EOF
OUT="$(probe --authorized "$WORK/nolimit.json")"
check "a route with no 429 is OPEN" \
  "$(verdict "$OUT" 'rate-limit')" OPEN

echo "== budget caps the burst"
cat > "$WORK/burst.json" <<EOF
{"base_url": "$BASE", "rate_limit": {"path": "/nolimit", "count": 99}}
EOF
OUT="$(probe --authorized "$WORK/burst.json")"
check "the burst is capped, never 99 requests" \
  "$(printf '%s\n' "$OUT" | grep -oE 'sent [0-9]+' | grep -oE '[0-9]+')" 25

echo "== usage errors"
probe --authorized "$WORK/missing.json" >/dev/null 2>&1
check "a missing plan exits 2" "$?" 2
printf '{"base_url": "%s", "rate_limit": {"path": "/x", "method": "DELETE"}}\n' \
  "$BASE" > "$WORK/bad.json"
probe --authorized "$WORK/bad.json" >/dev/null 2>&1
check "a write method in the plan exits 2" "$?" 2

echo "== exposure probes"
cat > "$WORK/exposure.json" <<EOF
{"base_url": "$BASE",
 "routes": [{"path": "/api/me"}, {"path": "/api/guarded"}, {"path": "/api/private"},
            {"path": "/api/session"}, {"path": "/api/clean"}],
 "exposure": {"error_routes": ["/boom"]}}
EOF
OUT="$(probe --authorized "$WORK/exposure.json")"
check "a served source map is OPEN" \
  "$(verdict "$OUT" 'sourcemap:/app.js')" OPEN
check "an inline data: source map is OPEN" \
  "$(verdict "$OUT" 'sourcemap:/inline.js')" OPEN
check "a large inline source map is OPEN" \
  "$(verdict "$OUT" 'sourcemap:/biginline.js')" OPEN
check "a script with no map is CLOSED" \
  "$(verdict "$OUT" 'sourcemap:/clean.js')" CLOSED
check "a foreign-host script is never probed" \
  "$(printf '%s\n' "$OUT" | grep -c 'cdn.invalid')" 0
check "a traceback in an error body is OPEN" \
  "$(verdict "$OUT" 'error-body:/boom')" OPEN
check "the random 404 path is CLOSED" \
  "$(verdict "$OUT" 'error-body:/guardrails-probe-')" CLOSED
check "sensitive keys in a JSON response are OPEN" \
  "$(verdict "$OUT" 'fields:/api/me')" OPEN
check "the sensitive key names are listed, never the values" \
  "$(printf '%s\n' "$OUT" | grep -A1 'fields:/api/me' | grep -c 'api_key, next_page_token, password_hash$')" 1
check "a bare token key is OPEN, a bare private key is not" \
  "$(verdict "$OUT" 'fields:/api/session')" OPEN
check "the session key list is token only" \
  "$(printf '%s\n' "$OUT" | grep -A1 'fields:/api/session' | grep -c 'token$')" 1
check "a clean JSON response is CLOSED" \
  "$(verdict "$OUT" 'fields:/api/clean')" CLOSED
check "a 503 map answer is SKIPPED" \
  "$(verdict "$OUT" 'sourcemap:/err.js')" SKIPPED
check "fields on a 401 is SKIPPED, never CLOSED" \
  "$(verdict "$OUT" 'fields:/api/guarded')" SKIPPED
check "fields on a non-JSON body is SKIPPED" \
  "$(verdict "$OUT" 'fields:/api/private')" SKIPPED
cat > "$WORK/unreachable.json" <<EOF
{"base_url": "http://127.0.0.1:1", "exposure": {}}
EOF
OUT="$(probe --authorized "$WORK/unreachable.json")"
check "an unreachable base page gives a SKIPPED sourcemap row" \
  "$(verdict "$OUT" 'sourcemap')" SKIPPED
printf '{"base_url": "%s", "exposure": {"error_routes": ["boom"]}}\n' "$BASE" > "$WORK/badexp.json"
probe --authorized "$WORK/badexp.json" >/dev/null 2>&1
check "an error route not starting with / exits 2" "$?" 2
printf '{"base_url": "%s", "exposure": []}\n' "$BASE" > "$WORK/badexp2.json"
probe --authorized "$WORK/badexp2.json" >/dev/null 2>&1
check "a non-object exposure block exits 2" "$?" 2
printf '{"base_url": "%s", "exposure": {"scripts": "/app.js"}}\n' "$BASE" > "$WORK/badexp3.json"
probe --authorized "$WORK/badexp3.json" >/dev/null 2>&1
check "a scripts string instead of a list exits 2" "$?" 2
printf '{"base_url": "%s", "routes": [{"path": ".evil.invalid/x"}]}\n' "$BASE" > "$WORK/badroute.json"
probe --authorized "$WORK/badroute.json" >/dev/null 2>&1
check "a route path that could leave the host exits 2" "$?" 2
printf '{"base_url": "%s", "routes": ["/x"]}\n' "$BASE" > "$WORK/badroute2.json"
probe --authorized "$WORK/badroute2.json" >/dev/null 2>&1
check "a route that is not an object exits 2" "$?" 2
printf '{"base_url": "%s", "exposure": true}\n' "$BASE" > "$WORK/badexp4.json"
probe --authorized "$WORK/badexp4.json" >/dev/null 2>&1
check "a boolean exposure block exits 2 without a traceback" "$?" 2
printf '{"base_url": "%s", "exposure": {"scripts": ["/does-not-exist.js"]}}\n' "$BASE" > "$WORK/stale.json"
OUT="$(probe --authorized "$WORK/stale.json")"
check "a listed script that answers 404 is SKIPPED, never CLOSED" \
  "$(verdict "$OUT" 'sourcemap:/does-not-exist.js')" SKIPPED
printf '{"base_url": "%s", "exposure": {"scripts": []}}\n' "$BASE" > "$WORK/noscript.json"
OUT="$(probe --authorized "$WORK/noscript.json")"
check "an empty scripts list still gives a SKIPPED sourcemap row" \
  "$(verdict "$OUT" 'sourcemap')" SKIPPED
printf '{"base_url": "%s", "rate_limit": null}\n' "$BASE" > "$WORK/badrl.json"
probe --authorized "$WORK/badrl.json" >/dev/null 2>&1
check "a null rate_limit exits 2" "$?" 2
printf '{"base_url": "%s", "routes": 5}\n' "$BASE" > "$WORK/badroutes.json"
probe --authorized "$WORK/badroutes.json" >/dev/null 2>&1
check "a non-list routes exits 2" "$?" 2
printf '{"base_url": "%s", "supabase": {"url": "%s", "cross_user_paths": "/x"}}\n' \
  "$BASE" "$BASE" > "$WORK/badcu.json"
probe --authorized "$WORK/badcu.json" >/dev/null 2>&1
check "a string cross_user_paths exits 2" "$?" 2
printf '{"base_url": "%s", "supabase": 5}\n' "$BASE" > "$WORK/badsb.json"
probe --authorized "$WORK/badsb.json" >/dev/null 2>&1
check "a non-object supabase block exits 2" "$?" 2
cat > "$WORK/lower.json" <<EOF
{"base_url": "$BASE", "cors": true, "cors_path": "/lower"}
EOF
OUT="$(probe --authorized "$WORK/lower.json")"
check "lowercase CORS header names are still read" \
  "$(verdict "$OUT" 'cors-reflect')" OPEN

echo "== exposure probes: map channels and fail-closed paths"
cat > "$WORK/maps.json" <<EOF
{"base_url": "$BASE",
 "exposure": {"scripts": ["/embed.js", "/redir.js", "/hdr.js", "/cmt.js",
   "/offhost.js", "/trunc.js", "/bigmap.js", "/badmap.js"], "error_routes": []}}
EOF
OUT="$(probe --authorized "$WORK/maps.json")"
check "a sourceMappingURL string inside code is CLOSED, not an inline map" \
  "$(verdict "$OUT" 'sourcemap:/embed.js')" CLOSED
check "a map that redirects off host is SKIPPED, never CLOSED" \
  "$(verdict "$OUT" 'sourcemap:/redir.js')" SKIPPED
check "a map named by the SourceMap header is OPEN" \
  "$(verdict "$OUT" 'sourcemap:/hdr.js')" OPEN
check "a map named by the trailing comment is OPEN" \
  "$(verdict "$OUT" 'sourcemap:/cmt.js')" OPEN
check "a map url on another host is SKIPPED" \
  "$(verdict "$OUT" 'sourcemap:/offhost.js')" SKIPPED
check "a malformed map url is SKIPPED, no traceback" \
  "$(verdict "$OUT" 'sourcemap:/badmap.js')" SKIPPED
check "the message line keeps its newline and 11-space indent" \
  "$(printf '%s\n' "$OUT" | grep -A1 'sourcemap:/offhost.js' | tail -1 | grep -c '^           [^ ]')" 1
check "a truncated script is SKIPPED" \
  "$(verdict "$OUT" 'sourcemap:/trunc.js')" SKIPPED
check "an oversize map is SKIPPED" \
  "$(verdict "$OUT" 'sourcemap:/bigmap.js')" SKIPPED

echo "== fields probe: depth and bearer"
cat > "$WORK/fields.json" <<EOF
{"base_url": "$BASE",
 "routes": [{"path": "/api/echo"}, {"path": "/api/graphql"}],
 "exposure": {"scripts": [], "error_routes": []}}
EOF
OUT="$(probe --authorized "$WORK/fields.json")"
check "a sensitive key nested past four levels is OPEN" \
  "$(verdict "$OUT" 'fields:/api/graphql')" OPEN
check "the fields probe sends the bearer (key seen only with it)" \
  "$(verdict "$OUT" 'fields:/api/echo')" OPEN
OUT="$(env -u GUARDRAILS_JWT2 python3 -B "$PROBE" --authorized "$WORK/fields.json")"
check "without the bearer the same route is CLOSED" \
  "$(verdict "$OUT" 'fields:/api/echo')" CLOSED

echo "== plan validation and host guard"
printf '{"base_url": "file:///tmp"}\n' > "$WORK/file.json"
probe --authorized "$WORK/file.json" >/dev/null 2>&1
check "a file:// base_url exits 2" "$?" 2
printf '{"base_url": "http://[x"}\n' > "$WORK/v6.json"
probe --authorized "$WORK/v6.json" >/dev/null 2>&1
check "a malformed base_url exits 2" "$?" 2
printf '{"base_url": 5}\n' > "$WORK/num.json"
ERR="$(probe --authorized "$WORK/num.json" 2>&1 >/dev/null)"
check "a non-string base_url exits 2 without a traceback" \
  "$(printf '%s\n' "$ERR" | grep -c 'Traceback')" 0
probe --authorized "$WORK/num.json" >/dev/null 2>&1
check "a non-string base_url exits 2" "$?" 2
printf '{"base_url": "%s", "rate_limit": {"count": 5}}\n' "$BASE" > "$WORK/nopath.json"
ERR="$(probe --authorized "$WORK/nopath.json" 2>&1 >/dev/null)"
check "a rate_limit with no path gives a usage message, no traceback" \
  "$(printf '%s\n' "$ERR" | grep -c 'rate_limit.path must be a string')" 1
probe --authorized "$WORK/nopath.json" >/dev/null 2>&1
check "a rate_limit with no path exits 2" "$?" 2
printf '{"base_url": "%s", "routes": [{"path": "/a\\u001b[31mb"}]}\n' "$BASE" > "$WORK/ctl.json"
check "a control character in a path is an ERROR row, no traceback" \
  "$(probe --authorized "$WORK/ctl.json" 2>&1 | grep -c 'Traceback')" 0
check "control characters of a target never reach the output" \
  "$(probe --authorized "$WORK/ctl.json" | LC_ALL=C grep -c "$(printf '\033')")" 0
same_host() { python3 -B -c '
import sys
sys.path.insert(0, sys.argv[1])
import probe
print(bool(probe._same_host(sys.argv[2], sys.argv[3])))' \
  "$ROOT/skills/guardrails/scripts" "$1" "$2"; }
check "an https to http move is not the same host" \
  "$(same_host https://a.test/x http://a.test/y)" False
check "a different port is not the same host" \
  "$(same_host http://a.test/x http://a.test:81/y)" False
check "a same-scheme same-host url is kept" \
  "$(same_host http://a.test/x /y)" True
check "an http to https upgrade on the host is kept" \
  "$(same_host http://a.test/x https://a.test/y)" True

echo "== JSON output"
check "json reports the open count" \
  "$(probe --authorized --json "$WORK/plan.json" \
     | python3 -B -c 'import json,sys; print(json.load(sys.stdin)["open"])')" 4

echo "---"
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
