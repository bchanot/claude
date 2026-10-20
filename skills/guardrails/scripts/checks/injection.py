"""Injection checks: SQL built from input, raw ORM escapes, dynamic SQL,
PostgREST filters, NoSQL operators, a shell into a DB tool."""
import re

from .common import Rule, blank_comments, code_files, dedupe_lines, hits

DOMAIN = "injection"
JS_EXTS = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".vue", ".svelte",
           ".astro")
SQL_EXTS = (".sql", ".pgsql", ".plpgsql")
GAP = r"[^'\"`]{0,200}"
STMT = (
    rf"(?:select\b{GAP}\bfrom\b{GAP}\b(?:where|join|limit|order\s+by"
    rf"|group\s+by)\b|select\s+\*\s+from\b"
    rf"|insert\s+into\s+[\w.\"]+{GAP}\b(?:values|select)\b"
    r"|insert\s+into\s+[\w.\"]+\s*\(|update\s+[\w.\"]+\s+set\b"
    r"|delete\s+from\s+[\w.\"]+\s+where\b"
    r"|\bwhere\s+[\w.\"]+\s*(?:=|like\b|in\b|<|>)"
    r"|create\s+(?:table|index)\s|drop\s+(?:table|index)\s"
    r"|alter\s+table\s|truncate\s+table\s)")
DQ = r"[^\"\n]{0,200}"
SQ = r"[^'\n]{0,200}"


def _quoted(tail):
    """A double- or single-quoted SQL statement string followed by tail."""
    return rf"\"{DQ}?{STMT}{DQ}\"{tail}|'{SQ}?{STMT}{SQ}'{tail}"


CONCAT = {
    JS_EXTS: re.compile(
        rf"(?<![\w$)\]>])`[^`]{{0,400}}?{STMT}[^`]{{0,400}}?\$\{{|"
        + _quoted(r"\s*\+\s*[\w$(]"), re.I),
    (".py",): re.compile(
        rf"\bf['\"][^'\"\n]{{0,200}}?{STMT}|"
        + _quoted(r"\s*(?:%\s*[\w(]|\.format\(|\+\s*[\w(])"), re.I),
    (".php",): re.compile(
        rf"\"{DQ}?{STMT}{DQ}\$[A-Za-z_]\w*|"
        + _quoted(r"\s*\.\s*\$[A-Za-z_]"), re.I),
    (".rb",): re.compile(
        rf"\"{DQ}?{STMT}{DQ}#\{{|\.where\(\s*\"{DQ}#\{{", re.I),
    (".rs",): re.compile(rf"format!\(\s*\"{DQ}?{STMT}", re.I),
    (".go",): re.compile(rf"fmt\.Sprintf\(\s*\"{DQ}?{STMT}", re.I),
}
RAW = {
    JS_EXTS: re.compile(
        r"(?:\$queryRawUnsafe|\$executeRawUnsafe|\bknex\.raw"
        r"|\bsequelize\.query|\b[Ss]equelize\.literal)\s*\(\s*(?![\s'\"`)])"),
    (".py",): re.compile(
        r"\.objects\.raw\(\s*(?![\s'\"`)])|\.extra\(\s*(?![\s'\"`)])"),
}
SQLA_TEXT = re.compile(
    r"(?:(?<![.\w])|(?<=\bsa\.)|(?<=\bsqlalchemy\.))text\s*\(\s*(?![\s'\"`)])")
DYNAMIC_EXEC = re.compile(r"\bexecute\s+(?:'[^']*'|\w+)\s*\|\|", re.I)
POSTGREST = re.compile(
    r"\.(?:or|filter|not|match|textSearch)\(\s*(?:`[^`\n]{0,200}\$\{"
    r"|['\"][^'\"\n]{0,200}['\"]\s*\+\s*[\w$])")
NOSQL = re.compile(
    r"\$where\s*:\s*(?:['\"`]|\w)"
    r"|\.(?:find|findOne|findOneAndUpdate|findOneAndDelete|updateOne"
    r"|updateMany|deleteOne|deleteMany|countDocuments|replaceOne)\(\s*"
    r"(?:req\.(?:body|query|params)\b"
    r"|\{\s*\w+\s*:\s*req\.(?:body|query|params)\.\w+\s*[,}])")
SHELL_DB_HEAD = (
    r"\b(?:exec|execSync|spawn|spawnSync|system|popen|subprocess\.\w+"
    r"|os\.system|Command::new|shell_exec|passthru|proc_open)\s*\("
    r"[^\n]{0,300}?\b(?:psql|mysql|mysqldump|pg_dump|pg_restore|mongosh"
    r"|mongo|mongodump|redis-cli|sqlite3|clickhouse-client)"
    r"\b(?![\"']\s*[,\]])[^\n]{0,300}?")
SHELL_INTERP = r"(?:\$\{|\+\s*[\w$]|#\{|\{\w+\}|%s|"
# An uppercase $NAME is a shell env reference, except in PHP where every
# $name is a variable.
SHELL_DB = re.compile(SHELL_DB_HEAD + SHELL_INTERP + r"\$[a-z_])")
SHELL_DB_PHP = re.compile(SHELL_DB_HEAD + SHELL_INTERP + r"\$[A-Za-z_])")


def applies(project):
    return bool(project.with_ext(*JS_EXTS, ".py", ".php", ".rb", ".rs",
                                 ".go", *SQL_EXTS))


def _by_ext(files, exts):
    return [p for p in files if p.suffix.lower() in exts]


def _per_language(project, files, table, rule, message):
    out = []
    for exts, regex in table.items():
        out += hits(project, _by_ext(files, exts), regex, rule, message)
    return out


def _raw_unsafe(project, files):
    rule = Rule(DOMAIN, "INJ-SQL-RAW-UNSAFE", "WARN")
    msg = ("raw SQL escape fed a non-literal: show it is a constant "
           "with bound values, else bind them")
    sqla = [p for p in _by_ext(files, (".py",))
            if "sqlalchemy" in project.text(p)]
    return (_per_language(project, files, RAW, rule, msg)
            + hits(project, sqla, SQLA_TEXT, rule, msg))


def _concat(project, files):
    return _per_language(
        project, files, CONCAT, Rule(DOMAIN, "INJ-SQL-CONCAT", "FAIL"),
        "SQL built from an expression: use placeholders")


def _dynamic_exec(project):
    rule = Rule(DOMAIN, "INJ-SQL-DYNAMIC-EXEC", "WARN")
    out = []
    for path in code_files(project, SQL_EXTS):
        text = blank_comments(project.text(path))
        for m in DYNAMIC_EXEC.finditer(text):
            out.append(project.found(
                rule, path, m.start(),
                "EXECUTE built with ||: use format() with %I/%L and USING"))
    return out


def _postgrest(project, files):
    client = [p for p in _by_ext(files, JS_EXTS)
              if "supabase" in project.text(p)]
    return hits(project, client, POSTGREST,
                Rule(DOMAIN, "INJ-POSTGREST-FILTER", "WARN"),
                "PostgREST filter string built from a value: use .eq()")


def _nosql(project, files):
    return hits(project, _by_ext(files, JS_EXTS), NOSQL,
                Rule(DOMAIN, "INJ-NOSQL-OPERATOR", "WARN"),
                "filter taken from the request: allowlist fields, cast")


def _shell_db(project, files):
    rule = Rule(DOMAIN, "INJ-SHELL-DB-TOOL", "FAIL")
    msg = "DB tool run through a shell with input: pass an argv"
    php = _by_ext(files, (".php",))
    other = [p for p in files if p.suffix.lower() != ".php"]
    return (hits(project, other, SHELL_DB, rule, msg)
            + hits(project, php, SHELL_DB_PHP, rule, msg))


def check(project):
    files = code_files(project)
    found = _concat(project, files) + _raw_unsafe(project, files)
    found += _dynamic_exec(project) + _postgrest(project, files)
    found += _nosql(project, files) + _shell_db(project, files)
    return dedupe_lines(found)
