#!/usr/bin/env bash
# lib/tests/effort-routing.test.sh — census: effort tiering (BDR-NEXT)
# agent pins, skill entry levels, shifter skills, orchestrator wiring, settings.
# shellcheck disable=SC2015  # A && ok || ko is deliberate here: ok/ko never fail, so C never masks a true A
set -u
R="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
ok() { pass=$((pass+1)); }
ko() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
has()   { if grep -qF "$2" "$R/$1"; then ok; else ko "$1 missing: $2"; fi; }
lacks() { if grep -qF "$2" "$R/$1"; then ko "$1 must NOT contain: $2"; else ok; fi; }
# frontmatter = the lines between the first two '---' lines
fm() { awk 'NR==1&&/^---$/{p=1;next} p&&/^---$/{exit} p' "$1"; }
fm_effort() { fm "$1" | grep -E '^effort: (low|medium|high|xhigh|max)$' | head -1 | cut -d' ' -f2; }
fm_has_effort() {
  got="$(fm_effort "$R/$1")"
  if [ "$got" = "$2" ]; then ok; else ko "$1 frontmatter effort must be '$2', got '${got:-none}'"; fi
}
fm_no_effort() { if fm "$R/$1" | grep -q '^effort:'; then ko "$1 must NOT pin effort"; else ok; fi; }

# ── flip-test: the frontmatter reader must accept a valid level and reject an invalid one
FIX="$(mktemp -d)"; trap 'rm -rf "$FIX"' EXIT
printf -- '---\nname: good\neffort: xhigh\n---\nbody with effort: low in prose\n' > "$FIX/good.md"
printf -- '---\nname: bad\neffort: turbo\n---\n' > "$FIX/bad.md"
[ "$(fm_effort "$FIX/good.md")" = "xhigh" ] && ok || ko "flip: valid level not read"
[ -z "$(fm_effort "$FIX/bad.md")" ] && ok || ko "flip: invalid level accepted"
[ "$(fm "$FIX/good.md" | grep -c 'prose')" -eq 0 ] && ok || ko "flip: body leaked into frontmatter"

# ── 1) session default (spec D1)
has "settings.json" '"effortLevel": "high"'

# ── summary (later tasks insert their locks ABOVE this line)
printf 'effort-routing census: %d pass, %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
