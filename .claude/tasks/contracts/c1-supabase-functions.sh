#!/usr/bin/env bash
# GATE 0 oracle, contract context-diet c12: Supabase / cloud-functions bodies
# moved verbatim to path rules; secure-by-default keeps one bullet each and
# every other section byte-identical to 017a28b.
set -u
fail() { echo "$1"; exit 1; }
S=rules/secure-by-default.md
sect() { awk -v h="$1" '$0 == h { f = 1; next } f && /^## / { exit } f && NF'; }
bullets() { awk '/^- / { f = 1 } f && NF' "$1"; }
for r in supabase cloud-functions; do [ -f "rules/$r.md" ] || fail "no rules/$r.md"; done
[ "$(sed -n 2p rules/supabase.md)" = 'paths: ["**/supabase/**", "**/*supabase*.*"]' ] \
  || fail "supabase.md paths"
[ "$(sed -n 2p rules/cloud-functions.md)" = 'paths: ["**/functions/**", "**/serverless.*", "**/firebase.json"]' ] \
  || fail "cloud-functions.md paths"
[ "$(git show "017a28b:$S" | sect '## 4. Supabase')" = "$(bullets rules/supabase.md)" ] \
  || fail "supabase bullets differ"
[ "$(git show "017a28b:$S" | sect '## 6. Cloud functions')" = "$(bullets rules/cloud-functions.md)" ] \
  || fail "cloud-functions bullets differ"
one() { # one <heading> <word>… → the section holds one bullet carrying every word
  local t; t=$(sect "$1" < "$S"); shift
  [ "$(printf '%s\n' "$t" | grep -c '^- ')" = 1 ] || return 1
  t=$(printf '%s' "$t" | tr '\n' ' ')
  for w in "$@"; do case "$t" in *"$w"*) ;; *) return 1 ;; esac; done
}
one '## 4. Supabase' RLS service_role rules/supabase.md || fail "§4 line"
one '## 6. Cloud functions' 'Max instances' self-trigger rules/cloud-functions.md || fail "§6 line"
strip() { awk '/^## / { skip = ($0 == "## 4. Supabase" || $0 == "## 6. Cloud functions"); print; next } !skip'; }
[ "$(git show "017a28b:$S" | strip)" = "$(strip < "$S")" ] || fail "other sections changed"
echo SB-CF-MOVED
