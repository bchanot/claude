#!/usr/bin/env bash
# GATE 0 oracle, contract context-diet c9: architecture defaults in the lib,
# verbatim; one always-on line in CLAUDE.global.md; default-language.md gone.
set -u
fail() { echo "$1"; exit 1; }
L=lib/architecture-defaults.md
body() { awk -v h="$1" 'index($0, h) == 1 { f = 1; print; next } f && /^#/ { exit } f'; }
[ -f "$L" ] || fail "no $L"
[ -e rules/default-language.md ] && fail "rules/default-language.md still exists"
grep -q '^## Public websites' CLAUDE.global.md && fail "Public websites in CLAUDE.global.md"
grep -q '^## Web APIs' CLAUDE.global.md && fail "Web APIs in CLAUDE.global.md"
a=$(git show 017a28b:CLAUDE.global.md | body '## Public websites — never SPA')
b=$(body '## Public websites — never SPA' < "$L")
[ -n "$a" ] && [ "$a" = "$b" ] || fail "SPA section differs"
a=$(git show 017a28b:rules/default-language.md | sed '1s/^# /## /')
b=$(body '## Default language — Rust' < "$L")
[ -n "$a" ] && [ "$a" = "$b" ] || fail "language section differs"
grep -q 'rules/rest-api.md' "$L" || fail "no rest-api.md pointer in the lib"
line=$(awk '/^# Architecture decisions/ { f = 1; next } f && /^#/ { exit } f' CLAUDE.global.md \
  | tr '\n' ' ')
for w in 'Rust by default' 'never a SPA' '/api/v1/' '~/.claude/lib/architecture-defaults.md'; do
  case "$line" in *"$w"*) ;; *) fail "architecture line lacks: $w" ;; esac
done
echo ARCH-MOVED
