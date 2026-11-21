# Modern Web Guidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Vendor Google's Modern Web Guidance (guides + chrome-extensions) at a pinned commit and make every front-end task consult it through our own local, network-free skill.

**Architecture:** A new `vendor_pinned_tree` helper in `lib/vendor-skills.sh` fetches one pinned commit with git, copies an allowlist of upstream paths into `skills-external/<dest>/`, generates `INDEX.md` / `NOTICE.md` / `.vendored-commit`, and swaps the result in. Our tracked skill `skills/modern-web-guidance/` reaches the guides through relative symlinks and only uses Read/Grep/Glob. `rules/web-building.md` and `site-motion` send front-end work to the skill.

**Tech Stack:** bash, python3 (lock parsing, argv only), git, markdown.

**Spec:** `docs/superpowers/specs/2026-11-21-modern-web-guidance-design.md`
**Contract:** `.claude/tasks/contracts/2026-11-21-modern-web-guidance-2314.md`

Out of this plan, done by `/ship-feature` itself: README / USAGE / CHANGELOG (STEP 8 doc sync) and the BDR recording the decisions, including the fixed pin as an exception to BDR-056 (STEP 7).

## Global Constraints

- Pin: tag `v1.0.1`, commit `64a6d708f5a43f2cd3fde5d4d7db3905ba1bdf65`, source `https://github.com/GoogleChrome/modern-web-guidance`.
- No path of this feature runs `npx`, `pnpx` or the `modern-web-guidance` CLI; the skill's `allowed-tools` is `Read, Grep, Glob` only.
- The upstream `skills/modern-web-guidance/SKILL.md` is never copied into `skills-external/`.
- Vendored text is never edited (BDR-104/106).
- `CLAUDE.global.md`, `settings.json`, `CLAUDE.md` are not modified (BDR-028, 320-line budget).
- `rules/web-building.md`: the heading line `## Design work — full toolchain (tiered by scope)` and the line `- The vendored stack members route to \`reflect\` (high) through their` stay byte-identical (doctrine-citers and effort-routing locks, LRN-166).
- Tests run only through `make test suite=<file>` (hermetic git config).
- `VENDOR_BASE_URL` override is honored only when it starts with `file://` (same rule as `vendor_pinned_skills`).

## Review Focus

1. Fetch failure or a commit that is not the pin → rc 1, `skills-external/` unchanged (no half-swapped dest).
2. A pin bump that drops a guide upstream → the guide disappears locally after refresh (whole-dir swap, not file overwrite).
3. A machine that never ran `make plugin` → `make update` (refresh mode) installs the copy instead of skipping it.
4. A lock entry with `..`, an absolute path or a bad dest name → rejected before any fetch.
5. Fresh clone before install → our skill's symlinks dangle; the skill says "run `make update`" and doctor warns (no error).

---

### Task 1: `vendor_pinned_tree` fetcher + hermetic suite

**Files:**
- Modify: `lib/vendor-skills.sh` (append after `vendor_pinned_skills`)
- Create: `lib/tests/vendor-tree.test.sh`

**Interfaces:**
- Produces: `vendor_pinned_tree <lock-key> [refresh]` (rc 0 ok/already at pin, rc 1 any failure, nothing changed); `_vendor_read_tree_lock <lockfile> <key>` (stdout lines: source, commit, tag, license, then `<dest>\t<target>\t<repo-path>`); lock entry shape:
  `{"source","commit","tag","license","trees":{"<dest>":{"<target>|.":"<repo-path>"}},"managed_by":"git-tree","always_on":true}`.
- Writes per dest: `skills-external/<dest>/.vendored-commit` (the commit), `NOTICE.md`, and `INDEX.md` when the dest holds `guides/`.

- [ ] **Step 1: Write the failing test** — create `lib/tests/vendor-tree.test.sh`:

```bash
#!/usr/bin/env bash
# lib/tests/vendor-tree.test.sh — lib/vendor-skills.sh vendor_pinned_tree():
# pinned git fetch from a file:// fixture repo, allowlisted copy, INDEX /
# NOTICE / .vendored-commit generation, upstream SKILL.md never copied,
# commit mismatch refused with nothing written, refresh prunes a guide
# dropped upstream, refresh installs an absent copy, install mode skips a
# copy already at the pin, unsafe lock paths rejected before any fetch.
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

# Fixture upstream: modern-web-guidance layout (SKILL.md + guides/) and a
# chrome-extensions skill with a references/ file.
mkdir -p "$UP/skills/modern-web-guidance/guides/css" \
  "$UP/skills/modern-web-guidance/guides/html" \
  "$UP/skills/chrome-extensions/references/extensions"
printf 'npx -y modern-web-guidance@latest search\n' \
  > "$UP/skills/modern-web-guidance/SKILL.md"
printf '# Animate to intrinsic sizes\nbody\n' \
  > "$UP/skills/modern-web-guidance/guides/css/animate-to-intrinsic-sizes.md"
printf '# Dialog\nbody\n' > "$UP/skills/modern-web-guidance/guides/html/dialog.md"
printf '# Old guide\nbody\n' > "$UP/skills/modern-web-guidance/guides/html/old-guide.md"
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
      "mwg": {"guides": "skills/modern-web-guidance/guides", "LICENSE": "LICENSE"},
      "chrome-extensions": {".": "skills/chrome-extensions"}${2:-}
    }
  }
}
JSON
}
run() { # run <args…> — sources the lib in a subshell against the fixture
  ( export VENDOR_SKILLS_REPO_OVERRIDE="$REPO" VENDOR_BASE_URL="file://$UP"
    # shellcheck disable=SC1090
    source "$LIB"; vendor_pinned_tree "$@" ) >"$WORK/out" 2>&1
}

# T1 install: allowlisted copy, generated files, no upstream SKILL.md.
write_lock "$SHA1"; run mwg-key; rc=$?
M="$REPO/skills-external/mwg"; C="$REPO/skills-external/chrome-extensions"
check_bool T1-rc "$([ $rc -eq 0 ] && echo 1)"
check_bool T1-guide "$([ -f "$M/guides/html/dialog.md" ] && echo 1)"
check_bool T1-license "$([ -f "$M/LICENSE" ] && echo 1)"
check_bool T1-no-upstream-skill "$([ ! -e "$M/SKILL.md" ] && echo 1)"
check_bool T1-index-line "$(grep -qx -- '- dialog | html | Dialog' "$M/INDEX.md" && echo 1)"
check_bool T1-index-count "$([ "$(grep -c '^- ' "$M/INDEX.md")" -eq 3 ] && echo 1)"
check_bool T1-notice "$(grep -q "$SHA1" "$M/NOTICE.md" && grep -q 'CC-BY 4.0' "$M/NOTICE.md" && echo 1)"
check_bool T1-marker "$([ "$(cat "$M/.vendored-commit")" = "$SHA1" ] && echo 1)"
check_bool T1-ce-contents "$([ -f "$C/SKILL.md" ] && [ -f "$C/references/extensions/api.md" ] && echo 1)"
check_bool T1-no-stage-left "$([ -z "$(ls -A "$REPO/skills-external" | grep '^\.vendor-stage')" ] && echo 1)"

# T2 install mode at the pin: skip, no fetch (source made unreachable).
( export VENDOR_SKILLS_REPO_OVERRIDE="$REPO" VENDOR_BASE_URL="file://$WORK/nowhere"
  source "$LIB"; vendor_pinned_tree mwg-key ) >"$WORK/out" 2>&1; rc=$?
check_bool T2-skip-rc "$([ $rc -eq 0 ] && grep -q 'already at pin' "$WORK/out" && echo 1)"

# T3 refresh after an upstream drop: old-guide disappears locally.
g rm -q skills/modern-web-guidance/guides/html/old-guide.md; g commit -qm two
SHA2="$(git -C "$UP" rev-parse HEAD)"
write_lock "$SHA2"; run mwg-key refresh; rc=$?
check_bool T3-rc "$([ $rc -eq 0 ] && echo 1)"
check_bool T3-pruned "$([ ! -e "$M/guides/html/old-guide.md" ] && echo 1)"
check_bool T3-marker "$([ "$(cat "$M/.vendored-commit")" = "$SHA2" ] && echo 1)"

# T4 refresh installs an absent copy (never-installed machine).
rm -rf "$REPO/skills-external/chrome-extensions"
run mwg-key refresh; rc=$?
check_bool T4-installs-absent "$([ $rc -eq 0 ] && [ -f "$C/SKILL.md" ] && echo 1)"

# T5 commit not in upstream: rc 1, existing copy untouched.
BAD="0123456789abcdef0123456789abcdef01234567"
write_lock "$BAD"; run mwg-key refresh; rc=$?
check_bool T5-rc "$([ $rc -eq 1 ] && echo 1)"
check_bool T5-untouched "$([ "$(cat "$M/.vendored-commit")" = "$SHA2" ] && echo 1)"

# T6 unsafe repo path rejected before any fetch.
write_lock "$SHA2" ', "evil": {"x": "../etc"}'; run mwg-key; rc=$?
check_bool T6-traversal "$([ $rc -eq 1 ] && grep -q "rejected" "$WORK/out" && [ ! -e "$REPO/skills-external/evil" ] && echo 1)"

# T7 bad dest name rejected.
write_lock "$SHA2" ', "a/b": {"x": "LICENSE"}'; run mwg-key; rc=$?
check_bool T7-dest "$([ $rc -eq 1 ] && grep -q "rejected" "$WORK/out" && echo 1)"

# T8 a missing upstream path aborts with nothing swapped.
write_lock "$SHA2" ', "ghost": {"x": "no/such/path"}'; run mwg-key refresh; rc=$?
check_bool T8-missing-path "$([ $rc -eq 1 ] && [ ! -e "$REPO/skills-external/ghost" ] && [ "$(cat "$M/.vendored-commit")" = "$SHA2" ] && echo 1)"

# T9 a non-file:// VENDOR_BASE_URL is ignored with a warn.
write_lock "$SHA2"
( export VENDOR_SKILLS_REPO_OVERRIDE="$REPO" VENDOR_BASE_URL="https://evil.example"
  source "$LIB"; vendor_pinned_tree mwg-key ) >"$WORK/out" 2>&1
check_bool T9-override-ignored "$(grep -q 'VENDOR_BASE_URL ignored' "$WORK/out" && echo 1)"

echo "vendor-tree: $pass pass, $fail fail"
[ "$fail" -eq 0 ]
```

T9 note: with the override ignored the source becomes the real `https://github.com/acme/mwg` URL; the copy is already at the pin, so install mode returns "already at pin" before any fetch. The warn is printed first only if the override check runs before the at-pin skip — the implementation below runs the override check first, on purpose.

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
# the pin or nothing is written. Every dest is staged complete under
# skills-external/.vendor-stage.<pid>/, then swapped in whole, so a file
# dropped upstream disappears on a pin bump. Per dest it writes
# .vendored-commit, NOTICE.md, and INDEX.md when the dest holds guides/.
# Install mode skips when every dest is already at the pin; refresh
# re-fetches; both install a missing copy.

# _vendor_read_tree_lock <lockfile> <key> — prints source, commit, tag,
# license, then one "<dest>\t<target>\t<path>" line per item (sorted).
# rc 1 silent when the entry is absent or incomplete; rc 1 with one
# "INVALID\t<field>=<value>" or "INVALID\t<value>" line on a bad field.
_vendor_read_tree_lock() {
  python3 - "$1" "$2" <<'PY'
import json, re, sys

SAFE = re.compile(r'^[A-Za-z0-9._/-]+$')
NAME = re.compile(r'^[A-Za-z0-9_-][A-Za-z0-9._-]*$')
COMMIT_RE = re.compile(r'^[0-9a-f]{40}$')
SOURCE_RE = re.compile(
    r'^https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/?$')
NOTE_RE = re.compile(r'^[A-Za-z0-9 .,()/+-]*$')


def unsafe(value):
    return ".." in value or value.startswith("/") or not SAFE.fullmatch(value)


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
if tag and unsafe(tag):
    bad(f"tag={tag}")
if not isinstance(note, str) or not NOTE_RE.fullmatch(note):
    bad(f"license={note}")
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

# _vendor_tree_checkout <dir> <url> <sha> — shallow fetch of <sha> into a
# fresh repo at <dir>; rc 0 only when the checked-out HEAD is <sha>.
_vendor_tree_checkout() {
  local dir="$1" url="$2" sha="$3"
  git init -q "$dir" 2>/dev/null || return 1
  GIT_TERMINAL_PROMPT=0 git -C "$dir" fetch -q --depth 1 -- "$url" "$sha" \
    2>/dev/null || return 1
  git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD \
    2>/dev/null || return 1
  [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" = "$sha" ]
}

# _vendor_tree_index <dest_dir> — writes <dest_dir>/INDEX.md, one
# "- <id> | <category> | <H1 title>" line per guides/<category>/<id>.md.
_vendor_tree_index() {
  local dir="$1" f id category title
  [ -d "$dir/guides" ] || return 0
  {
    printf '# Guide index\n\nOne line per guide: `id | category | title`.'
    printf ' Read `guides/<category>/<id>.md`.\n\n'
    find "$dir/guides" -type f -name '*.md' | LC_ALL=C sort \
      | while IFS= read -r f; do
        id="$(basename "$f" .md)"
        category="$(basename "$(dirname "$f")")"
        title="$(grep -m1 '^# ' "$f" | sed 's/^# //')"
        printf -- '- %s | %s | %s\n' "$id" "$category" "${title:-$id}"
      done
  } > "$dir/INDEX.md"
}

# _vendor_tree_stage <src> <stage> <items> — copies every
# "<dest>\t<target>\t<path>" item from the checkout <src> into
# <stage>/<dest>/; rc 1 (err names the path) when a path is missing.
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
# <root>/<dest>, the previous copy parked under <stage>/.old-<dest>.
_vendor_tree_swap() {
  local root="$1" stage="$2" dest
  while IFS= read -r dest; do
    [ -n "$dest" ] || continue
    if [ -e "$root/$dest" ]; then
      mv "$root/$dest" "$stage/.old-$dest" || return 1
    fi
    mv "$stage/$dest" "$root/$dest" || return 1
  done <<<"$3"
}

# vendor_pinned_tree <lock-key> [refresh] — see the block comment above.
vendor_pinned_tree() {
  local key="$1" refresh="${2:-}" out root="$VENDOR_REPO/skills-external"
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
  if [ "$refresh" != "refresh" ] && _vendor_tree_current "$root" "$sha" "$dests"; then
    ok "$key already at pin ${sha:0:7}"
    return 0
  fi
  local tmp stage="$root/.vendor-stage.$$"
  tmp="$(mktemp -d)" || return 1
  mkdir -p "$stage" || { rm -rf "$tmp"; return 1; }
  if _vendor_tree_checkout "$tmp/src" "${base:-$source}" "$sha" \
    && _vendor_tree_stage "$tmp/src" "$stage" "$items" \
    && _vendor_tree_finish "$stage" "$dests" "$source" "$sha" "$tag" "$note" \
    && _vendor_tree_swap "$root" "$stage" "$dests"; then
    ok "$key vendored (pinned @ ${sha:0:7}): $(tr '\n' ' ' <<<"$dests")"
    rm -rf "$tmp" "$stage"
    return 0
  fi
  err "$key: fetch, stage or swap failed at ${sha:0:7} — see above; copies at the previous pin kept"
  rm -rf "$tmp" "$stage"
  return 1
}
```

Swap failure note: `_vendor_tree_swap` moves dests one by one; a failure after the first move leaves that dest updated and the others at the old pin (each dest self-consistent, `.vendored-commit` tells which). The error line says so; doctor reports the mismatch.

- [ ] **Step 4: Run the suite**

Run: `make test suite=lib/tests/vendor-tree.test.sh`
Expected: every line `PASS …`, `vendor-tree: 21 pass, 0 fail`, `all suites green`.
Then: `shellcheck lib/vendor-skills.sh lib/tests/vendor-tree.test.sh` → no output.
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
- Modify: `install-plugins.sh` Step 8e (≈ lines 913-940)
- Modify: `update-all.sh` 7.3 (≈ lines 369-383)
- Modify: `link.sh:78-81` (`EXTERNAL_SKILLS`)
- Modify: `.gitignore` (top flat-link block + a new vendored block)
- Modify: `lib/doctor-vendored.sh` (new `check_vendored_trees`), `doctor.sh:133`
- Test: `lib/tests/doctor-vendored.test.sh` (new cases)

**Interfaces:**
- Consumes: `vendor_pinned_tree <key> [refresh]` (Task 1).
- Produces: `check_vendored_trees <repo>` (doctor: pass/warn lines, never fail); lock key `modern-web-guidance`; dests `skills-external/mwg/`, `skills-external/chrome-extensions/`.

- [ ] **Step 1: Write the failing test** — append before the final summary of `lib/tests/doctor-vendored.test.sh` (reuse its `check`/`pass`/`fail` helpers; read the file first and follow its helper names exactly):

```bash
# ── check_vendored_trees: git-tree lock entries ──
TR="$(mktemp -d)"
mkdir -p "$TR/skills-external/at-pin" "$TR/skills-external/stale"
printf '%s\n' 1111111111111111111111111111111111111111 > "$TR/skills-external/at-pin/.vendored-commit"
printf '%s\n' 2222222222222222222222222222222222222222 > "$TR/skills-external/stale/.vendored-commit"
cat > "$TR/plugins.lock.json" <<'JSON'
{"t": {"managed_by": "git-tree", "commit": "1111111111111111111111111111111111111111",
       "trees": {"at-pin": {"x": "a"}, "stale": {"x": "a"}, "absent": {"x": "a"}}},
 "c": {"managed_by": "curl", "commit": "1111111111111111111111111111111111111111", "skills": ["s"]}}
JSON
out="$(source "$ROOT/lib/doctor-vendored.sh"; check_vendored_trees "$TR" 2>&1)"
printf '%s\n' "$out" | grep -q 't: at-pin at pin 1111111' && R1=1 || R1=0
printf '%s\n' "$out" | grep -q 't: skills-external/stale at 2222222, pin 1111111' && R2=1 || R2=0
printf '%s\n' "$out" | grep -q 't: skills-external/absent missing' && R3=1 || R3=0
printf '%s\n' "$out" | grep -q '✗' && R4=0 || R4=1
rm -rf "$TR"
```

Then, with the suite's own helper (`check_bool NAME 0|1`, lib/tests/doctor-vendored.test.sh:25):

```bash
check_bool TREES_AT_PIN "$R1"
check_bool TREES_STALE_WARN "$R2"
check_bool TREES_MISSING_WARN "$R3"
check_bool TREES_NEVER_FAIL "$R4"
```

The file ends with `echo "PASS=$pass FAIL=$fail"`; insert the block above that line.

- [ ] **Step 2: Run it to verify it fails**

Run: `make test suite=lib/tests/doctor-vendored.test.sh`
Expected: the four new checks FAIL (`check_vendored_trees: command not found`).

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
# skills-external/ with a .vendored-commit equal to its pin. Never fails:
# a missing or stale copy is a warn naming `make update`.
check_vendored_trees() {
  local repo="$1" key dest sha got
  while IFS=$'\t' read -r key dest sha; do
    [ -n "$key" ] || continue
    got="$(cat "$repo/skills-external/$dest/.vendored-commit" 2>/dev/null)"
    if [ -z "$got" ]; then
      warn "$key: skills-external/$dest missing — run: make update"
    elif [ "$got" != "$sha" ]; then
      warn "$key: skills-external/$dest at ${got:0:7}, pin ${sha:0:7} — run: make update"
    else
      pass "$key: $dest at pin ${sha:0:7}"
    fi
  done < <(_dv_tree_expectations "$repo/plugins.lock.json")
}
```

`doctor.sh` line 133, after `check_vendored_skills "$REPO" "$HOME/.claude"`:

```bash
check_vendored_trees "$REPO"
```

`plugins.lock.json`, new key (keep the file's existing key order; place it after `superpowers`):

```json
"modern-web-guidance": {
  "source": "https://github.com/GoogleChrome/modern-web-guidance",
  "commit": "64a6d708f5a43f2cd3fde5d4d7db3905ba1bdf65",
  "tag": "v1.0.1",
  "license": "Apache-2.0 (code), CC-BY 4.0 (guides)",
  "managed_by": "git-tree",
  "always_on": true,
  "trees": {
    "mwg": {"guides": "skills/modern-web-guidance/guides", "LICENSE": "LICENSE"},
    "chrome-extensions": {".": "skills/chrome-extensions"}
  },
  "note": "Google Modern Web Guidance (Chrome, Edge, Firefox, MDN). Guides read locally by skills/modern-web-guidance; the upstream SKILL.md (npx @latest) is never copied. chrome-extensions linked as is by link.sh. Bump commit + tag deliberately."
}
```

`install-plugins.sh` Step 8e: after `vendor_pinned_skills superpowers` add

```bash
vendor_pinned_tree modern-web-guidance
```

and add `chrome-extensions` at the end of the `EXT_SKILL_NAMES=(…)` array.

`update-all.sh` 7.3: after `vendor_pinned_skills superpowers refresh` add

```bash
echo ""
echo "── Updating Modern Web Guidance (GoogleChrome/modern-web-guidance)..."
vendor_pinned_tree modern-web-guidance refresh
```

`link.sh:81`: append `chrome-extensions` inside `EXTERNAL_SKILLS=(…)` (last element, before `)`).

`.gitignore`: in the top flat-link block add `skills/chrome-extensions`; after the superpowers block add

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
Expected: `all suites green`. Then `shellcheck lib/doctor-vendored.sh doctor.sh install-plugins.sh update-all.sh link.sh` → no new warning; `python3 -c "import json;json.load(open('plugins.lock.json'))"` → no output.

- [ ] **Step 5: Commit**

```bash
git add plugins.lock.json install-plugins.sh update-all.sh link.sh .gitignore lib/doctor-vendored.sh doctor.sh lib/tests/doctor-vendored.test.sh
git commit -m "feat(vendor): pin Modern Web Guidance v1.0.1 and chrome-extensions, doctor checks the pin"
```

---

### Task 3: Our `modern-web-guidance` skill + routing rows

**Files:**
- Create: `skills/modern-web-guidance/SKILL.md`, `skills/modern-web-guidance/test-prompts.json`
- Create (tracked symlinks): `skills/modern-web-guidance/guides`, `skills/modern-web-guidance/INDEX.md`, `skills/modern-web-guidance/NOTICE.md`
- Modify: `mods/model-router/routing.json` (`skills` object)
- Test: `lib/tests/mwg-skill.test.sh`

**Interfaces:**
- Consumes: `skills-external/mwg/{guides,INDEX.md,NOTICE.md}` (Task 1/2 layout).
- Produces: skill name `modern-web-guidance`; disclosure line format `Modern Web Guidance: <id>, <id>` / `Modern Web Guidance: checked <topics>, none applied`.

- [ ] **Step 1: Write the failing test** — `lib/tests/mwg-skill.test.sh`:

```bash
#!/usr/bin/env bash
# lib/tests/mwg-skill.test.sh — skills/modern-web-guidance: read-only
# tools, no npx or network command anywhere in a fenced block, the three
# relative links into skills-external/mwg, the disclosure format, and a
# routing.json row.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/skills/modern-web-guidance"
pass=0; fail=0
check() { if [ "$2" = 1 ]; then pass=$((pass+1)); echo "PASS $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }
check exists "$([ -f "$S/SKILL.md" ] && echo 1)"
check tools "$(grep -qx 'allowed-tools: Read, Grep, Glob' "$S/SKILL.md" && echo 1)"
check no-bash "$(grep -q '^allowed-tools:.*Bash' "$S/SKILL.md" || echo 1)"
fenced_npx="$(awk '/^```/{f=!f; next} f' "$S/SKILL.md" | grep -c 'npx\|pnpx\|curl\|wget')"
check no-fenced-network "$([ "$fenced_npx" -eq 0 ] && echo 1)"
check never-run "$(grep -q 'Never run npx' "$S/SKILL.md" && echo 1)"
check disclosure "$(grep -q '`Modern Web Guidance: <id>, <id>`' "$S/SKILL.md" && echo 1)"
for l in guides:../../skills-external/mwg/guides INDEX.md:../../skills-external/mwg/INDEX.md NOTICE.md:../../skills-external/mwg/NOTICE.md; do
  check "link-${l%%:*}" "$([ -L "$S/${l%%:*}" ] && [ "$(readlink "$S/${l%%:*}")" = "${l#*:}" ] && echo 1)"
done
check tracked-links "$([ "$(cd "$ROOT" && git ls-files skills/modern-web-guidance | grep -c 'guides$\|INDEX.md$\|NOTICE.md$')" -eq 3 ] && echo 1)"
row="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['skills'].get('modern-web-guidance',''))" "$ROOT/mods/model-router/routing.json")"
check routing-row "$([ "$row" = explore ] && echo 1)"
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
effort: medium
description: |
  Current web-platform practice from Google's Modern Web Guidance (Chrome,
  Edge, Firefox and MDN teams), read from a pinned local copy. Run it FIRST,
  before writing or changing front-end code: HTML, CSS, client-side JS, UI
  components in any framework. Covers dialogs, popovers, forms and
  validation, tables, dark mode, container queries, anchor positioning, view
  transitions, scroll-driven animation, Core Web Vitals (LCP, INP, CLS),
  images, passkeys, sanitization, web components, dates and time zones,
  built-in AI. Not for backend, infra, build tooling or tests.
allowed-tools: Read, Grep, Glob
---

# Modern Web Guidance (local, pinned)

The guides sit in this skill's folder: `INDEX.md` (one line per guide,
`id | category | title`) and `guides/<category>/<id>.md`. They are a copy
of GoogleChrome/modern-web-guidance pinned in `plugins.lock.json`
(`NOTICE.md` names the commit and the licenses). Nothing here touches the
network.

## Steps

1. Search: Grep `INDEX.md`, case-insensitive, for one capability at a
   time, in 1-3 words naming the UI pattern or platform feature
   (`dialog`, `popover`, `table`, `validation`, `view transition`, `LCP`).
   No hit: rephrase once with a synonym, then Grep the bodies under
   `guides/`. Nothing relevant: go on without a guide.
2. Read: open each matching guide, plus the discipline guide of the task
   when one exists (`html`, `css`, `forms`, `accessibility`, `performance`,
   `security`).
3. Cross-references: a guide line `npx -y modern-web-guidance@latest
   retrieve "<id>"` points at another guide. Glob `guides/*/<id>.md` and
   Read it instead. Never run npx, the guidance CLI or any network command
   for this skill.
4. Apply: follow the guide, its fallbacks and its Baseline notes, without
   adding features the task did not ask for. Where a guide and a rule of
   `rules/web-building.md` disagree on how to use the platform, the guide
   wins.
5. Disclose: end the answer that delivers the front-end change with one
   line, `Modern Web Guidance: <id>, <id>`. Guides checked and none
   applied: `Modern Web Guidance: checked <topics>, none applied`. No
   quotes.

## Missing copy

`INDEX.md` unreadable (the link dangles on a machine that never ran the
install): say once "Modern Web Guidance not installed, run `make update`"
and continue without it.
````

Symlinks (from the repo root):

```bash
ln -s ../../skills-external/mwg/guides skills/modern-web-guidance/guides
ln -s ../../skills-external/mwg/INDEX.md skills/modern-web-guidance/INDEX.md
ln -s ../../skills-external/mwg/NOTICE.md skills/modern-web-guidance/NOTICE.md
```

`skills/modern-web-guidance/test-prompts.json`:

```json
[
  {"id": 1, "prompt": "Add a confirmation modal before deleting an item", "expected": "Grep INDEX.md for dialog, Read the dialog guide (+ html/accessibility), build on <dialog> per the guide, end with `Modern Web Guidance: <ids>`"},
  {"id": 2, "prompt": "Make this table usable on mobile", "expected": "Search table/responsive, Read the matching guide, apply its pattern and fallback, disclosure line"},
  {"id": 3, "prompt": "Améliore le LCP de la page d'accueil", "expected": "FR trigger: search LCP, Read the performance guides, apply fetchpriority/image guidance, disclosure line"},
  {"id": 4, "prompt": "Write a SQL migration for the orders table", "expected": "Does not trigger: backend task"}
]
```

`mods/model-router/routing.json`, inside `"skills"`: add `"modern-web-guidance": "explore"` and `"chrome-extensions": "implement"` (keep the object's existing formatting; place them alphabetically if the object is sorted, else at the end).

- [ ] **Step 4: Run tests**

Run: `make test suite="lib/tests/mwg-skill.test.sh lib/tests/effort-routing.test.sh lib/tests/model-routing.test.sh lib/tests/pack-census.test.sh lib/tests/skill-routing-census.test.sh"`
Expected: `all suites green`. If `skill-routing-census` reports a pair ≥ 0.75 involving `modern-web-guidance`, reword the description's trigger list (keep the first sentence) and re-run; a WARN (≥ 0.50) is acceptable and is reported.

- [ ] **Step 5: Commit**

```bash
git add skills/modern-web-guidance mods/model-router/routing.json lib/tests/mwg-skill.test.sh
git commit -m "feat(skills): modern-web-guidance reads the pinned guides locally"
```

---

### Task 4: Wiring in `rules/web-building.md` and `site-motion`

**Files:**
- Modify: `rules/web-building.md` (after line 5 title; lines 27-29 motion; § Design work Build bullet ≈ line 52-57)
- Modify: `skills/pack-design/skills/site-motion/SKILL.md` (intro paragraph ≈ line 24-27)
- Test: `lib/tests/mwg-skill.test.sh` (append wiring checks)

**Interfaces:**
- Consumes: skill name `modern-web-guidance` (Task 3).

- [ ] **Step 1: Write the failing test** — append before the summary line of `lib/tests/mwg-skill.test.sh`:

```bash
W="$ROOT/rules/web-building.md"
check rule-section "$(grep -qx '## Modern Web Guidance first' "$W" && echo 1)"
check rule-before-design "$([ "$(grep -n '^## Modern Web Guidance first' "$W" | cut -d: -f1)" -lt "$(grep -n '^## Design work' "$W" | cut -d: -f1)" ] && echo 1)"
check rule-guide-wins "$(grep -q 'platform, the guide wins' "$W" && echo 1)"
check motion-line "$(grep -q '^- Motion: transform and opacity for continuous or scroll-linked motion,$' "$W" && echo 1)"
check motion-old-gone "$(grep -q 'transform and opacity only' "$W" || echo 1)"
check design-build "$(awk '/^## Design work/{p=1} /^## /&&!/Design work/{p=0} p' "$W" | grep -q 'consult `modern-web-guidance` first' && echo 1)"
check design-heading "$(grep -qx '## Design work — full toolchain (tiered by scope)' "$W" && echo 1)"
check locked-line "$(grep -qx '- The vendored stack members route to `reflect` (high) through their' "$W" && echo 1)"
check site-motion "$(grep -q '`modern-web-guidance`' "$ROOT/skills/pack-design/skills/site-motion/SKILL.md" && echo 1)"
```

- [ ] **Step 2: Run it to verify it fails** — `make test suite=lib/tests/mwg-skill.test.sh` → the new checks FAIL.

- [ ] **Step 3: Implement**

`rules/web-building.md`, insert after the line `# Web building — no default reflexes + done checklist` and its following blank line:

```markdown
## Modern Web Guidance first
Before writing or changing front-end code (markup, styles, client-side JS,
components), run the `modern-web-guidance` skill: it reads Google's pinned
guides locally. Where a guide and a line below disagree on how to use the
platform, the guide wins. End the answer with the skill's one-line
disclosure.

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
- Every Build step above (impeccable, ui-ux-pro-max, 21st, emil, motion,
  design-html, site-motion) must consult `modern-web-guidance` first for
  the platform features it uses.
```

`skills/pack-design/skills/site-motion/SKILL.md`: append to the intro paragraph ending `top of it.` a new paragraph:

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

### Task 5 (main loop, after the gates): live install and doctor

Not an executor task (network fetch on this machine, link refresh):

- `source lib/vendor-skills.sh && vendor_pinned_tree modern-web-guidance` → `modern-web-guidance vendored (pinned @ 64a6d70): chrome-extensions mwg`.
- `bash link.sh` → `chrome-extensions` linked.
- `ls skills/modern-web-guidance/INDEX.md` resolves; `grep -c '^- ' skills-external/mwg/INDEX.md` → 210.
- `make doctor` → no new error; `check_vendored_trees` passes both dests.
- Full `make test` (bun on PATH) → green.
