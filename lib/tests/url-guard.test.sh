#!/usr/bin/env bash
# lib/tests/url-guard.test.sh
set -u
G="$(cd "$(dirname "$0")/../.." && pwd)/lib/url-guard.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
# rc of a guard call, output discarded
rc()  { bash "$G" "$1" "$2" >/dev/null 2>&1; return $?; }
# stdout of a guard call (empty on refusal)
out() { bash "$G" "$1" "$2" 2>/dev/null; }

# --- hosts that must pass, echoing back unchanged ---
rc host "example.com";            check H1-plain          "$?" 0
rc host "www.sub.example.co.uk";  check H2-subdomains     "$?" 0
rc host "my-site.fr";             check H3-hyphen         "$?" 0
check H4-echoes-input "$(out host example.com)" "example.com"

# --- shell metacharacters: the reason this guard exists ---
# Inside the double quotes seo-analyzer.md:257 uses, $ ` \ " break out.
rc host 'x$(id)';                            check H5-cmdsubst       "$?" 2
rc host 'x`id`';                             check H6-backtick       "$?" 2
rc host 'x;id';                              check H7-semicolon      "$?" 2
rc host 'x|id';                              check H8-pipe           "$?" 2
rc host 'x&id';                              check H9-ampersand      "$?" 2
rc host 'x"';                                check H10-dquote        "$?" 2
rc host "x'";                                check H11-squote        "$?" 2
rc host 'x\y';                               check H12-backslash     "$?" 2
rc host 'x y';                               check H13-space         "$?" 2
rc host 'a
b';                                          check H14-newline       "$?" 2
# the real payload: read the OAuth vault into a request
rc host 'x$(cat ${HOME}/.claude/.env)';      check H15-env-exfil     "$?" 2
check H16-refusal-is-silent "$(out host 'x$(id)')" ""

# --- literal local / private / metadata targets ---
rc host "localhost";        check L1-localhost        "$?" 2
rc host "LOCALHOST";        check L2-case-folded      "$?" 2
rc host "127.0.0.1";        check L3-loopback         "$?" 2
rc host "10.1.2.3";         check L4-private-10       "$?" 2
rc host "192.168.1.1";      check L5-private-192      "$?" 2
rc host "172.16.0.1";       check L6-private-172-lo   "$?" 2
rc host "172.31.255.254";   check L7-private-172-hi   "$?" 2
rc host "172.32.0.1";       check L8-172-32-is-public "$?" 0
rc host "169.254.169.254";  check L9-link-local       "$?" 2
rc host "metadata.google.internal"; check L10-gcp-metadata "$?" 2
rc host "0.0.0.0";          check L11-any-addr        "$?" 2
rc host "printer.local";    check L12-mdns            "$?" 2

# --- urls ---
rc url "https://example.com/";                    check U1-https        "$?" 0
rc url "http://example.com/a/b?x=1&y=2";          check U2-query        "$?" 0
rc url "https://example.com:8443/p";              check U3-port         "$?" 0
rc url "https://example.com/a%20b#frag";          check U4-pct-and-frag "$?" 0
check U5-echoes-input "$(out url https://example.com/x)" "https://example.com/x"
rc url "ftp://example.com/";                      check U6-ftp          "$?" 2
rc url "file:///etc/passwd";                      check U7-file         "$?" 2
rc url "gopher://example.com/";                   check U8-gopher       "$?" 2
rc url "example.com";                             check U9-no-scheme    "$?" 2
rc url 'https://example.com/$(id)';               check U10-cmdsubst    "$?" 2
rc url 'https://example.com/`id`';                check U11-backtick    "$?" 2
rc url "https://localhost/x";                     check U12-local       "$?" 2
rc url "https://127.0.0.1:8080/admin";            check U13-loopback    "$?" 2
# authority confusion: the real host is after the @, not before it
rc url "https://trusted.com@127.0.0.1/";          check U14-userinfo-local "$?" 2
rc url "https://trusted.com@evil.com/";           check U15-userinfo-any   "$?" 2

# --- usage ---
rc host "";                                    check X1-host-empty    "$?" 2
bash "$G" >/dev/null 2>&1;                     check X2-no-args       "$?" 2
bash "$G" bogus x >/dev/null 2>&1;             check X3-bad-verb      "$?" 2
bash "$G" host a b >/dev/null 2>&1;            check X4-extra-args    "$?" 2

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
