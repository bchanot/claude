#!/usr/bin/env bash
# lib/tests/cc.test.sh — lib/cc.sh `cc <name> [profile]`: unknown profile →
# list + rc 2, no session; a profile → claude --settings <fragment> with
# CLAUDE_PROFILE / CLAUDE_PROFILE_SETTINGS / TMPDIR exported through
# systemd-run + dtach; no profile → plain claude, TMPDIR still set; .env
# sourced. Hermetic: PATH shims, HOME in a fixture holding .claude/lib.
set -u
unset CLAUDE_PROFILE CLAUDE_PROFILE_SETTINGS
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
check_has() { case "$2" in *"$3"*) pass=$((pass+1));; *) fail=$((fail+1));
  printf 'FAIL %s: [%s] does not contain [%s]\n' "$1" "$2" "$3";; esac; }
FX="$(mktemp -d)" || exit 1; trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/bin" "$FX/home/.claude/lib/profiles"
cp "$ROOT/lib/cc.sh" "$ROOT/lib/profile.sh" "$FX/home/.claude/lib/"
printf '{"enabledPlugins": {"x@skills-dir": true}}\n' > "$FX/home/.claude/lib/profiles/webx.json"
printf -- '- **webx**: web fixture\n' > "$FX/home/.claude/lib/profiles/README.md"
cat > "$FX/bin/systemd-run" <<'EOT'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do case "$1" in --*) shift ;; *) break ;; esac; done
echo "systemd-run" >> "$CC_LOG"; exec "$@"
EOT
cat > "$FX/bin/dtach" <<'EOT'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do case "$1" in -c|-e) shift 2 ;; *) break ;; esac; done
echo "dtach" >> "$CC_LOG"; exec "$@"
EOT
cat > "$FX/bin/claude" <<'EOT'
#!/usr/bin/env bash
{ echo "claude argv: $*"; echo "CLAUDE_PROFILE=${CLAUDE_PROFILE-unset}"
  echo "CLAUDE_PROFILE_SETTINGS=${CLAUDE_PROFILE_SETTINGS-unset}"
  echo "TMPDIR=${TMPDIR-unset}"; echo "canary=${CC_ENV_CANARY-unset}"; } >> "$CC_LOG"
EOT
chmod +x "$FX/bin/"*
# shellcheck source=lib/tests/claude-stub.sh
. "$ROOT/lib/tests/claude-stub.sh"
for c in claude systemd-run dtach; do
  PATH="$FX/bin:$PATH" stub_first_or_die "$c" "$FX/bin/$c"
done
export CC_LOG="$FX/log" HOME="$FX/home"
PATH="$FX/bin:$PATH"
# shellcheck disable=SC1091
. "$FX/home/.claude/lib/cc.sh"

: > "$CC_LOG"; out="$(cc s1 nope 2>&1)"; rc=$?
check T1-unknown-rc "$rc" 2; check_has T1-unknown-msg "$out" "cc: unknown profile 'nope'"
check_has T1-unknown-list "$out" "webx"; check T1-no-session "$(cat "$CC_LOG")" ""

: > "$CC_LOG"; cc s2 webx; rc=$?; log="$(cat "$CC_LOG")"
check T2-rc "$rc" 0; check_has T2-chain "$log" "systemd-run"; check_has T2-dtach "$log" "dtach"
check_has T2-argv "$log" "claude argv: --settings $FX/home/.claude/lib/profiles/webx.json"
check_has T2-profile "$log" "CLAUDE_PROFILE=webx"
check_has T2-settings "$log" "CLAUDE_PROFILE_SETTINGS=$FX/home/.claude/lib/profiles/webx.json"
check_has T2-tmpdir "$log" "TMPDIR=$FX/home/.cache/claude-tmp"
check T2-tmpdir-exists "$([ -d "$FX/home/.cache/claude-tmp" ] && echo yes)" yes

: > "$CC_LOG"; cc s3; rc=$?; log="$(cat "$CC_LOG")"
check T3-rc "$rc" 0; check_has T3-argv "$log" "claude argv: "$'\n'
check_has T3-profile-empty "$log" "CLAUDE_PROFILE="$'\n'
check_has T3-tmpdir "$log" "TMPDIR=$FX/home/.cache/claude-tmp"

# name allowlist: a path-like name or profile starts no session
for args in "x ../y" "../x webx" "x web/x" "-x webx"; do
  : > "$CC_LOG"
  # shellcheck disable=SC2086
  out="$(cc $args 2>&1)"; rc=$?
  check "T6-rc-$args" "$rc" 2; check_has "T6-msg-$args" "$out" "cc: invalid"
  check "T6-no-session-$args" "$(cat "$CC_LOG")" ""
done

printf 'CC_ENV_CANARY=1\n' > "$FX/home/.claude/.env"
: > "$CC_LOG"; cc s4 webx; check_has T4-env "$(cat "$CC_LOG")" "canary=1"
check T5-shellcheck "$(shellcheck "$ROOT/lib/cc.sh" >/dev/null 2>&1 && echo ok)" ok
printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
