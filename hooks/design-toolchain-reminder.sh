#!/usr/bin/env bash
# design-toolchain-reminder.sh
#
# UserPromptSubmit hook. When the prompt carries a UI/design signal, inject a
# reminder to mobilize the full design toolchain (tiered by scope, per CLAUDE.md
# "Design work — full toolchain"). A UserPromptSubmit hook's stdout is appended
# to the model's context, so the cat block below becomes additional guidance.
#
# This is a soft nudge: the tiered rule itself says trivial work uses NO
# toolchain, so a false positive (e.g. "API design") costs only a reminder the
# model can disregard. Always exits 0 so it never blocks prompt submission.

set -euo pipefail

input="$(cat)"

# Extract the user's prompt from the hook JSON; fall back to the raw stdin if
# python or the expected field is unavailable.
prompt="$(printf '%s' "$input" \
  | python3 -c 'import sys, json; print(json.load(sys.stdin).get("prompt", ""))' \
  2>/dev/null || true)"
[ -z "$prompt" ] && prompt="$input"

lc="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"

# UI/design build and review signals (FR + EN). Word boundaries (\b) avoid
# substring false matches like perform/platform/information. Tightened
# 2026-07-02: ultra-generic English tokens (page, form, menu, card, style,
# look, screen, interface, color) fired on a large share of NON-UI prompts —
# ~200 tokens of reminder each time (measured: 6 fires during a pure config
# audit). Kept: unambiguous design vocabulary + FR aesthetic words; specific
# compounds (stylesheet, styling, formulaire, écran) still match.
pattern='design|redesign|refonte|refont|ui/ux|ux/ui|\bui\b|\bux\b|ui kit|design system|design-system|frontend|front-end|front end|composant|component|\bnavbar\b|\bsidebar\b|\bmodal\b|\bbouton\b|\bbutton\b|formulaire|\bhero\b|\bheader\b|\bfooter\b|dropdown|tooltip|\bbadge\b|\bchart\b|graphique|accordion|carousel|\bslider\b|landing|dashboard|homepage|home page|\baccueil\b|\bécran\b|\becran\b|portfolio|maquette|mockup|wireframe|prototype|\bjoli\b|\bjolie\b|\bbeau\b|\bbelle\b|esth[eé]tique|aesthetic|\bvisuel\b|\bvisual\b|embellir|fignol|peaufin|polish|styliser|styling|stylesheet|\bskin\b|charte graphique|\bbrand\b|branding|\blogo\b|favicon|ic[oô]ne|\bicon\b|\bcss\b|tailwind|shadcn|couleur|palette|gradient|d[eé]grad[eé]|\bombre\b|spacing|espacement|\bmarge\b|\bpadding\b|\bmargin\b|\bradius\b|arrondi|\bhover\b|dark mode|light mode|\btheme\b|th[eè]me|typograph|\bfont\b|\bfonts\b|font pairing|\bpolice\b|animation|\bmotion\b|transition|micro-interaction|keyframe|glassmorph|neumorph|claymorph|skeuomorph|brutalis|bento|minimalis|responsive|figma'

if printf '%s' "$lc" | grep -Eq "$pattern"; then
  cat <<'EOF'
[design-toolchain] UI/design signal detected. Apply CLAUDE.md "Design work — full toolchain (tiered by scope)":
- Trivial (≤2 files, single cosmetic value, CSS tweak) → /hotfix, NO toolchain.
- Build UI (component/page/screen/redesign) → ui-ux-pro-max (plan/build) + frontend-design (anti-slop) + Magic MCP /ui (21st.dev scaffold) + emil-design-eng (polish) + design-motion-principles (if motion) + design-html (if static/Pretext).
- Design system/brand → design-consultation FIRST, then the build tools above.
- Review/audit → design-review + emil-design-eng lens + design-motion-principles (audit mode).
If genuinely trivial/non-UI, ignore this and proceed. IN DOUBT about scope (trivial vs real UI change) → do NOT silently skip: ask the user, or default to the build tier rather than /hotfix.
EOF
fi

exit 0
