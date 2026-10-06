#!/usr/bin/env bash
# lib/tests/profile-census.test.sh — profile catalog invariants (skill-
# catalog prune, 2026-09-28): no GSTACK_REMOVED name listed in any
# profile, exactly one profile carries the `# SUPERSET-OF: full` marker
# and it is a superset of full + the parked tools + every name any
# profile carries, and `full` carries every name any other (non-max)
# profile carries save one named exception (pr-review-toolkit).
#
# Hermetic: a passing baseline fixture, then one single-change mutant per
# invariant (each mutant is a positive control — it MUST be detected).
# Live part runs against this repo's real lib/profiles/ (a violation
# there fails the suite for real, same style as
# lib/tests/skill-routing-census.test.sh).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=lib/gstack-removed.sh disable=SC1091
source "$ROOT/lib/gstack-removed.sh"

# Parked = kept installed, out of `full`, listed only in the superset
# profile (`max`). Names come from the single denylist above for REMOVED;
# PARKED has no such shared source (it is a positive allowlist, not a
# denylist), so it is spelled out here.
PARKED=(make-pdf diagram 21st-ai 21st-ui-explore 21st-ui-review)

# full carries every name any other (non-max) profile carries, with one
# named exception: pr-review-toolkit is deliberately out of full (audit
# 2026-07-02 #12, heaviest single plugin, ~2.2k tokens/session, PR-only
# use) — measured 2026-09-28: it is the only name any specialized
# profile carries that full lacks (audit.profile).
FULL_EXCEPTIONS=(pr-review-toolkit)

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

# census_check <profiles_dir> [parked_csv] [exceptions_csv] — one
# violation code per line on stdout, rc 0 iff none. REMOVED always comes
# from the sourced denylist (single source, never overridden);
# PARKED/FULL_EXCEPTIONS default to the real production sets and can be
# overridden per call (fixture runs use a small standalone catalog).
census_check() {
  local dir="$1"
  # Unset (arg omitted, live call) falls back to the real production
  # set; an explicitly EMPTY string (fixture calls) means "none" and
  # must stay empty — hence "-" defaults, never ":-" (which would treat
  # empty the same as unset and silently pull the real set back in).
  local parked_csv="${2-$(IFS=,; echo "${PARKED[*]}")}"
  local exc_csv="${3-$(IFS=,; echo "${FULL_EXCEPTIONS[*]}")}"
  local removed_csv out
  removed_csv="$(IFS=,; echo "${GSTACK_REMOVED[*]}")"
  out=$(python3 - "$dir" "$removed_csv" "$parked_csv" "$exc_csv" <<'PY'
import glob, os, re, sys

def entries(path):
    """Entry = first whitespace token of a non-blank, non-comment line."""
    names = set()
    for line in open(path, encoding="utf-8"):
        s = line.strip()
        if s and not s.startswith("#"):
            names.add(s.split()[0])
    return names

def has_marker(path):
    text = open(path, encoding="utf-8").read()
    return re.search(r'^# SUPERSET-OF: full\s*$', text, re.M) is not None

def check_removed(by_name, removed):
    return [f"REMOVED_LISTED:{n}:{e}" for n, ents in by_name.items()
            for e in sorted(ents & removed)]

def find_superset(files):
    hits = [p for p in files if has_marker(p)]
    if not hits:
        return None, ["NO_SUPERSET"]
    if len(hits) > 1:
        return None, ["MANY_SUPERSETS"]
    return os.path.basename(hits[0])[:-len(".profile")], []

def check_superset_gap(by_name, sname, parked, exceptions):
    full = by_name.get("full", set())
    target = full | parked | exceptions
    return [f"SUPERSET_GAP:{n}" for n in sorted(target - by_name[sname])]

def check_max_gap(by_name, sname, removed):
    union = set().union(*by_name.values())
    gap = (union - removed) - by_name[sname]
    return [f"MAX_GAP:{n}" for n in sorted(gap)]

def check_full_gap(by_name, sname, removed, exceptions):
    trio = {"21st-ai", "21st-ui-explore", "21st-ui-review"}
    src = set().union(*(e for n, e in by_name.items()
                         if n not in ("full", sname)))
    full = by_name.get("full", set())
    gap = src - full - removed - trio - exceptions
    return [f"FULL_GAP:{n}" for n in sorted(gap)]

def main():
    d, removed_csv, parked_csv, exc_csv = sys.argv[1:5]
    removed = {x for x in removed_csv.split(",") if x}
    parked = {x for x in parked_csv.split(",") if x}
    exceptions = {x for x in exc_csv.split(",") if x}

    files = sorted(glob.glob(os.path.join(d, "*.profile")))
    by_name = {os.path.basename(p)[:-len(".profile")]: entries(p)
               for p in files}

    violations = check_removed(by_name, removed)
    sname, sup_violations = find_superset(files)
    violations += sup_violations
    if sname:
        violations += check_superset_gap(by_name, sname, parked, exceptions)
        violations += check_max_gap(by_name, sname, removed)
        violations += check_full_gap(by_name, sname, removed, exceptions)

    # Reason codes only, one per line; no exit here — the bash caller
    # derives pass/fail from whether this captured output is empty.
    print("\n".join(violations))

main()
PY
)
  if [ -n "$out" ]; then
    printf '%s\n' "$out"
    return 1
  fi
  return 0
}

# run_mutant <label> <dir> <code> <flag> — census_check on <dir> (fixture
# PARKED override, empty FULL_EXCEPTIONS), asserts a non-zero rc AND the
# presence of <code>; echoes <flag> when both hold (the positive-control
# marker the contract CHECK greps for).
run_mutant() {
  local label="$1" dir="$2" code="$3" flag="$4"
  local out rc hit nonzero
  out=$(census_check "$dir" "parked-x" ""); rc=$?
  [ -n "$out" ] && printf '%s\n' "$out"
  hit=$(printf '%s\n' "$out" | grep -qxF "$code" && echo yes || echo no)
  nonzero=$([ "$rc" -ne 0 ] && echo yes || echo no)
  check "$label-code" "$hit" yes
  check "$label-nonzero" "$nonzero" yes
  [ "$hit" = yes ] && [ "$nonzero" = yes ] && echo "$flag"
}

# ── live: this repo's real profiles dir (a violation here → suite RED) ──
live_out=$(census_check "$ROOT/lib/profiles"); live_rc=$?
[ -n "$live_out" ] && printf '%s\n' "$live_out"
check T1-live-clean "$live_rc" 0

# ── fixtures: baseline + one single-change mutant per invariant ────────
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
BASE="$WORK/baseline"
mkdir -p "$BASE"
cat > "$BASE/full.profile" <<'EOF'
alpha
beta
EOF
cat > "$BASE/qa.profile" <<'EOF'
alpha
EOF
cat > "$BASE/max.profile" <<'EOF'
# SUPERSET-OF: full
alpha
beta
parked-x
EOF

base_out=$(census_check "$BASE" "parked-x" ""); base_rc=$?
[ -n "$base_out" ] && printf '%s\n' "$base_out"
check T2-fixture-baseline-clean "$base_rc" 0
[ "$base_rc" -eq 0 ] && echo FIXTURE_BASELINE_OK

# Mutant 1: a REMOVED name (ship) added to a profile other than full.
M1="$WORK/mutant-removed"; cp -r "$BASE" "$M1"
printf 'ship\n' >> "$M1/qa.profile"
run_mutant T3-mutant-removed "$M1" 'REMOVED_LISTED:qa:ship' \
  FIXTURE_REMOVED_DETECTED

# Mutant 2: the superset profile drops a name full carries.
M2="$WORK/mutant-superset"; cp -r "$BASE" "$M2"
# BSD sed -i needs a suffix argument
sed -i.bak '/^beta$/d' "$M2/max.profile" && rm -f "$M2/max.profile.bak"
run_mutant T4-mutant-superset "$M2" 'SUPERSET_GAP:beta' \
  FIXTURE_SUPERSET_DETECTED

# Mutant 3: a non-full, non-superset profile carries a name full lacks.
M3="$WORK/mutant-fullgap"; cp -r "$BASE" "$M3"
printf 'gamma\n' >> "$M3/qa.profile"
run_mutant T5-mutant-fullgap "$M3" 'FULL_GAP:gamma' \
  FIXTURE_FULLGAP_DETECTED

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
