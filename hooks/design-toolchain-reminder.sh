#!/usr/bin/env bash
# design-toolchain-reminder.sh
#
# UserPromptSubmit hook. When the prompt carries a UI/design signal, inject a
# reminder to mobilize the full design toolchain (tiered by scope, per CLAUDE.global.md
# "Design work — full toolchain"). A UserPromptSubmit hook's stdout is appended
# to the model's context, so the cat block below becomes additional guidance.
#
# This is a soft nudge: the tiered rule itself says trivial work uses NO
# toolchain, so a false positive (e.g. "API design") costs only a reminder the
# model can disregard. Always exits 0 so it never blocks prompt submission.
#
# Every fire appends one line (time, matched token, prompt excerpt) to
# ~/.claude/logs/design-toolchain-fires.log — a counter so the next "is it
# over-firing?" decision is measured, not anecdotal.

set -euo pipefail

input="$(cat)"

# Extract the user's prompt from the hook JSON; fall back to the raw stdin if
# python or the expected field is unavailable.
prompt="$(printf '%s' "$input" \
  | python3 -c 'import sys, json; print(json.load(sys.stdin).get("prompt", ""))' \
  2>/dev/null || true)"
[ -z "$prompt" ] && prompt="$input"

# Harness-generated turns (subagent/task notifications) are not user
# requests — never fire on them (CLAUDE.global.md trigger = a design/UI *request*).
case "$prompt" in
  '<task-notification>'*) exit 0 ;;
esac

lc="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"

# UI/design build and review signals (FR + EN). Word boundaries (\b) avoid
# substring false matches like perform/platform/information.
# Tightened 2026-07-02: dropped ultra-generic tokens (page, form, menu, card,
# style, look, screen, interface, color) that fired on non-UI prompts.
# Tightened again 2026-07-03: dropped bare design|component|composant|theme|
# thème|transition|frontend|front-end|palette — all common in non-UI technical
# talk (a design decision, a system component, the theme of a discussion, a
# state transition, frontend architecture). Kept as UI-specific compounds:
# "design system", "redesign", "front-?end design". dashboard -> \bdashboard\b
# so a filename like ecc_dashboard.py no longer matches while "admin dashboard"
# still does. animation kept (rarely non-UI).
pattern='redesign|refonte|refont|ui/ux|ux/ui|\bui\b|\bux\b|ui kit|design system|design-system|front-?end design|\bnavbar\b|\bsidebar\b|\bmodal\b|\bbouton\b|\bbutton\b|formulaire|\bhero\b|\bheader\b|\bfooter\b|dropdown|tooltip|\bbadge\b|\bchart\b|graphique|accordion|carousel|\bslider\b|landing|\bdashboard\b|homepage|home page|\baccueil\b|\bécran\b|\becran\b|portfolio|maquette|mockup|wireframe|prototype|\bjoli\b|\bjolie\b|\bbeau\b|\bbelle\b|esth[eé]tique|aesthetic|\bvisuel\b|\bvisual\b|embellir|fignol|peaufin|polish|styliser|styling|stylesheet|\bskin\b|charte graphique|\bbrand\b|branding|\blogo\b|favicon|ic[oô]ne|\bicon\b|\bcss\b|tailwind|shadcn|couleur|gradient|d[eé]grad[eé]|\bombre\b|spacing|espacement|\bmarge\b|\bpadding\b|\bmargin\b|\bradius\b|arrondi|\bhover\b|dark mode|light mode|typograph|\bfont\b|\bfonts\b|font pairing|\bpolice\b|animation|\bmotion\b|micro-interaction|keyframe|glassmorph|neumorph|claymorph|skeuomorph|brutalis|bento|minimalis|responsive|figma'

if printf '%s' "$lc" | grep -Eq "$pattern"; then
  # Counter: log the fire (time, matched token, excerpt) — best-effort, never blocks.
  logf="${HOME}/.claude/logs/design-toolchain-fires.log"
  mkdir -p "$(dirname "$logf")" 2>/dev/null || true
  printf '%s\t%s\t%s\n' "$(date -Iseconds)" \
    "$(printf '%s' "$lc" | grep -oiE "$pattern" | head -1 || true)" \
    "$(printf '%s' "$prompt" | tr '\n\t' '  ' | cut -c1-100)" >> "$logf" 2>/dev/null || true
  cat <<'EOF'
Design work detected → apply global CLAUDE.md section "Design work — full toolchain" (already in context). Trivial (≤2 files, cosmetic) → /hotfix.
EOF
fi

exit 0
