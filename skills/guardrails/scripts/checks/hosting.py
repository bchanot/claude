"""Hosting checks: rate limit, CDN and firewall, spend cap."""
from .apis import route_files
from .common import Rule, non_doc_files

DOMAIN = "hosting"

PLATFORMS = {
    "vercel.json": ("Vercel", True),
    "netlify.toml": ("Netlify", True),
    "wrangler.toml": ("Cloudflare", True),
    "wrangler.json": ("Cloudflare", True),
    "wrangler.jsonc": ("Cloudflare", True),
    "firebase.json": ("Firebase Hosting", True),
    "amplify.yml": ("AWS Amplify", True),
    "fly.toml": ("Fly.io", False),
    "render.yaml": ("Render", False),
    "railway.json": ("Railway", False),
    "railway.toml": ("Railway", False),
    "docker-compose.yml": ("Docker Compose", False),
    "docker-compose.yaml": ("Docker Compose", False),
    "compose.yml": ("Docker Compose", False),
    "compose.yaml": ("Docker Compose", False),
    "nginx.conf": ("nginx", False),
    "Caddyfile": ("Caddy", False),
    ".htaccess": ("Apache", False),
    "app.yaml": ("App Engine", False),
}
RATE_LIMIT = (
    r"rate[-_ ]?limit|ratelimit|limit_req|throttl|governor|slowapi"
    r"|flask[-_]limiter|django[-_]ratelimit|@vercel/firewall|fail2ban"
    r"|\blimiter\b"
)
CDN_MENTION = (
    r"cloudflare|cloudfront|fastly|bunny\.net|akamai|cf-connecting-ip"
    r"|set_real_ip_from"
)
SPEND_HINTS = {
    "Vercel": "set a Spend Management amount with automatic pause",
}
SPEND_DEFAULT = (
    "check the plan for a hard spend cap and enable it; if there is none, "
    "set a budget alert and write the kill-switch step in the deploy notes"
)


def detect(project):
    """Map platform label to (has_cdn, config path)."""
    found = {}
    for path in project.files:
        entry = ("Docker", False) if path.name.startswith("Dockerfile") \
            else PLATFORMS.get(path.name)
        if entry:
            found.setdefault(entry[0], (entry[1], path))
    return found


def applies(project):
    return bool(detect(project)) or bool(route_files(project))


def check(project):
    platforms = detect(project)
    return (_rate_limit(project, platforms)
            + _origin_exposure(project, platforms)
            + _manual_items(project, platforms))


def _rate_limit(project, platforms):
    if project.has(RATE_LIMIT, non_doc_files(project)):
        return []
    return [project.found_at_root(
        DOMAIN, "HOST-NO-RATE-LIMIT", "FAIL",
        "no rate limiting found: add it per IP and per account on login, "
        "signup, reset, send and upload")]


def _origin_exposure(project, platforms):
    origins = sorted(
        label for label, (has_cdn, _) in platforms.items() if not has_cdn)
    if not origins or project.has(CDN_MENTION):
        return []
    return [project.found_at_root(
        DOMAIN, "HOST-ORIGIN-EXPOSED", "WARN",
        ", ".join(origins) + ": the origin is served directly; put a CDN "
        "and firewall in front (Cloudflare, CloudFront, Fastly)")]


def _manual_items(project, platforms):
    out = [project.found_at_root(
        DOMAIN, "HOST-WAF-DDOS", "MANUAL",
        "enable the CDN firewall: DDoS protection, bot rules, rate rules "
        "(dashboard setting, not visible from code)")]
    if not platforms:
        out.append(project.found_at_root(
            DOMAIN, "HOST-SPEND-CAP", "MANUAL",
            "no hosting config found: " + SPEND_DEFAULT))
    for label, (_, path) in platforms.items():
        out.append(project.found(
            Rule(DOMAIN, "HOST-SPEND-CAP", "MANUAL"), path, 0,
            f"{label}: " + SPEND_HINTS.get(label, SPEND_DEFAULT)))
    return out
