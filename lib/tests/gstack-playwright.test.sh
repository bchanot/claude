#!/usr/bin/env bash
# lib/tests/gstack-playwright.test.sh — lib/gstack-playwright.sh (T1..T27)
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
# producer out of the pipe: grep -q SIGPIPEs it under pipefail on BSD
grep -qE 'git [^|;]*(checkout|reset|clean|stash)' < <(sed 's/#.*//' "$L") && d8=BAD
grep -qwE '(rm|rmdir|unlink|truncate|mv)' < <(sed 's/#.*//' "$L") && d8=BAD
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

# ── T18-T27 — the bump: version floor on any OS, OS reason kept ──────────
# Stub bun: logs "$*" to $BUN_LOG; `add playwright@latest` rewrites the
# fixture version ($BUN_ADD_SETS) and lib text ($BUN_ADD_LIB) when set;
# `install` fails when $BUN_FAIL_INSTALL=1.
mkdir -p "$tmp/stubbin"
cat > "$tmp/stubbin/bun" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${BUN_LOG:-/dev/null}"
if [ "${BUN_FAIL_INSTALL:-}" = 1 ] && [ "${1:-}" = install ]; then
  exit 1
fi
if [ "${1:-}" = add ] && [ "${2:-}" = playwright@latest ]; then
  pw=node_modules/playwright-core
  if [ -n "${BUN_ADD_SETS:-}" ]; then
    printf '{\n  "name": "playwright-core",\n  "version": "%s"\n}\n' \
      "$BUN_ADD_SETS" > "$pw/package.json"
  fi
  if [ -n "${BUN_ADD_LIB:-}" ]; then
    printf '%s\n' "$BUN_ADD_LIB" > "$pw/lib/index.js"
  fi
fi
exit 0
EOF
chmod +x "$tmp/stubbin/bun"
BUN_LOG="$tmp/bun.log"

# mk_gstack <dir> <version> <lib text>
mk_gstack() {
  mkdir -p "$1/node_modules/playwright-core/lib"
  printf '{\n  "name": "playwright-core",\n  "version": "%s"\n}\n' "$2" \
    > "$1/node_modules/playwright-core/package.json"
  printf '%s\n' "$3" > "$1/node_modules/playwright-core/lib/index.js"
}

# run_bump <dir> <ostag> <add sets> [add lib] [fail install]
run_bump() {
  (
    _t_os="$2"
    gstack_pw_ostag() { printf '%s' "$_t_os"; }
    BUN_ADD_SETS="$3"; BUN_ADD_LIB="${4:-}"; BUN_FAIL_INSTALL="${5:-}"
    export BUN_LOG BUN_ADD_SETS BUN_ADD_LIB BUN_FAIL_INSTALL
    PATH="$tmp/stubbin:$PATH"
    : > "$BUN_LOG"
    gstack_bump_playwright_if_unsupported "$1"
    echo "rc=$?"
  ) 2>&1
}
log_has() { grep -q -- "$1" "$BUN_LOG" && echo Y || echo N; }
out_has() { printf '%s\n' "$out" | grep -qF -- "$1" && echo Y || echo N; }

mk_gstack "$tmp/g18" 1.58.2 "x"
mkdir -p "$tmp/g18-empty"
check T18-version-read \
  "$(gstack_pw_version "$tmp/g18/node_modules/playwright-core")" 1.58.2
check T18-version-unreadable \
  "$(gstack_pw_version "$tmp/g18-empty")" ""

t19=""
for v in 1.58.2 1.59.1 1.60.0 1.63.0 2.0.0 "" garbage; do
  t19_rc=0; gstack_pw_extract_safe "$v" || t19_rc=$?
  t19="$t19$t19_rc"
done
check T19-extract-safe-floor "$t19" 1100000

mk_gstack "$tmp/g20" 1.58.2 "x"
out="$(run_bump "$tmp/g20" "" 1.65.0)"
check T20-no-os-release-bumps "$(log_has 'add playwright@latest')\
$(out_has 'bumped to 1.65.0')$(out_has 'rc=0')" YYY

mk_gstack "$tmp/g21" 1.63.0 "x"
out="$(run_bump "$tmp/g21" "" "")"
t21_add=$(grep -q '^add' "$BUN_LOG" && echo Y || echo N)
check T21-safe-version-no-bump "$(log_has '^install')$t21_add\
$(out_has '1.63.0: no bump needed')$(out_has 'rc=0')" YNYY

mk_gstack "$tmp/g22" 1.58.2 "supports ubuntu24.04"
out="$(run_bump "$tmp/g22" ubuntu24.04 1.65.0)"
check T22-version-reason-on-supported-os "$(log_has '^add')" Y

mk_gstack "$tmp/g23" 1.63.0 "supports nothing"
out="$(run_bump "$tmp/g23" ubuntu26.04 "" "")"
check T23-os-reason-left "$(log_has '^add')\
$(out_has 'bump left it: lacks ubuntu26.04 support')\
$(out_has 'expected to freeze')" YYN

mk_gstack "$tmp/g24" 1.63.0 "supports nothing"
out="$(run_bump "$tmp/g24" ubuntu26.04 "" "supports ubuntu26.04")"
check T24-os-reason-bumped "$(log_has '^add')$(out_has 'bumped to 1.63.0')" YY

mk_gstack "$tmp/g25" 1.58.2 "x"
out="$(run_bump "$tmp/g25" "" "")"
check T25-failed-bump-warns-freeze \
  "$(out_has 'bump left it: 1.58.2 hangs at browser extraction')\
$(out_has 'expected to freeze')$(out_has 'rc=0')" YYY

mk_gstack "$tmp/g26" 1.58.2 "x"
out="$(run_bump "$tmp/g26" "" "" "" 1)"
t26_add=$(grep -q '^add' "$BUN_LOG" && echo Y || echo N)
check T26-install-failure-warned "$(out_has 'bun install failed in gstack')\
$t26_add$(out_has 'rc=0')" YNY

# T27 — errexit safety: bare calls under set -euo pipefail, three paths
mkdir -p "$tmp/g27-empty"
mk_gstack "$tmp/g27b" 1.58.2 "x"
mk_gstack "$tmp/g27c" 1.58.2 "x"
cat > "$tmp/t27.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "$L"
gstack_pw_ostag() { :; }
PATH="$tmp/stubbin:\$PATH"
BUN_LOG="$tmp/bun27.log"; BUN_ADD_LIB=""; BUN_FAIL_INSTALL=""
export BUN_LOG BUN_ADD_LIB BUN_FAIL_INSTALL
BUN_ADD_SETS=""; export BUN_ADD_SETS
gstack_bump_playwright_if_unsupported "$tmp/g27-empty"
echo REACHED1
BUN_ADD_SETS=1.65.0
gstack_bump_playwright_if_unsupported "$tmp/g27b"
echo REACHED2
BUN_ADD_SETS=""
gstack_bump_playwright_if_unsupported "$tmp/g27c"
echo REACHED3
EOF
out="$(bash "$tmp/t27.sh" 2>&1)"
t27_add=$(grep -q '^add' "$tmp/bun27.log" && echo Y || echo N)
check T27-errexit-safe-bump "$(out_has REACHED1)$(out_has REACHED2)\
$(out_has REACHED3)$t27_add" YYYY

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
