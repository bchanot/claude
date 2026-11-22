#!/usr/bin/env bash
# lib/tests/vendor-tree.test.sh — lib/vendor-skills.sh vendor_pinned_tree():
# pinned git fetch from a file:// fixture repo, allowlisted copy, INDEX
# (README description, else H1) / NOTICE / .vendored-commit generation,
# upstream SKILL.md never copied, skip at the pin, a pin bump prunes a
# guide dropped upstream, an absent copy is installed, a commit not
# upstream is refused with nothing written, unsafe lock paths rejected
# before any fetch, an allowlist edit at the same commit re-fetched, a
# dest owned by someone else never replaced, a symlink in the fetched
# content or a listed path leaving the checkout refused.
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

# T12 an allowlist edit at the same commit is applied (README dropped:
# the dialog line falls back to its H1), then restored.
sed 's/, "README.md": "README.md"//' "$REPO/plugins.lock.json" > "$WORK/lock"
cp "$WORK/lock" "$REPO/plugins.lock.json"; run mwg-key; rc=$?
check_bool T12-spec-refetch "$([ $rc -eq 0 ] && [ ! -e "$M/README.md" ] && grep -qx -- '- dialog | html | Dialog' "$M/INDEX.md" && echo 1)"
write_lock "$SHA2"; run mwg-key; rc=$?
check_bool T12-spec-restored "$([ $rc -eq 0 ] && [ -f "$M/README.md" ] && grep -q 'README.md' "$M/.vendored-spec" && echo 1)"

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

# T13 a listed path that resolves outside the checkout is refused.
g rm -q skills/chrome-extensions/references/link.md
mkdir -p "$WORK/outside"; printf 'x\n' > "$WORK/outside/f"
ln -s "$WORK/outside" "$UP/skills/escape"; g add -A; g commit -qm four
SHA4="$(git -C "$UP" rev-parse HEAD)"
write_lock "$SHA4" ', "esc": {".": "skills/escape"}'; run mwg-key; rc=$?
check_bool T13-escape "$([ $rc -eq 1 ] && grep -q 'leaves the checkout' "$WORK/out" && [ ! -e "$REPO/skills-external/esc" ] && echo 1)"

echo "vendor-tree: $pass pass, $fail fail"
[ "$fail" -eq 0 ]
