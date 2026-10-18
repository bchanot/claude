"""Accessibility checks: keyboard, visible focus, alt text, field labels."""
import re
from collections import namedtuple

from .common import Rule, blank_markup_comments

DOMAIN = "a11y"
MARKUP_EXTS = (".html", ".htm", ".jsx", ".tsx", ".vue", ".svelte", ".astro")
STYLE_EXTS = (".css", ".scss", ".sass", ".less")
SCRIPT_EXTS = (".ts", ".js", ".mjs")
FIELD_TAGS = {"input", "select", "textarea"}
CLICK_TAGS = {"div", "span", "li", "p", "td", "tr", "section", "article"}
SKIP_INPUT_TYPES = {"hidden", "submit", "button", "reset", "image"}
INTERACTIVE = {"*", "a", "button", "input", "select", "textarea", "summary"}

_BRACES = r"\{(?:[^{}]|\{(?:[^{}]|\{[^{}]*\})*\})*\}"
TAG = re.compile(
    r"<(?P<name>[A-Za-z][\w.:-]*)(?P<attrs>(?:[^<>{}]|" + _BRACES + r")*)>")
SPREAD = re.compile(r"\{\s*\.\.\.|v-bind\s*=")
CLICK = re.compile(
    r"(?<![\w-])(?:onclick|@click|v-on:click|on:click)(?![\w-])", re.I)
KEYS = re.compile(
    r"(?<![\w-])(?:onkey(?:down|up|press)|@key(?:down|up|press)"
    r"|v-on:key(?:down|up|press)|on:key(?:down|up|press))(?![\w-])", re.I)
POSITIVE_TABINDEX = re.compile(
    r"(?<![\w-])tabindex\s*=\s*[{\"']*\s*[1-9]", re.I)
STYLE_TAG = re.compile(r"<style\b[^>]*>(.*?)</style>", re.I | re.S)
CSS_RULE = re.compile(r"(?P<sel>[^{}]+)\{(?P<body>[^{}]*)\}")
OUTLINE_OFF = re.compile(r"outline(?:-style)?\s*:\s*(?:none|0)\b", re.I)
REPLACEMENT = re.compile(
    r"(?:box-shadow|border(?:-color)?)\s*:\s*(?!none\b|0\b)", re.I)
NOT_A_CONTROL = re.compile(
    r"role\s*=\s*[\"'{]\s*[\"']?(?:presentation|none|dialog|alertdialog)\b"
    r"|stopPropagation", re.I)
TW_STRING = re.compile(
    r"[\"'`]([^\"'`\n]*\boutline-(?:none|hidden)\b[^\"'`\n]*)[\"'`]")
TW_REPLACED = re.compile(
    r"\bfocus(?:-visible|-within)?:(?:ring|outline\b(?!-none|-hidden)"
    r"|shadow|border|underline|bg-)")


def applies(project):
    return bool(project.with_ext(*MARKUP_EXTS, *STYLE_EXTS))


def has_attr(attrs, name):
    pattern = (r"(?<![\w-])(?:v-bind:|bind:|:)?" + re.escape(name)
               + r"(?=[\s=/]|$)")
    return re.search(pattern, attrs, re.I) is not None


def attr_value(attrs, name):
    """Literal value, '{expr}' for a braced value, None if absent."""
    pattern = (r"(?<![\w:-])" + re.escape(name)
               + r"\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|\{([^}]*)\})")
    m = re.search(pattern, attrs, re.I)
    if not m:
        return None
    literal = m.group(1) if m.group(1) is not None else m.group(2)
    return literal if literal is not None else "{" + m.group(3) + "}"


def check(project):
    out = []
    for path in project.with_ext(*MARKUP_EXTS):
        text = blank_markup_comments(project.text(path))
        out += _tag_findings(project, path, text)
    return out + _focus_css(project) + _focus_tailwind(project)


def _tag_findings(project, path, text):
    out = []
    for m in TAG.finditer(text):
        for rule, severity, message in _tag_issues(m, text):
            out.append(project.found(
                Rule(DOMAIN, rule, severity), path, m.start(), message))
    return out


def _tag_issues(m, text):
    name, attrs = m["name"], m["attrs"]
    if SPREAD.search(attrs):
        return []
    issues = [_tabindex_issue(attrs)]
    if name.lower() == "img" or name == "Image":
        issues.append(_img_issue(attrs))
    elif name in FIELD_TAGS:
        issues.append(_field_issue(m, text))
    elif name in CLICK_TAGS:
        issues.append(_click_issue(attrs))
    return [issue for issue in issues if issue]


def _img_issue(attrs):
    if has_attr(attrs, "alt"):
        return None
    return ("A11Y-IMG-ALT", "FAIL",
            'image without alt: describe it, or alt="" when decorative')


def _tabindex_issue(attrs):
    if not POSITIVE_TABINDEX.search(attrs):
        return None
    return ("A11Y-TABINDEX-POSITIVE", "WARN",
            "positive tabindex breaks the natural keyboard order")


def _click_issue(attrs):
    if not CLICK.search(attrs) or NOT_A_CONTROL.search(attrs):
        return None
    if attrs.rstrip().endswith("/"):  # empty overlay, nothing to operate
        return None
    missing = [label for label, ok in (
        ("role", has_attr(attrs, "role")),
        ("tabindex", has_attr(attrs, "tabindex")),
        ("key handler", bool(KEYS.search(attrs))),
    ) if not ok]
    if not missing:
        return None
    return ("A11Y-CLICK-NO-KEYBOARD", "FAIL",
            "click handler on a non-interactive element, missing "
            + ", ".join(missing) + ": use a <button>")


def _field_issue(m, text):
    attrs = m["attrs"]
    kind = (attr_value(attrs, "type") or "text").lower()
    if kind in SKIP_INPUT_TYPES or _is_hidden_field(attrs):
        return None
    if _is_labelled(attrs, text, m.start()):
        return None
    return ("A11Y-FIELD-LABEL", "FAIL",
            "form field without a label: add <label for>, a wrapping "
            "<label> or aria-label (a placeholder is not a label)")


def _is_hidden_field(attrs):
    """Fields that are never rendered need no label."""
    if has_attr(attrs, "hidden"):
        return True
    classes = attr_value(attrs, "className") or attr_value(attrs, "class")
    if "hidden" in (classes or "").split():
        return True
    return re.search(r"display\s*:\s*['\"]?none", attrs) is not None


def _is_labelled(attrs, text, position):
    if has_attr(attrs, "aria-label") or has_attr(attrs, "aria-labelledby"):
        return True
    before = text[:position].lower()
    if before.count("<label") > before.count("</label"):
        return True
    ident = attr_value(attrs, "id")
    if ident is None:
        return has_attr(attrs, "id")  # bound id: cannot tell, assume ok
    if not re.fullmatch(r"[\w-]+", ident):
        return True
    return re.search(
        r"(?:for|htmlFor)\s*=\s*[\"']" + re.escape(ident) + r"[\"']",
        text) is not None


Block = namedtuple("Block", "path css start")


def _style_blocks(project):
    """Yield a Block for each CSS source: stylesheets and <style> tags."""
    for path in project.with_ext(*STYLE_EXTS):
        yield Block(path, blank_markup_comments(project.text(path)), 0)
    for path in project.with_ext(*MARKUP_EXTS):
        for m in STYLE_TAG.finditer(project.text(path)):
            yield Block(path, blank_markup_comments(m.group(1)), m.start(1))


def _targets_focus(selector):
    for part in selector.split(","):
        part = part.strip()
        last = re.split(r"[\s>+~]+", part)[-1] if part else ""
        if ":focus" in part or last in INTERACTIVE:
            return True
        if last.startswith("[tabindex"):
            return True
    return False


def _kills_focus_ring(selector, body):
    return (OUTLINE_OFF.search(body) is not None
            and _targets_focus(selector)
            and ":not(:focus-visible)" not in selector
            and REPLACEMENT.search(body) is None)


def _focus_visible_defined(project, blocks):
    if any(":focus-visible" in block.css for block in blocks):
        return True
    return project.has(r"focus-visible:", project.with_ext(*MARKUP_EXTS))


def _lead(text):
    return len(text) - len(text.lstrip())


def _css_findings(project, block, covered):
    out = []
    for rule in CSS_RULE.finditer(block.css):
        if _kills_focus_ring(rule["sel"], rule["body"]):
            offset = block.start + rule.start("sel") + _lead(rule["sel"])
            out.append(_outline_finding(project, block.path, offset, covered))
    return out


def _focus_css(project):
    blocks = list(_style_blocks(project))
    covered = _focus_visible_defined(project, blocks)
    out = []
    for block in blocks:
        out += _css_findings(project, block, covered)
    return out


def _outline_finding(project, path, offset, covered):
    if covered:
        return project.found(
            Rule(DOMAIN, "A11Y-FOCUS-OUTLINE", "WARN"), path, offset,
            "outline removed here: confirm a :focus-visible style covers it")
    return project.found(
        Rule(DOMAIN, "A11Y-FOCUS-OUTLINE", "FAIL"), path, offset,
        "focus outline removed and no :focus-visible style exists")


def _focus_tailwind(project):
    out = []
    files = project.with_ext(*MARKUP_EXTS, *SCRIPT_EXTS)
    for path, m in project.matches(TW_STRING.pattern, files, 0):
        if not TW_REPLACED.search(m.group(1)):
            out.append(project.found(
                Rule(DOMAIN, "A11Y-FOCUS-OUTLINE", "FAIL"), path, m.start(),
                "outline-none without a focus-visible ring replacement"))
    return out
