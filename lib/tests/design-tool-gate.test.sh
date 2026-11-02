#!/usr/bin/env bash
# lib/tests/design-tool-gate.test.sh — lib/design-tool-gate.sh reads
# `profile.sh current --plain` (fake, $WORK/plain.txt) and the 21st sign-in
# state (fake `21st`, FAKE_21ST_MODE). READY (0); a pack off + source=local →
# INCOMPLETE (10) with the profile.sh remedy; source=flag → relaunch remedy;
# no 21st CLI → 10 with the npm hint; signed out → 12; whoami garbage → 11;
# a token → READY without whoami; bad --plain → 2.
set -u
unset CLAUDE_PROFILE CLAUDE_PROFILE_SETTINGS
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL $1 — $2"; }
if PATH=/usr/bin:/bin command -v 21st >/dev/null 2>&1 \
   || [ -e /usr/local/bin/21st ] || [ -e /opt/homebrew/bin/21st ]; then
  echo "FAIL precondition: system-wide 21st present," \
       "CLI_ABSENT case not hermetic"
  FAIL=$((FAIL + 1))
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home"; export WORK
printf '#!/usr/bin/env bash\ncat "$WORK/plain.txt"\n' > "$WORK/bin/profile.sh"
cat > "$WORK/bin/21st" <<'EOF'
#!/usr/bin/env bash
case "${FAKE_21ST_MODE:-in}" in
  in) echo "Logged in as fake@example.com" ;; out) echo "Not logged in" ;;
  garbage) echo "boom"; exit 3 ;;
esac
EOF
chmod +x "$WORK/bin/"*
plain() { # design gstack-design ui source profile
  printf 'profile=%s\nsource=%s\nflag=-\npack-design=%s\npack-gstack-design=%s\nplugin:ui-ux-pro-max@ui-ux-pro-max-skill=%s\nmodel=-\n' \
    "$5" "$4" "$1" "$2" "$3" > "$WORK/plain.txt"
}
gate_run() { # $1 mode, $2 PATH prefix ("" = no 21st)
  local p="$2"; [ -n "$p" ] && p="$p:"
  env -u TWENTYFIRST_TOKEN -u API_KEY_21ST HOME="$WORK/home" PATH="${p}/usr/bin:/bin" \
    FAKE_21ST_MODE="$1" WORK="$WORK" DESIGN_GATE_PROFILE_SH="$WORK/bin/profile.sh" \
    bash "$ROOT/lib/design-tool-gate.sh"
}
expect() { # name rc-want substring
  if [ "$rc" = "$2" ] && case "$out" in *"$3"*) true;; *) false;; esac
  then ok "$1"; else bad "$1" "rc=$rc out=[$out]"; fi
}
plain on on on local web; out="$(gate_run in "$WORK/bin")"; rc=$?
expect T1-ready 0 "READY — packs design + gstack-design + ui-ux-pro-max on (web)"
plain off on on local dev; out="$(gate_run in "$WORK/bin")"; rc=$?
expect T2-incomplete 10 "INCOMPLETE"; expect T2-remedy-local 10 "bash ~/.claude/lib/profile.sh set web"
expect T2-names 10 "off: pack-design"
plain on off off flag dev; out="$(gate_run in "$WORK/bin")"; rc=$?
expect T3-remedy-flag 10 "relaunch this conversation with a design profile:  cc <name> web"
expect T3-names 10 "off: pack-gstack-design plugin:ui-ux-pro-max@ui-ux-pro-max-skill"
plain on on on local web; out="$(gate_run in "")"; rc=$?
expect T4-no-cli 10 "21st needs the CLI: npm i -g @21st-dev/cli   then   21st login"
out="$(gate_run out "$WORK/bin")"; rc=$?
expect T5-signed-out 12 "SIGN-IN REQUIRED"; expect T5-ask 12 "! 21st login"
out="$(gate_run garbage "$WORK/bin")"; rc=$?
expect T6-unverified 11 "READY BUT UNVERIFIED — 21st could not answer: whoami: rc=3 boom"
out="$(TWENTYFIRST_TOKEN=x FAKE_21ST_MODE=out HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" WORK="$WORK" \
       DESIGN_GATE_PROFILE_SH="$WORK/bin/profile.sh" bash "$ROOT/lib/design-tool-gate.sh")"; rc=$?
expect T7-token 0 "READY"
printf 'nonsense\n' > "$WORK/plain.txt"; out="$(gate_run in "$WORK/bin" 2>&1)"; rc=$?
expect T8-bad-plain 2 "design-gate: profile.sh current --plain gave no pack-design line"
if shellcheck "$ROOT/lib/design-tool-gate.sh" >/dev/null 2>&1; then ok T9-shellcheck; else bad T9-shellcheck findings; fi
if [ "$(LC_ALL=C awk 'length($0) > 80' "$ROOT/lib/design-tool-gate.sh" | wc -l | tr -d ' ')" = 0 ]; then ok T9-width; else bad T9-width "lines over 80"; fi
echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
