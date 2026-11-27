#!/usr/bin/env bash
# lib/tests/disk-clean-scan.test.sh — /disk-clean scanner on a fixture root.
# The scanner is read-only: every fixture file must survive the run.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/skills/disk-clean/scripts/scan.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
H="$tmp/home"

# Cargo project with a debug dir, one without, one nested under target/
mkdir -p "$H/p/rs/target/debug" "$H/p/clean" "$H/p/rs/target/x"
touch "$H/p/rs/Cargo.toml" "$H/p/clean/Cargo.toml" "$H/p/rs/target/x/Cargo.toml"
mkdir -p "$H/p/js/node_modules/a" "$H/.hidden/node_modules"
echo '{}' > "$H/p/js/package.json"
pw="$H/.cache/ms-playwright"
mkdir -p "$pw/chromium-1243" "$pw/chromium-1255" "$pw/ffmpeg-1011"
mkdir -p "$H/.cache/claude-tmp/tmp.old" "$H/.cache/claude-tmp/tmp.new"
touch -d '10 days ago' "$H/.cache/claude-tmp/tmp.old"

# Docker stub: fixed `system df` output, records any other verb.
cat > "$tmp/docker" <<EOF
#!/usr/bin/env bash
[ "\$1 \$2" = "system df" ] || echo "\$*" >> "$tmp/docker.calls"
printf 'Build Cache\t30GB\n'
EOF
chmod +x "$tmp/docker"

before=$(find "$H" | sort | md5sum)
out=$(DISK_CLEAN_DOCKER="$tmp/docker" bash "$S" "$H")

col() { printf '%s\n' "$out" | awk -F'\t' -v c="$1" '$1==c{print $4}'; }
check T1-cargo "$(col cargo)" "$H/p/rs"
check T2-node "$(col node_modules)" "$H/p/js/node_modules"
check T3-playwright "$(col playwright)" "$pw/chromium-1243"
check T4-tmp "$(printf '%s\n' "$out" | awk -F'\t' '$1=="claude_tmp"{print $5}')" \
  "1 tmp.* dirs older than 2d"
check T5-docker "$(col docker)" "Build Cache"
check T6-disk-header "$(printf '%s\n' "$out" | head -1 | cut -f1)" "#disk"
check T7-read-only "$(find "$H" | sort | md5sum)" "$before"
check T8-docker-verbs "$(cat "$tmp/docker.calls" 2>/dev/null)" ""
check T9-bad-root "$(bash "$S" "$tmp/nope" >/dev/null 2>&1; echo $?)" 2

echo "disk-clean-scan: $pass pass, $fail fail"
[ "$fail" -eq 0 ]
