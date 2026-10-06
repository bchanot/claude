#!/usr/bin/env bash
# ============================================================
# lib/gstack-playwright.sh — gstack's Playwright: OS-support bump +
# read-only browser-cache report.
#
# Sourced by: install-plugins.sh, update-all.sh, doctor.sh — all three run
# `set -euo pipefail`. gstack_bump_playwright_if_unsupported and
# gstack_browsers_report are called as BARE STATEMENTS under that inherited
# errexit, so they `return 0` on every path and every capture that could
# fail is guarded (`|| true` or an `if`), never a bare `&&`/`||`-less
# statement. gstack_submodule_update_with_bump is the ONE function allowed
# to return non-zero — callers use it ONLY as an `if` condition.
#
# No `set -euo pipefail` here (mirrors lib/detect-plugins.sh): a sourced
# lib must not change the caller's shell options.
#
# See BDR-029 (bump origin), BLK-008 (Chromium-unsupported-OS saga),
# LRN-040 (two-layer fix — this file is layer 1 only).
# ============================================================

_GSPW_GREEN='\033[0;32m'; _GSPW_YELLOW='\033[1;33m'; _GSPW_BLUE='\033[0;34m'
_GSPW_NC='\033[0m'

_gspw_ok()   { echo -e "  ${_GSPW_GREEN}✓${_GSPW_NC} $1"; }
_gspw_warn() { echo -e "  ${_GSPW_YELLOW}⚠${_GSPW_NC}  $1"; }
_gspw_info() { echo -e "  ${_GSPW_BLUE}→${_GSPW_NC} $1"; }

# ── OS support ───────────────────────────────────────────────────────────

# gstack_pw_ostag [os_release_path] — "ubuntu<VERSION_ID>" on Ubuntu, empty
# otherwise. `|| true` on the capture: the reproduced bug had this exact
# line abort every non-Ubuntu host under inherited errexit.
gstack_pw_ostag() {
  local path="${1:-/etc/os-release}" tag
  [ -r "$path" ] || return 0
  # shellcheck disable=SC1090
  tag="$(. "$path" 2>/dev/null
    [ "${ID:-}" = ubuntu ] && printf 'ubuntu%s' "${VERSION_ID:-}")" || true
  if [ -n "$tag" ]; then
    printf '%s' "$tag"
  fi
  return 0
}

# gstack_pw_supports <playwright_core_lib_dir> <ostag> — 0 supported, 1 not.
# Always called from an `if`/`&&` context, never as a bare statement.
gstack_pw_supports() {
  local pwlib="$1" ostag="$2"
  [ -n "$ostag" ] && [ -d "$pwlib" ] || return 1
  grep -rqs "$ostag" "$pwlib" 2>/dev/null
}

# _gspw_run_timeout <dir> <cmd...> — runs <cmd> in <dir>, under `timeout 300`
# when available (absent on stock macOS). Exit 124 = the wrapped command was
# killed by the timeout. Callers MUST invoke this via `cmd || rc=$?` (never
# bare) so a non-zero exit never trips the caller's inherited errexit.
_gspw_run_timeout() {
  local dir="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    ( cd "$dir" && timeout 300 "$@" ) >/dev/null 2>&1
  else
    ( cd "$dir" && "$@" ) >/dev/null 2>&1
  fi
}

# _gspw_bump_install <gstack_dir> — populate node_modules at the pinned
# version so its support list can be read. 0 proceed, 1 give up silently
# (both installs failed, matches the pre-existing silent behavior), 2 give
# up loud (a timeout truncated node_modules — the support grep would then
# read a half-written tree).
_gspw_bump_install() {
  local dir="$1" rc=0
  _gspw_run_timeout "$dir" bun install --frozen-lockfile || rc=$?
  if [ "$rc" -eq 0 ]; then
    return 0
  elif [ "$rc" -eq 124 ]; then
    _gspw_warn "bun install timed out — skipping Playwright bump"
    return 2
  fi
  rc=0
  _gspw_run_timeout "$dir" bun install || rc=$?
  if [ "$rc" -eq 0 ]; then
    return 0
  elif [ "$rc" -eq 124 ]; then
    _gspw_warn "bun install timed out — skipping Playwright bump"
    return 2
  fi
  return 1
}

# _gspw_bump_add_latest <gstack_dir> — 0 ran (support re-checked by caller
# regardless of bun's own exit code, exactly as the pre-existing code did),
# 2 timed out (node_modules left half-written — caller must NOT re-check).
_gspw_bump_add_latest() {
  local dir="$1" rc=0
  _gspw_run_timeout "$dir" bun add playwright@latest || rc=$?
  if [ "$rc" -eq 124 ]; then
    _gspw_warn "bun add playwright@latest timed out — skipping Playwright bump"
    return 2
  fi
  return 0
}

# gstack_bump_playwright_if_unsupported <gstack_dir> — BDR-029: bump
# gstack's pinned Playwright when it lacks a build for this OS, so
# `./setup` rebuilds the browse binary against a version that has one.
# OS-gated, idempotent, non-fatal — `return 0` on every path.
gstack_bump_playwright_if_unsupported() {
  local gstack_dir="$1" ostag pwlib rc=0
  [ -d "$gstack_dir" ] && [ -r /etc/os-release ] || return 0
  ostag="$(gstack_pw_ostag)"
  [ -n "$ostag" ] || return 0
  if ! command -v bun >/dev/null 2>&1; then
    export PATH="$HOME/.bun/bin:$PATH"
  fi
  pwlib="$gstack_dir/node_modules/playwright-core/lib"
  _gspw_info "checking gstack's Playwright OS support ($ostag)..."
  _gspw_bump_install "$gstack_dir" || rc=$?
  [ "$rc" -eq 0 ] || return 0
  if gstack_pw_supports "$pwlib" "$ostag"; then
    return 0
  fi
  _gspw_info "gstack's Playwright lacks $ostag support — bumping to \
latest (local submodule edit)..."
  rc=0
  _gspw_bump_add_latest "$gstack_dir" || rc=$?
  [ "$rc" -eq 0 ] || return 0
  if gstack_pw_supports "$pwlib" "$ostag"; then
    _gspw_ok "gstack Playwright bumped — now supports $ostag (browse \
binary rebuilt by ./setup)"
  else
    _gspw_warn "Playwright bump didn't add $ostag support — gstack \
browser may stay unavailable"
  fi
  return 0
}

# ── Submodule update ──────────────────────────────────────────────────────

# gstack_submodule_update_with_bump <repo> [sub_path] — the ONE function
# allowed to return non-zero; callers use it ONLY as an `if` condition.
# Never touches the submodule working tree: on failure it prints git's own
# stderr verbatim (never parsed) and returns 1. On success it re-applies
# the bump (closes BDR-029's caveat: the bump used to survive only until
# the next `git submodule update`).
gstack_submodule_update_with_bump() {
  local repo="$1" sub="${2:-skills-external/gstack}" err rc=0
  err="$(git -C "$repo" submodule update --remote "$sub" 2>&1 >/dev/null)" \
    || rc=$?
  if [ "$rc" -eq 0 ]; then
    gstack_bump_playwright_if_unsupported "$repo/$sub"
    return 0
  fi
  _gspw_warn "$err"
  if [ -n "$(git -C "$repo/$sub" status --porcelain \
      -- package.json bun.lock 2>/dev/null)" ]; then
    _gspw_info "local Playwright bump (package.json/bun.lock) was not \
re-applied — re-run: make plugin"
  fi
  return 1
}

# ── Browsers report (read-only) ───────────────────────────────────────────

# _gspw_dir_name_parts <cache_dir_name> — prints "normalized_name revision"
# split on the LAST '-', mapping '_' -> '-' on the name (Playwright writes
# chromium_headless_shell-1228 on disk; browsers.json names it
# chromium-headless-shell).
_gspw_dir_name_parts() {
  local rev="${1##*-}" name="${1%-*}"
  printf '%s %s' "${name//_/-}" "$rev"
}

# _gspw_browser_referenced <playwright_core_path> <dir_name> — does that
# install require this cache directory (base revision or any
# revisionOverrides value)?
_gspw_browser_referenced() {
  local json="$1/browsers.json" name rev
  [ -r "$json" ] || return 1
  read -r name rev <<< "$(_gspw_dir_name_parts "$2")"
  awk -F'"' -v want_name="$name" -v want_rev="$rev" '
    $2 == "name" { cur = $4; in_ov = 0 }
    $2 == "revision" && !in_ov && cur == want_name && $4 == want_rev {
      found = 1
    }
    $2 == "revisionOverrides" { in_ov = 1 }
    in_ov && $2 != "revisionOverrides" && cur == want_name \
      && $4 == want_rev { found = 1 }
    /^[[:space:]]*}/ { in_ov = 0 }
    END { exit !found }
  ' "$json"
}

# _gspw_browser_name_known <playwright_core_path> <dir_name> — is the NAME
# listed at all, regardless of revision? (distinguishes "unknown revision"
# from "unreferenced" in the report.)
_gspw_browser_name_known() {
  local json="$1/browsers.json" name rev
  [ -r "$json" ] || return 1
  read -r name rev <<< "$(_gspw_dir_name_parts "$2")"
  awk -F'"' -v want="$name" '$2 == "name" && $4 == want { found = 1 }
    END { exit !found }' "$json"
}

# _gspw_install_label <playwright_core_path> — "<dir-before-node_modules>
# <version>", e.g. "gstack 1.61.1".
_gspw_install_label() {
  local pw_path="$1" parent version
  parent=$(basename "$(dirname "$(dirname "$pw_path")")")
  version=$(awk -F'"' '$2 == "version" { print $4; exit }' \
    "$pw_path/package.json" 2>/dev/null) || true
  printf '%s %s' "$parent" "${version:-?}"
}

# _gspw_registered_installs <cache_dir> — valid playwright-core paths (dir
# exists, browsers.json readable), one per line. A `.links` entry whose
# target is gone or unreadable is silently excluded here (it is counted as
# a broken link by the caller instead).
_gspw_registered_installs() {
  local links_dir="$1/.links" f target
  [ -d "$links_dir" ] || return 0
  for f in "$links_dir"/*; do
    [ -f "$f" ] || continue
    target=$(cat "$f" 2>/dev/null) || true
    [ -n "$target" ] || continue
    if [ -d "$target" ] && [ -r "$target/browsers.json" ]; then
      printf '%s\n' "$target"
    fi
  done
  return 0
}

# _gspw_report_dir_line <dir_name> <install_paths_newline_sep> — prints the
# report line for one cache directory. Returns 1 only when truly
# unreferenced (caller tallies that); "unknown revision" does not count.
_gspw_report_dir_line() {
  local dir_name="$1" installs="$2" p labels="" known=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if _gspw_browser_referenced "$p" "$dir_name"; then
      labels="${labels:+$labels, }$(_gspw_install_label "$p")"
    elif _gspw_browser_name_known "$p" "$dir_name"; then
      known=1
    fi
  done <<< "$installs"
  if [ -n "$labels" ]; then
    _gspw_info "$dir_name: $labels"
    return 0
  elif [ "$known" -eq 1 ]; then
    _gspw_info "$dir_name: unknown revision"
    return 0
  fi
  _gspw_info "$dir_name: unreferenced"
  return 1
}

# gstack_browsers_report [cache_dir] — read-only. `$1` (or
# PLAYWRIGHT_BROWSERS_PATH, or ~/.cache/ms-playwright) is resolved once;
# "0" (documented as "bundle into node_modules") and any non-directory
# degrade to a silent no-cache path. `return 0` on every path.
gstack_browsers_report() {
  local cache installs total links_total valid_count broken=0 unref=0 d name
  cache="${1:-${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}}"
  [ "$cache" = "0" ] && return 0
  [ -d "$cache" ] || return 0
  installs="$(_gspw_registered_installs "$cache")"
  links_total=$(find "$cache/.links" -maxdepth 1 -type f 2>/dev/null \
    | wc -l | tr -d ' ') || true
  valid_count=$(printf '%s\n' "$installs" | grep -c . || true)
  broken=$((links_total - valid_count))
  total=$(du -sh "$cache" 2>/dev/null | awk '{print $1}') || true
  _gspw_info "Playwright browsers: $cache (${total:-0})"
  for d in "$cache"/*-[0-9]*; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    _gspw_report_dir_line "$name" "$installs" || unref=$((unref + 1))
  done
  _gspw_info "${unref} unreferenced, ${broken} broken link(s)"
  if [ "$unref" -gt 0 ] || [ "$broken" -gt 0 ]; then
    _gspw_warn "unreferenced/broken Playwright browser dirs — re-run \
\`playwright install\`, which prunes stale revisions"
  fi
  return 0
}

# ── CLI dispatch (only when executed, not sourced) — browsers-report ONLY.
# The write functions (the bump, the submodule update) stay sourced-only: a
# CLI verb would expose `bun add playwright@latest` as a command-line entry
# point. ────────────────────────────────────────────────────────────────
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-}" in
    browsers-report) shift; gstack_browsers_report "$@" ;;
    *) echo "usage: gstack-playwright.sh browsers-report [cache_dir]" >&2
       exit 2 ;;
  esac
fi
