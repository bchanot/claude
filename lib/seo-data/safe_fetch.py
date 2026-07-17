#!/usr/bin/env python3
"""SSRF- and DNS-rebinding-safe HTTP(S) fetch. Stdlib only.

The verbs that fetch remote content (sitemap, linkgraph, render_check, drift)
all route through sitemap._fetch, which used urllib.request.urlopen. urlopen
resolves the host, then connects — two DNS lookups with a window between them.
A hostile authority can answer PUBLIC to the validation lookup and a PRIVATE
address (169.254.169.254 cloud metadata, 127.0.0.1, the LAN) to the connect
lookup. That is DNS rebinding, and a name-level guard cannot see it.

This collapses the two lookups into one: resolve ONCE, validate every returned
IP, then connect to the exact validated IP while preserving the Host header,
TLS SNI, and certificate validation for the real hostname. There is no second
resolution to poison.

Better than the reference implementation this idea came from (claude-seo
url_safety.py, MIT) on three axes, all verified before writing:
- dual-stack: validates IPv4 AND IPv6 (theirs is IPv4-only);
- no global state: each connection pins its own socket, so it is thread-safe
  by construction (theirs monkeypatches socket.getaddrinfo behind a global
  lock);
- stdlib only: http.client + ssl + ipaddress, no `requests`.

NOT covered, stated rather than left silent: the shell `curl` calls in the
agent specs (seo-analyzer/geo-analyzer STEP 4, the sameAs loop) run in a
separate process and cannot be pinned from here. Their surface is smaller
(a fixed set against an operator-typed/confirmed $DOMAIN). Closing them needs
`curl --resolve` and is a separate change.
"""
import gzip
import http.client
import ipaddress
import socket
import ssl
from urllib.parse import urljoin, urlparse

DEFAULT_TIMEOUT = 20
DEFAULT_MAX_BYTES = 20 * 1024 * 1024
MAX_REDIRECTS = 5


class UnsafeTarget(Exception):
    """A URL resolved to a non-public address, or a redirect did. Raised BEFORE
    any connection to that address. Callers already wrap _fetch in try/except
    and degrade, so the fail-open contract is preserved."""


# Special-use ranges that `is_global` reports as public but are not legitimate
# fetch targets. 192.88.99.0/24 = RFC 3068 6to4-relay anycast (a security
# review flagged it 2026-07-17). Grows if more surface.
_EXTRA_DENY = (ipaddress.ip_network("192.88.99.0/24"),)


def _ip_is_public(ip_str):
    """A globally routable unicast address, dual-stack. `is_global` is the
    decisive gate — it alone rejects CGNAT (100.64/10) that the per-flag checks
    miss — with the explicit flags plus an extra special-use deny list as
    defence in depth."""
    ip = ipaddress.ip_address(ip_str)
    if not ip.is_global:
        return False
    if any(ip in net for net in _EXTRA_DENY):
        return False
    return not (ip.is_private or ip.is_loopback or ip.is_link_local
                or ip.is_reserved or ip.is_multicast or ip.is_unspecified)


def _resolve_pinned(host, port, resolver=socket.getaddrinfo):
    """Resolve host ONCE and return [(family, ip)] for connecting. Refuse if
    ANY resolved address is non-public — a name advertising both public and
    private A records is exactly the multi-answer rebinding vector, and a
    legitimate public site does not do it. `resolver` is injected in tests to
    plant a private address and prove the refusal."""
    try:
        infos = resolver(host, port, type=socket.SOCK_STREAM)
    except socket.gaierror as e:
        raise UnsafeTarget("cannot resolve %r: %s" % (host, e))
    pinned = []
    for family, _type, _proto, _canon, sockaddr in infos:
        ip = sockaddr[0]
        if not _ip_is_public(ip):
            raise UnsafeTarget("%s resolves to non-public %s" % (host, ip))
        pinned.append((family, ip))
    if not pinned:
        raise UnsafeTarget("%s resolved to nothing" % host)
    return pinned


class _PinnedHTTPSConnection(http.client.HTTPSConnection):
    """HTTPS to a pinned IP, with SNI + cert validation for the real host."""
    def __init__(self, host, pinned_ip, family, **kw):
        super().__init__(host, **kw)          # host → Host header + SNI
        self._pinned_ip = pinned_ip
        self._family = family

    def connect(self):
        sock = socket.create_connection((self._pinned_ip, self.port),
                                        timeout=self.timeout)
        # server_hostname = the real host → SNI + hostname check both use it,
        # never the IP.
        self.sock = self._context.wrap_socket(sock, server_hostname=self.host)


class _PinnedHTTPConnection(http.client.HTTPConnection):
    """Plain HTTP to a pinned IP (Host header stays the real host)."""
    def __init__(self, host, pinned_ip, family, **kw):
        super().__init__(host, **kw)
        self._pinned_ip = pinned_ip
        self._family = family

    def connect(self):
        self.sock = socket.create_connection((self._pinned_ip, self.port),
                                             timeout=self.timeout)


def _one_request(url, timeout, max_bytes, resolver):
    """One hop: resolve+pin the host, connect, return (status, headers, body)."""
    p = urlparse(url)
    if p.scheme not in ("http", "https"):
        raise UnsafeTarget("scheme must be http/https: %r" % url)
    host = p.hostname
    if not host:
        raise UnsafeTarget("no host in %r" % url)
    port = p.port or (443 if p.scheme == "https" else 80)
    family, ip = _resolve_pinned(host, port, resolver)[0]   # any is public here
    ctx = ssl.create_default_context() if p.scheme == "https" else None
    if p.scheme == "https":
        conn = _PinnedHTTPSConnection(host, ip, family, port=port,
                                      timeout=timeout, context=ctx)
    else:
        conn = _PinnedHTTPConnection(host, ip, family, port=port,
                                     timeout=timeout)
    try:
        path = p.path or "/"
        if p.query:
            path += "?" + p.query
        # No Accept-Encoding: keep HTTP bodies un-gzipped; the .xml.gz
        # content-level case is handled by the caller's magic-byte check.
        conn.request("GET", path, headers={"Host": host,
                                           "User-Agent": "claude-seo-data/1.0"})
        r = conn.getresponse()
        body = r.read(max_bytes)
        return r.status, {k.lower(): v for k, v in r.getheaders()}, body
    finally:
        conn.close()


def safe_fetch(url, timeout=DEFAULT_TIMEOUT, max_bytes=DEFAULT_MAX_BYTES,
               max_redirects=MAX_REDIRECTS, resolver=socket.getaddrinfo):
    """Fetch url with resolve-then-pin, following redirects and RE-VALIDATING
    each hop — urlopen followed redirects to whatever address the Location
    named, re-opening the rebinding window on every hop. Returns the raw body
    bytes (the caller handles content-level gzip)."""
    seen = 0
    current = url
    while True:
        status, headers, body = _one_request(current, timeout, max_bytes, resolver)
        if status in (301, 302, 303, 307, 308) and "location" in headers:
            seen += 1
            if seen > max_redirects:
                raise UnsafeTarget("too many redirects from %r" % url)
            current = urljoin(current, headers["location"])   # re-validated next loop
            continue
        return body
