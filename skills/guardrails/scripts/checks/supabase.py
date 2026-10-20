"""Supabase checks: RLS, owner-scoped policies, keys kept off the client."""
import base64
import json
import re
from dataclasses import dataclass

from .apis import ignore_patterns, is_ignored_env
from .common import CLIENT_EXTS, Rule, SOURCE_EXTS, blank_comments
from .common import client_reachable

DOMAIN = "supabase"
_NAME = r'(?:"?\w+"?\.)?"?\w+"?'
TABLE = re.compile(
    r"create\s+(?:unlogged\s+)?table\s+(?:if\s+not\s+exists\s+)?(?P<name>"
    + _NAME + r")", re.I)
RLS_ON = re.compile(
    r"alter\s+table\s+(?:only\s+)?(?:if\s+exists\s+)?(?P<name>" + _NAME
    + r")\s+enable\s+row\s+level\s+security", re.I)
DROP = re.compile(
    r"drop\s+table\s+(?:if\s+exists\s+)?(?P<name>" + _NAME + r")", re.I)
POLICY = re.compile(
    r"create\s+policy\s+(?P<pname>\"[^\"]+\"|\w+)\s+on\s+(?P<table>"
    + _NAME + r")(?P<rest>[^;]*);", re.I)
VIEW = re.compile(
    r"create\s+(?:or\s+replace\s+)?(?P<mat>materialized\s+)?view\s+"
    r"(?P<name>" + _NAME + r")(?P<rest>[^;]*);", re.I)
FUNCTION = re.compile(
    r"create\s+(?:or\s+replace\s+)?function\s+(?P<name>" + _NAME + r")\s*\(",
    re.I)
BUCKET_SQL = re.compile(
    r"(?:insert\s+into|update)\s+storage\.buckets[^;]*;", re.I)
OPEN_EXPR = re.compile(r"\b(?:using|with\s+check)\s*\(\s*true\s*\)")
OWNER = re.compile(r"auth\.(?:uid|jwt|role)\s*\(")
WRITE_CMDS = {"all", "insert", "update", "delete"}
ANON_ROLES = {"anon", "public"}
PRIVILEGED_ROLES = {"service_role", "postgres", "supabase_admin"}

SERVICE_REF = r"service_role|SERVICE_ROLE|SUPABASE_SECRET_KEY|sb_secret_"
JWT = r"eyJ[\w-]{8,}\.(eyJ[\w-]{8,})\.[\w-]{8,}"
MANIFESTS = (
    "package.json", "Cargo.toml", "requirements.txt", "pyproject.toml",
    "pubspec.yaml", "composer.json", "go.mod", "deno.json",
)


@dataclass(frozen=True)
class Policy:
    name: str
    table: str
    cmd: str
    roles: tuple
    open_expr: bool
    owner: bool
    offset: int


def split_name(raw):
    """Return (schema, name), schema defaulting to public."""
    parts = raw.replace('"', "").lower().split(".")
    return (parts[0], parts[1]) if len(parts) == 2 else ("public", parts[0])


def function_statement(text, start):
    """Text of a CREATE FUNCTION from `start` to its closing semicolon."""
    tag = re.compile(r"\bas\s+(\$\w*\$)", re.I).search(text, start)
    if not tag:
        end = text.find(";", start)
    else:
        close = text.find(tag.group(1), tag.end())
        end = text.find(";", close if close != -1 else tag.end())
    return text[start:end if end != -1 else len(text)]


def sql_files(project):
    return [(p, blank_comments(project.text(p)))
            for p in project.with_ext(".sql")]


def applies(project):
    if (project.root / "supabase").is_dir():
        return True
    return project.has(r"supabase", project.named(*MANIFESTS))


def check(project):
    sql = sql_files(project)
    out = _rls(project, sql)
    for path, text in sql:
        out += (_policies(project, path, text) + _views(project, path, text)
                + _functions(project, path, text, sql)
                + _buckets(project, path, text))
    out += _config(project) + _client_leaks(project) + _jwt_literals(project)
    return _dedupe_last(out)


def _dedupe_last(findings):
    """An object redefined by a later migration is reported once, there."""
    latest = {(f.rule, f.message): f for f in findings}
    return [f for f in findings if latest[(f.rule, f.message)] is f]


LIVE_NOTE = (
    "static check sees migrations only: run the RLS query from "
    "references/checks.md against the live project")


def _public_name(m):
    schema, name = split_name(m["name"])
    return name if schema == "public" else None


def _created_tables(sql):
    created = {}
    for path, text in sql:
        for m in TABLE.finditer(text):
            name = _public_name(m)
            if name:
                created.setdefault(name, (path, m.start()))
    return created


def _all_names(pattern, sql):
    return {split_name(m["name"])[1]
            for _, text in sql for m in pattern.finditer(text)}


def _rls(project, sql):
    live = project.found_at_root(DOMAIN, "SB-RLS-LIVE", "MANUAL", LIVE_NOTE)
    covered = _all_names(RLS_ON, sql) | _all_names(DROP, sql)
    return [live] + [
        project.found(
            Rule(DOMAIN, "SB-RLS-MISSING", "FAIL"), path, offset,
            f'table "{name}" never enables row level security')
        for name, (path, offset) in _created_tables(sql).items()
        if name not in covered
    ]


def _roles(rest):
    to = re.search(r"\bto\s+(.+?)(?=\s+(?:using|with\s+check)\b|$)", rest, re.S)
    listed = to.group(1).split(",") if to else ["public"]
    return tuple(r.strip(' "') for r in listed)


def parse_policy(m):
    rest = m["rest"].lower()
    cmd = re.search(r"\bfor\s+(all|select|insert|update|delete)\b", rest)
    return Policy(
        m["pname"].strip('"'), split_name(m["table"])[1],
        cmd.group(1) if cmd else "all", _roles(rest),
        bool(OPEN_EXPR.search(rest)), bool(OWNER.search(rest)), m.start())


def policy_issues(pol):
    """Return (Rule, message) pairs for one policy."""
    if set(pol.roles) <= PRIVILEGED_ROLES:
        return []
    writes = pol.cmd in WRITE_CMDS
    anon = bool(ANON_ROLES & set(pol.roles))
    where = f'policy "{pol.name}" on "{pol.table}"'
    if pol.open_expr and writes:
        return [(Rule(DOMAIN, "SB-POLICY-OPEN-WRITE", "FAIL"),
                 f"{where}: true on a write lets anyone change rows")]
    if writes and anon and not pol.owner:
        return [(Rule(DOMAIN, "SB-POLICY-ANON-WRITE", "FAIL"),
                 f"{where}: anon can write; scope it to auth.uid()")]
    if pol.open_expr:
        return [(Rule(DOMAIN, "SB-POLICY-PUBLIC-READ", "WARN"),
                 f"{where}: open read; confirm the data is public")]
    if not pol.owner:
        return [(Rule(DOMAIN, "SB-POLICY-NOT-OWNER", "WARN"),
                 f"{where}: not tied to auth.uid(); confirm owner scoping")]
    return []


def _policies(project, path, text):
    out = []
    for m in POLICY.finditer(text):
        pol = parse_policy(m)
        for rule, message in policy_issues(pol):
            out.append(project.found(rule, path, pol.offset, message))
    return out


def _views(project, path, text):
    out = []
    for m in VIEW.finditer(text):
        schema, name = split_name(m["name"])
        if schema != "public":
            continue
        if m["mat"]:
            out.append(project.found(
                Rule(DOMAIN, "SB-MATVIEW-EXPOSED", "WARN"), path, m.start(),
                f'materialized view "{name}" ignores RLS: do not expose it'))
        elif "security_invoker" not in m["rest"].lower():
            out.append(project.found(
                Rule(DOMAIN, "SB-VIEW-INVOKER", "WARN"), path, m.start(),
                f'view "{name}" runs as its owner: add security_invoker'))
    return out


def _statements(sql, word):
    return " ".join(t for _, t in sql if word in t.lower())


def _revoked(revokes, name):
    pattern = r"revoke\s+(?:all|execute)[^;]*\b" + re.escape(name) + r"\b"
    return re.search(pattern, revokes, re.I) is not None


def _execute_issue(revokes, grants, name, stmt):
    if "returns trigger" in stmt or _revoked(revokes, name):
        return None
    granted = r"grant\s+(?:all|execute)[^;]*\b" + re.escape(name)
    if re.search(granted + r"\b[^;]*\banon\b", grants, re.I):
        return (f'definer function "{name}" is explicitly granted to anon: '
                "confirm it is meant to be public")
    return (f'definer function "{name}" is callable by anon by default: '
            "revoke execute from public, anon")


def _definer_findings(project, path, m, text, privileges):
    schema, name = split_name(m["name"])
    stmt = function_statement(text, m.start()).lower()
    if schema != "public" or "security definer" not in stmt:
        return []
    out = []
    if "set search_path" not in stmt:
        out.append(project.found(
            Rule(DOMAIN, "SB-DEFINER-SEARCH-PATH", "WARN"), path, m.start(),
            f'definer function "{name}" must pin search_path'))
    issue = _execute_issue(*privileges, name, stmt)
    if issue:
        out.append(project.found(
            Rule(DOMAIN, "SB-DEFINER-EXECUTE", "WARN"), path, m.start(),
            issue))
    return out


def _functions(project, path, text, sql):
    privileges = (_statements(sql, "revoke"), _statements(sql, "grant"))
    out = []
    for m in FUNCTION.finditer(text):
        out += _definer_findings(project, path, m, text, privileges)
    return out


def _buckets(project, path, text):
    return [
        project.found(
            Rule(DOMAIN, "SB-BUCKET-PUBLIC", "WARN"), path, m.start(),
            "storage bucket set public: confirm every file is meant "
            "to be world-readable")
        for m in BUCKET_SQL.finditer(text)
        if re.search(r"\btrue\b", m.group(), re.I)
    ]


def _config(project):
    out = []
    for path in project.named("config.toml"):
        if path.parent.name != "supabase":
            continue
        text = project.text(path)
        for m in re.finditer(
                r"\[functions\.([\w-]+)\][^\[]*?verify_jwt\s*=\s*false",
                text, re.S):
            out.append(project.found(
                Rule(DOMAIN, "SB-EDGE-NO-JWT", "WARN"), path, m.start(),
                f'function "{m.group(1)}" skips JWT verification: confirm '
                "it checks a webhook signature instead"))
        for m in re.finditer(
                r"\[storage\.buckets\.([\w-]+)\][^\[]*?public\s*=\s*true",
                text, re.S):
            out.append(project.found(
                Rule(DOMAIN, "SB-BUCKET-PUBLIC", "WARN"), path, m.start(),
                f'bucket "{m.group(1)}" is public: confirm it is intended'))
    return out


def _client_leaks(project):
    files = project.with_ext(*SOURCE_EXTS, *CLIENT_EXTS)
    return [
        project.found(
            Rule(DOMAIN, "SB-SERVICE-ROLE-CLIENT", "FAIL"), path, m.start(),
            "service role or secret key referenced in client-reachable "
            "code: it bypasses RLS for anyone who reads the bundle")
        for path, m in project.matches(SERVICE_REF, files, 0)
        if client_reachable(project, path)
    ]


def _jwt_role(payload):
    try:
        raw = base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4))
        data = json.loads(raw)
    except ValueError:
        return None
    return data.get("role") if isinstance(data, dict) else None


def _jwt_literals(project):
    patterns = ignore_patterns(project)
    return [
        project.found(
            Rule(DOMAIN, "SB-SERVICE-ROLE-LITERAL", "FAIL"), path, m.start(),
            "service_role JWT hardcoded: rotate the key, keep it in "
            "server env only")
        for path, m in project.matches(JWT, None, 0)
        if _jwt_role(m.group(1)) == "service_role"
        and not is_ignored_env(path, patterns)
    ]
