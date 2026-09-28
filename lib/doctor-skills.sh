#!/usr/bin/env bash
# ============================================================
# lib/doctor-skills.sh — doctor.sh's skill-catalog stats
#
# `skill_catalog_stats <skills_dir>` counts every skill reachable
# through <skills_dir>/*/SKILL.md (symlinks included — Python's
# glob.glob follows them, verified: a symlinked skill dir matches the
# pattern the same as a real one) and sums their description length,
# reusing lib/skill-routing-census.py's extract_description() (handles
# a plain scalar AND a `|`/`>` YAML block scalar) instead of doctor.sh's
# old `grep '^description:' | head -1` (0 chars on every block-scalar
# description) and its `find -maxdepth 2` skill count (missed
# symlinked skill dirs without `-L`).
#
# Prints "<count> <desc_chars>" on stdout and ALWAYS exits 0 — an
# absent <skills_dir> naturally globs to nothing (0 0, no error); a
# python failure also prints "0 0" so doctor.sh (which runs under
# `set -euo pipefail`) never aborts on this check, PLUS one warn line on
# stderr so a real failure still shows instead of reading as a healthy
# empty catalog. The warn goes to stderr explicitly (not just via the
# caller's own warn() convention) because the caller reads this
# function's stdout with `read -r … < <(skill_catalog_stats …)` — any
# extra stdout line would corrupt that capture.
#
# No `set -euo pipefail` here (mirrors lib/vendor-skills.sh): a sourced
# lib must not change the caller's shell options.
# ============================================================

DOCTOR_SKILLS_LIB_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! declare -F warn >/dev/null 2>&1; then
  YELLOW='\033[1;33m'; NC='\033[0m'
  warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
fi

# skill_catalog_stats <skills_dir> — see file header.
skill_catalog_stats() {
  local dir="$1" census="$DOCTOR_SKILLS_LIB_DIR/skill-routing-census.py"
  local out rc
  out=$(python3 - "$dir" "$census" <<'PY'
import glob, importlib.util, sys

skills_dir, census_path = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location(
    "skill_routing_census", census_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

paths = glob.glob(skills_dir + "/*/SKILL.md")
chars = sum(len(module.extract_description(p) or "") for p in paths)
print(len(paths), chars)
PY
  )
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "$out"
    return 0
  fi
  warn "skill_catalog_stats: python failed (rc=$rc) — showing 0 0" >&2
  echo "0 0"
  return 0
}
