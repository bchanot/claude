#!/usr/bin/env bash
# ============================================================
# lib/profile.sh — Partition Claude skills + plugins + MCPs by purpose
#
# Profiles group skills (gstack + external + personal), plugins, MCPs,
# and CLIs for a specific kind of work: web, seo, web-full, backend,
# design, dev, qa, audit, minimal. Apply a profile to enable just the
# relevant tools and disable the rest, instead of carrying every gstack
# skill + every plugin in every session.
#
# Mechanism:
#   - Skills (gstack/external/personal): symlink toggle skills/ ↔ skills-disabled/
#   - Plugins: `claude plugin enable|disable <name>@<marketplace>`
#   - MCPs: delegated to lib/toggle-external.sh for known servers (magic),
#           advisory otherwise
#   - CLIs: advisory only (rtk, gsd, ctx7, graphify — installed externally)
#
# Always-on plugins (never toggled by `set`): caveman, security-guidance,
# superpowers + rtk hook + .claude internal. The script refuses to disable
# anything in PROTECTED_PLUGINS.
#
# Usage:
#   profile.sh list                  list available profiles
#   profile.sh show <name>           show contents of a profile
#   profile.sh current               detect which profile is active
#   profile.sh apply <name>          enable items in profile (additive)
#   profile.sh set <name>            enable only profile (disables rest)
#   profile.sh reset                 re-enable all gstack skills + managed plugins
#   profile.sh diff <a> <b>          compare two profiles
#
# Profile file format (lib/profiles/<name>.profile):
#   # DESC: <one-line description>
#   <skill-name>                          # type defaults to "gstack"
#   <skill-name>     personal             # personal skill (skills/<x>/SKILL.md is real)
#   <skill-name>     external             # symlinked into skills-external/
#   <plugin-name>    plugin@<marketplace> # Claude plugin — auto-toggle
#   <mcp-name>       mcp                  # MCP — advisory or via toggle-external
#   <cli-name>       cli                  # standalone CLI — advisory only
#
# ============================================================
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO/skills"
DISABLED_DIR="$REPO/skills-disabled"
PROFILES_DIR="$REPO/lib/profiles"
TOGGLE_EXTERNAL="$REPO/lib/toggle-external.sh"

# Plugins that are toggle-managed by `set`. Anything NOT in this list is
# never auto-disabled — protects always-on plugins (caveman, security-guidance,
# superpowers) and unrelated user plugins. Add a plugin here only when its
# enabled state is meaningfully driven by task type.
MANAGED_PLUGINS=(
  "ui-ux-pro-max@ui-ux-pro-max-skill"
  "plugin-dev@claude-code-plugins"
  "pr-review-toolkit@claude-code-plugins"
)

# Plugins that MUST stay enabled — `set` will refuse to disable these even if
# they're not in the profile. (Defensive: belt-and-suspenders alongside
# MANAGED_PLUGINS allowlist.)
PROTECTED_PLUGINS=(
  "caveman@caveman"
  "security-guidance@claude-code-plugins"
  "superpowers@superpowers-marketplace"
)

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "${RED}✗${NC} $1" >&2; }
info() { echo -e "${BLUE}ℹ${NC}  $1"; }

# ── Profile parsing ────────────────────────────────────────

# Read a profile file. Output one line per entry: "<skill>\t<type>"
# Comments (#…) and blank lines are stripped. Default type is "gstack".
read_profile() {
  local prof="$1"
  local file="$PROFILES_DIR/$prof.profile"
  [ -f "$file" ] || { err "Profile not found: $prof (looked in $PROFILES_DIR)"; return 1; }
  local skill type rest
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    # trim leading whitespace + tabs
    while [[ "$line" =~ ^[[:space:]] ]]; do line="${line#?}"; done
    # trim trailing whitespace + tabs
    while [[ "$line" =~ [[:space:]]$ ]]; do line="${line%?}"; done
    [ -z "$line" ] && continue
    # split on first whitespace run
    skill="${line%%[[:space:]]*}"
    rest="${line#"$skill"}"
    while [[ "$rest" =~ ^[[:space:]] ]]; do rest="${rest#?}"; done
    type="${rest:-gstack}"
    # Validate type. Accepted forms:
    #   gstack | external | personal       — skill (symlink toggle)
    #   plugin@<marketplace>               — Claude plugin (auto-toggle)
    #   plugin                             — legacy/advisory (no marketplace known)
    #   mcp                                — MCP server (advisory or via toggle-external)
    #   cli                                — standalone CLI (advisory only)
    case "$type" in
      gstack|external|personal|plugin|mcp|cli) : ;;
      plugin@*) : ;;
      *) warn "unknown type '$type' for entry '$skill' in $prof — defaulting to gstack"; type=gstack ;;
    esac
    printf '%s\t%s\n' "$skill" "$type"
  done < "$file"
}

# All skills bundled in skills-external/gstack/
gstack_skills() {
  local src="$REPO/skills-external/gstack"
  [ -d "$src" ] || return 0
  for d in "$src"/*/; do
    [ -f "${d}SKILL.md" ] || continue
    basename "$d"
  done
}

# Profile description (line starting with "# DESC: …")
profile_desc() {
  local file="$1"
  grep -m1 '^# DESC:' "$file" 2>/dev/null | sed 's/^# DESC:[[:space:]]*//' || true
}

# ── Status detection ──────────────────────────────────────

skill_status() {
  local skill="$1" type="$2"
  case "$type" in
    gstack|external|personal)
      if [ -e "$SKILLS_DIR/$skill" ]; then
        echo "enabled"
      elif [ -e "$DISABLED_DIR/gstack__$skill" ] || [ -e "$DISABLED_DIR/$skill" ]; then
        echo "disabled"
      else
        echo "missing"
      fi
      ;;
    plugin|plugin@*)
      # `claude plugin list` is the source of truth — settings.json may be
      # ahead of or behind reality if the user toggled outside this tool.
      if command -v claude >/dev/null 2>&1; then
        # Match the plugin block by name then check Status line
        if claude plugin list 2>/dev/null \
           | awk -v p="$skill" '
               /^[[:space:]]*❯ '"$skill"'@/ { found=1; next }
               found && /Status:/ { print; exit }
             ' \
           | grep -q "✔ enabled"; then
          echo "enabled"
        else
          echo "disabled"
        fi
      else
        echo "unknown"
      fi
      ;;
    mcp)
      if command -v claude >/dev/null 2>&1 && \
         claude mcp list 2>/dev/null | grep -q "^${skill}"; then
        echo "enabled"
      else
        echo "disabled"
      fi
      ;;
    cli)
      command -v "$skill" >/dev/null 2>&1 && echo "installed" || echo "not-installed"
      ;;
    *) echo "unknown" ;;
  esac
}

# ── Enable / disable ──────────────────────────────────────

enable_skill() {
  local skill="$1" type="$2"
  case "$type" in
    gstack)
      if [ -e "$DISABLED_DIR/gstack__$skill" ]; then
        rm -rf "${SKILLS_DIR:?}/${skill:?}"
        mv "$DISABLED_DIR/gstack__$skill" "$SKILLS_DIR/$skill"
        ok "enabled: $skill"
      elif [ -e "$DISABLED_DIR/$skill" ]; then
        rm -rf "${SKILLS_DIR:?}/${skill:?}"
        mv "$DISABLED_DIR/$skill" "$SKILLS_DIR/$skill"
        ok "enabled: $skill"
      elif [ -e "$SKILLS_DIR/$skill" ]; then
        : # already enabled — silent
      else
        warn "missing: $skill — try: bash link.sh"
      fi
      ;;
    external|personal)
      if [ -e "$DISABLED_DIR/$skill" ]; then
        rm -rf "${SKILLS_DIR:?}/${skill:?}"
        mv "$DISABLED_DIR/$skill" "$SKILLS_DIR/$skill"
        ok "enabled: $skill ($type)"
      elif [ -e "$SKILLS_DIR/$skill" ]; then
        :
      else
        warn "missing: $skill ($type)"
      fi
      ;;
    plugin@*)
      # type holds the marketplace: plugin@<marketplace>
      local marketplace="${type#plugin@}"
      if [ "$(skill_status "$skill" "$type")" = "enabled" ]; then
        : # already on
      elif command -v claude >/dev/null 2>&1; then
        if claude plugin enable "${skill}@${marketplace}" 2>&1 | grep -qiE "enabled|already"; then
          ok "enabled plugin: ${skill}@${marketplace}"
        else
          warn "could not enable plugin: ${skill}@${marketplace}"
        fi
      else
        info "claude CLI not in PATH — manual: claude plugin enable ${skill}@${marketplace}"
      fi
      ;;
    plugin)
      # No marketplace specified — purely advisory.
      if [ "$(skill_status "$skill" plugin)" = "enabled" ]; then
        : # already on
      else
        info "plugin '$skill' not enabled — run: claude plugin enable $skill@<marketplace>"
      fi
      ;;
    mcp)
      if [ "$(skill_status "$skill" mcp)" = "enabled" ]; then
        : # already on
      elif [ "$skill" = "magic" ] && [ -x "$TOGGLE_EXTERNAL" ]; then
        # Known MCP — delegate to lib/toggle-external.sh which handles env vars.
        if bash "$TOGGLE_EXTERNAL" enable magic 2>&1 | grep -qE "enabled|already"; then
          ok "enabled MCP: magic"
        else
          info "MCP 'magic' could not be enabled (check .env for MAGIC_API_KEY)"
        fi
      else
        info "MCP '$skill' not registered — run: claude mcp add $skill -- <command>"
      fi
      ;;
    cli)
      # CLIs install externally; we never auto-install. Just report status.
      if command -v "$skill" >/dev/null 2>&1; then
        : # installed — silent
      else
        info "CLI '$skill' not installed — install separately (npm/cargo/pipx)"
      fi
      ;;
  esac
}

disable_skill() {
  local skill="$1" type="$2"
  case "$type" in
    gstack)
      if [ -e "$SKILLS_DIR/$skill" ]; then
        mkdir -p "$DISABLED_DIR"
        rm -rf "$DISABLED_DIR/gstack__$skill"
        mv "$SKILLS_DIR/$skill" "$DISABLED_DIR/gstack__$skill"
        ok "disabled: $skill"
      fi
      ;;
    external|personal)
      if [ -e "$SKILLS_DIR/$skill" ]; then
        mkdir -p "$DISABLED_DIR"
        rm -rf "${DISABLED_DIR:?}/${skill:?}"
        mv "$SKILLS_DIR/$skill" "$DISABLED_DIR/$skill"
        ok "disabled: $skill ($type)"
      fi
      ;;
    plugin@*)
      local marketplace="${type#plugin@}"
      local key="${skill}@${marketplace}"
      # Defensive check against PROTECTED_PLUGINS (always-on).
      local p
      for p in "${PROTECTED_PLUGINS[@]}"; do
        if [ "$key" = "$p" ]; then
          warn "refusing to disable protected plugin: $key"
          return 0
        fi
      done
      if [ "$(skill_status "$skill" "$type")" = "disabled" ]; then
        : # already off
      elif command -v claude >/dev/null 2>&1; then
        if claude plugin disable "$key" 2>&1 | grep -qiE "disabled|already"; then
          ok "disabled plugin: $key"
        else
          warn "could not disable plugin: $key"
        fi
      else
        info "claude CLI not in PATH — manual: claude plugin disable $key"
      fi
      ;;
    plugin)
      info "plugin '$skill' — manual: claude plugin disable $skill@<marketplace>"
      ;;
    mcp)
      if [ "$skill" = "magic" ] && [ -x "$TOGGLE_EXTERNAL" ]; then
        if bash "$TOGGLE_EXTERNAL" disable magic 2>&1 | grep -qE "disabled|already"; then
          ok "disabled MCP: magic"
        else
          info "MCP 'magic' — manual disable failed"
        fi
      else
        info "MCP '$skill' — manual: claude mcp remove $skill"
      fi
      ;;
    cli)
      : # never auto-uninstall CLIs
      ;;
  esac
}

# ── Commands ──────────────────────────────────────────────

cmd_list() {
  printf "%-12s %s\n" "PROFILE" "DESCRIPTION"
  printf "%-12s %s\n" "-------" "-----------"
  local f name desc
  for f in "$PROFILES_DIR"/*.profile; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .profile)"
    desc="$(profile_desc "$f")"
    printf "%-12s %s\n" "$name" "${desc:--}"
  done
}

cmd_show() {
  local prof="$1"
  local file="$PROFILES_DIR/$prof.profile"
  [ -f "$file" ] || { err "Profile not found: $prof"; return 1; }
  echo "Profile: $prof"
  local desc
  desc="$(profile_desc "$file")"
  [ -n "$desc" ] && echo "Description: $desc"
  echo ""
  printf "%-25s %-30s %s\n" "ITEM" "TYPE" "STATUS"
  printf "%-25s %-30s %s\n" "----" "----" "------"
  local skill type status
  while IFS=$'\t' read -r skill type; do
    status="$(skill_status "$skill" "$type")"
    printf "%-25s %-30s %s\n" "$skill" "$type" "$status"
  done < <(read_profile "$prof")
}

cmd_apply() {
  local prof="$1"
  info "Applying profile: $prof (additive — leaves other skills alone)"
  local skill type
  while IFS=$'\t' read -r skill type; do
    enable_skill "$skill" "$type"
  done < <(read_profile "$prof")
}

cmd_set() {
  local prof="$1"
  info "Setting profile: $prof (exclusive — disables non-listed gstack skills + managed plugins)"

  # Index of items in profile (skill names + plugin keys "name@marketplace").
  local keep_file
  keep_file="$(mktemp)"
  # Skill names (col 1) — used to keep gstack skills.
  read_profile "$prof" | cut -f1 | sort -u > "$keep_file"
  # Plugin keys "name@marketplace" — used to keep managed plugins.
  local plugin_keep_file
  plugin_keep_file="$(mktemp)"
  read_profile "$prof" | awk -F'\t' '$2 ~ /^plugin@/ { sub(/^plugin@/, "", $2); print $1"@"$2 }' | sort -u > "$plugin_keep_file"

  # Disable gstack-origin skills not in profile.
  local name
  while read -r name; do
    [ -n "$name" ] || continue
    if ! grep -qx "$name" "$keep_file"; then
      disable_skill "$name" gstack
    fi
  done < <(gstack_skills | sort -u)

  # Disable managed plugins not in profile (PROTECTED_PLUGINS are excluded
  # by disable_skill itself — belt and suspenders).
  local p key plugin_name marketplace
  for p in "${MANAGED_PLUGINS[@]}"; do
    if ! grep -qx "$p" "$plugin_keep_file"; then
      plugin_name="${p%@*}"
      marketplace="${p#*@}"
      disable_skill "$plugin_name" "plugin@${marketplace}"
    fi
  done

  rm -f "$keep_file" "$plugin_keep_file"
  # Enable everything listed in the profile.
  cmd_apply "$prof"
}

cmd_reset() {
  info "Re-enabling all gstack skills (move skills-disabled/gstack__* back)"
  local entry name
  if [ -d "$DISABLED_DIR" ]; then
    for entry in "$DISABLED_DIR"/gstack__*; do
      [ -e "$entry" ] || continue
      name="$(basename "$entry" | sed 's/^gstack__//')"
      rm -rf "${SKILLS_DIR:?}/${name:?}"
      mv "$entry" "$SKILLS_DIR/$name"
      ok "re-enabled: $name"
    done
  fi
  info "Plugin state NOT touched. To re-enable a managed plugin disabled by 'set',"
  info "run: claude plugin enable <name>@<marketplace>  (or: profile apply <profile>)"
}

cmd_current() {
  # A profile is "active" only if (a) most of its skills are enabled AND
  # (b) at least one non-listed gstack skill is currently disabled (i.e. a
  # `set` has actually been applied). Without (b), every profile reports
  # 100% trivially because the full gstack is on.
  local disabled_count=0
  if [ -d "$DISABLED_DIR" ]; then
    disabled_count=$(find "$DISABLED_DIR" -maxdepth 1 -name 'gstack__*' 2>/dev/null | wc -l | tr -d ' ')
  fi
  if [ "$disabled_count" -eq 0 ]; then
    echo "none (all gstack skills enabled — no profile set)"
    return 0
  fi
  # Pick the profile with the highest "available" ratio. An item counts as
  # available when its status is "enabled" (skills, plugins, MCPs) or
  # "installed" (CLIs). On ties, the profile with the larger total wins
  # — superset profiles describe state more completely than subsets.
  local f name total available score skill type status
  local best="" best_score=0 best_total=0
  for f in "$PROFILES_DIR"/*.profile; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .profile)"
    total=0; available=0
    while IFS=$'\t' read -r skill type; do
      total=$((total + 1))
      status="$(skill_status "$skill" "$type")"
      case "$status" in
        enabled|installed) available=$((available + 1)) ;;
      esac
    done < <(read_profile "$name")
    [ "$total" -eq 0 ] && continue
    score=$((available * 100 / total))
    if [ "$score" -gt "$best_score" ] || \
       { [ "$score" -eq "$best_score" ] && [ "$total" -gt "$best_total" ]; }; then
      best_score="$score"
      best_total="$total"
      best="$name"
    fi
  done
  if [ -n "$best" ] && [ "$best_score" -ge 80 ]; then
    echo "$best (${best_score}% match, $disabled_count gstack skills disabled)"
  else
    echo "custom (best guess: ${best:-none} ${best_score}%, $disabled_count gstack skills disabled)"
  fi
}

cmd_diff() {
  local a="$1" b="$2"
  local fa="$PROFILES_DIR/$a.profile" fb="$PROFILES_DIR/$b.profile"
  [ -f "$fa" ] || { err "Profile not found: $a"; return 1; }
  [ -f "$fb" ] || { err "Profile not found: $b"; return 1; }
  local list_a list_b
  list_a="$(mktemp)"; list_b="$(mktemp)"
  read_profile "$a" | cut -f1 | sort -u > "$list_a"
  read_profile "$b" | cut -f1 | sort -u > "$list_b"
  echo "Only in $a:"; comm -23 "$list_a" "$list_b" | sed 's/^/  - /'
  echo "Only in $b:"; comm -13 "$list_a" "$list_b" | sed 's/^/  + /'
  echo "Common:"   ; comm -12 "$list_a" "$list_b" | sed 's/^/  = /'
  rm -f "$list_a" "$list_b"
}

usage() {
  cat <<EOF
profile.sh — partition Claude skills by purpose

USAGE:
  profile list              list all available profiles
  profile show <name>       show profile contents + per-skill status
  profile current           detect which profile is currently active
  profile apply <name>      enable skills in profile (additive)
  profile set <name>        enable only listed skills (disables rest of gstack)
  profile reset             re-enable all gstack skills
  profile diff <a> <b>      compare two profiles

PROFILES (in $PROFILES_DIR):
EOF
  local f name desc
  for f in "$PROFILES_DIR"/*.profile; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .profile)"
    desc="$(profile_desc "$f")"
    printf "  %-10s %s\n" "$name" "${desc:--}"
  done
  cat <<EOF

EXAMPLES:
  bash lib/profile.sh list
  bash lib/profile.sh show design
  bash lib/profile.sh set design       # only design skills active
  bash lib/profile.sh apply qa         # add QA skills on top
  bash lib/profile.sh reset            # restore everything

NOTE:
  Plugin and MCP entries print advisory commands — they are NOT toggled
  automatically. Run "claude plugin enable|disable" or "claude mcp add|remove"
  yourself for those.
EOF
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    list)    cmd_list ;;
    show)    [ $# -ge 2 ] || { usage; exit 1; }; cmd_show "$2" ;;
    current) cmd_current ;;
    apply)   [ $# -ge 2 ] || { usage; exit 1; }; cmd_apply "$2" ;;
    set)     [ $# -ge 2 ] || { usage; exit 1; }; cmd_set "$2" ;;
    reset)   cmd_reset ;;
    diff)    [ $# -ge 3 ] || { usage; exit 1; }; cmd_diff "$2" "$3" ;;
    ""|-h|--help|help) usage ;;
    *) err "Unknown command: $cmd"; usage; exit 1 ;;
  esac
}

main "$@"
