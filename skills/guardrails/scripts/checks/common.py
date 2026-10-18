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


SQL_COMMENT = re.compile(r"--[^\n]*|/\*.*?\*/", re.S)
MARKUP_COMMENT = re.compile(
    r"<!--.*?-->|/\*.*?\*/|(?:^|(?<=\s))//[^\n]*", re.S | re.M)


def _blank(pattern, text):
    """Replace matches with spaces, keeping offsets and newlines."""
    return pattern.sub(lambda m: re.sub(r"[^\n]", " ", m.group()), text)


def blank_comments(text):
    return _blank(SQL_COMMENT, text)


def blank_markup_comments(text):
    return _blank(MARKUP_COMMENT, text)


def _is_scannable(path):
    if path.name in SKIP_FILES or path.suffix.lower() in BINARY_EXTS:
        return False
    try:
        return (path.is_file() and not path.is_symlink()
                and path.stat().st_size <= MAX_BYTES)
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
        if _is_scannable(path) and not _excluded(root, path, prefixes):
            yield path


def _walk(root, prefixes):
    for base, dirs, names in os.walk(root):
        dirs[:] = _kept_dirs(root, base, dirs, prefixes)
        yield from _kept_files(root, base, names, prefixes)


class Project:
    """A directory tree read as data. Nothing in it is ever executed."""

    def __init__(self, root, exclude=()):
        self.root = Path(root).resolve()
        prefixes = [e.strip("/") for e in exclude if e.strip("/")]
        self.files = sorted(_walk(self.root, prefixes))
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
