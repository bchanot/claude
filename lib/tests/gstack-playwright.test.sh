#!/usr/bin/env bash
# lib/tests/gstack-playwright.test.sh — lib/gstack-playwright.sh (T1..T17)
#
# git 2.53 defaults protocol.file to "user", which blocks submodule clone
# and fetch. The fixture git calls alone are not enough: the
# `git submodule update --remote` under test runs INSIDE the lib, in a
# fresh git subprocess spawned from THIS process — so the override is
# exported for the WHOLE test process, not passed per-command.
set -u
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=protocol.file.allow
export GIT_CONFIG_VALUE_0=always

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
L="$ROOT/lib/gstack-playwright.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
git_id() { git -C "$1" config user.email t@example.com
  git -C "$1" config user.name Test; }

# shellcheck source=lib/gstack-playwright.sh
source "$L"

# ── T1/T2 — ostag detection ──────────────────────────────────────────────
printf 'ID=ubuntu\nVERSION_ID="24.04"\n' > "$tmp/os-ubuntu"
printf 'ID=debian\nVERSION_ID="12"\n' > "$tmp/os-debian"
check T1-ostag-ubuntu "$(gstack_pw_ostag "$tmp/os-ubuntu")" "ubuntu24.04"
check T2-ostag-other "$(gstack_pw_ostag "$tmp/os-debian")" ""

# ── T3 — errexit safety of the ostag capture (regression: the reproduced
# bug aborted the whole caller on every non-Ubuntu host) ──
cat > "$tmp/t3.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "$L"
gstack_pw_ostag "$tmp/os-debian"
echo REACHED
EOF
check T3-errexit-safe "$(bash "$tmp/t3.sh" 2>&1 | tail -1)" "REACHED"

# ── T4/T5 — pw_supports, no bun involved ─────────────────────────────────
mkdir -p "$tmp/pwlib-hit" "$tmp/pwlib-miss"
echo "supports ubuntu24.04 and others" > "$tmp/pwlib-hit/index.js"
echo "supports nothing relevant" > "$tmp/pwlib-miss/index.js"
t4_rc=0; gstack_pw_supports "$tmp/pwlib-hit" ubuntu24.04 >/dev/null 2>&1 \
  || t4_rc=$?
check T4-supports-hit "$t4_rc" 0
t5_rc=0; gstack_pw_supports "$tmp/pwlib-miss" ubuntu24.04 >/dev/null 2>&1 \
  || t5_rc=$?
check T5-supports-miss "$t5_rc" 1

# ── T6/T7 — submodule update, real git fixtures ──────────────────────────
mkdir -p "$tmp/upstream6"
git -C "$tmp/upstream6" init -q -b main; git_id "$tmp/upstream6"
printf '{"a":1}\n' > "$tmp/upstream6/package.json"
git -C "$tmp/upstream6" add package.json
git -C "$tmp/upstream6" commit -q -m init

mkdir -p "$tmp/repo6"
git -C "$tmp/repo6" init -q -b main; git_id "$tmp/repo6"
printf 'x\n' > "$tmp/repo6/README.md"
git -C "$tmp/repo6" add README.md
git -C "$tmp/repo6" commit -q -m init
git -C "$tmp/repo6" -c protocol.file.allow=always \
  submodule add -q -b main "$tmp/upstream6" gstack-sub
git -C "$tmp/repo6" config submodule.gstack-sub.branch main
git -C "$tmp/repo6" commit -q -m "add submodule"

printf 'extra\n' > "$tmp/upstream6/extra.txt"
git -C "$tmp/upstream6" add extra.txt
git -C "$tmp/upstream6" commit -q -m "upstream update"

t6_out=$(
  gstack_bump_playwright_if_unsupported() { echo BUMP_CALLED; }
  gstack_submodule_update_with_bump "$tmp/repo6" "gstack-sub"
  echo "rc=$?"
)
t6_calls=$(printf '%s\n' "$t6_out" | grep -c BUMP_CALLED)
t6_rc=$(printf '%s\n' "$t6_out" | grep -o 'rc=[0-9]*')
check T6-update-success-bumps "$t6_calls:$t6_rc" "1:rc=0"

mkdir -p "$tmp/upstream7"
git -C "$tmp/upstream7" init -q -b main; git_id "$tmp/upstream7"
printf '{"a":1}\n' > "$tmp/upstream7/package.json"
printf 'lockA\n' > "$tmp/upstream7/bun.lock"
git -C "$tmp/upstream7" add package.json bun.lock
git -C "$tmp/upstream7" commit -q -m init

mkdir -p "$tmp/repo7"
git -C "$tmp/repo7" init -q -b main; git_id "$tmp/repo7"
printf 'x\n' > "$tmp/repo7/README.md"
git -C "$tmp/repo7" add README.md
git -C "$tmp/repo7" commit -q -m init
git -C "$tmp/repo7" -c protocol.file.allow=always \
  submodule add -q -b main "$tmp/upstream7" gstack-sub
git -C "$tmp/repo7" config submodule.gstack-sub.branch main
git -C "$tmp/repo7" commit -q -m "add submodule"

# upstream changes package.json content (would overwrite the local edit)
printf '{"a":2}\n' > "$tmp/upstream7/package.json"
git -C "$tmp/upstream7" add package.json
git -C "$tmp/upstream7" commit -q -m "upstream bumps package.json"
# local Playwright-bump-style dirty edit, never committed
printf '{"a":99}\n' > "$tmp/repo7/gstack-sub/package.json"

echo "T7: update-conflict"
before_pkg=$(cat "$tmp/repo7/gstack-sub/package.json")
before_lock=$(cat "$tmp/repo7/gstack-sub/bun.lock")
t7_out=$(gstack_submodule_update_with_bump "$tmp/repo7" "gstack-sub" 2>&1)
t7_rc=$?
after_pkg=$(cat "$tmp/repo7/gstack-sub/package.json")
after_lock=$(cat "$tmp/repo7/gstack-sub/bun.lock")
t7_files_ok=N
[ "$before_pkg" = "$after_pkg" ] && [ "$before_lock" = "$after_lock" ] \
  && t7_files_ok=Y
t7_hint_ok=N
printf '%s\n' "$t7_out" | grep -q 'make plugin' && t7_hint_ok=Y
t7_state="$t7_rc:$t7_files_ok:$t7_hint_ok"
check T7-update-conflict-nondestructive "$t7_state" "1:Y:Y"

# ── T8 — no destructive command anywhere in the lib source ───────────────
d8=OK
sed 's/#.*//' "$L" | grep -qE 'git [^|;]*(checkout|reset|clean|stash)' && d8=BAD
sed 's/#.*//' "$L" | grep -qwE '(rm|rmdir|unlink|truncate|mv)' && d8=BAD
check T8-no-destructive-command "$d8" OK

# ── T9-T14 — browsers-report, fixture cache + playwright-core installs ───
mkdir -p "$tmp/installs/fixA/node_modules/playwright-core"
cat > "$tmp/installs/fixA/node_modules/playwright-core/browsers.json" <<'EOF'
{
  "comment": "Do not edit this file, use utils/roll_browser.js",
  "browsers": [
    {
      "name": "chromium",
      "revision": "1228",
      "installByDefault": true
    },
    {
      "name": "chromium-headless-shell",
      "revision": "1228",
      "installByDefault": true
    },
    {
      "name": "webkit",
      "revision": "2311",
      "installByDefault": true,
      "revisionOverrides": {
        "mac14": "2251",
        "debian11-x64": "2105"
      }
    },
    {
      "name": "ffmpeg",
      "revision": "1011",
      "installByDefault": true
    }
  ]
}
EOF
cat > "$tmp/installs/fixA/node_modules/playwright-core/package.json" <<'EOF'
{
  "name": "playwright-core",
  "version": "1.61.1"
}
EOF

mkdir -p "$tmp/cache1/.links" \
  "$tmp/cache1/chromium-1228" \
  "$tmp/cache1/chromium_headless_shell-1228" \
  "$tmp/cache1/webkit-2105" \
  "$tmp/cache1/firefox-9999" \
  "$tmp/cache1/chromium-9999"
printf '%s' "$tmp/installs/fixA/node_modules/playwright-core" \
  > "$tmp/cache1/.links/link-valid"
printf '%s' "$tmp/no-such-install/node_modules/playwright-core" \
  > "$tmp/cache1/.links/link-broken"

out1="$(gstack_browsers_report "$tmp/cache1" 2>&1)"
has1() { printf '%s\n' "$out1" | grep -q "$1" && echo Y; }
check T9-report-referenced "$(has1 'chromium-1228: fixA 1.61.1')" Y
check T10-report-underscore-dir \
  "$(has1 'chromium_headless_shell-1228: fixA 1.61.1')" Y
t11_unref=$(has1 'firefox-9999: unreferenced')
t11_unknown=$(has1 'chromium-9999: unknown revision')
check T11-report-unreferenced "$t11_unref$t11_unknown" YY
check T12-report-broken-link "$(has1 '1 broken link')" Y
check T13-report-revision-override "$(has1 'webkit-2105: fixA 1.61.1')" Y

mkdir -p "$tmp/cache2/.links" "$tmp/cache2/chromium-1228"
printf '%s' "$tmp/installs/fixA/node_modules/playwright-core" \
  > "$tmp/cache2/.links/link-valid"
out2="$(gstack_browsers_report "$tmp/cache2" 2>&1)"; rc2=$?
zero2=$(printf '%s\n' "$out2" | grep -q '0 unreferenced, 0 broken link(s)' \
  && echo Y)
check T14-report-zero-counts-exit-0 "$rc2:$zero2" "0:Y"

# ── T15/T16 — degrade silently, nothing on stderr ────────────────────────
err15="$(gstack_browsers_report "$tmp/does-not-exist-cache" 2>&1 1>/dev/null)"
rc15=$?
check T15-report-no-cache "$rc15:[$err15]" "0:[]"

err16="$(gstack_browsers_report "0" 2>&1 1>/dev/null)"
rc16=$?
check T16-report-browsers-path-zero "$rc16:[$err16]" "0:[]"

# ── T17 — sourcing emits nothing ──────────────────────────────────────────
out17="$(bash -c "source '$L'; :" 2>&1)"
check T17-source-safe "[$out17]" "[]"

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
