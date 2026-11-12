"""Cloud function checks: no self-trigger, instance cap, budget stop."""
import re
from dataclasses import dataclass

from .common import Rule, SOURCE_EXTS, non_doc_files
from .supabase import function_statement, sql_files, split_name

DOMAIN = "functions"
INFRA_EXTS = (".yml", ".yaml", ".tf", ".toml", ".json", ".sh")
AWS_PATTERN = r"AWS::Serverless|AWS::Lambda|aws_lambda_function|lambda_runtime"
GCP_PATTERN = (
    r"google_cloudfunctions|google_cloud_run"
    r"|gcloud\s+(?:functions|run)\s+deploy"
)
CAPS = {
    "Firebase": r"maxInstances|max_instances",
    "AWS Lambda": r"reserved_?concurren\w*",
    "Google Cloud": (
        r"max[-_]instances|max_instance_count|maxInstanceCount|maxInstances"
    ),
}
_NAME = r'(?:"?\w+"?\.)?"?\w+"?'
TRIGGER = re.compile(
    r"create\s+(?:or\s+replace\s+)?trigger\s+(?P<name>\w+)\s+"
    r"(?:before|after|instead\s+of)\s+[^;]*?\bon\s+(?P<table>" + _NAME
    + r")\s+(?P<rest>[^;]*?)execute\s+(?:function|procedure)\s+"
    r"(?P<func>" + _NAME + r")\s*\((?P<args>[^;]*)\)\s*;", re.I | re.S)
CREATE_FUNCTION = re.compile(
    r"create\s+(?:or\s+replace\s+)?function\s+(" + _NAME + r")\s*\(", re.I)
FN_URL = re.compile(r"/functions/v1/([\w-]+)")
FIREBASE_V2 = re.compile(
    r"(onDocument\w+)\(\s*(?:\{[^}]*\}\s*,\s*)?['\"`]([^'\"`]+)['\"`]")
FIREBASE_V1 = re.compile(
    r"\.document\(\s*['\"`]([^'\"`]+)['\"`]\s*\)\s*\.(on\w+)\(")
REWRITES_SELF = ("Written", "Updated", "onWrite", "onUpdate")


def supabase_functions(project):
    """Map edge function name to its files."""
    found = {}
    for path in project.files:
        parts = project.rel(path).split("/")
        if parts[:2] == ["supabase", "functions"] and len(parts) > 3:
            if parts[2] != "_shared":
                found.setdefault(parts[2], []).append(path)
    return found


def _infra(project):
    return project.with_ext(*INFRA_EXTS)


def _firebase(project):
    return bool(project.named("firebase.json")) and project.has(
        r'"functions"|firebase-functions', project.files)


def _vercel(project):
    return bool(project.named("vercel.json")) and any(
        "api" in project.segments(p) for p in project.with_ext(*SOURCE_EXTS))


def detect(project):
    on = {
        "Supabase Edge Functions": bool(supabase_functions(project)),
        "Firebase": _firebase(project),
        "AWS Lambda": project.has(AWS_PATTERN, _infra(project)),
        "Google Cloud": project.has(GCP_PATTERN, _infra(project)),
        "Vercel Functions": _vercel(project),
        "Netlify Functions": any(
            "netlify/functions/" in project.rel(p) for p in project.files),
        "Cloudflare Workers": bool(
            project.named("wrangler.toml", "wrangler.json", "wrangler.jsonc")),
    }
    return [label for label, enabled in on.items() if enabled]


def applies(project):
    return bool(detect(project))


def check(project):
    platforms = detect(project)
    out = _instance_caps(project, platforms)
    out += _budget_stop(project, platforms)
    out += _supabase_loops(project) + _self_invoke(project)
    return out + _firebase_loops(project)


def _instance_caps(project, platforms):
    out = []
    docs = non_doc_files(project)
    for label in platforms:
        pattern = CAPS.get(label)
        if pattern is None:
            out.append(project.found_at_root(
                DOMAIN, "FN-CAP-UNVERIFIED", "MANUAL",
                f"{label}: no instance cap to verify from code; check the "
                "provider docs for a concurrency limit, and rely on the "
                "spend cap, rate limiting and a short timeout"))
        elif not project.has(pattern, docs):
            out.append(project.found_at_root(
                DOMAIN, "FN-NO-MAX-INSTANCES", "FAIL",
                f"{label}: no max instances or reserved concurrency set"))
    return out


def _budget_stop(project, platforms):
    return [
        project.found_at_root(
            DOMAIN, "FN-BUDGET-STOP", "MANUAL",
            f"{label}: wire a budget alert to an automatic stop (throttle "
            "concurrency to zero, revoke invoke rights or disable billing); "
            "verify it in the console")
        for label in platforms
    ]


def _function_bodies(sql):
    """Map function name to the text of its CREATE FUNCTION statement."""
    bodies = {}
    for _, text in sql:
        for m in CREATE_FUNCTION.finditer(text):
            bodies[split_name(m.group(1))[1]] = function_statement(
                text, m.start())
    return bodies


@dataclass(frozen=True)
class Loop:
    """An edge function fired by a database trigger on `table`."""
    function: str
    table: str
    trigger: str
    guarded: bool


def _loops_of(m, bodies):
    func = split_name(m["func"])[1]
    source = m["args"] if func == "http_request" else bodies.get(func, "")
    guarded = bool(re.search(r"\bwhen\b", m["rest"], re.I))
    table = split_name(m["table"])[1]
    return [Loop(u.group(1), table, m["name"], guarded)
            for u in FN_URL.finditer(source)]


def _triggered_edge_functions(sql):
    """Yield a Loop per edge function that a database trigger calls."""
    bodies = _function_bodies(sql)
    for _, text in sql:
        for m in TRIGGER.finditer(text):
            yield from _loops_of(m, bodies)


def _writes_table(table):
    return re.compile(
        r"\.(?:from|table)\(\s*['\"`](?:public\.)?" + re.escape(table)
        + r"['\"`]\s*\)\s*\.(?:insert|update|upsert|delete)\s*\("
        r"|(?:update|insert\s+into|delete\s+from)\s+(?:public\.)?"
        + re.escape(table) + r"\b", re.I)


def _supabase_loops(project):
    functions = supabase_functions(project)
    out = []
    for loop in _triggered_edge_functions(sql_files(project)):
        for path in functions.get(loop.function, []):
            out += _loop_findings(project, path, loop)
    return out


def _loop_findings(project, path, loop):
    m = _writes_table(loop.table).search(project.text(path))
    return [_loop_finding(project, path, m.start(), loop)] if m else []


def _loop_finding(project, path, offset, loop):
    head = (f'"{loop.function}" writes "{loop.table}" which fires trigger '
            f"{loop.trigger}")
    if loop.guarded:
        return project.found(
            Rule(DOMAIN, "FN-SELF-TRIGGER", "WARN"), path, offset,
            head + ", guarded by WHEN: confirm the write cannot satisfy it")
    return project.found(
        Rule(DOMAIN, "FN-SELF-TRIGGER", "FAIL"), path, offset,
        head + ": infinite loop; add a WHEN guard or an idempotency flag")


def _invocations(project, name, paths):
    pattern = (r"functions/v1/" + re.escape(name)
               + r"\b|invoke\(\s*['\"]" + re.escape(name) + r"['\"]")
    return [
        project.found(
            Rule(DOMAIN, "FN-SELF-INVOKE", "FAIL"), path, m.start(),
            f'"{name}" invokes itself: cap the depth or remove the call')
        for path, m in project.matches(pattern, paths)
    ]


def _self_invoke(project):
    out = []
    for name, paths in supabase_functions(project).items():
        out += _invocations(project, name, paths)
    return out


def _firebase_handlers(text):
    """Yield (collection, kind, offset) for each Firestore trigger."""
    for m in FIREBASE_V2.finditer(text):
        yield m.group(2).split("/")[0], m.group(1), m.start()
    for m in FIREBASE_V1.finditer(text):
        yield m.group(1).split("/")[0], m.group(2), m.start()


def _file_loops(project, path):
    text = project.text(path)
    return [
        project.found(
            Rule(DOMAIN, "FN-SELF-TRIGGER", "WARN"), path, offset,
            f'trigger on "{collection}" also writes it in this file: '
            "confirm the write cannot fire the trigger again")
        for collection, kind, offset in _firebase_handlers(text)
        if _rewrites_trigger(text, collection, kind)
    ]


def _firebase_loops(project):
    out = []
    for path in project.with_ext(".js", ".ts", ".mjs"):
        if not project.rel(path).startswith("supabase/"):
            out += _file_loops(project, path)
    return out


def _rewrites_trigger(text, collection, kind):
    own_ref = re.search(r"\.ref\.(?:set|update)\(", text)
    if own_ref and kind.endswith(REWRITES_SELF):
        return True
    return re.search(
        r"collection\(\s*['\"`]" + re.escape(collection)
        + r"['\"`]\s*\)(?:\s*\.doc\([^)]*\))?\s*\.(?:add|set|update)\(",
        text) is not None
