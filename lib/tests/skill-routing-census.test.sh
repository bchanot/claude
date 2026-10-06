#!/usr/bin/env bash
# lib/tests/skill-routing-census.test.sh — TF-IDF cosine census of
# skill-description collisions across the live catalog (routing ambiguity),
# adapted from addyosmani/agent-skills evals Tier 2. Two skills whose
# descriptions read alike route the same prompt to both — a routing
# collision, not a cosmetic naming clash.
#
# Fixture flip-test math note: with only 2 documents, corpus-wide IDF zeroes
# EVERY term's contribution — a term unique to one doc (df=1) is absent from
# the other vector and can't enter the dot product, a term shared by both
# (df=2) gets idf=log(N/df)=log(1)=0. Cosine is trivially 0 for any 2-doc
# corpus, near-duplicate or not — a bare 2-doc "distinct pair" fixture would
# pass for that reason alone, not because the pair is actually distinct. Both
# fixtures below ride in a 4-doc corpus so IDF carries real signal. The
# distinct-pair fixture also carries its own same-corpus positive control (a
# near-dup pair that must FAIL) and a sensitivity re-run where the "distinct"
# partner is swapped for a near-copy of its counterpart, to prove the WARN/
# FAIL marker actually fires when the pair collides — not just that it stays
# silent for reasons unrelated to distinctness.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CENSUS="$ROOT/lib/skill-routing-census.py"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
TRANSLATE_DESC='description: "Translate a PDF, keeping layout and images."'
SECAUDIT_DESC="description: 'Run a security audit for secrets, CVEs, OWASP.'"

# _mkskill <root> <name> <frontmatter-line>... — a fixture skill/SKILL.md
_mkskill() {
  local dir="$1" name="$2"; shift 2
  mkdir -p "$dir/$name"
  { echo "---"; echo "name: $name"; printf '%s\n' "$@"; echo "---"; } \
    > "$dir/$name/SKILL.md"
}

# _mkcontrol <root> — same-corpus positive control: skill-e/skill-f, a
# near-duplicate deploy-runbook pair that must FAIL wherever it rides.
_mkcontrol() {
  local dir="$1"
  _mkskill "$dir" skill-e "description: |" \
    "  Use when deploying a project via its per-project runbook to ship the" \
    "  application to production servers safely with rollback support and" \
    "  health checks after each release."
  _mkskill "$dir" skill-f "description: >-" \
    "  Use when deploying a project via its per-project deployment runbook to" \
    "  ship the application to production servers safely with rollback" \
    "  support and health checks after each release."
}

# ── live run: this machine's real catalog (a FAIL line here → suite RED) ──
live_out=$(python3 "$CENSUS" 2>&1); live_rc=$?
printf '%s\n' "$live_out"
check T1-live-run-no-collision "$live_rc" 0
has_count=$(printf '%s\n' "$live_out" \
  | grep -qE 'skills with description: [0-9]{2,}' && echo yes)
check T2-live-catalog-non-trivial "$has_count" yes

# ── fixture AB: near-duplicate pair + 2 unrelated fillers (N=4, real signal) ──
AB="$WORK/ab"
_mkskill "$AB" skill-a "description: |" \
  "  Use when deploying a project via its per-project runbook to ship the" \
  "  application to production servers safely with rollback support and" \
  "  health checks after each release."
_mkskill "$AB" skill-b "description: >-" \
  "  Use when deploying a project via its per-project deployment runbook to" \
  "  ship the application to production servers safely with rollback" \
  "  support and health checks after each release."
_mkskill "$AB" filler-translate "$TRANSLATE_DESC"
_mkskill "$AB" filler-secaudit "$SECAUDIT_DESC"
out_ab=$(SKILL_ROUTING_ROOTS="$AB" python3 "$CENSUS" 2>&1)
fail_line=$(printf '%s\n' "$out_ab" \
  | grep -qE '^FAIL 0\.[0-9]{2}  skill-a  ~  skill-b$' && echo yes)
check T3-collision-fail-line "$fail_line" yes
[ "$fail_line" = yes ] && echo FIXTURE_COLLISION_DETECTED

# ── fixture CD: distinct pair + same-corpus positive control (N=4) ────────
# skill-e/skill-f (positive control) must FAIL; skill-c/skill-d (the pair
# under test) must stay silent (no WARN/FAIL line naming them).
CD="$WORK/cd"
_mkcontrol "$CD"
_mkskill "$CD" skill-c "$TRANSLATE_DESC"
_mkskill "$CD" skill-d "$SECAUDIT_DESC"
out_cd=$(SKILL_ROUTING_ROOTS="$CD" python3 "$CENSUS" 2>&1)
control_fail=$(printf '%s\n' "$out_cd" \
  | grep -qE '^FAIL 0\.[0-9]{2}  skill-e  ~  skill-f$' && echo yes)
check T4-positive-control-fail "$control_fail" yes
distinct_marker=$(printf '%s\n' "$out_cd" \
  | grep -E '^(WARN|FAIL) 0\.[0-9]{2}  skill-c  ~  skill-d$')
distinct_silent=$([ -z "$distinct_marker" ] && echo yes || echo no)
check T5-distinct-pair-silent "$distinct_silent" yes

# ── sensitivity re-run: skill-d -> near-copy of skill-c ────────────────────
# Same corpus, but skill-d's description now near-duplicates skill-c's: the
# marker that stayed silent above must appear here, proving T5 wasn't silent
# by construction (e.g. a broken pattern or a threshold nothing can cross).
CD2="$WORK/cd-nearcopy"
_mkcontrol "$CD2"
_mkskill "$CD2" skill-c "$TRANSLATE_DESC"
_mkskill "$CD2" skill-d \
  'description: "Translate a PDF document, keeping the layout and images intact."'
out_cd2=$(SKILL_ROUTING_ROOTS="$CD2" python3 "$CENSUS" 2>&1)
sensitivity_marker=$(printf '%s\n' "$out_cd2" \
  | grep -qE '^(WARN|FAIL) 0\.[0-9]{2}  skill-c  ~  skill-d$' && echo yes)
check T6-sensitivity-marker-appears "$sensitivity_marker" yes

[ "$control_fail" = yes ] && [ "$distinct_silent" = yes ] \
  && [ "$sensitivity_marker" = yes ] && echo FIXTURE_DISTINCT_OK

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
