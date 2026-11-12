"""Checks for every project: secrets, public env vars, CORS, route auth."""
import fnmatch
import re

from . import passwords
from .common import Rule, SOURCE_EXTS, non_doc_files, redact

DOMAIN = "api"

SECRET_PATTERNS = [
    ("Stripe live key", r"sk_live_[0-9A-Za-z]{10,}"),
    ("AWS access key id", r"AKIA[0-9A-Z]{16}"),
    ("GitHub token", r"gh[pousr]_[A-Za-z0-9]{30,}"),
    ("Slack token", r"xox[abprs]-[A-Za-z0-9-]{10,}"),
    ("SendGrid key", r"SG\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}"),
    ("Supabase secret key", r"sb_secret_[A-Za-z0-9_-]{10,}"),
    ("private key block", r"-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----"
                          r"(?:\\n|\s)*[A-Za-z0-9+/=]{20,}"),
]
PUBLIC_ENV = (
    r"\b(?:NEXT_PUBLIC|VITE|REACT_APP|EXPO_PUBLIC|NUXT_PUBLIC|GATSBY"
    r"|VUE_APP|PUBLIC)_\w*(?:SERVICE_ROLE|SECRET|PRIVATE|PASSWORD)\w*"
)
CORS_WILDCARD = (
    r"Access-Control-Allow-Origin['\"]?\s*[:,=)]\s*['\"]\*['\"]"
    r"|\borigin\s*:\s*(?:['\"]\*['\"]|true)\b"
    r"|allow_origins\s*=\s*\[\s*['\"]\*['\"]"
    r"|allow_any_origin\(\)|CorsLayer::permissive\(\)"
)
CORS_CREDENTIALS = (
    r"credentials\s*:\s*true|Allow-Credentials|allow_credentials\s*=\s*True"
    r"|allow_credentials\(true\)|supports_credentials"
)
ROUTE_PATH = re.compile(
    r"(?:^|/)(?:api|routes|controllers|handlers)/"
    r"|(?:^|/)route\.[jt]s$|\+server\.[jt]s$"
    r"|(?:^|/)supabase/functions/[^/]+/index\.", re.I)
API_DIR = re.compile(r"(?:^|/)api/", re.I)
UI_EXTS = (".tsx", ".jsx", ".vue", ".svelte", ".astro")
ROUTE_SKIP = re.compile(
    r"_shared|\.test\.|\.spec\.|health|ping|status|robots|sitemap"
    r"|favicon|/og[./]"
    r"|(?:^|/)(?:bin|scripts?|cron|jobs?|tests?|__tests__|migrations?"
    r"|seeds?|public|config|helpers?|libs?|models?|utils?|services?"
    r"|middleware|core|includes|types|schemas?|constants|templates?"
    r"|views?)/", re.I)
AUTH_EVIDENCE = re.compile(
    r"\b(?:auth\w*|getUser|getSession|session|jwt\w*|bearer|verify\w*"
    r"|signature|hmac|login_required|Depends|requireAuth|requireUser"
    r"|requireRole|guard|permission\w*|clerk\w*|csrf)\b", re.I)
ENV_NAME = re.compile(r"\.env(?:\.[\w.-]+)?")
ENV_SAMPLE = (".example", ".sample", ".template", ".dist")


def applies(project):
    return True


def ignore_patterns(project):
    """Patterns from every .gitignore in the tree."""
    patterns = []
    for gitignore in project.named(".gitignore"):
        for line in project.text(gitignore).splitlines():
            line = line.strip()
            if line and not line.startswith(("#", "!")):
                patterns.append(line.strip("/"))
    return patterns


def is_ignored_env(path, patterns):
    """True for an env file that .gitignore keeps out of git."""
    return bool(ENV_NAME.fullmatch(path.name)) and any(
        fnmatch.fnmatch(path.name, pat) for pat in patterns)


def _is_route(rel, ext):
    if ROUTE_SKIP.search(rel) or not ROUTE_PATH.search(rel):
        return False
    return ext not in UI_EXTS or bool(API_DIR.search(rel))


def route_files(project):
    return [
        p for p in project.with_ext(*SOURCE_EXTS)
        if _is_route(project.rel(p), p.suffix.lower())
    ]


def check(project):
    return (_secret_literals(project) + _public_env(project)
            + _unignored_env(project) + _cors(project)
            + _routes_without_auth(project) + passwords.check(project))


def _unignored_files(project):
    patterns = ignore_patterns(project)
    return [p for p in non_doc_files(project)
            if not is_ignored_env(p, patterns)]


def _literal_hits(project, files, label, pattern):
    return [
        project.found(
            Rule(DOMAIN, "API-SECRET-LITERAL", "FAIL"), path, m.start(),
            f"{label} hardcoded ({redact(m.group())}): "
            "move it to env and rotate it")
        for path, m in project.matches(pattern, files, 0)
    ]


def _secret_literals(project):
    files = _unignored_files(project)
    out = []
    for label, pattern in SECRET_PATTERNS:
        out += _literal_hits(project, files, label, pattern)
    return out


def _public_env(project):
    files = [p for p in project.files
             if p.suffix.lower() not in (".md", ".mdx")]
    return [
        project.found(
            Rule(DOMAIN, "API-PUBLIC-ENV-SECRET", "FAIL"), path, m.start(),
            f"{m.group()} ships to the browser: secrets stay server-side")
        for path, m in project.matches(PUBLIC_ENV, files, 0)
    ]


def _has_value(text):
    return re.search(r"^\s*[A-Za-z_]\w*\s*=\s*\S", text, re.M) is not None


def _unignored_env(project):
    patterns = ignore_patterns(project)
    out = []
    for path in project.files:
        if not ENV_NAME.fullmatch(path.name):
            continue
        if path.name.endswith(ENV_SAMPLE) or not _has_value(project.text(path)):
            continue
        if not is_ignored_env(path, patterns):
            out.append(project.found(
                Rule(DOMAIN, "API-ENV-NOT-IGNORED", "FAIL"), path, 0,
                f"{path.name} holds values and is not in .gitignore"))
    return out


def _cors_finding(project, path, m):
    creds = re.search(CORS_CREDENTIALS, project.text(path), re.I)
    note = " with credentials" if creds else ""
    return project.found(
        Rule(DOMAIN, "API-CORS-WILDCARD", "FAIL" if creds else "WARN"),
        path, m.start(),
        f"CORS allows any origin{note}: use an explicit allowlist")


def _cors(project):
    return [
        _cors_finding(project, path, m)
        for path, m in project.matches(CORS_WILDCARD, non_doc_files(project))
    ]


def _routes_without_auth(project):
    return [
        project.found(
            Rule(DOMAIN, "API-ROUTE-NO-AUTH", "WARN"), path, 0,
            "no authentication evidence in this route; if it is public "
            "on purpose, say so and rate limit it")
        for path in route_files(project)
        if not AUTH_EVIDENCE.search(project.text(path))
    ]
