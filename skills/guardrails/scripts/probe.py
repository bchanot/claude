#!/usr/bin/env python3
"""Live guardrails probe: observe a running target from outside, read-only.

The static scan shows a protection is absent in the code. This observes what
a running target the user owns and names actually returns. It sends GET, HEAD
and OPTIONS only; a login burst is opt-in in the plan. It never writes data,
never uses a service_role key, never follows a redirect to another host, and
stops at a fixed request budget. With an exposure block in the plan it
also reads what the page's scripts, error bodies and JSON responses give
away; a target it could not observe is ERROR or SKIPPED, never CLOSED.

Input is a plan JSON (built by the skill from the static findings) plus
secrets from the environment, never the command line:
  GUARDRAILS_ANON_KEY   Supabase anon/publishable key for the anon-read probe
  GUARDRAILS_JWT2       a second test user's token for the cross-user probe
                        (also sent as bearer by the fields probe when set)

A verdict is a factual observation, not a conclusion: the skill reads it
against the static findings. OPEN means the request returned data or a 200,
CLOSED means it was refused or empty. Exit codes: 0 no OPEN, 1 at least one
OPEN, 2 usage error.
"""
import argparse
import http.client
import json
import os
import re
import sys
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass
from urllib.parse import quote, urljoin, urlsplit

READ_METHODS = {"GET", "HEAD", "OPTIONS"}
FAKE_ORIGIN = "https://guardrails-probe.invalid"
DEFAULT_BUDGET = 200
BURST_CAP = 25
BODY_CAP = 1_000_000
SCRIPT_CAP = 10
SCRIPT_SRC = re.compile(r"<script[^>]{1,300}src=[\"']?([^\"'\s>]+)", re.I)
MAP_COMMENT = re.compile(
    r"^[ \t]*//[#@][ \t]*sourceMappingURL=(\S+)", re.M)
TRACE_MARKERS = re.compile(
    rb"Traceback \(most recent call last\)"
    rb"|\bat [\w.$<> ]{1,80} \([^)\n]{0,200}:\d+:\d+\)"
    rb"|File \"[^\"\n]+\", line \d+|SQLSTATE\[|syntax error at or near"
    rb"|node_modules/|/var/www/|Stack trace:|#\d+ /[\w/.-]+\.php\(\d+\)")
SENSITIVE_KEY = re.compile(
    r"(?:^|_)(?:password|passwd|pwd|salt|secret|token|hash|api_?key"
    r"|service_?role"
    r"|private_?key|(?:access|refresh|id|auth|api|session)_token|jwt|ssn"
    r"|iban|cvv|card_?number)(?:$|_)")
IDENT = re.compile(r"[A-Za-z_][\w-]{0,31}")  # used with fullmatch


@dataclass(frozen=True)
class Response:
    status: int  # None on a transport error
    headers: object  # http.client.HTTPMessage: .get() ignores case
    body: bytes
    error: str = ""


@dataclass(frozen=True)
class Probe:
    domain: str
    id: str
    verdict: str  # OPEN | CLOSED | SKIPPED | ERROR
    target: str
    message: str

    def as_dict(self):
        return asdict(self)


def _stays_on_host(old_url, new_url):
    """Same host and port; the scheme may stay or upgrade, never downgrade."""
    try:
        old, new = urlsplit(old_url), urlsplit(new_url)
    except ValueError:
        return False
    return old.netloc == new.netloc and (
        old.scheme == new.scheme or (old.scheme, new.scheme)
        == ("http", "https"))


class _SameHost(urllib.request.HTTPRedirectHandler):
    """Follow a same-host redirect, drop one that leaves the host."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not _stays_on_host(req.full_url, newurl):
            return None
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class Session:
    """Holds the redirect-guarded opener and the shared request budget."""

    def __init__(self, timeout=8, budget=DEFAULT_BUDGET):
        self.opener = urllib.request.build_opener(_SameHost())
        self.timeout = timeout
        self.budget = budget


def _error_body(exc):
    try:
        return exc.read(BODY_CAP)
    except (OSError, ValueError, AttributeError):
        return b""


def _response_from(resp):
    return Response(resp.status, resp.headers, resp.read(BODY_CAP))


def fetch(session, method, url, headers=None, body=None):
    if session.budget <= 0:
        return Response(None, {}, b"", "request budget exhausted")
    session.budget -= 1
    req = urllib.request.Request(
        url, data=body, method=method, headers=headers or {})
    try:
        with session.opener.open(req, timeout=session.timeout) as resp:
            return _response_from(resp)
    except urllib.error.HTTPError as exc:
        return Response(exc.code, exc.headers, _error_body(exc))
    except (urllib.error.URLError, OSError, ValueError,
            http.client.HTTPException) as exc:
        reason = str(exc)
        return Response(None, {}, b"", reason)


def _verdict(ctx, response, is_open, msgs):
    """ctx is (domain, id, target); msgs is (open_note, closed_note)."""
    domain, pid, target = ctx
    if response.error:
        return Probe(domain, pid, "ERROR", target, response.error)
    verdict = "OPEN" if is_open else "CLOSED"
    note = f"HTTP {response.status}: {msgs[0] if is_open else msgs[1]}"
    return Probe(domain, pid, verdict, target, note)


def _nonempty_rows(body):
    try:
        data = json.loads(body or b"[]")
    except ValueError:
        return False
    return isinstance(data, list) and len(data) > 0


def _table_probe(session, base, table, headers):
    target = f"{base}/rest/v1/{quote(table)}?select=*&limit=1"
    resp = fetch(session, "GET", target, headers)
    return _verdict(
        ("supabase", f"anon-read:{table}", target), resp,
        resp.status == 200 and _nonempty_rows(resp.body),
        ("anon request returned rows", "anon request returned no row"))


def probe_supabase(session, plan):
    cfg = plan.get("supabase")
    anon = os.environ.get("GUARDRAILS_ANON_KEY")
    if not cfg or not cfg.get("tables"):
        return []
    if not anon:
        return [Probe("supabase", "anon-read", "SKIPPED", cfg.get("url", ""),
                      "set GUARDRAILS_ANON_KEY to run the anon-read probe")]
    base = cfg["url"].rstrip("/")
    headers = {"apikey": anon, "Authorization": f"Bearer {anon}"}
    return [_table_probe(session, base, t, headers) for t in cfg["tables"]]


def _cross_user_probe(session, base, path, headers):
    target = base + path
    resp = fetch(session, "GET", target, headers)
    return _verdict(
        ("supabase", f"cross-user:{path}", target), resp,
        resp.status == 200 and _nonempty_rows(resp.body),
        ("second user's token returned these rows",
         "second user's token returned nothing"))


def probe_cross_user(session, plan):
    cfg = plan.get("supabase") or {}
    paths = cfg.get("cross_user_paths") or []
    jwt2 = os.environ.get("GUARDRAILS_JWT2")
    if not paths:
        return []
    if not jwt2:
        return [Probe("supabase", "cross-user", "SKIPPED", cfg.get("url", ""),
                      "set GUARDRAILS_JWT2 to run the cross-user probe")]
    headers = {"apikey": os.environ.get("GUARDRAILS_ANON_KEY", ""),
               "Authorization": f"Bearer {jwt2}"}
    base = cfg["url"].rstrip("/")
    return [_cross_user_probe(session, base, p, headers) for p in paths]


def _route_probe(session, base, route):
    target = base + route["path"]
    resp = fetch(session, "GET", target)
    return _verdict(
        ("api", f"no-auth:{route['path']}", target), resp,
        resp.status == 200,
        ("unauthenticated request returned 200",
         "unauthenticated request was refused"))


def probe_routes(session, plan):
    base = plan["base_url"].rstrip("/")
    routes = [r for r in plan.get("routes") or [] if not r.get("public")]
    return [_route_probe(session, base, r) for r in routes]


def _cors_open(headers):
    allow = headers.get("Access-Control-Allow-Origin", "")
    creds = headers.get("Access-Control-Allow-Credentials", "").lower()
    return allow in (FAKE_ORIGIN, "*") and creds == "true"


def probe_cors(session, plan):
    if not plan.get("cors"):
        return []
    base = plan["base_url"].rstrip("/")
    headers = {"Origin": FAKE_ORIGIN, "Access-Control-Request-Method": "GET"}
    resp = fetch(session, "OPTIONS", base + plan.get("cors_path", "/"), headers)
    return [_verdict(
        ("api", "cors-reflect", base), resp, _cors_open(resp.headers),
        ("foreign origin reflected with credentials",
         "foreign origin not reflected with credentials"))]


def _burst_codes(session, url, method, body, count):
    data = body.encode() if body else None
    codes = []
    for _ in range(count):
        if session.budget <= 0:
            break
        codes.append(fetch(session, method, url, None, data).status)
    return codes


def _rate_verdict(target, codes):
    sent = len([c for c in codes if c is not None])
    throttled = 429 in codes
    note = (f"sent {sent}, {'got a 429' if throttled else 'no 429'}: "
            + ("throttled" if throttled else "no 429 seen on this route"))
    return Probe("hosting", "rate-limit",
                 "CLOSED" if throttled else "OPEN", target, note)


def probe_rate_limit(session, plan):
    cfg = plan.get("rate_limit")
    if not cfg:
        return []
    target = plan["base_url"].rstrip("/") + cfg["path"]
    codes = _burst_codes(
        session, target, cfg.get("method", "GET").upper(),
        cfg.get("body"), min(cfg.get("count", 20), BURST_CAP))
    return [_rate_verdict(target, codes)]


def _same_host(context, url):
    """Absolute url when it stays on context's host, else None."""
    try:
        full = urljoin(context, url)
    except ValueError:
        return None
    return full if _stays_on_host(context, full) else None


def _page_scripts(session, base):
    """(urls, note): same-host scripts of the base page, or why none."""
    page = fetch(session, "GET", base + "/")
    if page.error:
        return [], f"base page unreachable: {page.error}"
    text = page.body.decode("utf-8", "ignore")
    urls = [u for u in (_same_host(base + "/", s)
                        for s in SCRIPT_SRC.findall(text)) if u]
    urls = list(dict.fromkeys(urls))[:SCRIPT_CAP]
    return urls, "" if urls else "no same-host script on the base page"


def _map_candidates(script_url, resp):
    bare = urlsplit(script_url)._replace(query="", fragment="").geturl()
    urls = [bare + ".map"]
    header = resp.headers.get("sourcemap") or resp.headers.get("x-sourcemap")
    if header:
        urls.append(header)
    comments = MAP_COMMENT.findall(resp.body.decode("utf-8", "ignore"))
    if comments:
        urls.append(comments[-1])
    return list(dict.fromkeys(urls))


def _map_verdict(session, script_url, candidates):
    """(verdict, target, note) over the candidate map urls, fail closed."""
    for url in candidates:
        if url.startswith("data:"):
            if "base64," not in url:
                continue
            return "OPEN", script_url, "inline source map in the script"
        target = _same_host(script_url, url)
        if not target:
            return "SKIPPED", url, "map url on another host, not fetched"
        resp = fetch(session, "GET", target)
        if resp.error or resp.status is None:
            return "ERROR", target, resp.error or "no response"
        if 300 <= resp.status < 400:
            return ("SKIPPED", target, f"HTTP {resp.status}: map redirect "
                    "dropped (off host or downgraded), not followed")
        if resp.status == 403 or (resp.status or 0) >= 500:
            return ("SKIPPED", target,
                    f"HTTP {resp.status}: map not readable, not confirmed")
        if resp.status == 200 and len(resp.body) >= BODY_CAP:
            return ("SKIPPED", target, "map answered 200 but its body is "
                    "over 1 MB: sources not confirmed, fetch it by hand")
        if resp.status == 200 and b'"sources"' in resp.body:
            return "OPEN", target, "source map served with its sources"
    return "CLOSED", script_url, "no source map served for this script"


def _sourcemap_probe(session, script_url):
    pid = f"sourcemap:{urlsplit(script_url).path}"
    resp = fetch(session, "GET", script_url)
    if resp.error:
        return Probe("exposure", pid, "ERROR", script_url, resp.error)
    if resp.status != 200:
        return Probe("exposure", pid, "SKIPPED", script_url,
                     f"HTTP {resp.status}: script not served, map not read")
    if len(resp.body) >= BODY_CAP:
        return Probe("exposure", pid, "SKIPPED", script_url,
                     "script body truncated: its map comment was not read")
    verdict, target, note = _map_verdict(
        session, script_url, _map_candidates(script_url, resp))
    return Probe("exposure", pid, verdict, target, note)


def _sourcemaps(session, base, cfg):
    listed = cfg.get("scripts")
    if listed is None:
        urls, note = _page_scripts(session, base)
    else:
        urls = [base + s for s in listed][:SCRIPT_CAP]
        note = "" if urls else "no script listed in exposure.scripts"
    if note:
        return [Probe("exposure", "sourcemap", "SKIPPED", base, note)]
    return [_sourcemap_probe(session, u) for u in urls]


def _error_probe(session, base, path):
    target = base + path
    resp = fetch(session, "GET", target)
    return _verdict(
        ("exposure", f"error-body:{path}", target), resp,
        bool(TRACE_MARKERS.search(resp.body)),
        ("error body carries a stack trace or an internal path",
         "error body carries no trace marker"))


def _error_paths(cfg):
    random_path = "/guardrails-probe-" + os.urandom(6).hex()
    return [random_path] + list(cfg.get("error_routes") or [])


def _keys(data):
    """Every string key of the whole body, walked without recursion."""
    found, stack = [], [data]
    while stack:
        node = stack.pop()
        if isinstance(node, dict):
            found += [k for k in node if isinstance(k, str)]
            stack += node.values()
        elif isinstance(node, list):
            stack += node
    return found


def _snake(key):
    return re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "_", key).replace("-", "_").lower()


def _sensitive_keys(data):
    return sorted({k for k in _keys(data) if SENSITIVE_KEY.search(_snake(k))})


def _key_note(keys):
    """Identifier-shaped key names only; anything else is counted."""
    shown = [k for k in keys if IDENT.fullmatch(k)]
    hidden = len(keys) - len(shown)
    return ", ".join(shown) + (f" (+{hidden} unprintable)" if hidden else "")


def _json_body(resp):
    try:
        return json.loads(resp.body), True
    except (ValueError, RecursionError):
        return None, False


def _fields_verdict(resp):
    if resp.error:
        return "ERROR", resp.error
    data, is_json = _json_body(resp)
    if resp.status != 200 or not is_json:
        return "SKIPPED", f"HTTP {resp.status}: no JSON body to read"
    keys = _sensitive_keys(data)
    if keys:
        return "OPEN", "response carries sensitive keys: " + _key_note(keys)
    return "CLOSED", "no sensitive key in the response"


def _bearer():
    token = os.environ.get("GUARDRAILS_JWT2")
    return {"Authorization": f"Bearer {token}"} if token else None


def _fields_probe(session, base, route):
    target = base + route["path"]
    verdict, note = _fields_verdict(fetch(session, "GET", target, _bearer()))
    return Probe("exposure", f"fields:{route['path']}", verdict, target, note)


def probe_exposure(session, plan):
    cfg = plan.get("exposure")
    if cfg is None:
        return []
    base = plan["base_url"].rstrip("/")
    out = _sourcemaps(session, base, cfg)
    out += [_error_probe(session, base, p) for p in _error_paths(cfg)]
    out += [_fields_probe(session, base, r) for r in plan.get("routes") or []]
    return out


PROBES = (probe_supabase, probe_cross_user, probe_routes,
          probe_cors, probe_exposure, probe_rate_limit)


def run_probes(session, plan):
    results = []
    for probe in PROBES:
        results += probe(session, plan)
    return results


def _tally(results):
    return {v: sum(p.verdict == v for p in results)
            for v in ("OPEN", "CLOSED", "SKIPPED", "ERROR")}


def _printable(text):
    """Control characters of a remote or plan string never reach the tty."""
    return re.sub(r"[\x00-\x1f\x7f-\x9f]", "?", str(text))


def _probe_row(probe):
    return (f"  {probe.verdict:<8} {probe.domain:<9} "
            f"{_printable(probe.id)}  {_printable(probe.target)}\n"
            f"           {_printable(probe.message)}")


def _summary(results):
    counts = _tally(results)
    return f"\nopen: {counts['OPEN']}  " + ", ".join(
        f"{v} {n}" for v, n in counts.items())


def _render_text(plan, results):
    body = [_probe_row(p) for p in results]
    head = [_printable(f"guardrails live probe: {plan['base_url']}"),
            f"probes: {len(results)}  (read-only, bounded budget)"]
    return "\n".join(head + [""] + body + [_summary(results)])


def _render_json(plan, results):
    return json.dumps({
        "base_url": plan["base_url"],
        "open": _tally(results)["OPEN"],
        "probes": [p.as_dict() for p in results],
    }, indent=2)


def _http_url(value):
    if not isinstance(value, str):
        return False
    try:
        parts = urlsplit(value)
    except ValueError:
        return False
    return parts.scheme in ("http", "https") and bool(parts.netloc)


def _load_plan(path):
    try:
        plan = json.loads(open(path, encoding="utf-8").read())
    except (OSError, ValueError) as exc:
        return None, f"cannot read plan: {exc}"
    if not isinstance(plan, dict) or not _http_url(plan.get("base_url")):
        return None, "plan needs an object with an http(s) base_url"
    return plan, ""


def _obj(plan, key):
    value = plan.get(key)
    return value if isinstance(value, dict) else {}


def _plan_paths(plan):
    """Every path the probe would append to base_url (None when malformed)."""
    routes = plan.get("routes") or []
    cfg, supa, rate = _obj(plan, "exposure"), _obj(plan, "supabase"), \
        _obj(plan, "rate_limit")
    return ([r.get("path") if isinstance(r, dict) else None for r in routes]
            + list(supa.get("cross_user_paths") or [])
            + [plan.get("cors_path", "/"), rate.get("path", "/")]
            + list(cfg.get("scripts") or [])
            + list(cfg.get("error_routes") or []))


def _exposure_error(cfg):
    if cfg is None:
        return ""
    if not isinstance(cfg, dict):
        return "exposure must be an object"
    for key in ("scripts", "error_routes"):
        if cfg.get(key) is not None and not isinstance(cfg[key], list):
            return f"exposure.{key} must be a list"
    return ""


def _shape_error(plan):
    rate = plan.get("rate_limit", {})
    if not isinstance(rate, dict):
        return "rate_limit must be an object"
    if rate and not isinstance(rate.get("path"), str):
        return "rate_limit.path must be a string"
    if plan.get("routes") is not None and \
            not isinstance(plan["routes"], list):
        return "routes must be a list"
    if plan.get("supabase") is not None and \
            not isinstance(plan["supabase"], dict):
        return "supabase must be an object"
    paths = _obj(plan, "supabase").get("cross_user_paths")
    if paths is not None and not isinstance(paths, list):
        return "supabase.cross_user_paths must be a list"
    return ""


def _plan_error(plan):
    method = str(_obj(plan, "rate_limit").get("method", "GET")).upper()
    if method not in READ_METHODS and method != "POST":
        return f"rate_limit method {method} is not a probe method"
    error = _exposure_error(plan.get("exposure")) or _shape_error(plan)
    if error:
        return error
    bad = [p for p in _plan_paths(plan)
           if not isinstance(p, str) or not p.startswith("/")]
    return f"plan path {bad[0]!r} must start with /" if bad else ""


def parse_args(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("plan", help="path to the probe plan JSON")
    parser.add_argument(
        "--authorized", action="store_true",
        help="confirm you own the target and may test it (required)")
    parser.add_argument("--json", action="store_true", help="JSON output")
    return parser.parse_args(argv)


def main(argv):
    args = parse_args(argv)
    plan, error = _load_plan(args.plan)
    error = error or _plan_error(plan or {})
    if error:
        print(f"usage error: {error}", file=sys.stderr)
        return 2
    if not args.authorized:
        print("refused: pass --authorized to confirm you own "
              f"{_printable(plan['base_url'])} and may probe it",
              file=sys.stderr)
        return 2
    results = run_probes(Session(), plan)
    render = _render_json if args.json else _render_text
    print(render(plan, results))
    return 1 if any(p.verdict == "OPEN" for p in results) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
