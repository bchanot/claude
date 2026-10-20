"""Exposure checks: what the browser can see that it should not."""
import re

from . import passwords
from .apis import ENV_NAME, ENV_SAMPLE, ignore_patterns, is_ignored_env
from .apis import route_files
from .common import Rule, client_reachable, code_files, dedupe_lines, hits

DOMAIN = "exposure"
MARKUP_EXTS = (".html", ".htm", ".astro", ".php", ".ejs", ".hbs", ".twig",
               ".njk", ".liquid")
ATTR_EXTS = MARKUP_EXTS + (".jsx", ".tsx", ".vue", ".svelte")
DEV_TOKEN = re.compile(
    r"(?:^|[._-])(?:dev|development|local|test|testing)(?:[._-]|$)", re.I)
CONSOLE = re.compile(
    r"\bconsole\.(?:log|info|debug|dir|table)\s*\(([^\n]{0,300})")
DATA_NAMES = re.compile(
    r"\b(?:users?|profile|session|token|account|customer|order|payment"
    r"|response|res|data|result|rows|body|headers|props|state|error|err"
    r"|json|payload|record|items?)\b", re.I)
SENSITIVE = (
    r"(?:token|accessToken|refreshToken|secret|apiKey|api_key|password"
    r"|passwordHash|password_hash|serviceRole|service_role|privateKey"
    r"|private_key|ssn|iban|stripeSecret|clientSecret)")
EXPORT = re.compile(r"^export\b", re.M)
LOADER = re.compile(
    r"getServerSideProps|getStaticProps"
    r"|export\s+(?:async\s+)?function\s+(?:loader|load)\b"
    r"|export\s+const\s+(?:loader|load)\b|window\.__\w+__\s*=")
TYPEISH = (r"(?:string|number|boolean|null|undefined|unknown|any|never"
           r"|[A-Z][\w<>\[\]|]*)")
HYDRATED = re.compile(
    rf"\b{SENSITIVE}\s*:(?!\s*{TYPEISH}\s*(?:[;,}}]|$))", re.M)
COMMENT = re.compile(r"<!--([\s\S]{0,400}?)-->")
COMMENT_WORDS = re.compile(
    r"\b(?:todo|fixme|hack|xxx|debug|password|passwd|secret|token"
    r"|api[-_ ]?key|internal|staging|localhost|admin|remove before"
    r"|do not commit|don'?t commit|temporary)\b", re.I)
SENSITIVE_WORD = (r"(?:secret|api-?_?key|password|passwd|jwt|private"
                  r"|credential|service-?role)")
DATA_ATTR = re.compile(
    rf"\b(data-[\w-]{{0,60}}{SENSITIVE_WORD}[\w-]{{0,60}})\s*=", re.I)
UI_ATTR = re.compile(
    rf"{SENSITIVE_WORD}-(?:toggle|visible|visibility|show|hide|reveal|mask"
    r"|strength|meter|hint|label|placeholder|confirm|error|required"
    r"|pattern)$", re.I)
HIDDEN_INPUT = re.compile(r"<input\b[^>]{0,300}>", re.I)
SENSITIVE_NAME = re.compile(
    r"secret|api[-_]?key|password|passwd|jwt|private|credential", re.I)
SAFE_NAME = re.compile(r"csrf|xsrf|authenticity|nonce", re.I)
SENDING = (
    r"(?:\bres\.(?:status|json|send|end|write)\b"
    r"|\breply\.(?:send|code|status)\b|\bctx\.body\b|\bResponse\("
    r"|Response\.json\(|\bjsonify\(|\bJSONResponse\(|\bHTTPException\("
    r"|\bdetail\s*=|\becho\b)")
ERR = r"(?:err|error|e|exc|exception)"
ERROR_STACK = re.compile(
    rf"{SENDING}[^\n]{{0,300}}?(?:\b{ERR}\.stack\b|traceback\.format_exc"
    rf"|getTraceAsString\(\))"
    rf"|\b(?:json|send)\s*\(\s*\{{[^}}\n]{{0,200}}\berror\s*:\s*{ERR}\s*[,}}]")
ERROR_MESSAGE = re.compile(
    rf"{SENDING}[^\n]{{0,300}}?(?:\b{ERR}\.message\b|\bstr\({ERR}\)"
    rf"|\brepr\({ERR}\)|->getMessage\(\))")
SETTINGS_NAME = re.compile(r"^(?:settings|config)", re.I)
DEBUG_SETTINGS = re.compile(r"^DEBUG\s*=\s*True\b", re.M)
DEBUG_ENV = re.compile(
    r"^[ \t]*(?:APP_DEBUG\s*=\s*true|FLASK_DEBUG\s*=\s*1)\b", re.M | re.I)
DEBUG_CODE = re.compile(
    r"app\.debug\s*=\s*True|app\.run\([^)\n]{0,200}debug\s*=\s*True")
DEBUG_HANDLER = re.compile(r"app\.use\(\s*errorhandler\(\)")
ENV_GUARD = re.compile(r"development|NODE_ENV")
DEBUG_RAILS = re.compile(r"consider_all_requests_local\s*=\s*true")
NEXT_MAPS = re.compile(r"productionBrowserSourceMaps\s*:\s*true")
VITE_MAPS = re.compile(r"\bsourcemap\s*:\s*(?:true|['\"]inline['\"])")
WEBPACK_DEVTOOL = re.compile(
    r"\bdevtool\s*:\s*['\"](?:source-map|eval[\w-]*|inline[\w-]*"
    r"|cheap[\w-]*)['\"]")
ENV_MAPS = re.compile(r"^[ \t]*GENERATE_SOURCEMAP\s*=\s*true\b", re.M | re.I)
ANGULAR_MAPS = re.compile(r"\"sourceMap\"\s*:\s*true")
PUBLIC_DIRS = {"public", "static", "assets", "www"}
VENDORED = re.compile(r"\.min\.|vendor|bootstrap|jquery", re.I)
USERS = (r"(?:users|profiles|accounts|customers|members|employees"
         r"|patients|clients)")
WIDE = re.compile(
    rf"\.from\(\s*['\"]{USERS}['\"]\s*\)\s*\.select\(\s*(?:['\"]\*['\"]\s*)?\)"
    rf"|select\s+\*\s+from\s+{USERS}\b"
    r"|\b(?:user|profile|account|customer|member)\.(?:findUnique|findFirst"
    r"|findMany)\(\s*\{(?![^\n]{0,300}\b(?:select|omit)\s*:)[^\n]{0,300}\}"
    r"\s*\)", re.I)


def applies(project):
    return bool(project.with_ext(".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs",
                                 ".py", ".php", ".rb", ".vue", ".svelte",
                                 ".astro", *MARKUP_EXTS))


def _named(project, prefix):
    return [p for p in project.files if p.name.startswith(prefix)]


def _client(project, path):
    """client_reachable, plus Next pages and a root App component."""
    if client_reachable(project, path):
        return True
    segments = project.segments(path)
    return (path.suffix.lower() in (".tsx", ".jsx") and "api" not in segments
            and ("pages" in segments or path.stem == "App"))


def _console_data(project, files):
    rule = Rule(DOMAIN, "EXP-CONSOLE-DATA", "WARN")
    out = []
    for path in (p for p in files if _client(project, p)):
        for m in CONSOLE.finditer(project.text(path)):
            if passwords.LOGGED_NAME.search(m.group(1)):
                continue
            if DATA_NAMES.search(passwords.log_args(m.group(1))):
                out.append(project.found(
                    rule, path, m.start(),
                    "data logged to the browser console"))
    return out


def _map_config(project):
    fail = Rule(DOMAIN, "EXP-SOURCEMAP-PUBLIC", "FAIL")
    warn = Rule(DOMAIN, "EXP-SOURCEMAP-PUBLIC", "WARN")
    out = hits(project, _named(project, "next.config"), NEXT_MAPS, fail,
               "production source maps enabled")
    out += hits(project, _named(project, "vite.config"), VITE_MAPS, fail,
                "build source maps enabled: use 'hidden' or false")
    prod = _named(project, "webpack.prod")
    other = [p for p in _named(project, "webpack")
             if p not in prod and not DEV_TOKEN.search(p.name)]
    out += hits(project, prod, WEBPACK_DEVTOOL, fail,
                "devtool emits readable source maps in production")
    out += hits(project, other, WEBPACK_DEVTOOL, warn,
                "devtool emits readable source maps: confirm not in prod")
    return out + hits(project, project.named("angular.json"), ANGULAR_MAPS,
                      warn, "sourceMap true: confirm not the production build")


def _env_files(project):
    """Committed env files that are not samples and not dev/local/test."""
    patterns = ignore_patterns(project)
    return [p for p in project.files if ENV_NAME.fullmatch(p.name)
            and not p.name.endswith(ENV_SAMPLE)
            and not DEV_TOKEN.search(p.name[4:] or "x")
            and not is_ignored_env(p, patterns)]


def _public_map(project, path):
    return (set(project.segments(path)) & PUBLIC_DIRS
            and not VENDORED.search(project.rel(path)))


def _large_map(project, path):
    """A large public .map whose first 4 KB hold a mappings or sources key."""
    if path.suffix.lower() != ".map" or not _public_map(project, path):
        return False
    try:
        with path.open("rb") as handle:
            head = handle.read(4096)
        return b'"mappings"' in head or b'"sources"' in head
    except OSError:
        return False


def _map_files(project):
    rule = Rule(DOMAIN, "EXP-SOURCEMAP-PUBLIC", "FAIL")
    out = hits(project, _env_files(project), ENV_MAPS, rule,
               "GENERATE_SOURCEMAP=true ships source maps")
    small = [p for p in project.with_ext(".map")
             if _public_map(project, p) and '"mappings"' in project.text(p)]
    large = [p for p in project.large if _large_map(project, p)]
    return out + [project.found(rule, p, 0, "source map in a public directory")
                  for p in small + large]


def _hydrated_spans(text):
    """(start, end) of each export chunk holding a loader, from its line."""
    bounds = sorted({0, *(m.start() for m in EXPORT.finditer(text))})
    spans = []
    for start, end in zip(bounds, bounds[1:] + [len(text)]):
        found = LOADER.search(text, start, end)
        if found:
            spans.append((text.rfind("\n", 0, found.start()) + 1, end))
    return spans


def _hydrated(project, files):
    rule = Rule(DOMAIN, "EXP-HYDRATED-SENSITIVE", "WARN")
    out = []
    for path in files:
        text = project.text(path)
        out += [project.found(rule, path, m.start(),
                              "sensitive key in server-to-client state")
                for begin, end in _hydrated_spans(text)
                for m in HYDRATED.finditer(text, begin, end)]
    return dedupe_lines(out)


def _markup_comments(project):
    rule = Rule(DOMAIN, "EXP-MARKUP-COMMENT", "WARN")
    return [project.found(rule, path, m.start(),
                          "HTML comment shipped to the browser carries "
                          "internal notes")
            for path in project.with_ext(*MARKUP_EXTS)
            for m in COMMENT.finditer(project.text(path))
            if COMMENT_WORDS.search(m.group(1))]


def _hidden_sensitive(tag):
    if not re.search(r"type\s*=\s*[\"']?hidden\b", tag, re.I):
        return False
    name = re.search(r"name\s*=\s*[\"']([^\"']+)", tag, re.I)
    return bool(name and SENSITIVE_NAME.search(name.group(1))
                and not SAFE_NAME.search(name.group(1)))


def _data_attrs(project):
    rule = Rule(DOMAIN, "EXP-DATA-ATTR-SENSITIVE", "WARN")
    out = []
    for path in project.with_ext(*ATTR_EXTS):
        text = project.text(path)
        out += [project.found(rule, path, m.start(),
                              "sensitive value in a data-* attribute")
                for m in DATA_ATTR.finditer(text)
                if not SAFE_NAME.search(m.group(1))
                and not UI_ATTR.search(m.group(1))]
        out += [project.found(rule, path, m.start(),
                              "sensitive value in a hidden input")
                for m in HIDDEN_INPUT.finditer(text)
                if _hidden_sensitive(m.group(0))]
    return out


def _errors(project, files):
    server = [p for p in files if not client_reachable(project, p)]
    stack = hits(project, server, ERROR_STACK,
                 Rule(DOMAIN, "EXP-ERROR-STACK", "FAIL"),
                 "stack trace or error object sent to the client")
    message = hits(project, server, ERROR_MESSAGE,
                   Rule(DOMAIN, "EXP-ERROR-MESSAGE", "WARN"),
                   "raw exception message sent to the client")
    return dedupe_lines(stack + message)


def _settings_modules(project, files):
    return [p for p in files if p.suffix == ".py"
            and (SETTINGS_NAME.match(p.name)
                 or "settings" in project.segments(p))
            and not DEV_TOKEN.search(p.stem)]


def _handler_hits(project, files):
    """errorhandler() mounted with no env guard in the 200 chars before."""
    rule = Rule(DOMAIN, "EXP-DEBUG-ON", "FAIL")
    return [project.found(rule, path, m.start(),
                          "dev error handler mounted without an "
                          "environment guard")
            for path in files
            for m in DEBUG_HANDLER.finditer(project.text(path))
            if not ENV_GUARD.search(
                project.text(path)[max(0, m.start() - 200):m.start()])]


def _debug(project, files):
    rule = Rule(DOMAIN, "EXP-DEBUG-ON", "FAIL")
    out = hits(project, _settings_modules(project, files), DEBUG_SETTINGS,
               rule, "DEBUG = True in a settings module")
    out += hits(project, _env_files(project), DEBUG_ENV, rule,
                "debug mode on in a committed env file")
    out += hits(project, files, DEBUG_CODE, rule,
                "debug mode enabled in code")
    out += _handler_hits(project, files)
    return out + hits(project, project.named("production.rb"), DEBUG_RAILS,
                      rule, "full error pages enabled in production")


def _response_wide(project):
    return hits(project, route_files(project), WIDE,
                Rule(DOMAIN, "EXP-RESPONSE-WIDE", "WARN"),
                "whole rows of a user table returned: select the fields")


def check(project):
    files = code_files(project)
    console = code_files(project, keep_built=True)
    found = _console_data(project, console) + _map_config(project)
    found += _map_files(project) + _hydrated(project, files)
    found += _markup_comments(project) + _data_attrs(project)
    found += _errors(project, files) + _debug(project, files)
    return found + _response_wide(project)
