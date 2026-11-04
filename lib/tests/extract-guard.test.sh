#!/usr/bin/env bash
# lib/tests/extract-guard.test.sh
# hooks/extract-guard.sh: denies an extraction into / or a system dir,
# silent on everything else. Also locks the settings.json wiring (last).
# shellcheck disable=SC2016  # single-quoted forms are the commands under test
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
H="$ROOT/hooks/extract-guard.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

OUT=""; RC=0
run() { # run <cmd>
  OUT=$(jq -n --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' \
    | bash "$H" 2>/dev/null); RC=$?
}
decision() { printf '%s' "$OUT" \
  | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null; }
deny() { run "$1"; check "deny[$1]" "$RC $(decision)" "0 deny"; }
allow() { run "$1"; check "allow[$1]" "$RC [$OUT]" "0 []"; }

# ── deny ──
deny 'dpkg -x p.deb /'
deny 'dpkg-deb --extract p.deb /usr'
deny 'dpkg -x p.deb'
deny $'dpkg -x p.deb \\\n/'
deny 'tar -xzf a.tgz -C /usr'
deny 'tar -xf a.tar -C "/usr"'
deny 'tar -C /usr -xzf a.tgz'
deny 'tar -z -xvf a.tgz -C /'
deny 'tar xzf a.tgz -C/'
deny 'tar -xvC / -f a.tar'
deny 'tar -xf a.tar --directory=/etc'
deny 'tar -C /tmp/w -C / -xf a.tar'
deny $'tar -xzf a.tgz \\\n -C /usr'
deny 'cd / && tar xf a.tar'
deny 'cd / && cd usr && tar xf a.tar'
deny 'pushd /usr && unzip a.zip'
deny "unzip a.zip -d '/opt'"
deny 'unzip -od /usr a.zip'
deny 'cpio -idm -D /usr < a.cpio'
deny 'cd / && cpio -vidm < a.cpio'
deny 'cp -r build /opt/app'
deny 'cp -r build /opt/app 2>/dev/null'
deny 'cp -rt /usr/lib src'
deny 'cp -a src "/usr/local/x"'
deny 'find dist -exec cp -r {} /var/www/html \;'
deny "ssh vm 'dpkg -x p.deb /'"
deny "ssh -i k -p 2222 root@vm 'tar -xf /tmp/a.tar -C /'"
deny 'vaas-cli ssh vm -- tar -xzf a.tgz -C /usr'
deny "vaas-cli ssh vm 'dpkg -x /tmp/p.deb /'"
deny $'vaas-cli ssh vm "\nset -e\ncd /\ntar xf /tmp/a.tar\n"'
deny 'bash -c "cd /usr/lib && unzip a.zip"'
deny "sudo sh -c 'cd / && tar xzf /tmp/a.tgz'"
deny "timeout 600 vaas-cli ssh vm 'dpkg -x p.deb /'"
deny $'ssh vm bash -s <<\'EOF\' 2>&1 | tail -5\ntar -xf a.tar -C /\nEOF'
deny $'cat <<< "$x"\ntar -xf a.tar -C /'
deny 'tar -xf $(ls *.tar) -C /'
deny 'tar -xf `ls *.tar` -C /usr'
deny 'out="$(vaas-cli ssh vm '"'dpkg -x /tmp/p.deb /'"')"'
deny 'tar -xf a.tar -C "$DEST"'
deny 'tar -xf a.tar -C ~/../../usr'
deny 'stdbuf -oL tar -xf a.tar -C /'
deny 'busybox tar -xf a.tar -C /'
deny 'for f in *.deb; do dpkg -x $f /; done'
deny 'cd "$work" && tar xf a.tar'
deny "bash -c \"ssh vm 'sh -c \\\"bash -c \\\\\\\"tar xf a -C /\\\\\\\"\\\"'\""

# two violations: exactly one JSON object
run 'dpkg -x a.deb / ; tar -xf a.tar -C /usr'
check two-violations "$(printf '%s' "$OUT" | jq -s length)" 1

# ── allow ──
allow 'tar -C /tmp/x -xf a.tar'
allow 'tar -cf /tmp/a.tar /usr'
allow 'tar tf a.tar'
allow 'tar -tvf a.tar -C /'
allow 'tar -xf a.tar'
allow 'tar -xf a.tar -C ~/x'
allow 'tar -xf a.tar -C "$HOME/x"'
allow 'tar -xf a.tar -C /var/folders/ab/T/tmp.X'
allow 'tar -xf a.tar -C /var/tmp/w'
allow 'dpkg -c p.deb'
allow 'dpkg -R -i debs/'
allow 'unzip -l a.zip'
allow 'unzip -Z1 a.zip'
allow 'cpio -itv < a.cpio'
allow 'unzip a.zip -d build'
allow 'cp a.txt /etc/hosts'
allow 'cp -r src dist'
allow 'cp --parents a /tmp/x'
allow 'cp -r a b > /dev/null'
allow 'grep -rn "dpkg -x" docs'
allow 'echo "tar xf a"'
allow "vaas-cli ssh vm 'tar -xf a.tar -C /tmp/w'"
allow "vaas-cli ssh vm 'unzip a.zip -d build'"
allow "vaas-cli ssh vm 'command -v unzip || sudo apt-get install -y unzip'"
allow 'sudo apt install tar xz-utils'
allow 'git commit -m "doc: list an archive with tar tf before extracting"'
allow 'bash ~/.claude/lib/memory.sh add learning --title "dpkg -x into a system dir breaks usr-merge" --body-file /tmp/b'

# quiet corpus: ordinary commands, silent rc 0
while IFS= read -r c; do allow "$c"; done <<'EOF'
ls -la /usr/lib | grep tar
jq -r '.a[] | select(.x > 1)' f.json
awk '{ print $1 }' data.txt
echo "a" "b"
git status --short
git log --oneline -n 5
cat /etc/hosts
grep -rn "cp" src
make test suite=memory
npm run build && npm test
sed -n '1,20p' README.md
find . -name '*.sh' -exec shellcheck {} +
curl -sS https://example.org/x -o /tmp/x.json
mkdir -p /tmp/w && cd /tmp/w && ls
python3 -I -c 'print(1)'
docker ps --format '{{.Names}}'
ssh vm 'uname -a'
rsync -n a/ b/
cp a.txt b.txt
git commit -m "$(printf 'fix: a\n\nbody')"
EOF
run $'git commit -m "$(cat <<\'EOF\'\nfeat: x\n\nbody about archives\nEOF\n)"'
check quiet-heredoc-commit "$RC [$OUT]" "0 []"

# ── timed flood cases ──
flood=$(awk 'BEGIN { for (i = 1; i <= 5001; i++) print "echo " i; print "tar xf a" }')
SECONDS=0; run "$flood"; el=$SECONDS
check flood-5001-deny "$RC $(decision)" "0 deny"
check flood-5001-fast "$([ "$el" -le 2 ] && echo ok || echo "slow ${el}s")" ok
plain=$(awk 'BEGIN { for (i = 1; i <= 5000; i++) print "echo line " i }')
SECONDS=0; run "$plain"; el=$SECONDS
check plain-5000-allow "$RC [$OUT]" "0 []"
check plain-5000-fast "$([ "$el" -le 1 ] && echo ok || echo "slow ${el}s")" ok
many=$(awk "BEGIN { for (i = 1; i <= 299; i++) print \"bash -c 'cp -r a b'\" }")
SECONDS=0; run "$many"; el=$SECONDS
check rescan-299-allow "$RC [$OUT]" "0 []"
check rescan-299-fast "$([ "$el" -le 3 ] && echo ok || echo "slow ${el}s")" ok
over=$(awk "BEGIN { for (i = 1; i <= 301; i++) print \"bash -c 'cp -r a b'\" }")
run "$over"; check rescan-301-deny "$RC $(decision)" "0 deny"
deep="bash -c \"bash -c 'bash -c \\\"bash -c \\\\\\\"tar xf a\\\\\\\"\\\"'\""
run "$deep"; check nesting-deny "$RC $(decision)" "0 deny"

# ── plumbing ──
BASH_BIN=$(command -v bash)
mkdir -p "$WORK/shim"
for t in awk grep head; do ln -s "$(command -v "$t")" "$WORK/shim/$t"; done
err=$(printf '%s' '{"tool_input":{"command":"tar xf a -C /"}}' \
  | PATH="$WORK/shim" "$BASH_BIN" "$H" 2>&1 >"$WORK/o"); rc=$?
check nojq "$rc [$(cat "$WORK/o")] [$err]" \
  "0 [] [extract-guard: jq missing, guard inactive]"
run 'tar xf a -C /'
check deny-json-shape "$(printf '%s' "$OUT" | jq -r \
  '.hookSpecificOutput | .hookEventName + " " + .permissionDecision')" \
  "PreToolUse deny"
check deny-reason-names-rule "$(printf '%s' "$OUT" \
  | jq -r '.hookSpecificOutput.permissionDecisionReason' \
  | grep -c 'Destructive tools & data loss')" 1
out=$(printf 'not json' | bash "$H" 2>/dev/null); check badjson "$? [$out]" "0 []"
out=$(printf '{}' | bash "$H" 2>/dev/null); check nocmd "$? [$out]" "0 []"

# ── wiring (last): settings.json carries the entry and the soft_deny line ──
S="$ROOT/settings.json"
check wiring-entry "$(jq -e '.hooks.PreToolUse[]
  | select(any(.hooks[]; .command=="bash ~/.claude/hooks/extract-guard.sh"))
  | .matcher=="Bash|Monitor" and .hooks[0].timeout==10' "$S" 2>&1)" true
check wiring-soft-deny "$(jq -r '[.autoMode.soft_deny[]
  | select(startswith("Extracting, unpacking or recursively copying"))]
  | length' "$S")" 1

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
