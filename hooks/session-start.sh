#!/usr/bin/env bash
# ============================================================
# Claude Code — Session start plugin status
# Runs once per session. Filesystem only, except one quiet
# git fetch for the version/update check near the end.
# ============================================================

# Recursion guard (BLK-043): defense-in-depth, no live caller. Relies on
# Claude Code passing the env to hooks.
[ -n "${SESSION_START_RUNNING:-}" ] && exit 0
export SESSION_START_RUNNING=1

# ── Session source (memory digest gate) ──
# stdin carries the hook JSON. Read it first, before any child can eat it.
# Digest on startup | clear | compact, and on an empty source from a manual
# terminal run; never on resume. Without timeout or jq the source is
# unknowable: digest only when stdin is a terminal, never from a hook.
# A non-JSON stdin makes jq print nothing: it reads as an empty source and
# the digest prints.
_ss_digest=0
if command -v timeout >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  _ss_source=""
  if [ ! -t 0 ]; then
    _ss_in=$(timeout 1 cat 2>/dev/null)
    _ss_source=$(printf '%s' "$_ss_in" | jq -r '.source // empty' 2>/dev/null)
  fi
  case "$_ss_source" in ""|startup|clear|compact) _ss_digest=1 ;; esac
  # The mod's switch: `"enabled": false` (a boolean) cuts the digest. An
  # absent, unreadable or unparsable file, or any other value, keeps it.
  # "recall" is the mod's own key and is ignored here.
  _ss_off=$(jq -r 'if .enabled == false then "off" else "on" end' \
    "$HOME/.claude/memory.json" 2>/dev/null)
  [ "$_ss_off" = off ] && _ss_digest=0
  unset _ss_in _ss_source _ss_off
elif [ -t 0 ]; then
  _ss_digest=1
fi

# ── Bounded runner: timeout, else gtimeout, else perl alarm (stock macOS) ──
# perl execs the command, so the child is the same process alarm kills.
_SS_TMO=()
for _ss_t in timeout gtimeout; do
  command -v "$_ss_t" >/dev/null 2>&1 && { _SS_TMO=("$_ss_t" 2); break; }
done
if [ ${#_SS_TMO[@]} -eq 0 ] && command -v perl >/dev/null 2>&1; then
  _SS_TMO=(perl -e "alarm shift; exec { \$ARGV[0] } @ARGV" 2)
fi
unset _ss_t

# ── Quick health check (filesystem only, no subprocesses) ──
BROKEN=()
for f in CLAUDE.md settings.json agents skills rules; do
  [ ! -e "$HOME/.claude/$f" ] && BROKEN+=("$f")
done

if [ ${#BROKEN[@]} -gt 0 ]; then
  # Try to find the repo path from an existing symlink
  _repo_hint=""
  for _probe in CLAUDE.md settings.json; do
    if [ -L "$HOME/.claude/$_probe" ]; then
      _repo_hint="$(cd "$(dirname "$(readlink "$HOME/.claude/$_probe")")" 2>/dev/null && pwd)"
      break
    fi
  done
  _fix_cmd="${_repo_hint:+cd $_repo_hint && }bash link.sh"

  echo ""
  echo "┌─ ⚠️  CONFIG ISSUES ────────────────────────────────┐"
  for b in "${BROKEN[@]}"; do
    printf "│  MISSING: ~/.claude/%-30s│\n" "$b"
  done
  printf "│  → %-47s│\n" "$_fix_cmd"
  echo "│  → make doctor for full diagnostic                 │"
  echo "└───────────────────────────────────────────────────┘"
  unset _repo_hint _fix_cmd
fi

# ── Load shared detection library ──
_lib="$(dirname "${BASH_SOURCE[0]}")/../lib/detect-plugins.sh"
if [ -f "$_lib" ]; then
  # shellcheck source=../lib/detect-plugins.sh disable=SC1091
  source "$_lib"
else
  echo "⚠️  lib/detect-plugins.sh not found — config broken, run: bash link.sh"
  exit 0
fi
unset _lib

# ── gitflow hooks reconcile (BDR-095) ──
# A repo's .githooks/ lags lib/gitflow.sh until someone re-runs install-hook
# (LRN-114). Do it here, once per session, silently when current; the lib
# prints the refreshed names, shown in the banner with a commit reminder.
GF_REFRESHED=""
_gf_lib="$(dirname "${BASH_SOURCE[0]}")/../lib/gitflow.sh"
if [ -f "$_gf_lib" ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GF_REFRESHED=$(bash "$_gf_lib" reconcile-hooks 2>/dev/null | sed -n 's/^gitflow hooks refreshed: *//p')
fi

# ── graphify threshold signal (BDR-097) ──
# Informs, never acts: one banner line when the repo holds ≥ 200 tracked code
# files and no graph. The user decides whether to build one.
GRAPHIFY_HINT=""
_gg_lib="$(dirname "${BASH_SOURCE[0]}")/../lib/graphify-gate.sh"
if [ -f "$_gg_lib" ]; then GRAPHIFY_HINT=$(bash "$_gg_lib" "$PWD" 2>/dev/null); fi
unset _gg_lib

# ── Toggle plugin detection ──

# One profile.sh run, shared with detect_gstack through PROFILE_PLAIN.
PROFILE_PLAIN="$(bash "$HOME/.claude/lib/profile.sh" -C "$PWD" current \
  --plain 2>/dev/null)" || PROFILE_PLAIN=""
export PROFILE_PLAIN

TOGGLE_ACTIVE=()
TOGGLE_INACTIVE=()

for plugin in gstack uiux_pro_max context7 graphifyy; do
  # Map function name to display name. graphifyy = the pipx PACKAGE name
  # (pypi:graphifyy); the CLI and skill are 'graphify' — display that.
  case "$plugin" in
    uiux_pro_max)    display="ui-ux-pro-max" ;;
    graphifyy)       display="graphify" ;;
    *)               display="$plugin" ;;
  esac

  if "detect_$plugin" 2>/dev/null; then
    TOGGLE_ACTIVE+=("$display")
  else
    TOGGLE_INACTIVE+=("$display")
  fi
done

# Profile row: the project's local profile, the conversation's --settings
# one, or none (manifest defaults = full) with the /plugin-check pointer.
_pname="$(sed -n 's/^profile=//p' <<<"$PROFILE_PLAIN" | head -1)"
case "$(sed -n 's/^source=//p' <<<"$PROFILE_PLAIN" | head -1)" in
  flag)    PROFILE_ROW="profile: ${_pname} (conv)" ;;
  local)   PROFILE_ROW="profile: ${_pname} (local)" ;;
  default) PROFILE_ROW="profile: none (full), try /plugin-check" ;;
  *)       PROFILE_ROW="profile: ? (profile.sh failed)" ;;
esac
unset _pname

# GSD v2 — standalone CLI (not a Claude Code plugin — shown separately)
if detect_gsd 2>/dev/null; then
  GSD_STATUS="gsd v2 ✓"
else
  GSD_STATUS="gsd v2 ✗ (npm install -g gsd-pi)"
fi

# Version detection: follow CLAUDE.md symlink back to repo, then read version.txt
_claude_real="$(readlink "$HOME/.claude/CLAUDE.md" 2>/dev/null || true)"
if [ -n "$_claude_real" ]; then
  _repo_dir="$(cd "$(dirname "$_claude_real")" 2>/dev/null && pwd)"
  CONFIG_VERSION=$(cat "$_repo_dir/version.txt" 2>/dev/null || echo "?")
else
  CONFIG_VERSION="?"
fi
REPO_DIR="${_repo_dir:-}"
unset _claude_real _repo_dir

# Effort tiering (BDR-107): this env var beats every skill/agent `effort:` pin.
EFFORT_WARN=""
if [ -n "${CLAUDE_CODE_EFFORT_LEVEL:-}" ]; then
  EFFORT_WARN="⚠️  CLAUDE_CODE_EFFORT_LEVEL=${CLAUDE_CODE_EFFORT_LEVEL} set: skill/agent effort pins ignored"
fi

echo ""
echo "┌─ Claude Code config ──────────────────────────────────┐"
# "ALWAYS ON" row — actual state, not hardcoded. RTK is a binary on PATH;
# the others come from list_on_plugins (lib/detect-plugins.sh, same source
# as detect_uiux_pro_max and /status): the effective profile for the ids
# lib/profiles manages, user-scope settings.json for the rest. A hardcoded
# SET under-reports newly enabled plugins (pr-review-toolkit was enabled
# yet invisible). LRN-005 class. Missing/disabled is omitted. Plugins owned
# by the toggle row below are excluded (dual display).
ALWAYS_ON=()
detect_rtk &>/dev/null && ALWAYS_ON+=("rtk")
_toggle_owned=" gstack ui-ux-pro-max context7 graphify "
while IFS= read -r _pl; do
  _pl="${_pl%%@*}"
  [ -n "$_pl" ] || continue
  case "$_toggle_owned" in
    *" $_pl "*) : ;;
    *) ALWAYS_ON+=("$_pl") ;;
  esac
done < <(list_on_plugins)
unset _toggle_owned _pl
ALWAYS_ON_STR="${ALWAYS_ON[*]:-none}"
# 40-char width, greedy split: keeps the right border aligned on overflow
# (not a fixed 3-name cut: 3 long names overflowed line 1, line 2 empty).
if [ "${#ALWAYS_ON_STR}" -le 40 ]; then
  printf "│  ✅ ON  : %-40s│\n" "$ALWAYS_ON_STR"
else
  _ao_l1=""; _ao_l2=""
  for _ao_e in "${ALWAYS_ON[@]}"; do
    if [ -z "$_ao_l2" ] && [ $(( ${#_ao_l1} + ${#_ao_e} + 1 )) -le 40 ]; then
      _ao_l1="${_ao_l1:+$_ao_l1 }$_ao_e"
    else
      _ao_l2="${_ao_l2:+$_ao_l2 }$_ao_e"
    fi
  done
  printf "│  ✅ ON  : %-40s│\n" "$_ao_l1"
  printf "│             %-40s│\n" "$_ao_l2"
  unset _ao_l1 _ao_l2 _ao_e
fi
unset ALWAYS_ON ALWAYS_ON_STR
# Toggle rows: the four display names (38 chars) must fit the 40-char
# field; a fifth toggle needs a split again. OFF prints only when non-empty.
printf "│  🟢 ON  : %-40s│\n" "${TOGGLE_ACTIVE[*]:-none}"
if [ ${#TOGGLE_INACTIVE[@]} -gt 0 ]; then
  printf "│  ⚫ OFF : %-40s│\n" "${TOGGLE_INACTIVE[*]}"
fi
printf "│  🖥️  CLI : %-40s│\n" "$GSD_STATUS"
printf "│  📦 v%-45s│\n" "$CONFIG_VERSION"
if [ -n "$GF_REFRESHED" ]; then
  _gf_line="hooks refreshed: $GF_REFRESHED → commit .githooks/"
  printf "│  🪝 %-44s│\n" "${_gf_line:0:44}"
  unset _gf_line
fi
# ── manual-push mode (BDR-111): one lock line when this repo never auto-pushes ──
# %-46s, not 44: bash printf pads by BYTES and "—" is 3 bytes (2 extra).
_pm=$( [ -r "$_gf_lib" ] && bash "$_gf_lib" push-mode 2>/dev/null )
case "$_pm" in
  manual) printf "│  🔒 %-46s│\n" "push : manual (autopush=false) — ! git push" ;;
  invalid) printf "│  🔒 %-46s│\n" "push : manual (autopush bad) — ! git push" ;;
esac
unset _pm _gf_lib
# ── code origin: one line inside a git repo, none outside ──
_co_lib="$(dirname "${BASH_SOURCE[0]}")/../lib/code-origin.sh"
if [ -r "$_co_lib" ] && git rev-parse --git-dir >/dev/null 2>&1; then
  _co=$(bash "$_co_lib" 2>/dev/null)
  case "$_co" in
    ours*) _co_line="code : ours (limites strictes)" ;;
    foreign*) _co_line="code : foreign (${_co#foreign })" ;;
    *) _co_line="" ;;
  esac
  [ -n "$_co_line" ] && printf "│  📐 %-44s│\n" "${_co_line:0:44}"
  unset _co _co_line
fi
unset _co_lib
if [ -n "$GRAPHIFY_HINT" ]; then
  printf "│  🕸️  %-44s│\n" "${GRAPHIFY_HINT:0:44}"
  printf "│             %-40s│\n" "→ /graphify (AST, seconds) — you decide"
fi
# CLAUDE.global.md line-count guard (anti-regression, BDR-062): warn past
# 320. BDR-125 phase 1 moved Design work, the graphify usage and the
# architecture defaults to their carriers.
if [ -n "$REPO_DIR" ] && [ -f "$REPO_DIR/CLAUDE.global.md" ]; then
  _claude_lines=$(wc -l < "$REPO_DIR/CLAUDE.global.md")
  if [ "$_claude_lines" -gt 320 ]; then
    _cmd_warn="CLAUDE.global.md ${_claude_lines}L (>320) — density pass"
    printf "│  ⚠️  %-44s│\n" "${_cmd_warn:0:44}"
    unset _cmd_warn
  fi
  unset _claude_lines
fi
# Registry v1 (BDR-125 phase 4a): a project registry without `format: 2`.
# The lib names each v1 registry on stderr (`memory: v1: <file>`).
_mem_lib="$(dirname "${BASH_SOURCE[0]}")/../lib/memory.sh"
if [ -f "$_mem_lib" ] && [ -d .claude/memory ]; then
  # a hung memory.sh must not stall every session start
  _v1=$("${_SS_TMO[@]}" bash "$_mem_lib" check .claude/memory 2>&1 >/dev/null \
    | grep -c '^memory: v1:' || true)
  if [ "${_v1:-0}" -gt 0 ]; then
    printf "│  ⚠️  %-44s│\n" "registry v1: ${_v1} file(s) (memory.sh check)"
  fi
  unset _v1
fi
unset _mem_lib

# Version check: compare local vs remote (non-blocking)
_remote_ver=""
if [ -n "$REPO_DIR" ] && [ -d "$REPO_DIR/.git" ] && [ -z "${SESSION_START_OFFLINE:-}" ]; then
  _remote_ver=$(cd "$REPO_DIR" 2>/dev/null && git fetch origin --quiet 2>/dev/null && git show origin/main:version.txt 2>/dev/null) || _remote_ver=""
fi
if [ -n "$_remote_ver" ] && [ "$_remote_ver" != "$CONFIG_VERSION" ]; then
  printf "│  🔄 update available: v%-27s│\n" "$_remote_ver"
fi
unset _remote_ver REPO_DIR

printf "│  🎛 %-46s│\n" "$PROFILE_ROW"
echo "│  🩺 make doctor  full diagnostic                  │"
echo "└───────────────────────────────────────────────────┘"
[ -n "$EFFORT_WARN" ] && printf '%s\n' "$EFFORT_WARN"
# graphify usage (BDR-125 phase 1): the rules left CLAUDE.global.md, which
# keeps the 200-file threshold and a one-line reminder; they print where a
# graph exists.
_gx_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -n "$_gx_root" ] && [ -f "$_gx_root/graphify-out/graph.json" ]; then
  cat <<'EOF'
graphify (graphify-out/graph.json present):
- Codebase-wide question → `graphify query`; relationships → `path A B`;
  concept → `explain`. Scoped subgraph beats raw grep.
- Known file / small task → read directly, no graphify.
- `wiki/index.md` → broad-nav entry; `GRAPH_REPORT.md` → whole-architecture.
- After editing code → `graphify update .` (AST-only, free).
EOF
fi
unset _gx_root
# ── memory digest ──
# Cut a line at 160 chars with an ellipsis; a cut that split a multibyte
# char (non-UTF-8 locale) loses trailing chars until iconv accepts it.
_digest_cut() {
  local v=$1
  [ "${#v}" -le 160 ] && { printf '%s' "$v"; return; }
  v="${v:0:159}"
  if command -v iconv >/dev/null 2>&1; then
    while [ -n "$v" ] \
      && ! printf '%s' "$v" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1; do
      v="${v%?}"
    done
  fi
  printf '%s…' "$v"
}

# Open BLK (≤ 3 listed, the rest counted) and upstream count, as digest lines.
_digest_blockers() {  # <root> <memory.sh>
  local row line rest status title open=0 upstream=0 more=""
  while IFS= read -r row; do
    [[ "$row" == "| BLK-"* ]] || continue
    line="${row#| }"; line="${line% |}"
    rest="${line#* | }"; rest="${rest#* | }"
    [[ "$rest" == *" | "* ]] || continue
    status="${rest##* | }"; title="${rest% | *}"
    case "$status" in
      open) open=$((open + 1))
        [ "$open" -le 3 ] && echo "- open: ${line%% | *} $title" ;;
      upstream) upstream=$((upstream + 1)) ;;
    esac
  done < <("${_SS_TMO[@]}" bash "$2" -C "$1" index blocker 2>/dev/null)
  [ "$open" -gt 3 ] && more="+$((open - 3)) more"
  [ "$upstream" -gt 0 ] && more="${more:+$more, }+${upstream} upstream"
  [ -n "$more" ] && echo "- open: $more"
}

# <root> → first 3 unchecked Actionable items, else the file's first 3.
# Comment blocks (as _digest_journal) hide headings and items; indented
# items never count.
_digest_todo() {
  awk '/^[ \t]*<!--/ { c = 1 }
    !c && /^###? Actionable([ \t\r]|$)/ { on = 1; next }
    !c && /^#/ { on = 0 }
    !c && /^- \[ \] / {
      t = substr($0, 7)
      if (on && a < 3) A[++a] = t
      if (f < 3) F[++f] = t
    }
    /-->/ { c = 0 }
    END { if (a) { n = a; for (i = 1; i <= n; i++) print "- todo: " A[i] }
      else for (i = 1; i <= f; i++) print "- todo: " F[i] }' \
    "$1/.claude/tasks/TODO.md"
}

_digest_journal() {  # <root> → last journal bullet
  local last
  last=$(awk '/^[ \t]*<!--/ { c = 1 } !c && /^- / { l = $0 } /-->/ { c = 0 }
    END { if (!c) print l }' "$1/.claude/memory/journal.md")
  [ -n "$last" ] && echo "- journal: ${last#- }"
}

# How many leading todo lines fit in <room> chars (newline included).
_digest_fit() {  # <room>; reads the array todo of the caller
  local line size=0 shown=0
  for line in "${todo[@]}"; do
    size=$((size + ${#line} + 1))
    [ "$size" -le "$1" ] || break
    shown=$((shown + 1))
  done
  echo "$shown"
}

_digest_marker() {  # <dropped count>
  echo "- todo: +$1 not shown, read .claude/tasks/TODO.md"
}

# The block: header + open BLK lines + count line + todo lines + journal.
# Todo lines are added in order while the block stays <= 800 chars, so the
# last ones drop first; when one drops, room is reserved for a marker line
# that counts the dropped ones. Header, open BLK lines (3 x 160 max), count
# line, marker and journal always stay and always fit. The only loops are
# bounded by the todo count (3). Stays bash 3.2 safe (checked by SD11).
# Built in a variable and printed once, so a failure mid-way prints nothing.
_digest_assemble() {  # reads the arrays blk, cnt, todo, jr of the caller
  local out="memory digest:" tail="" line room shown
  for line in "${blk[@]}" "${cnt[@]}"; do out+=$'\n'"$line"; done
  for line in "${jr[@]}"; do tail=$'\n'"$line"; done
  room=$((800 - ${#out} - ${#tail}))
  shown=$(_digest_fit "$room")
  if [ "$shown" -lt "${#todo[@]}" ]; then
    line=$(_digest_marker 1)
    shown=$(_digest_fit $((room - ${#line} - 1)))
  fi
  for line in "${todo[@]:0:shown}"; do out+=$'\n'"$line"; done
  [ "$shown" -lt "${#todo[@]}" ] &&
    out+=$'\n'"$(_digest_marker $((${#todo[@]} - shown)))"
  printf '%s%s\n' "$out" "$tail"
}

_memory_digest() {  # <project-root>
  local root=$1 lib line blk=() cnt=() todo=() jr=()
  lib="$(dirname "${BASH_SOURCE[0]}")/../lib/memory.sh"
  [ -d "$root/.claude/memory" ] || return 0
  if [ -f "$lib" ]; then
    while IFS= read -r line; do
      case "$line" in
        "- open: +"*) cnt+=("$line") ;;
        *) blk+=("$(_digest_cut "$line")") ;;
      esac
    done < <(_digest_blockers "$root" "$lib")
  fi
  while IFS= read -r line; do todo+=("$(_digest_cut "$line")"); done \
    < <(_digest_todo "$root")
  while IFS= read -r line; do jr+=("$(_digest_cut "$line")"); done \
    < <(_digest_journal "$root")
  [ $((${#blk[@]} + ${#cnt[@]} + ${#todo[@]} + ${#jr[@]})) -gt 0 ] || return 0
  _digest_assemble
}
if [ "$_ss_digest" = 1 ]; then
  # phase 4d: the weekly /memory-feedback reminder, bounded, never fatal
  _ss_mf="$(dirname "${BASH_SOURCE[0]}")/../lib/memory-feedback-remind.sh"
  [ -f "$_ss_mf" ] && { "${_SS_TMO[@]}" bash "$_ss_mf" 2>/dev/null || true; }
  unset _ss_mf
  _ss_root=$(git rev-parse --show-toplevel 2>/dev/null) || _ss_root=$PWD
  # A foreign repository (`gitflow.protect` false) gets no digest.
  _ss_protect=$(git -C "$_ss_root" config --get gitflow.protect 2>/dev/null)
  [ "$_ss_protect" = false ] ||
    ( _memory_digest "$_ss_root" ) 2>/dev/null || true
  unset _ss_root _ss_protect
fi
unset _ss_digest

echo ""
unset PROFILE_PLAIN
