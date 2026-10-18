"""Password handling: clear storage or compare, fast hash, log, literal."""
import re

from .common import Rule, SOURCE_EXTS, non_doc_files, redact

DOMAIN = "api"
NAME = r"(?:password|passwd|pwd|mot_de_passe)"
CONFIG_EXTS = {".yml", ".yaml", ".toml", ".ini", ".cfg", ".conf", ".sh",
               ".properties", ".json"}
SKIP_PATH = re.compile(
    r"\.(?:test|spec|e2e|stories)\.|(?:^|/)(?:tests?|__tests__|spec|e2e"
    r"|fixtures?|i18n|locales?|lang|translations?|messages)/", re.I)
HASH_EVIDENCE = (
    r"bcrypt|argon2|scrypt|pbkdf2|password_hash\(|password_verify\("
    r"|Hash::make|make_password|hashpw|PasswordHasher|hash_password"
    r"|verify_password|\bphpass\b")
COLUMN = (
    rf"\b{NAME}\s+(?:text|varchar|character varying|char|citext|string)\b"
    rf"|->string\(\s*['\"]{NAME}['\"]"
    rf"|\b{NAME}\s*=\s*models\.(?:Char|Text)Field"
    rf"|\b{NAME}\s*:\s*(?:text|varchar)\(")
COMPARE = (
    rf"(?:\.|->|\[['\"]){NAME}['\"]?\]?\s*[!=]==?\s*[\w$]"
    rf"|[\w$\]\)]\s*[!=]==?\s*\$?\w+(?:\.|->){NAME}\b"
    rf"|\b(?:where|and)\s+(?:\w+\.)?{NAME}\s*=\s*(?:\$\d+|\?|:\w+|%s)")
COMPARE_SKIP = re.compile(
    r"confirm|repeat|again|undefined|null|hash|digest|length", re.I)
WEAK_HASH = (
    rf"\b(?:md5|sha1|sha256|sha512|crc32|hashlib\.\w+)\s*\(\s*[^()\n]*{NAME}"
    rf"|createHash\([^)\n]*\)\s*\.update\(\s*[^()\n]*{NAME}"
    rf"|\bhash\(\s*['\"](?:md5|sha1|sha256|sha512)['\"]\s*,\s*[^()\n]*{NAME}")
WEAK_SKIP = re.compile(r"token|reset|otp|nonce|session", re.I)
LOG_CALL = (
    r"\b(?:console\.\w+|logger?\.\w+|log\.\w+|logging\.\w+|print(?:ln!?)?"
    r"|error_log|Log::\w+|tracing::\w+!|dbg!|var_dump|print_r)\s*\(([^\n]*)")
STRING = re.compile(r"'[^'\n]*'|\"[^\"\n]*\"|`[^`\n]*`")
LOGGED_NAME = re.compile(
    rf"\b(?:(?:new|old|plain|raw|user|current)_?)?{NAME}\b|\bcredentials\b",
    re.I)
LITERAL = rf"\b(\w*{NAME})['\"]?\s*(?:[:=]|=>)\s*['\"]([^'\"\n]{{8,}})['\"]"
BARE_LITERAL = rf"\b(\w*{NAME})(?:=\s*|:\s+)([^'\"\s#]{{8,}})"
PLACEHOLDER = re.compile(
    r"change|your|xxx|\*\*|example|placeholder|dummy|sample|secret[-_ ]?here"
    r"|^[$%<{.*/]|\||required|^\$argon|^[0-9a-f]{32,}$|^[a-z]+(?:_[a-z]+)+$| ",
    re.I)
PLAINTEXT = Rule(DOMAIN, "API-PASSWORD-PLAINTEXT", "FAIL")
LITERAL_RULE = Rule(DOMAIN, "API-PASSWORD-LITERAL", "WARN")


def _line(text, offset):
    start = text.rfind("\n", 0, offset) + 1
    end = text.find("\n", offset)
    return text[start:] if end < 0 else text[start:end]


def _files(project):
    return [p for p in non_doc_files(project)
            if not SKIP_PATH.search(project.rel(p))]


def check(project):
    files = _files(project)
    return (_columns(project, files) + _compares(project, files)
            + _weak_hash(project, files) + _logged(project, files)
            + _literals(project, files))


def _columns(project, files):
    if project.has(HASH_EVIDENCE, files):
        return []
    return [
        project.found(
            PLAINTEXT, path, m.start(),
            "password column and no hashing library anywhere: store an "
            "argon2id or bcrypt hash, never the password")
        for path, m in project.matches(COLUMN, files)
    ]


def _compares(project, files):
    return [
        project.found(
            PLAINTEXT, path, m.start(),
            "stored password compared in clear: verify a hash with the "
            "library's constant-time check")
        for path, m in project.matches(COMPARE, files)
        if not COMPARE_SKIP.search(_line(project.text(path), m.start()))
    ]


def _weak_hash(project, files):
    return [
        project.found(
            Rule(DOMAIN, "API-PASSWORD-WEAK-HASH", "FAIL"), path, m.start(),
            "password through a fast hash: use argon2id, scrypt or bcrypt")
        for path, m in project.matches(WEAK_HASH, files)
        if not WEAK_SKIP.search(_line(project.text(path), m.start()))
    ]


def _log_args(args):
    """Call arguments with string literals reduced to their interpolations."""
    return STRING.sub(
        lambda m: " ".join(re.findall(r"\{([^}]*)\}", m.group())), args)


def _logged(project, files):
    return [
        project.found(
            Rule(DOMAIN, "API-PASSWORD-LOGGED", "FAIL"), path, m.start(),
            "password reaches a log: never log credentials")
        for path, m in project.matches(LOG_CALL, files)
        if LOGGED_NAME.search(_log_args(m.group(1)))
    ]


def _is_placeholder(key, value):
    return value.lower() == key.lower() or bool(PLACEHOLDER.search(value))


def _literal_hits(project, files, pattern):
    return [
        project.found(
            LITERAL_RULE, path, m.start(),
            f"{m.group(1)} set to a literal ({redact(m.group(2))}): a real "
            "credential moves to env and gets rotated; a dev default is "
            "documented as such")
        for path, m in project.matches(pattern, files)
        if not _is_placeholder(m.group(1), m.group(2))
    ]


def _literals(project, files):
    config = [p for p in files if p.suffix.lower() in CONFIG_EXTS]
    source = [p for p in files if p.suffix.lower() in SOURCE_EXTS]
    return (_literal_hits(project, source + config, LITERAL)
            + _literal_hits(project, config, BARE_LITERAL))
