#!/usr/bin/env python3
"""Fill the explain-diff template: fill_template.py <values.json> <out.html>.

values.json maps each placeholder name (without braces) to its content.
A value starting with "@" names a file whose content is used instead, so
long HTML bodies can live in their own fragment files. QUIZ_JSON may be a
JSON list: it is serialised here, with "</" escaped for the script block.
Exit 1 when a placeholder is missing or unknown.
"""
import json
import re
import sys
from pathlib import Path

TEMPLATE = Path(__file__).resolve().parent.parent / "assets/template.html"
PLACEHOLDER = re.compile(r"\{\{([A-Z_]+)\}\}")


def resolve(value, base):
    if isinstance(value, str) and value.startswith("@"):
        return (base / value[1:]).read_text(encoding="utf-8")
    return value


def quiz_text(value):
    if isinstance(value, str):
        value = json.loads(value)
    return json.dumps(value, ensure_ascii=False, indent=1).replace(
        "</", "<\\/")


def fill(template, values):
    wanted = set(PLACEHOLDER.findall(template))
    missing, unknown = wanted - set(values), set(values) - wanted
    if missing or unknown:
        raise KeyError(f"missing: {sorted(missing)}, "
                       f"unknown: {sorted(unknown)}")
    return PLACEHOLDER.sub(lambda m: values[m.group(1)], template)


def main(argv):
    if len(argv) != 3:
        print(__doc__.strip())
        return 2
    values_path = Path(argv[1]).expanduser()
    raw = json.loads(values_path.read_text(encoding="utf-8"))
    values = {k: resolve(v, values_path.parent) for k, v in raw.items()}
    if "QUIZ_JSON" in values:
        values["QUIZ_JSON"] = quiz_text(values["QUIZ_JSON"])
    try:
        page = fill(TEMPLATE.read_text(encoding="utf-8"), values)
    except KeyError as err:
        print(f"ERROR {err}")
        return 1
    Path(argv[2]).expanduser().write_text(page, encoding="utf-8")
    print(f"wrote {argv[2]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
