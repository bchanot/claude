#!/usr/bin/env bash
# ============================================================
# lib/vendor-skills.sh — shared curl-vendoring for commit-pinned skills
#
# One helper, `vendor_pinned_skills <lock-key> [refresh]`, replaces the
# inline curl loops install-plugins.sh (Step 8e) and update-all.sh (7.3)
# used to carry separately for the addyosmani/agent-skills trio. Both
# scripts source this file and call it once per plugins.lock.json entry
# ("agent-skills", "mengto-skills", …) — no sha ever hardcoded here.
#
# Lock entry shape (plugins.lock.json):
#   "<key>": {
#     "source": "https://github.com/<owner>/<repo>",
#     "commit": "<sha>",
#     "path": "<repo-relative dir holding the skill folders>",   # optional
#     "skills": ["<name>", ...] | {"<name>": ["<file>", ...], ...}
#   }
# `skills` as a bare list defaults every named skill to `["SKILL.md"]` and
# `path` to "skills" (the agent-skills shape); `skills` as a dict carries an
# explicit per-skill file list (references/*, etc.) and `path` is required.
# `"always_on": true` (optional) is ignored by this helper (fetch is the
# same either way) — lib/doctor-vendored.sh reads it to expect the
# entry's skills linked regardless of the active profile.
#
# Raw URL: https://raw.githubusercontent.com/<owner>/<repo>/<sha>/<path>/
# <skill>/<file>. VENDOR_BASE_URL overrides the "https://…/<repo>" prefix
# (everything before "/<sha>/…") ONLY when it starts with "file://" (the
# hermetic suite's fixture form); any other non-empty value is ignored —
# a warn names the variable and the default raw.githubusercontent.com
# prefix is used, so a stray value in the caller's environment can never
# silently redirect a real install/update run.
#
# Per file: tmp + mv, tmp removed on failure. A file already at its
# destination is skipped unless refresh="refresh". A skill counts as
# vendored only when every one of its listed files landed; otherwise err
# names the file and the manual curl to retry it.
#
# Every skill name and file path from the lock is rejected — before any
# URL is built or any file fetched — if it contains "..", starts with
# "/", or holds a character outside [A-Za-z0-9._/-] (checked with
# re.fullmatch, so a trailing newline or other stray character cannot
# slip past the "$" anchor the way it could under re.match); this guards
# against a lock entry walking a fetch outside skills-external/<skill>/.
# The entry's own "commit" (must be 40 lowercase hex chars), "source"
# (must be "https://github.com/<owner>/<repo>", trailing slash optional)
# and "path" (same SAFE class as a file, no traversal) are format-checked
# the same way, before either is ever spliced into the raw-file URL.
#
# No `set -euo pipefail` here (mirrors lib/detect-plugins.sh): a sourced
# lib must not change the caller's shell options.
# ============================================================

VENDOR_REPO="${VENDOR_SKILLS_REPO_OVERRIDE:-$(cd -P \
  "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Fallback color helpers when sourced standalone (e.g. the test suite) —
# skip anything the caller (install-plugins.sh / update-all.sh) already
# defines, so the same ok/warn/info/err instances keep being used.
if ! declare -F ok >/dev/null 2>&1; then
  GREEN='\033[0;32m'; NC='\033[0m'
  ok() { echo -e "${GREEN}✓${NC} $1"; }
fi
if ! declare -F info >/dev/null 2>&1; then
  BLUE='\033[0;34m'; NC='\033[0m'
  info() { echo -e "${BLUE}→${NC} $1"; }
fi
if ! declare -F warn >/dev/null 2>&1; then
  YELLOW='\033[1;33m'; NC='\033[0m'
  warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
fi
if ! declare -F err >/dev/null 2>&1; then
  RED='\033[0;31m'; NC='\033[0m'
  err() { echo -e "${RED}✗${NC} $1"; }
fi

# _vendor_read_lock <lockfile> <key> <base_override> — prints, on
# success: line 1: "<url_base>" (the raw-file URL up to and including
# <path>, using <base_override> when non-empty) line 2: "<sha>" then one
# "<skill>\t<file1> <file2> …" line per skill (sorted). <base_override>
# is a plain argv string — the caller (vendor_pinned_skills) already
# checked it is either empty or a "file://" value, never the raw
# VENDOR_BASE_URL.
# rc 1 when the key, its commit, source or skills are absent (nothing
# printed); when the commit, source or path fails its format check
# (prints one "INVALID\t<field>=<offending value>" line); or when a
# skill name or file path fails the traversal/character check (prints
# one "INVALID\t<offending value>" line) — no URL is built and no file
# is fetched for that lock key either way.
# Reads the lock path, key and base override via argv — never
# string-spliced into the script.
_vendor_read_lock() {
  python3 - "$1" "$2" "$3" <<'PY'
import json, re, sys

SAFE = re.compile(r'^[A-Za-z0-9._/-]+$')
COMMIT_RE = re.compile(r'^[0-9a-f]{40}$')
SOURCE_RE = re.compile(
    r'^https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/?$')


def unsafe(value):
    return ".." in value or value.startswith("/") or not SAFE.fullmatch(value)


lockfile, key, base_override = sys.argv[1], sys.argv[2], sys.argv[3]
with open(lockfile) as f:
    data = json.load(f)
entry = data.get(key, {})
sha = entry.get("commit", "")
source = entry.get("source", "")
path = entry.get("path", "skills")
skills = entry.get("skills", {})
if isinstance(skills, list):
    skills = {name: ["SKILL.md"] for name in skills}
if not sha or not source or not skills:
    sys.exit(1)
if not COMMIT_RE.fullmatch(sha):
    print(f"INVALID\tcommit={sha}")
    sys.exit(1)
if not SOURCE_RE.fullmatch(source):
    print(f"INVALID\tsource={source}")
    sys.exit(1)
if unsafe(path):
    print(f"INVALID\tpath={path}")
    sys.exit(1)
owner_repo = source.rstrip("/").rsplit("github.com/", 1)[-1]
for name, files in skills.items():
    if unsafe(name):
        print(f"INVALID\t{name}")
        sys.exit(1)
    for file in files:
        if unsafe(file):
            print(f"INVALID\t{file}")
            sys.exit(1)
base = base_override or f"https://raw.githubusercontent.com/{owner_repo}"
print(f"{base}/{sha}/{path}")
print(sha)
for name in sorted(skills):
    print(f"{name}\t{' '.join(skills[name])}")
PY
}

# _vendor_fetch_file <url> <dest> <refresh> — tmp + mv; tmp removed on
# failure. Skips an existing dest unless refresh="refresh". rc 0 on
# success or skip, rc 1 (with an err naming the manual curl) on failure.
_vendor_fetch_file() {
  local url="$1" dest="$2" refresh="$3"
  [ -f "$dest" ] && [ "$refresh" != "refresh" ] && return 0
  mkdir -p "$(dirname "$dest")"
  local tmp="$dest.tmp"
  if curl -fsSL "$url" -o "$tmp" 2>/dev/null && mv "$tmp" "$dest"; then
    return 0
  fi
  rm -f "$tmp"
  err "$dest download failed — try: curl -fsSL $url -o $dest"
  return 1
}

# _vendor_install_skill <url_base> <skill> <files> <dest_root> <refresh> —
# fetches every listed file under <dest_root>/<skill>/, from
# <url_base>/<skill>/<file>. rc 0 only when all of them landed (existing
# or freshly fetched).
_vendor_install_skill() {
  local url_base="$1" skill="$2" files="$3" dest_root="$4" refresh="$5"
  local file landed=0 total=0
  for file in $files; do
    total=$((total + 1))
    _vendor_fetch_file "$url_base/$skill/$file" "$dest_root/$skill/$file" \
      "$refresh" && landed=$((landed + 1))
  done
  [ "$landed" -eq "$total" ]
}

# _vendor_report_lock_error <lock_key> <lock_out> — turns a failed
# _vendor_read_lock into the right err line: a rejected commit/source/
# path when <lock_out> carries the "INVALID\t<field>=<value>" marker (the
# field named in full), a rejected skill name/file when it carries the
# plain "INVALID\t<value>" marker, the generic no-commit-pinned hint
# otherwise.
_vendor_report_lock_error() {
  local lock_key="$1" lock_out="$2" rest msg
  if [[ "$lock_out" == INVALID$'\t'* ]]; then
    rest="${lock_out#INVALID$'\t'}"
    if [[ "$rest" == *=* ]]; then
      msg="$lock_key: rejected ${rest%%=*}='${rest#*=}' — invalid format"
    else
      msg="$lock_key: rejected '$rest'"
      msg="$msg — path traversal or disallowed characters"
    fi
    err "$msg"
    return
  fi
  local hint="add an entry with a \"commit\" field"
  err "$lock_key: no commit/skills pinned in plugins.lock.json — $hint"
}

# vendor_pinned_skills <lock-key> [refresh] — vendors every skill listed
# under plugins.lock.json's <lock-key> entry into skills-external/<name>/.
# Pass "refresh" as the second arg to re-fetch files already present (at
# the same pinned commit — never advances the pin). In refresh mode, a
# skill whose skills-external/<name>/ directory does not exist yet is
# skipped (the standard "not installed — skipping" info line, no fetch) —
# refresh keeps installed skills current, it never installs a new one;
# install mode (no refresh) still creates it.
vendor_pinned_skills() {
  local lock_key="$1" refresh="${2:-}"
  local lockfile="$VENDOR_REPO/plugins.lock.json" lock_out lock_rc
  local base_override="${VENDOR_BASE_URL:-}"
  if [ -n "$base_override" ] && [[ "$base_override" != file://* ]]; then
    warn "VENDOR_BASE_URL ignored (must start with file://): $base_override"
    base_override=""
  fi
  lock_out="$(_vendor_read_lock "$lockfile" "$lock_key" "$base_override")"
  lock_rc=$?
  if [ "$lock_rc" -ne 0 ]; then
    _vendor_report_lock_error "$lock_key" "$lock_out"
    return 1
  fi
  local url_base sha dest_root="$VENDOR_REPO/skills-external"
  url_base="$(sed -n '1p' <<<"$lock_out")"
  sha="$(sed -n '2p' <<<"$lock_out")"
  local skill files
  while IFS=$'\t' read -r skill files; do
    [ -n "$skill" ] || continue
    if [ "$refresh" = "refresh" ] && [ ! -d "$dest_root/$skill" ]; then
      info "$skill not installed — skipping (run: make plugin)"
      continue
    fi
    if _vendor_install_skill "$url_base" "$skill" "$files" \
         "$dest_root" "$refresh"; then
      ok "$skill vendored (pinned @ ${sha:0:7})"
    else
      err "$skill: not all files landed (see the download-failed lines above)"
    fi
  done < <(tail -n +3 <<<"$lock_out")
}
