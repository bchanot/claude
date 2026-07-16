#!/usr/bin/env bash
# run-review-guards.sh — anti-"partial-fix" regression guards.
#
# Genesis: .audit/review-release-1.0.0.md fil rouge. The 9-job series repeatedly
# fixed ONE instance of a banned pattern and left the twins (A1 trailer, A4 YAML,
# A5 false attribution, A2 hook drift). Each guard below greps the WHOLE surface
# for a pattern and REDs if any occurrence subsists — the check that would have
# caught A1/A4/A5/A2 at make-test time instead of an adversarial review.
set -uo pipefail

GREP=/usr/bin/grep                                   # LRN-074: pin grep
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
cd "$REPO"

pass=0; fail=0; skip=0
ok()   { echo "GREEN ✓ $*"; pass=$((pass+1)); }
no()   { echo "RED   ✗ $*"; fail=$((fail+1)); }
warn() { echo "SKIP  ~ $*"; skip=$((skip+1)); }

echo "=== review-guards: anti-partial-fix surface checks ==="

# G1 — banned commit-attribution trailers must not live in our own config surface
# (the ban is [[no-commit-attribution]]; skills-external/ = gstack submodule, excluded).
# This guard file is excluded: it names the pattern literally as its own search term.
if hits=$($GREP -rInE --exclude=run-review-guards.sh 'Co-Authored-By|Claude-Session' agents/ lib/ hooks/ templates/ skills/ 2>/dev/null); then
  echo "$hits"; no "G1 trailer: banned attribution trailer present in tracked config surface"
else
  ok "G1 trailer: zero Co-Authored-By/Claude-Session in agents|lib|hooks|templates|skills"
fi

# G2 — false CLAUDE.md attribution (asserting a user policy CLAUDE.md does not contain)
if hits=$($GREP -rInE 'per user.{0,5}CLAUDE\.md|User CLAUDE\.md default' agents/ skills/ 2>/dev/null); then
  echo "$hits"; no "G2 attribution: false 'per user CLAUDE.md' policy reference present"
else
  ok "G2 attribution: zero false CLAUDE.md policy references in agents|skills"
fi

# G3 — every agent frontmatter must be strict-YAML valid (degrade if pyyaml absent)
if python3 -c 'import yaml' 2>/dev/null; then
  if python3 - "$REPO" <<'PY'
import glob, os, sys, yaml
root=sys.argv[1]; bad=0
for f in sorted(glob.glob(os.path.join(root,'agents','*.md'))):
    try: yaml.safe_load(open(f).read().split('---')[1])
    except Exception as e: print("  FAIL", os.path.relpath(f,root), str(e).splitlines()[0]); bad+=1
sys.exit(1 if bad else 0)
PY
  then ok "G3 strict-YAML: all agents/*.md frontmatter parse"
  else no "G3 strict-YAML: an agent frontmatter fails yaml.safe_load"
  fi
else
  warn "G3 strict-YAML: python3+pyyaml unavailable — skipped"
fi

# G4 — the reconcile test must stay hermetic (fixtures, never the live registry) [job3 B1]
if $GREP -q '\.claude/memory' lib/tests/run-reconcile.sh 2>/dev/null; then
  no "G4 hermetic: run-reconcile.sh reads the live .claude/memory registry"
else
  ok "G4 hermetic: run-reconcile.sh reads fixtures only, not the live registry"
fi

# G5 — installed pre-commit hook must match the generator (catches the A2 silent drift:
# editing _gitflow_emit_pre_commit without re-installing). Degrade if emit-hook absent.
if emitted=$(bash lib/gitflow.sh emit-hook 2>/dev/null) && [ -n "$emitted" ]; then
  if [ -f .githooks/pre-commit ] && diff -q <(printf '%s\n' "$emitted") .githooks/pre-commit >/dev/null 2>&1; then
    ok "G5 hook-drift: installed .githooks/pre-commit == generator emit-hook"
  else
    no "G5 hook-drift: installed hook diverges from generator (run 'gitflow.sh install-hook')"
  fi
else
  warn "G5 hook-drift: gitflow.sh emit-hook unavailable — skipped"
fi

echo
echo "================  $pass GREEN / $fail RED / $skip SKIP  (review-guards)  ================"
[ "$fail" -eq 0 ]
