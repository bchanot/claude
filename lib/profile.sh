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
# Always-on plugins (never toggled by `set`): security-guidance,
# superpowers + rtk hook + .claude internal. The script refuses to disable
# anything in PROTECTED_PLUGINS.
#
# Usage:
#   profile.sh list                  list available profiles
#   profile.sh show <name>           show contents of a profile (grouped by type)
#   profile.sh show <name> --plain   parsable type+name list (no status, no claude)
#   profile.sh current               detect which profile is active
#   profile.sh apply <name>          enable items in profile (additive)
#   profile.sh set <name>            enable only profile (disables rest)
#   profile.sh reset                 re-enable all gstack skills + managed plugins
#   profile.sh gstack on|off         toggle gstack, keeping active-profile label
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

REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO/skills"
DISABLED_DIR="$REPO/skills-disabled"
GSTACK_SRC="$REPO/skills-external/gstack"  # gstack submodule — source of truth for gstack skills
PROFILES_DIR="$REPO/lib/profiles"
TOGGLE_EXTERNAL="$REPO/lib/toggle-external.sh"
ACTIVE_CACHE="$REPO/.active-profile"  # statusline reads this — keep fast (single-line file, profile name only)

# Plugins that are toggle-managed by `set`. Anything NOT in this list is
# never auto-disabled — protects always-on plugins (security-guidance,
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
  "security-guidance@claude-code-plugins"
  "superpowers@superpowers-marketplace"
)

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "${RED}✗${NC} $1" >&2; }
info() { echo -e "${BLUE}ℹ${NC}  $1"; }

# Persist active-profile name for fast statusline lookup (cmd_current is slow
# — iterates every profile + every entry). Write profile name only; statusline
# reads the file directly without re-invoking this script.
write_active() {
  local name="$1"
  printf '%s\n' "$name" > "$ACTIVE_CACHE" 2>/dev/null || true
}

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

# ── Counting & formatting helpers ─────────────────────────

# Tally a profile's entries by category (claude-free, reads the .profile only).
# Echo: "<skills> <plugins> <mcps> <clis>" — skills = gstack+external+personal.
count_profile() {
  local prof="$1" type
  local g=0 e=0 p=0 pl=0 m=0 c=0
  while IFS=$'\t' read -r _ type; do
    case "$type" in
      gstack)          g=$((g + 1)) ;;
      external)        e=$((e + 1)) ;;
      personal)        p=$((p + 1)) ;;
      plugin@*|plugin) pl=$((pl + 1)) ;;
      mcp)             m=$((m + 1)) ;;
      cli)             c=$((c + 1)) ;;
    esac
  done < <(read_profile "$prof")
  printf '%d %d %d %d\n' "$((g + e + p))" "$pl" "$m" "$c"
}

# "<n> <noun>" with a plural "s" when n != 1.
_plur() {
  if [ "$1" -eq 1 ]; then printf '%d %s' "$1" "$2"; else printf '%d %ss' "$1" "$2"; fi
}

# Format four category counts. style=compact -> "12s·1p·1m·1c";
# style=long -> "12 skills · 1 plugin · 1 mcp · 1 cli". Zero categories are
# skipped; all-zero -> "—".
fmt_counts() {
  local style="$1" skills="$2" pl="$3" m="$4" c="$5" out=""
  if [ "$style" = compact ]; then
    [ "$skills" -gt 0 ] && out="${skills}s"
    [ "$pl" -gt 0 ] && out="${out:+$out·}${pl}p"
    [ "$m" -gt 0 ]  && out="${out:+$out·}${m}m"
    [ "$c" -gt 0 ]  && out="${out:+$out·}${c}c"
  else
    [ "$skills" -gt 0 ] && out="$(_plur "$skills" skill)"
    [ "$pl" -gt 0 ] && out="${out:+$out · }$(_plur "$pl" plugin)"
    [ "$m" -gt 0 ]  && out="${out:+$out · }$(_plur "$m" mcp)"
    [ "$c" -gt 0 ]  && out="${out:+$out · }$(_plur "$c" cli)"
  fi
  printf '%s' "${out:-—}"
}

# Right-pad a string to display width $2 (character count, UTF-8 aware).
rpad() {
  local s="$1" w="$2" len=${#1}
  if [ "$len" -lt "$w" ]; then printf '%s%*s' "$s" "$((w - len))" ''; else printf '%s' "$s"; fi
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
      elif [ -d "$GSTACK_SRC/$skill" ]; then
        # gstack is OFF by default: its skills live only in the submodule,
        # never pre-symlinked into skills/. A profile that lists this gstack
        # skill activates it on demand by symlinking the submodule skill dir
        # in. disable_gstack_not_in() parks it again when an unrelated profile
        # is set. The gstack/bin + browse/dist infra it relies on is created
        # by link.sh, independent of this.
        ln -sf "$GSTACK_SRC/$skill" "$SKILLS_DIR/$skill"
        ok "enabled: $skill (gstack on-demand)"
      elif [ ! -d "$GSTACK_SRC" ]; then
        warn "missing: $skill — gstack submodule absent, run: git submodule update --init"
      else
        warn "missing: $skill — not found in gstack submodule ($GSTACK_SRC)"
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

# ── Shared gstack operations ──────────────────────────────

# Re-enable every gstack skill parked in skills-disabled/ (move gstack__*
# back into skills/). Shared by cmd_reset and `gstack on`. Side effects
# only; prints one confirmation per restored skill.
enable_all_gstack() {
  local entry name
  [ -d "$DISABLED_DIR" ] || return 0
  for entry in "$DISABLED_DIR"/gstack__*; do
    [ -e "$entry" ] || continue
    name="$(basename "$entry" | sed 's/^gstack__//')"
    rm -rf "${SKILLS_DIR:?}/${name:?}"
    mv "$entry" "$SKILLS_DIR/$name"
    ok "re-enabled: $name"
  done
}

# Disable gstack-origin skills not listed in the given profile. Shared by
# cmd_set and `gstack off`. Caller is responsible for validating the profile.
disable_gstack_not_in() {
  local prof="$1"
  local keep_file name
  keep_file="$(mktemp)"
  read_profile "$prof" | cut -f1 | sort -u > "$keep_file"
  while read -r name; do
    [ -n "$name" ] || continue
    grep -qx "$name" "$keep_file" || disable_skill "$name" gstack
  done < <(gstack_skills | sort -u)
  rm -f "$keep_file"
}

# Count gstack skills currently parked in skills-disabled/.
parked_gstack_count() {
  [ -d "$DISABLED_DIR" ] || { echo 0; return 0; }
  find "$DISABLED_DIR" -maxdepth 1 -name 'gstack__*' 2>/dev/null | wc -l | tr -d ' '
}

# ── Commands ──────────────────────────────────────────────

cmd_list() {
  printf "%-9s %-13s %s\n" "PROFILE" "ITEMS" "DESCRIPTION"
  printf "%-9s %-13s %s\n" "-------" "-----" "-----------"
  local f name desc skills pl m c contents
  for f in "$PROFILES_DIR"/*.profile; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .profile)"
    desc="$(profile_desc "$f")"
    read -r skills pl m c <<<"$(count_profile "$name")"
    contents="$(fmt_counts compact "$skills" "$pl" "$m" "$c")"
    printf "%-9s %s %s\n" "$name" "$(rpad "$contents" 13)" "${desc:--}"
  done
}

cmd_show() {
  local prof="$1" plain=0
  [ "${2:-}" = "--plain" ] && plain=1
  local file="$PROFILES_DIR/$prof.profile"
  [ -f "$file" ] || { err "Profile not found: $prof"; return 1; }

  # Snapshot entries once (claude-free): "<cat><TAB><name>", canonical name.
  # A plugin's marketplace (plugin@<mp>) collapses to category "plugin".
  local entries=() skill type cat
  while IFS=$'\t' read -r skill type; do
    case "$type" in plugin@*|plugin) cat=plugin ;; *) cat="$type" ;; esac
    entries+=("$cat"$'\t'"$skill")
  done < <(read_profile "$prof")

  # --plain: parsable contract for the design gate. One "<type><TAB><name>"
  # per line, grouped by type, NO status, NO claude calls.
  if [ "$plain" -eq 1 ]; then
    local e
    for cat in gstack external personal plugin mcp cli; do
      for e in "${entries[@]}"; do
        [ "${e%%$'\t'*}" = "$cat" ] && printf '%s\t%s\n' "$cat" "${e#*$'\t'}"
      done
    done
    return 0
  fi

  echo "Profile: $prof"
  local desc; desc="$(profile_desc "$file")"
  [ -n "$desc" ] && echo "Description: $desc"
  local skills pl m c total
  read -r skills pl m c <<<"$(count_profile "$prof")"
  total=$((skills + pl + m + c))
  if [ "$total" -eq 0 ]; then
    echo "Total: 0 items (empty — strips all gstack)"
  else
    echo "Total: $total items — $(fmt_counts long "$skills" "$pl" "$m" "$c")"
  fi
  echo ""

  # Grouped by type, fixed order; empty groups skipped. Canonical name +
  # runtime status (existing skill_status — degrades to disabled if no claude).
  local e names status
  for cat in gstack external personal plugin mcp cli; do
    names=()
    for e in "${entries[@]}"; do
      [ "${e%%$'\t'*}" = "$cat" ] && names+=("${e#*$'\t'}")
    done
    [ "${#names[@]}" -eq 0 ] && continue
    printf '%s (%d):\n' "$cat" "${#names[@]}"
    for skill in "${names[@]}"; do
      status="$(skill_status "$skill" "$cat")"
      printf '  %-24s %s\n' "$skill" "$status"
    done
  done
}

cmd_apply() {
  local prof="$1"
  info "Applying profile: $prof (additive — leaves other skills alone)"
  local skill type
  while IFS=$'\t' read -r skill type; do
    enable_skill "$skill" "$type"
  done < <(read_profile "$prof")
  write_active "$prof"
}

cmd_set() {
  local prof="$1"
  info "Setting profile: $prof (exclusive — disables non-listed gstack skills + managed plugins)"

  # Disable gstack-origin skills not in profile.
  disable_gstack_not_in "$prof"

  # Disable managed plugins not in profile (PROTECTED_PLUGINS are excluded
  # by disable_skill itself — belt and suspenders).
  local plugin_keep_file p plugin_name marketplace
  plugin_keep_file="$(mktemp)"
  read_profile "$prof" | awk -F'\t' '$2 ~ /^plugin@/ { sub(/^plugin@/, "", $2); print $1"@"$2 }' | sort -u > "$plugin_keep_file"
  for p in "${MANAGED_PLUGINS[@]}"; do
    if ! grep -qx "$p" "$plugin_keep_file"; then
      plugin_name="${p%@*}"
      marketplace="${p#*@}"
      disable_skill "$plugin_name" "plugin@${marketplace}"
    fi
  done
  rm -f "$plugin_keep_file"

  # Enable everything listed in the profile.
  cmd_apply "$prof"
}

cmd_reset() {
  info "Re-enabling all gstack skills (move skills-disabled/gstack__* back)"
  enable_all_gstack
  info "Plugin state NOT touched. To re-enable a managed plugin disabled by 'set',"
  info "run: claude plugin enable <name>@<marketplace>  (or: profile apply <profile>)"
  write_active "none"
}

# gstack on|off — focused gstack-only toggle that keeps the active-profile
# label intact (unlike reset, which clears it to "none"). Lets the user
# layer all gstack on top of their current profile, or trim it back down
# to just what the active profile needs.
cmd_gstack() {
  local action="${1:-}"
  case "$action" in
    on)
      # Re-enable ALL gstack skills, but DON'T touch active-profile — the
      # user is adding gstack on top of their current profile, not clearing it.
      local parked
      parked="$(parked_gstack_count)"
      if [ "$parked" -eq 0 ]; then
        info "all gstack skills already enabled"
      else
        enable_all_gstack
        ok "all gstack enabled ($parked skills restored)"
      fi
      ;;
    off)
      # Disable gstack skills not needed by the active profile. Needs a real
      # active profile to know what to keep.
      local active
      active="$(head -n1 "$ACTIVE_CACHE" 2>/dev/null || echo none)"
      [ -z "$active" ] && active="none"
      if [ "$active" = "none" ] || [ ! -f "$PROFILES_DIR/$active.profile" ]; then
        err "no active profile — 'gstack off' needs one to know what to keep"
        info "run: bash lib/profile.sh set <name>   then: gstack off"
        return 1
      fi
      info "Disabling gstack skills not in active profile: $active"
      disable_gstack_not_in "$active"
      ok "gstack trimmed to profile: $active"
      ;;
    ""|-h|--help|help)
      cat <<'EOF'
profile gstack on|off — toggle gstack without losing the active-profile label

  on    re-enable ALL gstack skills (keeps active-profile label)
  off   disable gstack skills not in the active profile
EOF
      ;;
    *)
      err "Unknown gstack action: '$action' (use: on | off)"; return 1 ;;
  esac
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
  profile show <name>       show profile contents grouped by type + status
  profile show <name> --plain  parsable type+name list (no status, no claude)
  profile current           detect which profile is currently active
  profile apply <name>      enable skills in profile (additive)
  profile set <name>        enable only listed skills (disables rest of gstack)
  profile reset             re-enable all gstack skills
  profile gstack on|off     toggle gstack only, keep active-profile label
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
    show)    [ $# -ge 2 ] || { usage; exit 1; }; cmd_show "$2" "${3:-}" ;;
    current) cmd_current ;;
    apply)   [ $# -ge 2 ] || { usage; exit 1; }; cmd_apply "$2" ;;
    set)     [ $# -ge 2 ] || { usage; exit 1; }; cmd_set "$2" ;;
    reset)   cmd_reset ;;
    gstack)  cmd_gstack "${2:-}" ;;
    diff)    [ $# -ge 3 ] || { usage; exit 1; }; cmd_diff "$2" "$3" ;;
    ""|-h|--help|help) usage ;;
    *) err "Unknown command: $cmd"; usage; exit 1 ;;
  esac
}

main "$@"
