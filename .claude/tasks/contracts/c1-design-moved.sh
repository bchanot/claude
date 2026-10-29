#!/usr/bin/env bash
# GATE 0 oracle, contract context-diet c4: Design work moved verbatim to
# rules/web-building.md (last section), gone from CLAUDE.global.md, paths kept.
set -u
fail() { echo "$1"; exit 1; }
sec() { awk '/^## Design work — full toolchain/ { f = 1; print; next }
             f && /^#/ { exit } f'; }
old=$(git show 017a28b:CLAUDE.global.md | sec)
[ -n "$old" ] || fail "no source section at 017a28b"
grep -q '^## Design work' CLAUDE.global.md && fail "still in CLAUDE.global.md"
new=$(sec < rules/web-building.md)
[ "$old" = "$new" ] || { diff <(printf '%s\n' "$old") <(printf '%s\n' "$new"); fail "body differs"; }
tail_=$(awk '/^## Design work — full toolchain/ { f = 1 } f' rules/web-building.md)
[ "$tail_" = "$new" ] || fail "not the last section"
[ "$(git show 017a28b:rules/web-building.md | sed -n 2p)" = "$(sed -n 2p rules/web-building.md)" ] \
  || fail "paths changed"
echo DESIGN-MOVED
