# Modern Web Guidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Vendor Google's Modern Web Guidance (guides + chrome-extensions) at a pinned commit and make every front-end task consult it through our own local, network-free skill.

**Architecture:** A new `vendor_pinned_tree` helper in `lib/vendor-skills.sh` fetches one pinned commit with git, copies an allowlist of upstream paths into `skills-external/<dest>/`, generates `INDEX.md` (one line per guide, the upstream README's one-sentence description) / `NOTICE.md` / `.vendored-commit`, and swaps the result in. Our tracked skill `skills/modern-web-guidance/` reaches the copy through one relative symlink `mwg` and needs only Read (Grep and Glob are absent in some sessions). `rules/web-building.md` and `site-motion` send front-end work to the skill; a sub-agent without the Skill tool Reads its `SKILL.md` by path.

**Tech Stack:** bash, python3 (lock parsing, argv only), git, markdown.

**Spec:** `docs/superpowers/specs/2026-11-21-modern-web-guidance-design.md`
**Contract:** `.claude/tasks/contracts/2026-11-21-modern-web-guidance-2314.md`

Out of this plan, done by `/ship-feature` itself: README / USAGE / CHANGELOG (STEP 8 doc sync) and the BDR recording the decisions, including the fixed pin as an exception to BDR-056 (STEP 7).

## Alternatives weighed for the fetcher

- A pinned git submodule (the gstack precedent) gets pin checks, pruning and an atomic checkout from git, but it puts the whole upstream repo on disk (the npx `SKILL.md`, the CLI, policies), against the allowlist rule for fetchers (LRN-109, LRN-184). Its pin would live in the gitlink, while acceptance criterion 1 (user-gated) puts it in `plugins.lock.json`. It cannot hold the generated `INDEX.md` without a dirty submodule, and install-plugins.sh only inits submodules when gstack is absent. Rejected.
- `vendor_pinned_skills` (curl per listed file) for chrome-extensions: 24 files to list by hand and to keep in sync on every pin bump, and a second fetch path at the same commit. Rejected; one git fetch serves both dests.
- A pinned variant of `higgsfield_sync_skills`: same clone-stage-adopt shape, but no lock, no pin check, no prune. `vendor_pinned_tree` reuses its no-prompt git flags and its mktemp stage.

## Global Constraints

- Pin: tag `v1.0.1`, commit `64a6d708f5a43f2cd3fde5d4d7db3905ba1bdf65`, source `https://github.com/GoogleChrome/modern-web-guidance`.
- No path of this feature runs `npx`, `pnpx` or the `modern-web-guidance` CLI. The skill's `allowed-tools` is `Read`: it only pre-approves Read for the invoking turn, it does not restrict tools (Claude Code skills docs). The no-npx guarantee rests on the skill's "Never run npx" sentence, the absence of any command in it, and the settings soft-deny on undeclared `npx <pkg>`.
- No `routing.json` row and no `effort:` frontmatter for `modern-web-guidance` or `chrome-extensions`: a rowed skill reroutes the main loop on load ("last rowed skill wins", `mods/model-router/hooks/register.ts` onSkillLoad), which would pull design work off `reflect`. `modern-web-guidance` joins `NO_ROW_SKILLS` in `lib/tests/effort-routing.test.sh` (precedent: `find-docs`); `chrome-extensions` is an untracked linked external, the census does not ask for a row.
- Skill description at most 400 characters (listing budget `SLASH_COMMAND_TOOL_CHAR_BUDGET=50000`, ~34.5k already used by flat + pack descriptions).
- The upstream `skills/modern-web-guidance/SKILL.md` is never copied into `skills-external/`.
- Vendored text is never edited (BDR-104/106); `INDEX.md` and `NOTICE.md` are generated beside it.
- `CLAUDE.global.md`, `settings.json`, `CLAUDE.md` are not modified (BDR-028, 320-line budget).
- `rules/web-building.md`: the heading line `## Design work — full toolchain (tiered by scope)` and the line `- The vendored stack members route to \`reflect\` (high) through their` stay byte-identical (doctrine-citers and effort-routing locks, LRN-166).
- install-plugins.sh and update-all.sh run under `set -euo pipefail`: the new fetch is called inside `if !`, a failure warns and the script goes on (the `vendor_pinned_skills` and higgsfield convention). doctor.sh runs under the same options: no new check may trip errexit.
- Tests run only through `make test suite=<file>` (hermetic git config).
- `VENDOR_BASE_URL` override is honored only when it starts with `file://` (same rule as `vendor_pinned_skills`).

## Review Focus

1. Fetch failure or a commit that is not the pin → rc 1, `skills-external/` unchanged (no half-swapped dest), and `make plugin` / `make update` warn and continue.
2. A pin bump that drops a guide upstream → the guide disappears locally (whole-dir swap, not file overwrite).
3. A machine that never ran `make plugin` → `make update` installs the copy (one mode: anything not at the pin is fetched).
4. A lock entry with `..`, an absolute path or a bad dest name, a dest dir owned by someone else, or a symlink in the fetched content → rejected, nothing replaced.
5. Fresh clone before install → the skill's `mwg` link dangles; the skill says "run `make update`". Doctor warns for `mwg`; a missing `chrome-extensions` copy is the existing `check_vendored_skills` error, like every other external; doctor reaches its summary either way.
6. A sub-agent executor (feater, bugfixer, hotfixer: no Skill tool in their `tools:`) Reads a front file → the path rule tells it to Read `~/.claude/skills/modern-web-guidance/SKILL.md`; the relative link resolves through the `~/.claude/skills` link (checked on a fixture: the kernel resolves `../..` from the link's real directory). A closed plan that contradicts a guide is reported as an open choice, never overridden silently.

## Contract oracles (draft, written into the contract at STEP 3 with `- run-base:`)

1. Pin + install wiring + local copy at the pin, 210 guides, no upstream SKILL.md:
   CHECK: `python3 -c "import json;e=json.load(open('plugins.lock.json'))['modern-web-guidance'];assert e['commit']=='64a6d708f5a43f2cd3fde5d4d7db3905ba1bdf65' and e['tag']=='v1.0.1'" && grep -q 'if ! vendor_pinned_tree modern-web-guidance; then' install-plugins.sh && grep -q 'if ! vendor_pinned_tree modern-web-guidance; then' update-all.sh && [ "$(cat skills-external/mwg/.vendored-commit)" = 64a6d708f5a43f2cd3fde5d4d7db3905ba1bdf65 ] && [ "$(grep -c '^- ' skills-external/mwg/INDEX.md)" -eq 210 ] && [ -f skills-external/chrome-extensions/SKILL.md ] && [ ! -e skills-external/mwg/SKILL.md ] && make test suite=lib/tests/vendor-tree.test.sh 2>&1 | tail -1` → EXPECT `all suites green`
2. Our skill, local read only, disclosure: CHECK `make test suite=lib/tests/mwg-skill.test.sh 2>&1 | tail -1` → EXPECT `all suites green`
3. Rule wiring: CHECK `grep -qx '## Modern Web Guidance first' rules/web-building.md && grep -q 'Read `~/.claude/skills/modern-web-guidance/SKILL.md` and follow it.' rules/web-building.md && grep -q '`modern-web-guidance` first for the platform features it uses.' rules/web-building.md && echo WIRED` → EXPECT `WIRED`
4. Upstream SKILL.md not linked, chrome-extensions linked: CHECK `! grep -l 'modern-web-guidance@latest search' ~/.claude/skills/*/SKILL.md 2>/dev/null | grep -q . && [ -L ~/.claude/skills/chrome-extensions ] && echo NOT_LINKED` → EXPECT `NOT_LINKED`
5. Suite and doctor: CHECK `make test 2>&1 | tail -1` → EXPECT `all suites green`; CHECK `bash doctor.sh 2>&1 | grep -q 'No errors' && echo DOCTOR_OK` → EXPECT `DOCTOR_OK` (baseline 2026-11-22: "No errors, 2 warning(s)").

Oracles 1, 4 and 5 need the live copy: Task 5 runs after Task 4 and before the STEP 5 gates.

---

### Task 1: `vendor_pinned_tree` fetcher + hermetic suite

**Files:**
- Modify: `lib/vendor-skills.sh` (append after `vendor_pinned_skills`)
- Create: `lib/tests/vendor-tree.test.sh`

**Interfaces:**
- Produces: `vendor_pinned_tree <lock-key>` (rc 0 when every dest is at the pin, already or after the fetch; rc 1 on any failure, no dest half-replaced); `_vendor_read_tree_lock <lockfile> <key>` (stdout lines: source, commit, tag, license, then `<dest>\t<target>\t<repo-path>`); lock entry shape:
  `{"source","commit","tag","license","trees":{"<dest>":{"<target>|.":"<repo-path>"}},"managed_by":"git-tree","always_on":true}`.
- Writes per dest: `skills-external/<dest>/.vendored-commit` (the commit), `NOTICE.md`, and `INDEX.md` when the dest holds `guides/` (summary from the dest's `README.md` when present, else the guide's H1).

- [ ] **Step 1: Write the failing test** — create `lib/tests/vendor-tree.test.sh`:

```bash
#!/usr/bin/env bash
# lib/tests/vendor-tree.test.sh — lib/vendor-skills.sh vendor_pinned_tree():
# pinned git fetch from a file:// fixture repo, allowlisted copy, INDEX
# (README description, else H1) / NOTICE / .vendored-commit generation,
# upstream SKILL.md never copied, skip at the pin, a pin bump prunes a
# guide dropped upstream, an absent copy is installed, a commit not
# upstream is refused with nothing written, unsafe lock paths rejected
# before any fetch, a dest owned by someone else never replaced, a
# symlink in the fetched content refused.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/lib/vendor-skills.sh"
pass=0; fail=0
check_bool() {
  if [ "$2" = 1 ]; then pass=$((pass+1)); echo "PASS $1"
  else fail=$((fail+1)); echo "FAIL $1"; fi
}
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
UP="$WORK/upstream"; REPO="$WORK/repo"
mkdir -p "$REPO/skills-external"
g() { git -C "$UP" -c user.email=t@t -c user.name=t "$@"; }

# Fixture upstream: modern-web-guidance layout (SKILL.md + guides/), a
# README listing one guide, and a chrome-extensions skill with a
# references/ file.
mkdir -p "$UP/skills/modern-web-guidance/guides/css" \
  "$UP/skills/modern-web-guidance/guides/html" \
  "$UP/skills/chrome-extensions/references/extensions"
printf 'npx -y modern-web-guidance@latest search\n' \
  > "$UP/skills/modern-web-guidance/SKILL.md"
printf '# Animate to intrinsic sizes\nbody\n' \
  > "$UP/skills/modern-web-guidance/guides/css/animate-to-intrinsic-sizes.md"
printf '# Dialog\nbody\n' > "$UP/skills/modern-web-guidance/guides/html/dialog.md"
printf '# Old guide\nbody\n' > "$UP/skills/modern-web-guidance/guides/html/old-guide.md"
printf -- '- **[dialog](https://x/guides/html/dialog.md)**: Native modal dialog.\n' \
  > "$UP/README.md"
printf -- '---\nname: chrome-extensions\n---\nbody\n' \
  > "$UP/skills/chrome-extensions/SKILL.md"
printf 'ref\n' > "$UP/skills/chrome-extensions/references/extensions/api.md"
printf 'Apache License\n' > "$UP/LICENSE"
git init -q "$UP"; g add -A; g commit -qm one
SHA1="$(git -C "$UP" rev-parse HEAD)"

write_lock() { # write_lock <commit> [extra-tree-json]
  cat > "$REPO/plugins.lock.json" <<JSON
{
  "mwg-key": {
    "source": "https://github.com/acme/mwg",
    "commit": "$1",
    "tag": "v1.0.1",
    "license": "Apache-2.0 (code), CC-BY 4.0 (guides)",
    "managed_by": "git-tree",
    "trees": {
      "mwg": {"guides": "skills/modern-web-guidance/guides", "LICENSE": "LICENSE", "README.md": "README.md"},
      "chrome-extensions": {".": "skills/chrome-extensions"}${2:-}
    }
  }
}
JSON
}
# Same pattern as vendor-skills.test.sh: export once, source once (the lib
# reads VENDOR_SKILLS_REPO_OVERRIDE at source time), override per call.
export VENDOR_SKILLS_REPO_OVERRIDE="$REPO" VENDOR_BASE_URL="file://$UP"
# shellcheck source=../vendor-skills.sh disable=SC1091
source "$LIB"
run() { vendor_pinned_tree "$@" >"$WORK/out" 2>&1; }
M="$REPO/skills-external/mwg"; C="$REPO/skills-external/chrome-extensions"

# T1 install: allowlisted copy, generated files, no upstream SKILL.md.
write_lock "$SHA1"; run mwg-key; rc=$?
check_bool T1-rc "$([ $rc -eq 0 ] && echo 1)"
check_bool T1-guide "$([ -f "$M/guides/html/dialog.md" ] && echo 1)"
check_bool T1-license "$([ -f "$M/LICENSE" ] && echo 1)"
check_bool T1-no-upstream-skill "$([ ! -e "$M/SKILL.md" ] && echo 1)"
check_bool T1-index-desc "$(grep -qx -- '- dialog | html | Native modal dialog.' "$M/INDEX.md" && echo 1)"
check_bool T1-index-h1 "$(grep -qx -- '- animate-to-intrinsic-sizes | css | Animate to intrinsic sizes' "$M/INDEX.md" && echo 1)"
check_bool T1-index-count "$([ "$(grep -c '^- ' "$M/INDEX.md")" -eq 3 ] && echo 1)"
check_bool T1-notice "$(grep -q "$SHA1" "$M/NOTICE.md" && grep -q 'CC-BY 4.0' "$M/NOTICE.md" && echo 1)"
check_bool T1-marker "$([ "$(cat "$M/.vendored-commit")" = "$SHA1" ] && echo 1)"
check_bool T1-ce-contents "$([ -f "$C/SKILL.md" ] && [ -f "$C/references/extensions/api.md" ] && echo 1)"
check_bool T1-no-stage-left "$(compgen -G "$REPO/skills-external/.vendor-stage.*" >/dev/null || echo 1)"

# T2 at the pin: skip, no fetch (source made unreachable).
VENDOR_BASE_URL="file://$WORK/nowhere" vendor_pinned_tree mwg-key >"$WORK/out" 2>&1; rc=$?
check_bool T2-skip-rc "$([ $rc -eq 0 ] && grep -q 'already at pin' "$WORK/out" && echo 1)"

# T3 pin bump after an upstream drop: old-guide disappears locally.
g rm -q skills/modern-web-guidance/guides/html/old-guide.md; g commit -qm two
SHA2="$(git -C "$UP" rev-parse HEAD)"
write_lock "$SHA2"; run mwg-key; rc=$?
check_bool T3-rc "$([ $rc -eq 0 ] && echo 1)"
check_bool T3-pruned "$([ ! -e "$M/guides/html/old-guide.md" ] && echo 1)"
check_bool T3-marker "$([ "$(cat "$M/.vendored-commit")" = "$SHA2" ] && echo 1)"

# T4 an absent copy is installed (never-installed machine).
rm -rf "$REPO/skills-external/chrome-extensions"
run mwg-key; rc=$?
check_bool T4-installs-absent "$([ $rc -eq 0 ] && [ -f "$C/SKILL.md" ] && echo 1)"

# T5 commit not in upstream: rc 1, existing copy untouched.
BAD="0123456789abcdef0123456789abcdef01234567"
write_lock "$BAD"; run mwg-key; rc=$?
check_bool T5-rc "$([ $rc -eq 1 ] && echo 1)"
check_bool T5-untouched "$([ "$(cat "$M/.vendored-commit")" = "$SHA2" ] && echo 1)"

# T6 unsafe repo path rejected before any fetch.
write_lock "$SHA2" ', "evil": {"x": "../etc"}'; run mwg-key; rc=$?
check_bool T6-traversal "$([ $rc -eq 1 ] && grep -q "rejected" "$WORK/out" && [ ! -e "$REPO/skills-external/evil" ] && echo 1)"

# T7 bad dest name rejected.
write_lock "$SHA2" ', "a/b": {"x": "LICENSE"}'; run mwg-key; rc=$?
check_bool T7-dest "$([ $rc -eq 1 ] && grep -q "rejected" "$WORK/out" && echo 1)"

# T8 a missing upstream path aborts with nothing swapped.
write_lock "$SHA2" ', "ghost": {"x": "no/such/path"}'; run mwg-key; rc=$?
check_bool T8-missing-path "$([ $rc -eq 1 ] && [ ! -e "$REPO/skills-external/ghost" ] && [ "$(cat "$M/.vendored-commit")" = "$SHA2" ] && echo 1)"

# T9 a non-file:// VENDOR_BASE_URL is ignored with a warn.
write_lock "$SHA2"
VENDOR_BASE_URL="https://evil.example" vendor_pinned_tree mwg-key >"$WORK/out" 2>&1
check_bool T9-override-ignored "$(grep -q 'VENDOR_BASE_URL ignored' "$WORK/out" && echo 1)"

# T10 a dest that exists without .vendored-commit is never replaced.
mkdir -p "$REPO/skills-external/owned"; printf 'x\n' > "$REPO/skills-external/owned/keep"
write_lock "$SHA2" ', "owned": {"x": "LICENSE"}'; run mwg-key; rc=$?
check_bool T10-owned "$([ $rc -eq 1 ] && grep -q 'refusing to replace' "$WORK/out" && [ -f "$REPO/skills-external/owned/keep" ] && [ ! -e "$REPO/skills-external/owned/x" ] && echo 1)"

# T11 a symlink in the fetched content aborts with nothing swapped.
ln -s ../../SKILL.md "$UP/skills/chrome-extensions/references/link.md"
g add -A; g commit -qm three
SHA3="$(git -C "$UP" rev-parse HEAD)"
write_lock "$SHA3"; run mwg-key; rc=$?
check_bool T11-symlink "$([ $rc -eq 1 ] && [ ! -L "$C/references/link.md" ] && [ "$(cat "$C/.vendored-commit")" = "$SHA2" ] && echo 1)"

echo "vendor-tree: $pass pass, $fail fail"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run it to verify it fails**

Run: `make test suite=lib/tests/vendor-tree.test.sh`
Expected: FAIL lines (`vendor_pinned_tree: command not found` in `$WORK/out`), last line `1 suite(s) red: lib/tests/vendor-tree.test.sh`.

- [ ] **Step 3: Implement** — append to `lib/vendor-skills.sh`:

```bash
# ============================================================
# vendor_pinned_tree — whole upstream trees at one pinned commit, by git
# ============================================================
# Lock entry shape (plugins.lock.json, "managed_by": "git-tree"):
#   "<key>": {
#     "source": "https://github.com/<owner>/<repo>",
#     "commit": "<40-hex sha>", "tag": "<tag name, informational>",
#     "license": "<one-line license note>",
#     "trees": { "<dest>": { "<target>" | ".": "<repo path>", ... }, ... }
#   }
# Each <dest> becomes skills-external/<dest>/. "<target>": "<path>" copies
# the repo path as <dest>/<target>; ".": "<path>" copies the path's
# contents into <dest>/. Only listed paths are copied (allowlist). The
# fetch is one `git fetch --depth 1 <source> <commit>`; HEAD must equal
# the pin or nothing is written. Every dest is staged complete under a
# mktemp dir in skills-external/, then swapped in whole, so a file
# dropped upstream disappears on a pin bump. Per dest it writes
# .vendored-commit, NOTICE.md, and INDEX.md when the dest holds guides/.
# One mode: skip when every dest is at the pin, else fetch (a pin bump,
# a missing or partial copy). A dest that exists without .vendored-commit
# belongs to someone else and is never replaced; a symlink in the fetched
# content aborts the run.

# _vendor_read_tree_lock <lockfile> <key> — prints source, commit, tag,
# license, then one "<dest>\t<target>\t<path>" line per item (sorted).
# rc 1 silent when the entry is absent or incomplete; rc 1 with one
# "INVALID\t<field>=<value>" or "INVALID\t<value>" line on a bad field.
# Only values that reach a path or a URL are allowlisted; tag and license
# are free text without control characters.
_vendor_read_tree_lock() {
  python3 - "$1" "$2" <<'PY'
import json, re, sys

SAFE = re.compile(r'^[A-Za-z0-9._/-]+$')
NAME = re.compile(r'^[A-Za-z0-9_-][A-Za-z0-9._-]*$')
COMMIT_RE = re.compile(r'^[0-9a-f]{40}$')
SOURCE_RE = re.compile(
    r'^https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/?$')


def unsafe(value):
    return ".." in value or value.startswith("/") or not SAFE.fullmatch(value)


def free_text_bad(value):
    return not isinstance(value, str) or any(ord(c) < 32 for c in value)


def bad(text):
    print(f"INVALID\t{text}")
    sys.exit(1)


lockfile, key = sys.argv[1], sys.argv[2]
with open(lockfile) as f:
    entry = json.load(f).get(key, {})
source, sha = entry.get("source", ""), entry.get("commit", "")
tag, note = entry.get("tag", ""), entry.get("license", "")
trees = entry.get("trees", {})
if not source or not sha or not isinstance(trees, dict) or not trees:
    sys.exit(1)
if not COMMIT_RE.fullmatch(sha):
    bad(f"commit={sha}")
if not SOURCE_RE.fullmatch(source):
    bad(f"source={source}")
if free_text_bad(tag):
    bad("tag")
if free_text_bad(note):
    bad("license")
rows = []
for dest, items in trees.items():
    if not NAME.fullmatch(dest) or not isinstance(items, dict) or not items:
        bad(f"dest={dest}")
    for target, path in items.items():
        if target != "." and not NAME.fullmatch(target):
            bad(target)
        if not isinstance(path, str) or unsafe(path):
            bad(str(path))
        rows.append((dest, target, path))
print(source)
print(sha)
print(tag)
print(note)
for dest, target, path in sorted(rows):
    print(f"{dest}\t{target}\t{path}")
PY
}

# _vendor_tree_current <root> <sha> <dests> — rc 0 when every dest
# (newline-separated) holds a .vendored-commit equal to <sha>.
_vendor_tree_current() {
  local root="$1" sha="$2" dest
  while IFS= read -r dest; do
    [ -n "$dest" ] || continue
    [ "$(cat "$root/$dest/.vendored-commit" 2>/dev/null)" = "$sha" ] \
      || return 1
  done <<<"$3"
}

# _vendor_tree_owned <root> <dests> — rc 1 (err names it) when a dest
# exists without .vendored-commit: a directory another installer or the
# repo owns is never replaced.
_vendor_tree_owned() {
  local root="$1" dest
  while IFS= read -r dest; do
    [ -n "$dest" ] || continue
    if [ -e "$root/$dest" ] && [ ! -f "$root/$dest/.vendored-commit" ]; then
      err "skills-external/$dest exists without .vendored-commit — \
not vendored here, refusing to replace it"
      return 1
    fi
  done <<<"$2"
}

# _vendor_tree_checkout <dir> <url> <sha> — shallow fetch of <sha> into a
# fresh repo at <dir>; rc 0 only when the checked-out HEAD is <sha>.
_vendor_tree_checkout() {
  local dir="$1" url="$2" sha="$3"
  git init -q "$dir" >/dev/null 2>&1 || return 1
  # No credential prompt of any kind (same flags as
  # lib/higgsfield-skills.sh): a private or deleted upstream fails at
  # once, not on a terminal, an askpass program or a credential helper.
  GIT_TERMINAL_PROMPT=0 GIT_ASKPASS='' SSH_ASKPASS='' \
    git -C "$dir" -c credential.helper= -c core.askPass= \
    fetch -q --depth 1 -- "$url" "$sha" </dev/null >/dev/null 2>&1 \
    || return 1
  git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD \
    >/dev/null 2>&1 || return 1
  [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" = "$sha" ]
}

# _vendor_tree_summary <readme> <id> — the upstream README's one-line
# description of guide <id> (`- **[<id>](…)**: <text>`), empty when the
# README or the line is absent.
_vendor_tree_summary() {
  [ -f "$1" ] || return 0
  grep -m1 -F -- "- **[$2](" "$1" \
    | sed -n 's/^- \*\*\[[^]]*\]([^)]*)\*\*: //p' || true
}

# _vendor_tree_index <dest_dir> — writes <dest_dir>/INDEX.md, one
# "- <id> | <category> | <summary>" line per guides/<category>/<id>.md;
# the summary is the README description, else the guide's H1 title.
_vendor_tree_index() {
  local dir="$1" f id category summary
  [ -d "$dir/guides" ] || return 0
  {
    cat <<'EOF'
# Guide index

One line per guide: `id | category | summary` (the upstream README's
description, else the guide's title). Read `guides/<category>/<id>.md`.

EOF
    find "$dir/guides" -type f -name '*.md' | LC_ALL=C sort \
      | while IFS= read -r f; do
        id="$(basename "$f" .md)"
        category="$(basename "$(dirname "$f")")"
        summary="$(_vendor_tree_summary "$dir/README.md" "$id")"
        [ -n "$summary" ] \
          || summary="$(grep -m1 '^# ' "$f" | sed 's/^# //')"
        printf -- '- %s | %s | %s\n' "$id" "$category" "${summary:-$id}"
      done
  } > "$dir/INDEX.md"
}

# _vendor_tree_stage <src> <stage> <items> — copies every
# "<dest>\t<target>\t<path>" item from the checkout <src> into
# <stage>/<dest>/; rc 1 (err names the path) when a path is missing or
# the copied content holds a symlink.
_vendor_tree_stage() {
  local src="$1" stage="$2" dest target path
  while IFS=$'\t' read -r dest target path; do
    [ -n "$dest" ] || continue
    mkdir -p "$stage/$dest"
    if [ ! -e "$src/$path" ]; then
      err "upstream path missing at the pin: $path"
      return 1
    fi
    if [ "$target" = "." ]; then
      cp -R "$src/$path/." "$stage/$dest/" || return 1
    else
      cp -R "$src/$path" "$stage/$dest/$target" || return 1
    fi
  done <<<"$3"
  if [ -n "$(find "$stage" -type l -print -quit)" ]; then
    err "upstream content holds a symlink at the pin — refusing"
    return 1
  fi
}

# _vendor_tree_finish <stage> <dests> <source> <sha> <tag> <note> —
# writes INDEX.md, NOTICE.md and .vendored-commit into each staged dest.
_vendor_tree_finish() {
  local stage="$1" dest
  while IFS= read -r dest; do
    [ -n "$dest" ] || continue
    _vendor_tree_index "$stage/$dest"
    printf '# Vendored content\n\nSource: %s (tag %s, commit %s).\n' \
      "$3" "${5:-none}" "$4" > "$stage/$dest/NOTICE.md"
    printf 'Fetched by lib/vendor-skills.sh vendor_pinned_tree;' \
      >> "$stage/$dest/NOTICE.md"
    printf ' never edited here. License: %s.\n' "$6" >> "$stage/$dest/NOTICE.md"
    printf '%s\n' "$4" > "$stage/$dest/.vendored-commit"
  done <<<"$2"
}

# _vendor_tree_swap <root> <stage> <dests> — moves each staged dest into
# <root>/<dest>, the previous copy parked under <stage>/.old-<dest> and
# moved back when the new one cannot be put in place.
_vendor_tree_swap() {
  local root="$1" stage="$2" dest
  while IFS= read -r dest; do
    [ -n "$dest" ] || continue
    if [ -e "$root/$dest" ]; then
      mv "$root/$dest" "$stage/.old-$dest" || return 1
    fi
    if ! mv "$stage/$dest" "$root/$dest"; then
      [ ! -e "$stage/.old-$dest" ] || mv "$stage/.old-$dest" "$root/$dest"
      return 1
    fi
  done <<<"$3"
}

# vendor_pinned_tree <lock-key> — see the block comment above. rc 0 when
# every dest is at the pin (already or after the fetch), rc 1 otherwise.
vendor_pinned_tree() {
  local key="$1" out root="$VENDOR_REPO/skills-external"
  local base="${VENDOR_BASE_URL:-}"
  if [ -n "$base" ] && [[ "$base" != file://* ]]; then
    warn "VENDOR_BASE_URL ignored (must start with file://): $base"
    base=""
  fi
  if ! out="$(_vendor_read_tree_lock "$VENDOR_REPO/plugins.lock.json" "$key")"; then
    _vendor_report_lock_error "$key" "$out"
    return 1
  fi
  local source sha tag note items dests
  { read -r source; read -r sha; read -r tag; read -r note; } <<<"$out"
  items="$(tail -n +5 <<<"$out")"
  dests="$(cut -f1 <<<"$items" | sort -u)"
  if _vendor_tree_current "$root" "$sha" "$dests"; then
    ok "$key already at pin ${sha:0:7}"
    return 0
  fi
  _vendor_tree_owned "$root" "$dests" || return 1
  local tmp stage
  mkdir -p "$root" && tmp="$(mktemp -d)" || return 1
  stage="$(mktemp -d "$root/.vendor-stage.XXXXXX")" \
    || { rm -rf "${tmp:?}"; return 1; }
  if _vendor_tree_checkout "$tmp/src" "${base:-$source}" "$sha" \
    && _vendor_tree_stage "$tmp/src" "$stage" "$items" \
    && _vendor_tree_finish "$stage" "$dests" "$source" "$sha" "$tag" "$note" \
    && _vendor_tree_swap "$root" "$stage" "$dests"; then
    ok "$key vendored (pinned @ ${sha:0:7}): $(tr '\n' ' ' <<<"$dests")"
    rm -rf "${tmp:?}" "${stage:?}"
    return 0
  fi
  err "$key: fetch, stage or swap failed at ${sha:0:7}; a dest not \
swapped keeps its previous copy (doctor names any not at the pin)"
  rm -rf "${tmp:?}" "${stage:?}"
  return 1
}
```

Swap failure note: `_vendor_tree_swap` moves dests one by one. When putting a dest in place fails, its previous copy is moved back; a dest swapped before that stays at the new pin (each dest self-consistent, `.vendored-commit` tells which, doctor names it). No INT/TERM trap: a sourced function would override its caller's traps; a Ctrl-C between the two moves leaves the old copy under the stage dir and the next run re-fetches.

- [ ] **Step 4: Run the suite**

Run: `make test suite=lib/tests/vendor-tree.test.sh`
Expected: every line `PASS …`, `vendor-tree: 24 pass, 0 fail`, `all suites green` (simulated on a scratch clone 2026-11-22: 24/24).
Then: `shellcheck lib/vendor-skills.sh lib/tests/vendor-tree.test.sh` → no output (simulated: clean).
Then the old suite still green: `make test suite=lib/tests/vendor-skills.test.sh` → `all suites green`.

- [ ] **Step 5: Commit**

```bash
git add lib/vendor-skills.sh lib/tests/vendor-tree.test.sh
git commit -m "feat(vendor): vendor_pinned_tree fetches whole upstream trees at a pinned commit"
```

---

### Task 2: Lock entry, install/update/link wiring, gitignore, doctor check

**Files:**
- Modify: `plugins.lock.json` (new key `modern-web-guidance`)
- Modify: `install-plugins.sh` Step 8e (`EXT_SKILL_NAMES` at :924, call after :932)
- Modify: `update-all.sh` 7.3 (call after :383)
- Modify: `link.sh:78-81` (`EXTERNAL_SKILLS`)
- Modify: `.gitignore` (top flat-link block + a new vendored block after the superpowers block at :139)
- Modify: `lib/doctor-vendored.sh` (new `check_vendored_trees`; `|| true` on the per-name call at :230), `doctor.sh:133`
- Test: `lib/tests/doctor-vendored.test.sh` (new cases)

**Interfaces:**
- Consumes: `vendor_pinned_tree <key>` (Task 1).
- Produces: `check_vendored_trees <repo>` (doctor: pass/warn lines, never fail, never trips errexit); lock key `modern-web-guidance`; dests `skills-external/mwg/`, `skills-external/chrome-extensions/`.

- [ ] **Step 1: Write the failing test** — in `lib/tests/doctor-vendored.test.sh`, insert this block right above the last-but-one line `echo "PASS=$pass FAIL=$fail"` (it uses the suite's `WORK`, `LIB` and `check_bool`):

```bash
# ── check_vendored_trees: git-tree lock entries; doctor survives errexit ──
TR="$WORK/trees"
mkdir -p "$TR/skills-external/at-pin" "$TR/skills-external/stale"
printf '%s\n' 1111111111111111111111111111111111111111 \
  > "$TR/skills-external/at-pin/.vendored-commit"
printf '%s\n' 2222222222222222222222222222222222222222 \
  > "$TR/skills-external/stale/.vendored-commit"
cat > "$TR/plugins.lock.json" <<'JSON'
{"t": {"managed_by": "git-tree", "commit": "1111111111111111111111111111111111111111",
       "trees": {"at-pin": {"x": "a"}, "stale": {"x": "a"}, "absent": {"x": "a"}}},
 "c": {"managed_by": "curl", "commit": "1111111111111111111111111111111111111111", "skills": ["s"]}}
JSON
printf 'EXTERNAL_SKILLS=(\n  ghost-ext\n)\n' > "$TR/link.sh"
out_t="$(check_vendored_trees "$TR" 2>&1)"
printf '%s\n' "$out_t" | grep -q 't: at-pin at pin 1111111' && R1=1 || R1=0
printf '%s\n' "$out_t" | grep -q 't: skills-external/stale at 2222222, pin 1111111' && R2=1 || R2=0
printf '%s\n' "$out_t" | grep -q 't: skills-external/absent missing' && R3=1 || R3=0
printf '%s\n' "$out_t" | grep -q '✗' && R4=0 || R4=1
# doctor.sh runs under `set -euo pipefail`: a missing tree dest and a
# missing external copy are reported and doctor goes on to its summary.
# shellcheck disable=SC2016
out_e="$(bash -c 'set -euo pipefail; source "$1"
  check_vendored_trees "$2"; check_vendored_skills "$2" "$2/home"
  echo DOCTOR_GOES_ON' _ "$LIB" "$TR" 2>&1)"
printf '%s\n' "$out_e" | grep -qx 'DOCTOR_GOES_ON' \
  && printf '%s\n' "$out_e" | grep -q 'ghost-ext: skills-external/ghost-ext/SKILL.md missing' \
  && R5=1 || R5=0
check_bool TREES_AT_PIN "$R1"
check_bool TREES_STALE_WARN "$R2"
check_bool TREES_MISSING_WARN "$R3"
check_bool TREES_NEVER_FAIL "$R4"
check_bool TREES_ERREXIT_SURVIVES "$R5"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `make test suite=lib/tests/doctor-vendored.test.sh`
Expected: the five new checks FAIL (`check_vendored_trees: command not found`; TREES_ERREXIT_SURVIVES also fails on the current `_dv_check_name` call).

- [ ] **Step 3: Implement**

`lib/doctor-vendored.sh`, append:

```bash
# _dv_tree_expectations <lockfile> — prints "<key>\t<dest>\t<commit>" for
# every "managed_by": "git-tree" entry; dest and commit format-checked,
# an invalid one skipped. Lockfile via argv, stderr discarded.
_dv_tree_expectations() {
  python3 - "$1" 2>/dev/null <<'PY'
import json, re, sys
NAME = re.compile(r'^[A-Za-z0-9_-][A-Za-z0-9._-]*$')
COMMIT = re.compile(r'^[0-9a-f]{40}$')
with open(sys.argv[1]) as f:
    data = json.load(f)
for key, entry in sorted(data.items()):
    if not isinstance(entry, dict) or entry.get("managed_by") != "git-tree":
        continue
    sha = entry.get("commit", "")
    trees = entry.get("trees", {})
    if not COMMIT.fullmatch(sha) or not isinstance(trees, dict):
        continue
    for dest in sorted(trees):
        if NAME.fullmatch(dest):
            print(f"{key}\t{dest}\t{sha}")
PY
}

# check_vendored_trees <repo> — every git-tree dest exists under
# skills-external/ with a .vendored-commit equal to its pin. Never fails
# and never trips doctor.sh's errexit: a missing or stale copy is a warn
# naming `make plugin`.
check_vendored_trees() {
  local repo="$1" key dest sha got
  while IFS=$'\t' read -r key dest sha; do
    [ -n "$key" ] || continue
    got="$(cat "$repo/skills-external/$dest/.vendored-commit" \
      2>/dev/null || true)"
    if [ -z "$got" ]; then
      warn "$key: skills-external/$dest missing — run: make plugin"
    elif [ "$got" != "$sha" ]; then
      warn "$key: skills-external/$dest at ${got:0:7}, pin ${sha:0:7} \
— run: make plugin"
    else
      pass "$key: $dest at pin ${sha:0:7}"
    fi
  done < <(_dv_tree_expectations "$repo/plugins.lock.json")
}
```

`lib/doctor-vendored.sh:230`, inside `check_vendored_skills`, the line `    _dv_check_name "$repo" "$claude_home" "$name" "$lock_out"` becomes:

```bash
    # fail() reports a miss; doctor.sh (set -e) still reaches its summary.
    _dv_check_name "$repo" "$claude_home" "$name" "$lock_out" || true
```

(Pre-existing: a missing external copy killed doctor after its first `fail` line; adding `chrome-extensions` to `EXTERNAL_SKILLS` would add one more way to hit it. Simulated: TREES_ERREXIT_SURVIVES fails without either `|| true`, passes with both.)

`doctor.sh` line 133, after `check_vendored_skills "$REPO" "$HOME/.claude"`:

```bash
check_vendored_trees "$REPO"
```

`plugins.lock.json`, new key right after the `superpowers` entry (keep the file's existing order and formatting):

```json
"modern-web-guidance": {
  "source": "https://github.com/GoogleChrome/modern-web-guidance",
  "commit": "64a6d708f5a43f2cd3fde5d4d7db3905ba1bdf65",
  "tag": "v1.0.1",
  "license": "Apache-2.0 (code), CC-BY 4.0 (guides)",
  "managed_by": "git-tree",
  "always_on": true,
  "trees": {
    "mwg": {"guides": "skills/modern-web-guidance/guides", "LICENSE": "LICENSE", "README.md": "README.md"},
    "chrome-extensions": {".": "skills/chrome-extensions"}
  },
  "note": "Google Modern Web Guidance (Chrome, Edge, Firefox, MDN). Guides read locally by skills/modern-web-guidance; the upstream SKILL.md (npx @latest) is never copied. README.md feeds INDEX.md descriptions. chrome-extensions linked as is by link.sh. Bump commit + tag deliberately."
}
```

`install-plugins.sh` Step 8e: add `chrome-extensions` at the end of the `EXT_SKILL_NAMES=(…)` array (:924), and after `vendor_pinned_skills superpowers` (:932) add:

```bash
if ! vendor_pinned_tree modern-web-guidance; then
  warn "Modern Web Guidance not vendored (previous copy kept, if any) — rerun: make plugin"
fi
```

`update-all.sh` 7.3: after `vendor_pinned_skills superpowers refresh` (:383) add:

```bash
echo ""
echo "── Updating Modern Web Guidance (GoogleChrome/modern-web-guidance)..."
if ! vendor_pinned_tree modern-web-guidance; then
  warn "Modern Web Guidance not vendored (previous copy kept, if any) — rerun: make update"
fi
```

`link.sh:81`: append `chrome-extensions` inside `EXTERNAL_SKILLS=(…)` (last element, before `)`).

`.gitignore`: in the top flat-link block add `skills/chrome-extensions`; after the superpowers block (:139) add

```gitignore
# Modern Web Guidance, vendored (plugins.lock.json 'modern-web-guidance',
# managed_by git-tree) — machine-owned, fetched at the pinned commit by
# install-plugins.sh Step 8e and update-all.sh 7.3 through
# lib/vendor-skills.sh vendor_pinned_tree. Bump the commit deliberately.
skills-external/mwg/
skills-external/chrome-extensions/
skills-external/.vendor-stage.*/
```

- [ ] **Step 4: Run tests**

Run: `make test suite="lib/tests/doctor-vendored.test.sh lib/tests/vendor-skills.test.sh lib/tests/vendor-tree.test.sh lib/tests/curated-config-guard.test.sh"`
Expected: `all suites green`. Then `shellcheck lib/doctor-vendored.sh doctor.sh install-plugins.sh update-all.sh link.sh lib/tests/doctor-vendored.test.sh` → no new warning; `python3 -c "import json;json.load(open('plugins.lock.json'))"` → no output.

- [ ] **Step 5: Commit**

```bash
git add plugins.lock.json install-plugins.sh update-all.sh link.sh .gitignore lib/doctor-vendored.sh doctor.sh lib/tests/doctor-vendored.test.sh
git commit -m "feat(vendor): pin Modern Web Guidance v1.0.1 and chrome-extensions, doctor checks the pin"
```

---

### Task 3: Our `modern-web-guidance` skill (no routing row)

**Files:**
- Create: `skills/modern-web-guidance/SKILL.md`, `skills/modern-web-guidance/test-prompts.json`
- Create (tracked symlink): `skills/modern-web-guidance/mwg -> ../../skills-external/mwg`
- Modify: `lib/tests/effort-routing.test.sh:141` (`NO_ROW_SKILLS` gains `modern-web-guidance`)
- Test: `lib/tests/mwg-skill.test.sh`

**Interfaces:**
- Consumes: `skills-external/mwg/{guides,INDEX.md,NOTICE.md}` (Task 1/2 layout).
- Produces: skill name `modern-web-guidance`; disclosure line format `Modern Web Guidance: <id>, <id>` / `Modern Web Guidance: checked <topics>, none applied`.

- [ ] **Step 1: Write the failing test** — `lib/tests/mwg-skill.test.sh`:

```bash
#!/usr/bin/env bash
# lib/tests/mwg-skill.test.sh — skills/modern-web-guidance: Read is the
# only pre-approved tool, no effort pin and no routing.json row (a row
# reroutes the main loop on load), no npx or network command in a fenced
# block, the relative link into skills-external/mwg, the disclosure
# format, a description within the listing budget.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/skills/modern-web-guidance"
pass=0; fail=0
check() { if [ "$2" = 1 ]; then pass=$((pass+1)); echo "PASS $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }
fm() { awk '/^---$/{n++; next} n==1' "$S/SKILL.md"; }
check exists "$([ -f "$S/SKILL.md" ] && echo 1)"
check tools "$(fm | grep -qx 'allowed-tools: Read' && echo 1)"
check no-effort "$(fm | grep -q '^effort:' || echo 1)"
desc_len="$(fm | awk '/^description:/{f=1; next} /^[a-z-]+:/{f=0} f' | tr -s ' \n' ' ' | wc -c)"
check desc-budget "$([ "$desc_len" -gt 100 ] && [ "$desc_len" -le 400 ] && echo 1)"
fenced="$(awk '/^```/{f=!f; next} f' "$S/SKILL.md" | grep -c 'npx\|pnpx\|curl\|wget')"
check no-fenced-network "$([ "$fenced" -eq 0 ] && echo 1)"
check never-run "$(grep -q 'Never run npx' "$S/SKILL.md" && echo 1)"
check read-index "$(grep -q 'Read `mwg/INDEX.md` whole' "$S/SKILL.md" && echo 1)"
check search-root "$(grep -q '~/.claude/skills/modern-web-guidance/mwg/guides/' "$S/SKILL.md" && echo 1)"
check disclosure "$(grep -q '`Modern Web Guidance: <id>, <id>`' "$S/SKILL.md" && echo 1)"
check link-mwg "$([ -L "$S/mwg" ] && [ "$(readlink "$S/mwg")" = ../../skills-external/mwg ] && echo 1)"
check tracked-link "$([ "$(cd "$ROOT" && git ls-files skills/modern-web-guidance/mwg | wc -l)" -eq 1 ] && echo 1)"
check no-routing-row "$(grep -q '"modern-web-guidance"\|"chrome-extensions"' "$ROOT/mods/model-router/routing.json" || echo 1)"
check prompts "$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));sys.exit(0 if len(d)>=3 else 1)" "$S/test-prompts.json" && echo 1)"
echo "mwg-skill: $pass pass, $fail fail"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run it to verify it fails**

Run: `make test suite=lib/tests/mwg-skill.test.sh` → `FAIL exists` etc.

- [ ] **Step 3: Implement**

`skills/modern-web-guidance/SKILL.md`:

````markdown
---
name: modern-web-guidance
description: >-
  Current web-platform practice from Google's Modern Web Guidance, read
  from a pinned local copy. Use FIRST, before writing or changing
  front-end code: HTML, CSS, client-side JS, UI components, forms,
  dialogs, layout, motion, Core Web Vitals, images, accessibility. Not
  for backend, infra, build tooling or tests.
allowed-tools: Read
---

# Modern Web Guidance (local, pinned)

This folder is `~/.claude/skills/modern-web-guidance/`. Its `mwg/` holds
`INDEX.md`, one line per guide (`- <id> | <category> | <summary>`), and the
guides at `mwg/guides/<category>/<id>.md`. They are a copy of
GoogleChrome/modern-web-guidance pinned in `plugins.lock.json`;
`mwg/NOTICE.md` names the commit and the licenses. Read is the only tool
needed, nothing here touches the network.

## Steps

1. Pick: Read `mwg/INDEX.md` whole (about 210 lines) and choose the
   guides whose summary matches a platform feature or UI pattern the
   task uses (a modal is `dialog`, an accordion animates to intrinsic
   sizes, a slow first paint is LCP). No summary fits a feature: search
   `~/.claude/skills/modern-web-guidance/mwg/guides/` once with the
   text-search tool at hand, else go on without a guide.
2. Read each chosen guide. Read a discipline guide (the one whose id
   equals its category: `html`, `css`, `js`, `forms`, `accessibility`,
   `performance`, `security`, `privacy`) only when building a new
   component or page, or when no specific guide matched; they are long.
3. Cross-references: a guide line `npx -y modern-web-guidance@latest
   retrieve "<id>"` names another guide. Find `<id>` in `mwg/INDEX.md`
   for its category and Read `mwg/guides/<category>/<id>.md`.
   Never run npx, the guidance CLI or any network command for this skill.
4. Apply: follow the guide, its fallbacks and its Baseline notes, without
   adding features the task did not ask for. Where a guide and a rule of
   `rules/web-building.md` disagree on how to use the platform, the guide
   wins. An executor whose closed plan contradicts a guide reports it as
   an open choice, never overrides the plan silently.
5. Disclose: the answer that delivers the front-end change (a sub-agent:
   its report) ends with one line, `Modern Web Guidance: <id>, <id>`.
   Guides checked and none applied: `Modern Web Guidance: checked <topics>,
   none applied`. No quotes.

## Missing copy

`mwg/INDEX.md` unreadable (the link dangles on a machine that never ran
the install): say once "Modern Web Guidance not installed, run
`make update`" and continue without it.
````

Symlink (from the repo root), then stage the skill so the `tracked-link` check can see it:

```bash
ln -s ../../skills-external/mwg skills/modern-web-guidance/mwg
git add skills/modern-web-guidance
```

`skills/modern-web-guidance/test-prompts.json`:

```json
[
  {"id": 1, "prompt": "Add a confirmation modal before deleting an item", "expected": "Read mwg/INDEX.md, pick dialog, Read the dialog guide, build on <dialog> per the guide, end with `Modern Web Guidance: <ids>`"},
  {"id": 2, "prompt": "Make this accordion open smoothly", "expected": "Pick animate-to-intrinsic-sizes from its summary, Read it, apply its technique and fallback, disclosure line"},
  {"id": 3, "prompt": "Améliore le LCP de la page d'accueil", "expected": "FR trigger: pick the LCP guides, Read them, apply fetchpriority/image guidance, disclosure line"},
  {"id": 4, "prompt": "Write a SQL migration for the orders table", "expected": "Does not trigger: backend task"}
]
```

`lib/tests/effort-routing.test.sh:141`: the line becomes

```bash
NO_ROW_SKILLS=" find-docs graphify impeccable model-router modern-web-guidance "
```

No `routing.json` edit: neither `modern-web-guidance` nor `chrome-extensions` gets a row (Global Constraints).

- [ ] **Step 4: Run tests**

Run: `make test suite="lib/tests/mwg-skill.test.sh lib/tests/effort-routing.test.sh lib/tests/model-routing.test.sh lib/tests/pack-census.test.sh"`
Expected: `all suites green`. (The description-collision census runs on the live catalog, which holds neither skill before Task 5: its check moves to Task 5.)

- [ ] **Step 5: Commit**

```bash
git add skills/modern-web-guidance lib/tests/effort-routing.test.sh lib/tests/mwg-skill.test.sh
git commit -m "feat(skills): modern-web-guidance reads the pinned guides locally"
```

---

### Task 4: Wiring in `rules/web-building.md` and `site-motion`

**Files:**
- Modify: `rules/web-building.md` (after line 5 title; lines 27-29 motion; § Design work after the Build bullet ≈ line 57)
- Modify: `skills/pack-design/skills/site-motion/SKILL.md` (after the intro paragraph ending `top of it.`)
- Test: `lib/tests/mwg-skill.test.sh` (append wiring checks)

**Interfaces:**
- Consumes: skill name `modern-web-guidance` (Task 3).

- [ ] **Step 1: Write the failing test** — append before the summary line `echo "mwg-skill: …"` of `lib/tests/mwg-skill.test.sh`. Every grepped phrase sits on one line of the text below (checked against it):

```bash
W="$ROOT/rules/web-building.md"
check rule-section "$(grep -qx '## Modern Web Guidance first' "$W" && echo 1)"
check rule-before-design "$([ "$(grep -n '^## Modern Web Guidance first' "$W" | cut -d: -f1)" -lt "$(grep -n '^## Design work' "$W" | cut -d: -f1)" ] && echo 1)"
check rule-subagent-path "$(grep -qF 'Read `~/.claude/skills/modern-web-guidance/SKILL.md` and follow it.' "$W" && echo 1)"
check rule-plan-time "$(grep -qF 'Planning front-end work runs it before the plan closes.' "$W" && echo 1)"
check rule-guide-wins "$(grep -qF 'the platform, the guide wins.' "$W" && echo 1)"
check rule-no-silent "$(grep -qF 'reports it as an open choice, never overrides it silently.' "$W" && echo 1)"
check rule-disclosure-scope "$(grep -qF 'An answer that delivers a front-end change ends with' "$W" && echo 1)"
check motion-line "$(grep -q '^- Motion: transform and opacity for continuous or scroll-linked motion,$' "$W" && echo 1)"
check motion-old-gone "$(grep -q 'transform and opacity only' "$W" || echo 1)"
check design-build "$(awk '/^## Design work/{p=1; next} /^## /{p=0} p' "$W" | grep -qF '`modern-web-guidance` first for the platform features it uses.' && echo 1)"
check design-heading "$(grep -qx '## Design work — full toolchain (tiered by scope)' "$W" && echo 1)"
check locked-line "$(grep -qxF -- '- The vendored stack members route to `reflect` (high) through their' "$W" && echo 1)"
check site-motion "$(grep -q '`modern-web-guidance`' "$ROOT/skills/pack-design/skills/site-motion/SKILL.md" && echo 1)"
```

- [ ] **Step 2: Run it to verify it fails** — `make test suite=lib/tests/mwg-skill.test.sh` → the new checks FAIL except `design-heading` and `locked-line` (already true).

- [ ] **Step 3: Implement**

`rules/web-building.md`, insert after the line `# Web building — no default reflexes + done checklist` and its following blank line (keep the line breaks exactly as written):

```markdown
## Modern Web Guidance first
Before writing or changing front-end code (markup, styles, client-side
JS, components), run the `modern-web-guidance` skill: it reads Google's
pinned guides locally. No Skill tool (a sub-agent):
Read `~/.claude/skills/modern-web-guidance/SKILL.md` and follow it.
Planning front-end work runs it before the plan closes.
Where a guide and a line below disagree on how to use
the platform, the guide wins. An executor whose closed plan contradicts a guide
reports it as an open choice, never overrides it silently.
An answer that delivers a front-end change ends with
the skill's one-line disclosure.

```

Replace the three lines

```
- Motion: transform and opacity only; feedback under 200 ms, ease-out on
  entrances, never from scale(0); `will-change` only during an active
  animation; pause loops off-screen; honor `prefers-reduced-motion`.
```

with

```
- Motion: transform and opacity for continuous or scroll-linked motion,
  other transitions per the Modern Web Guidance guides; feedback under
  200 ms, ease-out on entrances, never from scale(0); `will-change` only
  during an active animation; pause loops off-screen; honor
  `prefers-reduced-motion`.
```

In § Design work, insert right after the Build bullet (after the line `  only for a one-off visual with no project context, not beside impeccable.`):

```
- Every Build, polish, motion and scroll step above consults
  `modern-web-guidance` first for the platform features it uses.
```

`skills/pack-design/skills/site-motion/SKILL.md`: after the intro paragraph ending `top of it.`, add a blank line and:

```markdown
Platform features (scroll-driven animation, view transitions, animating to
intrinsic sizes, reduced motion) come from the `modern-web-guidance` skill
first: read its guide before choosing a library or a technique.
```

- [ ] **Step 4: Run tests**

Run: `make test suite="lib/tests/mwg-skill.test.sh lib/tests/doctrine-citers.test.sh lib/tests/effort-routing.test.sh lib/tests/project-rules.test.sh lib/tests/user-rules.test.sh"`
Expected: `all suites green`.

- [ ] **Step 5: Commit**

```bash
git add rules/web-building.md skills/pack-design/skills/site-motion/SKILL.md lib/tests/mwg-skill.test.sh
git commit -m "feat(rules): front-end work consults modern-web-guidance first"
```

---

### Task 5 (main loop, after Task 4, before the STEP 5 gates): live install, census, doctor

Not an executor task (network fetch on this machine, link refresh). Contract oracles 1, 4 and 5 read its result, so it runs before GATE 0:

- `bash -c 'source lib/vendor-skills.sh && vendor_pinned_tree modern-web-guidance'` → `modern-web-guidance vendored (pinned @ 64a6d70): chrome-extensions mwg`.
- `bash link.sh` → `chrome-extensions` linked.
- `ls skills/modern-web-guidance/mwg/INDEX.md` resolves; `grep -c '^- ' skills-external/mwg/INDEX.md` → 210; 204 lines carry a README description, 6 fall back to the H1.
- `make test suite=lib/tests/skill-routing-census.test.sh`: a pair ≥ 0.75 involving `modern-web-guidance` or `chrome-extensions` → reword our description's list of front-end areas (keep the first sentence, within 400 characters; chrome-extensions is vendored, never reworded) through a fresh executor, re-run. A WARN (≥ 0.50) is reported, not fixed.
- `make doctor` → no new error; `check_vendored_trees` passes both dests.
- Full `make test` (bun on PATH) → green.

Rollback (if the feature is reverted): `rm ~/.claude/skills/chrome-extensions` (link.sh never unlinks a name dropped from `EXTERNAL_SKILLS`), and delete the gitignored `skills-external/mwg/` and `skills-external/chrome-extensions/` by hand from the repo root.

## Challenge dispositions (STEP 2b, 2026-11-22)

- MINOR dropped: shared Python validators across `_vendor_read_tree_lock`, `_vendor_read_lock` and `_dv_tree_expectations` (three heredocs, no shared module; the neighbouring code repeats them too).
- MINOR dropped: INT/TERM trap in `vendor_pinned_tree` (see the swap failure note).
