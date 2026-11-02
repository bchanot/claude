#!/usr/bin/env bash
# lib/tests/statusline.test.sh — hooks/statusline.sh profile segment comes
# from `profile.sh -C <project_dir> current --plain`; a --settings
# conversation shows "(conv)"; profile.sh failing or missing prints
# "profile: ?" and never breaks the line.
set -u
unset CLAUDE_PROFILE CLAUDE_PROFILE_SETTINGS
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check_has() { case "$2" in *"$3"*) pass=$((pass+1));; *) fail=$((fail+1));
  printf 'FAIL %s: [%s] does not contain [%s]\n' "$1" "$2" "$3";; esac; }
FX="$(mktemp -d)"; trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/hooks" "$FX/lib" "$FX/proj" "$FX/cwd"
cp "$ROOT/hooks/statusline.sh" "$FX/hooks/"
printf '{"effortLevel": "high"}\n' > "$FX/settings.json"
cat > "$FX/lib/profile.sh" <<'PROF'
#!/usr/bin/env bash
[ "$2" = "$FAKE_DIR" ] || { echo "wrong -C: $2" >&2; exit 2; }
printf 'profile=%s\nsource=%s\n' "$FAKE_PROFILE" "$FAKE_SOURCE"
PROF
# The project dir differs from the cwd: the segment must follow project_dir.
sl() { printf '{"cwd": "%s", "workspace": {"project_dir": "%s"}}\n' \
  "$FX/cwd" "$FX/proj" | FAKE_DIR="$FX/proj" bash "$FX/hooks/statusline.sh"; }
out="$(FAKE_PROFILE=web FAKE_SOURCE=local sl)"; check_has T1-local "$out" "profile: web |"
out="$(FAKE_PROFILE=dev FAKE_SOURCE=flag sl)"; check_has T2-conv "$out" "profile: dev (conv) |"
out="$(FAKE_PROFILE=full FAKE_SOURCE=default sl)"; check_has T3-default "$out" "profile: full |"
printf 'exit 2\n' > "$FX/lib/profile.sh"
out="$(sl 2>&1)"; check_has T4-failing "$out" "profile: ? |"
rm "$FX/lib/profile.sh"; out="$(sl 2>&1)"; check_has T5-missing "$out" "profile: ? |"
printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
