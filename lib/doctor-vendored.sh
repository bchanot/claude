#!/usr/bin/env bash
# ============================================================
# lib/doctor-vendored.sh — doctor.sh check for the externally vendored
# skills (curl-pinned externals in plugins.lock.json + link.sh's
# EXTERNAL_SKILLS array). doctor.sh's "GStack submodule" section only
# covers the gstack submodule — this covers the OTHER external skill
# packs (emil-design-eng, the agent-skills trio, the five Mengto scroll
# skills, the seven superpowers skills, and any name link.sh links with
# no lock entry at all, e.g. frontend-design, design-motion-principles).
#
# One entry point, `check_vendored_skills <repo> <claude_home>
# [profile_file]`, sourced and called by doctor.sh. Two things checked
# per name in link.sh's EXTERNAL_SKILLS array:
#   1. its file(s) exist under skills-external/<name>/ — expected file
#      list comes from the matching plugins.lock.json entry (list shape
#      -> ["SKILL.md"], dict shape -> its own file list, the
#      emil-design-eng single-file "path" shape -> the key itself is the
#      name, file "SKILL.md") or, when no lock entry names it at all,
#      defaults to ["SKILL.md"].
#   2. when the name is listed in <profile_file> (or no <profile_file>
#      is passed — the "could not resolve the active profile" case),
#      the <claude_home>/skills/<name> symlink points at
#      <repo>/skills-external/<name>. A name absent from the profile is
#      reported parked, not failed — unless its lock entry is
#      "always_on": true (the superpowers entry is), in which case the
#      symlink is checked regardless of the profile (see _dv_check_link).
#
# Lock parsing via python3 argv (never string-spliced) — same pattern as
# lib/vendor-skills.sh's _vendor_read_lock. link.sh's EXTERNAL_SKILLS
# array is parsed with a single-purpose grep/sed, tolerant to it
# spanning multiple lines.
#
# Every name/file pulled from the lock or link.sh is spliced into a
# filesystem path (skills-external/<name>/<file>,
# <claude_home>/skills/<name>): _dv_valid_item_name allowlists it first
# (a rejection is a warn + skip, never a fail). doctor.sh's active
# profile splices into lib/profiles/<name>.profile the same way, guarded
# by _dv_valid_profile_name.
#
# No `set -euo pipefail` here (mirrors lib/vendor-skills.sh): a sourced
# lib must not change the caller's shell options.
# ============================================================

# Fallback color helpers when sourced standalone (e.g. the test suite) —
# skip anything the caller (doctor.sh) already defines, so doctor.sh's
# ERRORS/WARNS counters keep working.
if ! declare -F pass >/dev/null 2>&1; then
  GREEN='\033[0;32m'; NC='\033[0m'
  pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fi
if ! declare -F fail >/dev/null 2>&1; then
  RED='\033[0;31m'; NC='\033[0m'
  fail() { echo -e "  ${RED}✗${NC} $1"; }
fi
if ! declare -F warn >/dev/null 2>&1; then
  YELLOW='\033[1;33m'; NC='\033[0m'
  warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
fi
if ! declare -F info >/dev/null 2>&1; then
  BLUE='\033[0;34m'; NC='\033[0m'
  info() { echo -e "  ${BLUE}→${NC} $1"; }
fi

# _dv_lock_expectations <lockfile> — prints "<name>\t<file>" for every
# skill named under a plugins.lock.json entry whose "managed_by" is
# "curl", plus a THIRD column "\t1" when that entry is "always_on": true
# (the superpowers entry is) — read by _dv_is_always_on, ignored by the
# $1==n {print $2} awk in _dv_check_files: a bare list defaults each name
# to ["SKILL.md"]; a dict names its own per-skill file list; an entry
# with neither (the emil-design-eng single-file "path" shape) is itself
# the skill name, file "SKILL.md" (the literal "path" value is upstream
# layout, not the local dest — never used here). Reads the lockfile via
# argv only.
# Every curl-managed entry's shape is validated ("skills" null, a list
# of str, or a dict of str -> list of str; "path" a str when present)
# BEFORE it is used, so a malformed entry is the same clean failure as
# an unreadable file: rc 1, nothing printed. The python3 call's stderr
# is discarded — no traceback ever reaches the caller's terminal, only
# the rc reaches bash's decision.
_dv_lock_expectations() {
  python3 - "$1" 2>/dev/null <<'PY'
import json, sys


def valid_skills(skills):
    """True when "skills" is null, a list of str, or a dict of
    str -> list of str — the only shapes this lock format allows."""
    if skills is None:
        return True
    if isinstance(skills, list):
        return all(isinstance(name, str) for name in skills)
    if isinstance(skills, dict):
        return all(
            isinstance(name, str) and isinstance(files, list)
            and all(isinstance(f, str) for f in files)
            for name, files in skills.items()
        )
    return False


def skill_files(skills):
    """Normalize an already-validated "skills" value to
    {name: [file, ...]} — a bare list defaults to ["SKILL.md"]."""
    if isinstance(skills, list):
        return {name: ["SKILL.md"] for name in skills}
    return skills


try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except (OSError, ValueError):
    sys.exit(1)

if not isinstance(data, dict):
    sys.exit(1)

for key, entry in data.items():
    if not isinstance(entry, dict) or entry.get("managed_by") != "curl":
        continue
    skills, path = entry.get("skills"), entry.get("path")
    if path is not None and not isinstance(path, str):
        sys.exit(1)
    if not valid_skills(skills):
        sys.exit(1)
    suffix = "\t1" if entry.get("always_on") is True else ""
    if skills is None:
        print(f"{key}\tSKILL.md{suffix}")
        continue
    for name, files in skill_files(skills).items():
        for file in files:
            print(f"{name}\t{file}{suffix}")
PY
}

# _dv_link_names <link_sh> — prints one name per line from link.sh's
# EXTERNAL_SKILLS=(...) array, tolerant to it spanning multiple lines.
# rc 1 (nothing printed) when the array marker is absent from the file.
_dv_link_names() {
  local link_sh="$1"
  grep -qF 'EXTERNAL_SKILLS=(' "$link_sh" 2>/dev/null || return 1
  awk '/EXTERNAL_SKILLS=\(/{f=1} f{print} f&&/\)/{exit}' "$link_sh" \
    | sed -e 's/^.*EXTERNAL_SKILLS=(//' -e 's/).*$//' \
    | tr -s '[:space:]' '\n' \
    | grep -v '^$'
}

# _dv_profile_has <profile_file> <name> — true when a line's FIRST
# whitespace-separated token equals <name> (the profile line's label
# column — comments and the type column are ignored).
_dv_profile_has() {
  local profile_file="$1" name="$2"
  awk -v n="$name" '$1 == n { found=1 } END { exit !found }' "$profile_file"
}

# _dv_valid_profile_name <name> — true when <name> matches the
# profile-name allowlist (letters, digits, underscore, hyphen only).
# <name> is spliced into "lib/profiles/<name>.profile" by doctor.sh, so
# a path-traversal or separator character must never reach it.
_dv_valid_profile_name() {
  [[ "$1" =~ ^[A-Za-z0-9_-]+$ ]]
}

# _dv_valid_item_name <name> — true when <name> (a skill name from
# link.sh's EXTERNAL_SKILLS array, or a relative file named by a
# plugins.lock.json entry) matches the item-name allowlist (letters,
# digits, dot, underscore, hyphen, slash), has no leading "/" and no
# ".." path segment. <name> is spliced into a filesystem path under
# skills-external/ or <claude_home>/skills/.
_dv_valid_item_name() {
  local name="$1"
  [[ "$name" =~ ^[A-Za-z0-9._/-]+$ ]] || return 1
  case "$name" in /*) return 1 ;; esac
  case "/$name/" in */../*) return 1 ;; esac
}

# _dv_check_files <repo> <name> <lock_out> — every file <lock_out> (the
# "<name>\t<file>" lines from _dv_lock_expectations) names for <name>,
# defaulting to just "SKILL.md" when <lock_out> names it no file at all
# (a link.sh-only name with no lock entry). fail per missing file. Each
# <rel> is checked against the item-name allowlist before it is spliced
# into a path — a rejected one is warned and skipped, not failed. rc 0
# only when every expected (and allowlisted) file is present.
_dv_check_files() {
  local repo="$1" name="$2" lock_out="$3"
  local files rel dest all_ok=1
  files="$(awk -F'\t' -v n="$name" '$1 == n { print $2 }' <<<"$lock_out")"
  [ -n "$files" ] || files="SKILL.md"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    if ! _dv_valid_item_name "$rel"; then
      warn "$name: lock file entry \"$rel\" rejected by the item-name \
allowlist — skipped"
      continue
    fi
    dest="$repo/skills-external/$name/$rel"
    if [ ! -f "$dest" ]; then
      fail "$name: skills-external/$name/$rel missing — run: make plugin"
      all_ok=0
    fi
  done <<< "$files"
  [ "$all_ok" -eq 1 ]
}

# _dv_is_always_on <name> <lock_out> — true when <lock_out> (the
# "<name>\t<file>[\t1]" lines from _dv_lock_expectations) carries the
# always_on third column for <name>'s lock entry.
_dv_is_always_on() {
  local name="$1" lock_out="$2"
  awk -F'\t' -v n="$name" '$1 == n && $3 == 1 { found=1 } \
    END { exit !found }' <<< "$lock_out"
}

# _dv_check_link <claude_home> <repo> <name> <profile_file> <always_on> —
# when <always_on> is "1" (the name's lock entry is "always_on": true),
# the symlink is checked whatever <profile_file> says — never parked.
# Otherwise, when <profile_file> is non-empty and does not list <name>,
# reports it parked (info), not failed. Otherwise (listed, always_on, or
# no <profile_file> was passed — active profile could not be resolved,
# every external is then expected linked) checks the
# <claude_home>/skills/<name> symlink points at
# <repo>/skills-external/<name>.
_dv_check_link() {
  local claude_home="$1" repo="$2" name="$3" profile_file="$4" \
    always_on="$5"
  local link target label
  if [ "$always_on" != "1" ] && [ -n "$profile_file" ] \
       && ! _dv_profile_has "$profile_file" "$name"; then
    label="$(basename "$profile_file" .profile)"
    info "$name: parked by profile $label"
    return
  fi
  link="$claude_home/skills/$name"
  target="$repo/skills-external/$name"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
    pass "$name: vendored + linked"
  else
    fail "$name: symlink missing/wrong — run: make link (or: bash \
lib/profile.sh apply <profile>)"
  fi
}

# _dv_check_name <repo> <claude_home> <name> <profile_file> <lock_out> —
# per-name dispatch for check_vendored_skills's loop: files first (the
# link check runs only when every expected file is present, same as
# before), then the symlink, passing _dv_is_always_on's verdict as
# _dv_check_link's 5th param.
_dv_check_name() {
  local repo="$1" claude_home="$2" name="$3" profile_file="$4" lock_out="$5"
  local always_on=""
  _dv_is_always_on "$name" "$lock_out" && always_on=1
  _dv_check_files "$repo" "$name" "$lock_out" \
    && _dv_check_link "$claude_home" "$repo" "$name" "$profile_file" \
         "$always_on"
}

# check_vendored_skills <repo> <claude_home> [profile_file] — see the
# file header. Either the lock or link.sh being unreadable (or a
# malformed lock entry — _dv_lock_expectations rc 1) is a warn, never a
# fail; link.sh unreadable skips the whole check (there is nothing to
# iterate). Each <name> from link.sh is checked against the item-name
# allowlist before it is spliced into a path — a rejected one is
# warned and skipped, not failed.
check_vendored_skills() {
  local repo="$1" claude_home="$2" profile_file="${3:-}"
  local lock_out names name

  if ! lock_out="$(_dv_lock_expectations "$repo/plugins.lock.json")"; then
    warn "plugins.lock.json unreadable or malformed (missing, invalid \
JSON, or an entry with a bad \"skills\"/\"path\" shape) — \
vendored-skills file check falls back to SKILL.md-only defaults"
    lock_out=""
  fi

  if ! names="$(_dv_link_names "$repo/link.sh")" || [ -z "$names" ]; then
    warn "link.sh EXTERNAL_SKILLS array unreadable — vendored-skills \
check skipped"
    return 0
  fi

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if ! _dv_valid_item_name "$name"; then
      warn "link.sh EXTERNAL_SKILLS entry \"$name\" rejected by the \
item-name allowlist — skipped"
      continue
    fi
    _dv_check_name "$repo" "$claude_home" "$name" "$profile_file" "$lock_out"
  done <<< "$names"
}
