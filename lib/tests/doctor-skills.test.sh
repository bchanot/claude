#!/usr/bin/env bash
# lib/tests/doctor-skills.test.sh — lib/doctor-skills.sh's
# skill_catalog_stats(): an inline scalar description, a `|` block
# scalar, a `>-` folded block, a SKILL.md with no description, a
# symlinked skill dir (counted, matching Python glob.glob's symlink
# behavior), and an absent skills dir ("0 0", rc 0 — doctor.sh runs
# under `set -euo pipefail` and must never abort on this check).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/lib/doctor-skills.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
SKILLS="$WORK/skills"
REAL="$WORK/real-skill"
mkdir -p "$SKILLS/inline" "$SKILLS/pipe-block" "$SKILLS/fold-block" \
  "$SKILLS/no-desc" "$REAL"

cat > "$SKILLS/inline/SKILL.md" <<'EOF'
---
name: inline
description: "Inline description, sixteen."
---
body
EOF

cat > "$SKILLS/pipe-block/SKILL.md" <<'EOF'
---
name: pipe-block
description: |
  Block scalar description
  spanning two lines.
---
body
EOF

cat > "$SKILLS/fold-block/SKILL.md" <<'EOF'
---
name: fold-block
description: >-
  Folded block description
  on two lines too.
---
body
EOF

cat > "$SKILLS/no-desc/SKILL.md" <<'EOF'
---
name: no-desc
---
body
EOF

cat > "$REAL/SKILL.md" <<'EOF'
---
name: symlinked
description: "Symlinked skill description."
---
body
EOF
ln -s "$REAL" "$SKILLS/symlinked"

# ── hand-computed expectations (mirrors extract_description()'s scalar
# and block-scalar handling) ──
INLINE_DESC="Inline description, sixteen."
PIPE_DESC="Block scalar description spanning two lines."
FOLD_DESC="Folded block description on two lines too."
SYM_DESC="Symlinked skill description."
EXP_COUNT=5
EXP_CHARS=$((${#INLINE_DESC} + ${#PIPE_DESC} + ${#FOLD_DESC} + ${#SYM_DESC}))

# shellcheck source=../doctor-skills.sh disable=SC1091
source "$LIB"

out="$(skill_catalog_stats "$SKILLS")"
rc=$?
got_count="${out%% *}"
got_chars="${out##* }"
check T1-rc "$rc" 0
check T1-count "$got_count" "$EXP_COUNT"
check T1-chars "$got_chars" "$EXP_CHARS"

# ── T2: absent dir — "0 0", rc 0 ──
out2="$(skill_catalog_stats "$WORK/does-not-exist")"
rc2=$?
check T2-rc "$rc2" 0
check T2-zeroes "$out2" "0 0"

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
