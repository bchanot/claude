"""Shared types and file helpers for the guardrails checks."""
import os
import re
from dataclasses import asdict, dataclass
from pathlib import Path

SKIP_DIRS = {
    ".git", "node_modules", "dist", "build", ".next", ".astro", "target",
    "vendor", ".venv", "venv", "coverage", "__pycache__", ".svelte-kit",
    ".nuxt", ".output", ".turbo", ".vercel", ".cache", ".phpunit.cache",
    ".pytest_cache", ".mypy_cache",
}
SKIP_FILES = {
    "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "Cargo.lock",
    "bun.lockb", "poetry.lock", "composer.lock",
}
BINARY_EXTS = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".avif", ".ico", ".pdf",
    ".woff", ".woff2", ".ttf", ".otf", ".zip", ".gz", ".mp4", ".mov",
    ".mp3", ".wasm", ".log",
}
MAX_BYTES = 1_000_000
SOURCE_EXTS = {
    ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".py", ".rs", ".go",
    ".php", ".rb", ".vue", ".svelte", ".astro",
}


@dataclass(frozen=True)
class Rule:
    domain: str
    id: str
    severity: str  # FAIL | WARN | MANUAL


@dataclass(frozen=True)
class Finding:
    domain: str
    rule: str
    severity: str  # FAIL | WARN | MANUAL
    path: str
    line: int
    message: str

    def as_dict(self):
        return asdict(self)


def line_of(text, offset):
    return text.count("\n", 0, offset) + 1


def redact(value):
    return value[:6] + "..."


SQL_COMMENT = re.compile(r"--[^\n]*|/\*[\s\S]{0,4000}?\*/")
MARKUP_COMMENT = re.compile(
    r"<!--(?:[^<]|<(?!!--)){0,4000}?-->|/\*[\s\S]{0,4000}?\*/"
    r"|(?:^|(?<=\s))//[^\n]*", re.M)


def _blank(pattern, text):
    """Replace matches with spaces, keeping offsets and newlines."""
    return pattern.sub(lambda m: re.sub(r"[^\n]", " ", m.group()), text)


def blank_comments(text):
    return _blank(SQL_COMMENT, text)


def blank_markup_comments(text):
    return _blank(MARKUP_COMMENT, text)


def _candidate(path):
    """A regular, non-symlink, non-binary file the walker may list."""
    if path.name in SKIP_FILES or path.suffix.lower() in BINARY_EXTS:
        return False
    try:
        return path.is_file() and not path.is_symlink()
    except OSError:
        return False


def _small(path):
    try:
        return path.stat().st_size <= MAX_BYTES
    except OSError:
        return False


def _excluded(root, path, prefixes):
    rel = Path(path).relative_to(root).as_posix()
    return any(rel == p or rel.startswith(p + "/") for p in prefixes)


def _kept_dirs(root, base, dirs, prefixes):
    return [
        d for d in dirs
        if d not in SKIP_DIRS and not _excluded(root, Path(base) / d, prefixes)
    ]


def _kept_files(root, base, names, prefixes):
    for name in names:
        path = Path(base) / name
        if _candidate(path) and not _excluded(root, path, prefixes):
            yield path, _small(path)


def _walk(root, prefixes):
    for base, dirs, names in os.walk(root):
        dirs[:] = _kept_dirs(root, base, dirs, prefixes)
        yield from _kept_files(root, base, names, prefixes)


class Project:
    """A directory tree read as data. Nothing in it is ever executed."""

    def __init__(self, root, exclude=()):
        self.root = Path(root).resolve()
        prefixes = [e.strip("/") for e in exclude if e.strip("/")]
        listed = sorted(_walk(self.root, prefixes))
        self.files = [p for p, small in listed if small]
        self.large = [p for p, small in listed if not small]
        self._text = {}

    def rel(self, path):
        return path.relative_to(self.root).as_posix()

    def text(self, path):
        if path not in self._text:
            try:
                self._text[path] = path.read_text(
                    encoding="utf-8", errors="ignore")
            except OSError:
                self._text[path] = ""
        return self._text[path]

    def with_ext(self, *exts):
        return [p for p in self.files if p.suffix.lower() in exts]

    def named(self, *names):
        return [p for p in self.files if p.name in names]

    def segments(self, path):
        return self.rel(path).split("/")[:-1]

    def matches(self, pattern, files=None, flags=re.I):
        """Yield (path, match) for each regex hit in the given files."""
        regex = re.compile(pattern, flags)
        for path in (self.files if files is None else files):
            for match in regex.finditer(self.text(path)):
                yield path, match

    def has(self, pattern, files=None, flags=re.I):
        return next(self.matches(pattern, files, flags), None) is not None

    def found(self, rule, path, offset, message):
        line = line_of(self.text(path), offset) if offset else 1
        return Finding(
            rule.domain, rule.id, rule.severity, self.rel(path), line,
            message)

    def found_at_root(self, domain, rule, severity, message):
        return Finding(domain, rule, severity, ".", 1, message)


def non_doc_files(project):
    """Files that can hold behavior: everything except docs and samples."""
    skip = (".md", ".mdx", ".txt", ".example", ".sample", ".template")
    return [p for p in project.files if not p.name.endswith(skip)]


TEST_PATH = re.compile(
    r"\.(?:test|spec|e2e|stories)\.|(?:^|/)(?:tests?|__tests__|spec|e2e"
    r"|fixtures?|mocks?)/", re.I)
BUILT_SEGMENTS = {"public", "static", "www", "assets"}
MINIFIED_NAME = re.compile(r"\.min\.|\.bundle\.", re.I)
LONG_LINE = 5000


def _minified(project, path):
    if MINIFIED_NAME.search(path.name):
        return True
    return any(len(line) > LONG_LINE
               for line in project.text(path).splitlines())


def code_files(project, exts=SOURCE_EXTS):
    """Hand-written source: no tests, fixtures, built dirs, minified files."""
    return [p for p in non_doc_files(project)
            if p.suffix.lower() in exts
            and not TEST_PATH.search(project.rel(p))
            and not set(project.segments(p)) & BUILT_SEGMENTS
            and not _minified(project, p)]


def hits(project, files, regex, rule, message):
    """One finding per match of a compiled regex over the given files."""
    return [project.found(rule, path, m.start(), message)
            for path in files
            for m in regex.finditer(project.text(path))]


def dedupe_lines(findings):
    """One finding per (path, line): the first emitted wins."""
    seen, out = set(), []
    for finding in findings:
        if (finding.path, finding.line) not in seen:
            seen.add((finding.path, finding.line))
            out.append(finding)
    return out


SERVER_SEGMENTS = {
    "functions", "api", "server", "scripts", "tests", "test", "migrations",
    "seed", ".github", "supabase", "tools",
}
CLIENT_SEGMENTS = {
    "components", "public", "static", "client", "browser", "www", "islands",
}
CLIENT_EXTS = (".vue", ".svelte", ".html", ".htm")
CLIENT_SCRIPT_EXTS = (".ts", ".tsx", ".js", ".jsx", ".mjs")


def client_reachable(project, path):
    """Heuristic: this file's text ends up in a browser bundle or page."""
    segments = set(project.segments(path))
    if segments & SERVER_SEGMENTS:
        return False
    if path.suffix.lower() in CLIENT_EXTS:
        return True
    if path.suffix.lower() not in CLIENT_SCRIPT_EXTS:
        return False
    head = project.text(path)[:300]
    return bool(segments & CLIENT_SEGMENTS) or "use client" in head
