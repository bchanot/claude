#!/usr/bin/env bash
# lib/tests/explain-diff-check.test.sh — skills/explain-diff checker
# (scripts/check_explanation.py): the template filled with valid content
# passes, the raw template fails, and one single-change mutant per check
# fails (each mutant is a positive control that MUST be detected).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/skills/explain-diff"
CHECK="$SKILL/scripts/check_explanation.py"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# fill <out> <quiz-mode> — the template with valid sample content; the quiz
# mode (valid | four | two-right | no-why) breaks the quiz on purpose.
fill() {
  python3 -I - "$SKILL/assets/template.html" "$1" "$2" <<'PY'
import json, sys
src = open(sys.argv[1], encoding="utf-8").read()
mode = sys.argv[3]
def opts(i):
    return [{"text": "a", "correct": True, "why": "right, since"},
            {"text": "b", "correct": mode == "two-right", "why": "no"},
            {"text": "c", "correct": False,
             "why": "" if mode == "no-why" else "no"}]
count = 4 if mode == "four" else 5
quiz = [{"q": f"Question {i}?", "options": opts(i)} for i in range(count)]
values = {
    "LANG": "en", "TITLE": "Sample", "PROJECT": "demo", "RANGE": "abc123",
    "DATE": "2026-10-17", "STATS": "2 files", "LEAD": "A lead.",
    "TOC_TITLE": "Contents", "BACKGROUND_TITLE": "Background",
    "INTUITION_TITLE": "Intuition", "CODE_TITLE": "Code",
    "QUIZ_TITLE": "Quiz", "BACKGROUND_BODY": "<p>Text.</p>",
    "INTUITION_BODY": "<p>Text with <code>a — b</code>.</p>",
    "CODE_BODY": "<pre><code>if (a &lt; b) { go(); }</code></pre>",
    "QUIZ_INTRO": "<p>Five questions.</p>", "QUIZ_RIGHT": "Right.",
    "QUIZ_WRONG": "Not quite.", "QUIZ_SCORE": "Score: {n} out of {total}",
    "COLOPHON": "Made by explain-diff.", "QUIZ_JSON": json.dumps(quiz),
}
for key, value in values.items():
    src = src.replace("{{" + key + "}}", value)
open(sys.argv[2], "w", encoding="utf-8").write(src)
PY
}

# mutate <in> <out> <old> <new> — exactly one literal replacement
mutate() {
  python3 -I -c 'import sys
s = open(sys.argv[1], encoding="utf-8").read()
assert s.count(sys.argv[3]) == 1, sys.argv[3]
open(sys.argv[2], "w", encoding="utf-8").write(s.replace(sys.argv[3], sys.argv[4]))
' "$1" "$2" "$3" "$4"
}

rc() { python3 "$CHECK" "$1" >/dev/null 2>&1; echo $?; }
D="$WORK/2026-10-17"
OK="$D-valid.html"
fill "$OK" valid

check T1-valid-page-passes "$(rc "$OK")" 0
cp "$SKILL/assets/template.html" "$D-raw-template.html"
check T2-raw-template-fails "$(rc "$D-raw-template.html")" 1
cp "$OK" "$WORK/sample.html"
check T3-undated-name-fails "$(rc "$WORK/sample.html")" 1
git init -q "$WORK/repo" && cp "$OK" "$WORK/repo/2026-10-17-in-repo.html"
check T4-inside-git-tree-fails "$(rc "$WORK/repo/2026-10-17-in-repo.html")" 1

mutate "$OK" "$D-cdn.html" '</title>' \
  '</title><script src="https://cdn.example.com/x.js"></script>'
check T5-remote-script-fails "$(rc "$D-cdn.html")" 1
mutate "$OK" "$D-nosection.html" 'id="intuition"' 'id="intuit"'
check T6-missing-section-fails "$(rc "$D-nosection.html")" 1
mutate "$OK" "$D-toc.html" 'href="#quiz"' 'href="#top"'
check T7-toc-link-missing-fails "$(rc "$D-toc.html")" 1
mutate "$OK" "$D-viewport.html" 'name="viewport"' 'name="x-viewport"'
check T8-no-viewport-fails "$(rc "$D-viewport.html")" 1

for mode in four two-right no-why; do
  fill "$D-quiz-$mode.html" "$mode"
  check "T9-quiz-$mode-fails" "$(rc "$D-quiz-$mode.html")" 1
done

mutate "$OK" "$D-generic.html" 'if (a &lt; b) { go(); }' \
  'const m = new Map<string, number>();'
check T10-unescaped-generic-fails "$(rc "$D-generic.html")" 1
mutate "$OK" "$D-box.html" 'if (a &lt; b) { go(); }' $'┌─┐'
check T11-box-drawing-fails "$(rc "$D-box.html")" 1
mutate "$OK" "$D-dash.html" 'A lead.' $'A lead — with a dash.'
check T12-em-dash-in-prose-fails "$(rc "$D-dash.html")" 1
check T13-em-dash-in-code-allowed "$(rc "$OK")" 0
mutate "$OK" "$D-left.html" 'A lead.' 'A lead. {{LEAD}}'
check T14-placeholder-left-fails "$(rc "$D-left.html")" 1

out=$(python3 "$CHECK" "$D-dash.html")
check T15-fail-line-names-check "$(printf '%s\n' "$out" \
  | grep -c '^FAIL em-dash:')" 1

printf 'explain-diff checker: %d pass, %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
