#!/usr/bin/env bash
# lib/tests/pack-census.test.sh — lib/pack-census.sh: pack layout (manifest
# name = folder, entries resolve, no skill twice, retired gstack names absent),
# fragment invariants (same key set, fixed values, full = manifest
# defaults), old-layout citers. Fixture cases, then the hermetic part of the
# census on the real repo (dangling targets are WARN without --installed).
set -u
unset CLAUDE_PROFILE CLAUDE_PROFILE_SETTINGS
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
check_has() { case "$2" in *"$3"*) pass=$((pass+1));; *) fail=$((fail+1));
  printf 'FAIL %s: [%s] does not contain [%s]\n' "$1" "$2" "$3";; esac; }

FX="$(mktemp -d)"; trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/lib/profiles" "$FX/hooks" "$FX/skills/core-a"; touch "$FX/skills/core-a/SKILL.md"
printf 'gs-dead\n' > "$FX/lib/gstack-removed.list"
mk_pack() { # name defaultEnabled skill...
  local n="$1" d="$2"; shift 2
  mkdir -p "$FX/skills/pack-$n/.claude-plugin" "$FX/skills/pack-$n/skills"
  printf '{"name":"pack-%s","version":"1.0.0","defaultEnabled":%s}\n' "$n" "$d" \
    > "$FX/skills/pack-$n/.claude-plugin/plugin.json"
  for s in "$@"; do mkdir -p "$FX/skills-external/$s"; touch "$FX/skills-external/$s/SKILL.md"
    ln -s "../../../skills-external/$s" "$FX/skills/pack-$n/skills/$s"; done
}
mk_pack alpha true a1 a2
mk_pack beta false b1
frag() { # name alpha beta
  printf '{"enabledPlugins": {"model-router@skills-dir": true, "pack-alpha@skills-dir": %s, "pack-beta@skills-dir": %s, "security-guidance@claude-code-plugins": true, "example-skills@anthropic-agent-skills": false, "brightdata-plugin@synced": false}}\n' \
    "$2" "$3" > "$FX/lib/profiles/$1.json"; }
frag full true false; frag dev false false
census() { bash "$ROOT/lib/pack-census.sh" --repo "$FX" "$@" 2>&1; }

out="$(census)"; rc=$?
check T1-green-rc "$rc" 0; check_has T1-green "$out" "PACKS OK 2 packs 3 skills"

rm -r "$FX/skills-external/b1"
out="$(census)"; rc=$?
check T2-off-dangling-rc "$rc" 0; check_has T2-off-dangling "$out" "WARN pack-beta: b1 target missing"
rm -r "$FX/skills-external/a2"
out="$(census)"; rc=$?
check T3-on-dangling-test-rc "$rc" 0; check_has T3-on-dangling-test "$out" "WARN pack-alpha: a2 target missing"
out="$(census --installed)"; rc=$?
check T3-on-dangling-doctor-rc "$rc" 1; check_has T3-on-dangling-doctor "$out" "RED pack-alpha: a2 target missing (pack ON)"
mkdir -p "$FX/skills-external/a2" "$FX/skills-external/b1"; touch "$FX/skills-external/a2/SKILL.md" "$FX/skills-external/b1/SKILL.md"

sed -i.bak 's/"pack-alpha"/"pack-alpho"/' "$FX/skills/pack-alpha/.claude-plugin/plugin.json"
out="$(census)"; rc=$?
check T4-name-rc "$rc" 1; check_has T4-name "$out" "RED pack-alpha: manifest name is pack-alpho"
mv "$FX/skills/pack-alpha/.claude-plugin/plugin.json.bak" "$FX/skills/pack-alpha/.claude-plugin/plugin.json"

ln -s ../skills-external/a1 "$FX/skills/a1"
out="$(census)"; rc=$?
check T5-dup-rc "$rc" 1; check_has T5-dup "$out" "RED a1 listed twice: skills/a1 and pack-alpha; run: rm skills/a1 (a flat link)"
rm "$FX/skills/a1"
mkdir "$FX/skills/a1"; touch "$FX/skills/a1/SKILL.md"
out="$(census)"
check_has T5-dup-real "$out" "run: mv skills/a1 skills-external/a1 (a real dir)"
rm -r "$FX/skills/a1"

ln -s "../../../skills-external/a1" "$FX/skills/pack-alpha/skills/gs-dead"
out="$(census)"; rc=$?
check T6-retired-rc "$rc" 1; check_has T6-retired "$out" "RED pack-alpha: gs-dead is a retired gstack skill"
rm "$FX/skills/pack-alpha/skills/gs-dead"
mv "$FX/lib/gstack-removed.list" "$FX/lib/gstack-removed.list.off"
out="$(census)"; rc=$?
check T6-nolist-rc "$rc" 1; check_has T6-nolist "$out" "RED lib/gstack-removed.list missing"
mv "$FX/lib/gstack-removed.list.off" "$FX/lib/gstack-removed.list"

printf 'Read ~/.claude/skills/a1/SKILL.md\n' > "$FX/hooks/x.sh"
cp "$ROOT/lib/tests/fixtures/pack-census-old-citers.sh" "$FX/hooks/y.sh"   # the old-layout terms live in a fixture, not in this file (the census scans lib/tests/)
out="$(census)"; rc=$?
check T7-citer-rc "$rc" 1
check_has T7-citer-tilde "$out" "RED hooks/x.sh cites ~/.claude/skills/a1"
check_has T7-citer-home "$out" "RED hooks/y.sh cites \$HOME/.claude/skills/a2"
check_has T7-citer-disabled "$out" "RED hooks/y.sh cites skills-disable""d/"
check_has T7-citer-toggle "$out" "RED hooks/y.sh cites toggle-externa""l"
check_has T7-citer-active "$out" "RED hooks/y.sh cites .active-profil""e"
check_has T7-citer-profile "$out" "RED hooks/y.sh cites lib/profiles/web.profil""e"
rm "$FX/hooks/x.sh" "$FX/hooks/y.sh"

# fragment invariants
printf '{"enabledPlugins": {"model-router@skills-dir": true, "pack-alpha@skills-dir": true}}\n' > "$FX/lib/profiles/short.json"
out="$(census)"; rc=$?
check T8-keyset-rc "$rc" 1; check_has T8-keyset "$out" "RED lib/profiles/short.json: key set differs from full.json"
rm "$FX/lib/profiles/short.json"
frag full true true
out="$(census)"; rc=$?
check T9-full-defaults-rc "$rc" 1; check_has T9-full-defaults "$out" "RED lib/profiles/full.json: pack-beta@skills-dir is true but the manifest default is false"
frag full true false
sed -i.bak 's/"security-guidance@claude-code-plugins": true/"security-guidance@claude-code-plugins": false/' "$FX/lib/profiles/dev.json"
out="$(census)"; rc=$?
check T10-fixed-rc "$rc" 1; check_has T10-fixed "$out" "RED lib/profiles/dev.json: security-guidance@claude-code-plugins must be true"
mv "$FX/lib/profiles/dev.json.bak" "$FX/lib/profiles/dev.json"

# identical fragments; a pack id with no manifest (WARN, not RED)
cp "$FX/lib/profiles/dev.json" "$FX/lib/profiles/zdev.json"
out="$(census)"; rc=$?
check T13-same-rc "$rc" 1
check_has T13-same "$out" "RED lib/profiles/dev.json and zdev.json are identical fragments"
rm "$FX/lib/profiles/zdev.json"
jq '. + {deniedMcpServers: [{serverName: "claude.ai Fictional"}]}' "$FX/lib/profiles/dev.json" > "$FX/lib/profiles/zdev.json"
out="$(census)"
check T13-deny-differs "$(grep -c 'zdev.json are identical fragments' <<<"$out")" 0
rm "$FX/lib/profiles/zdev.json"
sed 's/pack-beta@skills-dir": false/pack-beta@skills-dir": false, "pack-ghost@skills-dir": false/' "$FX/lib/profiles/dev.json" > "$FX/lib/profiles/ghost.json"
out="$(census)"; rc=$?
check_has T14-ghost "$out" "WARN lib/profiles/ghost.json: names pack-ghost with no skills/pack-ghost/"
rm "$FX/lib/profiles/ghost.json"

# real repo, hermetic part
out="$(bash "$ROOT/lib/pack-census.sh" 2>&1)"; rc=$?
check T11-real-rc "$rc" 0; check_has T11-real "$out" "PACKS OK 9 packs 55 skills"
check T12-shellcheck "$(shellcheck "$ROOT/lib/pack-census.sh" >/dev/null 2>&1 && echo ok)" ok
check T12-width "$(LC_ALL=C awk 'length($0) > 80' "$ROOT/lib/pack-census.sh" | wc -l | tr -d ' ')" 0
printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
