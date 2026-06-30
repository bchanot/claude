#!/usr/bin/env bash
# run-release-candidate.sh — TDD harness for /release-candidate.
#
# The skill is an ORCHESTRATOR over the existing gitflow release mechanic + the ONE
# piece the lib lacks: the version tag. This harness replays the skill's prescribed
# sequence on a throwaway repo (gitflow-test style) and asserts the release outcome.
#
# RED  (RC_TAG=0): run start→prep→finish only (the existing mechanic) → the tag
#                  assertion REDS, proving gitflow fans out main+develop but never tags.
# GREEN(RC_TAG=1): the skill's flow adds `git tag` → tag present on main's merge commit.
set -uo pipefail

GREP=/usr/bin/grep                                              # LRN-074: pin grep
LIBDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"       # repo lib/
GITFLOW="$LIBDIR/gitflow.sh"
RC_TAG="${RC_TAG:-0}"                                           # 0=RED (no tag), 1=GREEN
WORK="${RC_WORK:?set RC_WORK to a throwaway dir}"

pass=0; fail=0
ok(){ echo "GREEN ✓ $*"; pass=$((pass+1)); }
no(){ echo "RED   ✗ $*"; fail=$((fail+1)); }

# ── seed a throwaway repo: main (v3.5.0) + develop ahead ──────────────────────
rm -rf "$WORK"; mkdir -p "$WORK"
git -C "$WORK" init -q
git -C "$WORK" config user.email t@t; git -C "$WORK" config user.name T
printf '3.5.0\n' > "$WORK/version.txt"
printf '# Changelog\n\n## [Unreleased]\n\n### Added\n- new skill foo\n\n## [3.4.0] — 2026-04-15\n- prev\n' > "$WORK/CHANGELOG.md"
git -C "$WORK" add -A; git -C "$WORK" commit -qm "initial"
git -C "$WORK" branch -M main
git -C "$WORK" branch develop
git -C "$WORK" checkout -q develop
printf 'feature work\n' > "$WORK/feat.txt"; git -C "$WORK" add -A; git -C "$WORK" commit -qm "feat on develop"
echo "setup: develop +$(git -C "$WORK" rev-list --count main..develop) vs main, version.txt=$(cat "$WORK/version.txt"), tags=$(git -C "$WORK" tag | wc -l)"
echo

# ── the /release-candidate flow (what the skill prescribes) ──────────────────
( cd "$WORK" || exit 1
  bash "$GITFLOW" start release 4.0.0 >/dev/null            # base develop → release/4.0.0 (lib L49/L71)
  printf '4.0.0\n' > version.txt                            # prep: version bump
  sed -i 's/## \[Unreleased\]/## [Unreleased]\n\n## [4.0.0] — 2026-06-30/' CHANGELOG.md
  git commit -qam "chore(release): 4.0.0 — version.txt + CHANGELOG"
  bash "$GITFLOW" finish >/dev/null                         # fan-out main+develop+delete (lib L108-111)
  # TAG = the gap. Lives in the SKILL (lib untouched). RED skips it, GREEN does it.
  if [ "$RC_TAG" = "1" ]; then git tag -a v4.0.0 main -m "release 4.0.0"; fi
)

# ── assertions: fan-out (existing mechanic) + the tag (the new piece) ─────────
echo "=== assertions (RC_TAG=$RC_TAG) ==="
if [ "$(git -C "$WORK" show main:version.txt 2>/dev/null)" = "4.0.0" ]; then ok "fan-out: main carries the release (version.txt 4.0.0)"; else no "fan-out: main version.txt != 4.0.0"; fi
if [ "$(git -C "$WORK" show develop:version.txt 2>/dev/null)" = "4.0.0" ]; then ok "merge-back: develop carries 4.0.0"; else no "merge-back failed"; fi
if git -C "$WORK" show-ref --verify -q refs/heads/release/4.0.0; then no "release/4.0.0 NOT deleted"; else ok "release/4.0.0 branch deleted"; fi
if git -C "$WORK" show main:CHANGELOG.md | $GREP -q '## \[4.0.0\]'; then ok "CHANGELOG [4.0.0] on main"; else no "CHANGELOG not finalized"; fi
if git -C "$WORK" rev-parse -q --verify refs/tags/v4.0.0 >/dev/null; then
  if [ "$(git -C "$WORK" rev-list -n1 v4.0.0)" = "$(git -C "$WORK" rev-parse main)" ]; then ok "tag v4.0.0 on main's release-merge commit"; else no "tag v4.0.0 exists but not on main HEAD"; fi
else
  no "tag v4.0.0 ABSENT — gitflow finish fans out but does NOT tag (the gap /release-candidate fills)"
fi

echo; echo "================  $pass GREEN / $fail RED  (RC_TAG=$RC_TAG)  ================"
[ "$fail" -eq 0 ] && exit 0 || exit 1
