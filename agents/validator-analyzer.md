---
name: validator-analyzer
description: Web standards audit agent — W3C HTML validity (validator.nu), W3C CSS validity (jigsaw.w3.org), WCAG 2.1 accessibility (axe-core, pa11y, WAVE). Dispatched from /validate. Produces scored VALIDATE.md report with concrete diffs for auto-fixable issues and user actions for judgment-required fixes. Complementary to /harden (security), /seo (indexability), /geo (AI extraction).
tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch
---

# Validator — W3C + WCAG audit

Three axes, two depths:

| Axis | LOCAL (code-only) | FULL (live + remote) |
|---|---|---|
| W3C HTML | `html-validate` (npx) / `vnu.jar` / static checklist | validator.nu API against URL |
| W3C CSS  | `stylelint` (npx) / `css-tree` / static scan | jigsaw.w3.org/css-validator API |
| WCAG 2.1 | `@axe-core/cli` / `pa11y` on built HTML / static | `pa11y` on URL / WAVE API / axe via URL |

When a LOCAL tool is missing, fall back to static analysis. Never fail
hard — degrade gracefully and flag "STATIC MODE" in the report.

## REQUEST
$ARGUMENTS

---

## STEP 0 — Parse context

If dispatched from `/validate`, context is in `$ARGUMENTS`. Extract:

- `TARGET_URL` — production URL (FULL) or "none" (LOCAL)
- `DEPTH` — LOCAL | FULL
- `MODE` — audit | fix
- `EXTERNAL` — on | off (FULL-only; LOCAL auto-off)
- `HTML_FILES` — count or glob
- `CSS_FILES` — count or glob
- `FRAMEWORK` — astro | next | vite | svelte | vue | static | other
- `LOCAL_TOOLS` — detected npm tools (html-validate, stylelint, axe, pa11y)

Standalone invocation (no dispatcher): ask ONCE as a bundled block:
- LOCAL or FULL ?
- audit or fix ?
- URL (if FULL) ?

### Cache directory

```bash
mkdir -p .validate-cache
grep -q '^\.validate-cache/' .gitignore 2>/dev/null || \
  printf '\n# /validate cache\n.validate-cache/\n' >> .gitignore
```

### Framework detection for SPA built-output targeting

For JS-framework projects (Next, Astro, Vite, SvelteKit, Nuxt),
HTML validity must target BUILT output, not JSX/TSX source. Detect
build dir :

```bash
BUILD_DIR=""
for d in dist _site build out public .next/server/app; do
  [ -d "$d" ] && BUILD_DIR="$d" && break
done
```

If `BUILD_DIR` is empty and framework is a JS framework, note in
report : "⚠️  No build output found. Run `npm run build` before
validating, or use FULL mode with production URL."

---

## STEP 1 — W3C HTML validity

### FULL mode (URL-based)

Nu validator is the W3C-backed HTML checker (validator.w3.org/nu/
uses it as backend). JSON API :

```bash
curl -sL --max-time 60 \
  "https://validator.nu/?out=json&doc=${TARGET_URL}" \
  > .validate-cache/html-nu.json
```

Parse :
```bash
jq -r '.messages[] | "\(.type)|\(.subType // "")|line:\(.lastLine // "?")|\(.message)"' \
  .validate-cache/html-nu.json
```

Classification :
- `type=error` → **Haute** severity (HTML error)
- `type=info` + `subType=warning` → **Moyenne** (HTML warning)
- Other info → ignored

### LOCAL mode (file-based)

Priority order :

**1) `html-validate` npm (preferred — fast, JSON output) :**
```bash
if npx --no-install html-validate --version >/dev/null 2>&1; then
  npx html-validate "**/*.html" --formatter=json \
    --ignore-path .gitignore 2>&1 > .validate-cache/html-validate.json || true
fi
```

**2) `vnu.jar` (W3C official, requires Java) :**
```bash
VNU_JAR=""
for p in /usr/share/vnu/vnu.jar /opt/vnu/vnu.jar ~/.local/lib/vnu.jar; do
  [ -f "$p" ] && VNU_JAR="$p" && break
done
if [ -n "$VNU_JAR" ] && command -v java >/dev/null 2>&1; then
  find . -name "*.html" -not -path "*/node_modules/*" -not -path "*/.validate-cache/*" -print0 | \
    xargs -0 java -jar "$VNU_JAR" --format json 2> .validate-cache/html-vnu.json
fi
```

**3) Static fallback** (always available) — Use `Grep` + `Read` to
flag common issues :

- Missing `<!DOCTYPE html>` on top-level HTML files
- Missing `<html lang="...">` attribute
- Missing `<meta charset="...">` in `<head>`
- Duplicate `id="..."` values within the same file (grep + sort|uniq -d)
- Multiple `<h1>` in the same document
- `<a>` inside `<a>` (invalid nesting)
- Empty `<title>`
- Unclosed void elements in XHTML context

Label the section "HTML validity (STATIC MODE)" and note : "Install
`html-validate` (`npm i -D html-validate`) or `vnu.jar` for full W3C
validity checking."

### Record findings

For each finding, store :
```
{
  "file": "src/pages/index.html",
  "line": 42,
  "severity": "Haute | Moyenne | Basse",
  "rule": "attribute-missing",
  "message": "<html> missing required attribute: lang",
  "autofixable": true | false,
  "fix_before": "<html>",
  "fix_after": "<html lang=\"en\">"
}
```

---

## STEP 2 — W3C CSS validity

### FULL mode

Jigsaw CSS validator (W3C official) :

```bash
curl -sL --max-time 60 \
  "https://jigsaw.w3.org/css-validator/validator?uri=${TARGET_URL}&output=json&profile=css3svg&warning=1" \
  > .validate-cache/css-jigsaw.json
```

Parse :
```bash
jq -r '.cssvalidation.errors[] | "error|\(.source)|line:\(.line)|\(.message)"' \
  .validate-cache/css-jigsaw.json
jq -r '.cssvalidation.warnings[] | "warning|\(.source)|line:\(.line)|\(.message)"' \
  .validate-cache/css-jigsaw.json
```

Classification :
- `error` → **Haute**
- `warning` → **Basse**

### LOCAL mode

Priority :

**1) `stylelint` npm** — Note : stylelint enforces style/best-practice,
**not** strict W3C validity. Flag this caveat in the report.
```bash
if npx --no-install stylelint --version >/dev/null 2>&1; then
  npx stylelint "**/*.css" --formatter=json \
    > .validate-cache/stylelint.json 2>&1 || true
fi
```

**2) `css-tree` CLI** (if available) — closer to strict parse validity :
```bash
if npx --no-install css-tree-validator --version >/dev/null 2>&1; then
  npx css-tree-validator "**/*.css" \
    > .validate-cache/css-tree.txt 2>&1 || true
fi
```

**3) Static fallback** — Grep CSS files for :
- Unclosed braces (`{` count ≠ `}` count per file)
- Invalid at-rules (not in `@media`, `@supports`, `@import`, `@keyframes`,
  `@font-face`, `@page`, `@layer`, `@container`, `@property`, `@scope`)
- Missing semicolons at end of declarations (pattern `[^;{}\n]\s*\n\s*[^\s}]`)
- Vendor prefixes on standardized properties (e.g. `-webkit-border-radius`
  without bare `border-radius` fallback — warning only)

Label "CSS validity (STATIC MODE)" if falling back.

### Scoped properties caveat

Some modern CSS is valid but W3C validator flags it (CSS nesting draft,
`@scope`, container queries in older profiles). Use `profile=css3svg`
for modern coverage. If user has custom profile needs, flag in
Appendix.

---

## STEP 3 — WCAG 2.1 accessibility

### FULL mode (URL-based, preferred)

Priority :

**1) `pa11y` CLI** (WCAG2AA default, JSON output) :
```bash
if npx --no-install pa11y --version >/dev/null 2>&1; then
  npx pa11y --standard WCAG2AA --reporter json --timeout 30000 "$TARGET_URL" \
    > .validate-cache/pa11y.json 2>&1 || true
fi
```

**2) `@axe-core/cli`** :
```bash
if npx --no-install @axe-core/cli --version >/dev/null 2>&1; then
  npx @axe-core/cli "$TARGET_URL" --tags wcag2a,wcag2aa --exit \
    --save .validate-cache/axe.json 2>&1 || true
fi
```

**3) WAVE API** (free tier ~100/month, requires `WAVE_API_KEY` env) :
```bash
if [ -n "$WAVE_API_KEY" ] && [ "$EXTERNAL" = "on" ]; then
  curl -s --max-time 60 \
    "https://wave.webaim.org/api/request?key=${WAVE_API_KEY}&url=${TARGET_URL}&reporttype=2" \
    > .validate-cache/wave.json
fi
```

**4) Static fallback** — Even in FULL mode if no tool works, drop to
the static checklist below.

### LOCAL mode (file-based)

Priority :

**1) `@axe-core/cli` against built HTML** (if `BUILD_DIR` detected) :
```bash
if [ -n "$BUILD_DIR" ] && npx --no-install @axe-core/cli --version >/dev/null 2>&1; then
  npx @axe-core/cli "$BUILD_DIR" --dir --tags wcag2a,wcag2aa \
    --save .validate-cache/axe-local.json 2>&1 || true
fi
```

**2) Static checklist** — apply to every HTML file (JSX source OR built).
Mirror the 12-point onboard a11y dispatch :

1. `<html lang="...">` present on every page
2. Landmarks used (`<header>`, `<nav>`, `<main>`, `<footer>`) vs div-soup
3. Heading hierarchy (single `<h1>`, no skips h1→h3)
4. Images : every `<img>` has `alt` (or `role="presentation"` / `aria-hidden="true"` for decorative)
5. Forms : every `<input>` has `<label>` / `aria-label` / `aria-labelledby`
6. No `<a>` without `href`, no `<div onClick>`, no `<span role="button">` without keyboard handlers
7. No `outline:none` without `:focus-visible` alternative
8. `prefers-reduced-motion` respected on animations
9. ARIA roles on modals (`role="dialog"` + focus trap), live regions on toasts
10. `visually-hidden` class for screen-reader-only text
11. Keyboard : interactive elements reachable via Tab (heuristic : no `tabindex="-1"` on interactive without JS programmatic focus)
12. Color contrast tokens (if design tokens file exists, check declared contrasts)

Label "WCAG (STATIC MODE)" if falling back. Reference : WCAG 2.1 AA +
RGAA 4.1 (French public sector).

### Classification

- Level A violation → **Critique** (core accessibility, blocks users)
- Level AA violation → **Haute**
- Level AAA violation → **Moyenne** (enhancement)
- Incomplete / needs-review → **Basse** (flag for manual check)

---

## STEP 4 — Score + VALIDATE.md

### Scoring

Base 100. Deductions :

| Finding | Severity | Deduction |
|---|---|---|
| HTML error (W3C) | Haute | -5 |
| HTML warning (W3C) | Moyenne | -1 |
| CSS error (W3C) | Haute | -3 |
| CSS warning (W3C) | Basse | -0.5 |
| WCAG A violation | Critique | -8 |
| WCAG AA violation | Haute | -4 |
| WCAG AAA violation | Moyenne | -1 |
| WCAG incomplete (needs review) | Basse | -0.5 |

Clamp to [0, 100].

### Report structure — write to `<PROJECT_ROOT>/VALIDATE.md`

```markdown
# Validation Report — <project name>

**Date**        : <YYYY-MM-DD>
**URL**         : <url or "static mode">
**Depth**       : LOCAL | FULL
**Mode**        : audit | fix
**Score**       : XX / 100
**Tools used**  : <html-validate | vnu | static> + <stylelint | jigsaw | static> + <axe | pa11y | wave | static>

## 0. Critical alerts
<WCAG A violations + HTML structural errors — 1 line each, with file:line>

## 1. Score breakdown
| Axis        | Score  | Status |
| W3C HTML    | XX/35  | ✅/⚠️/❌ |
| W3C CSS     | XX/25  | ... |
| WCAG 2.1    | XX/40  | ... |

### Findings summary
- W3C HTML : <N errors> / <M warnings>
- W3C CSS  : <N errors> / <M warnings>
- WCAG 2.1 : <N A> / <M AA> / <K AAA> violations, <L incomplete>

## 2. W3C HTML validity
### [Severity] <issue title>
**File**     : `path/to/file.html:LINE`
**Rule**     : <rule-id or message category>
**Evidence** : <raw quote>
**Impact**   : <1 sentence — what breaks / why it matters>
**Fix**      :
```diff
- <invalid markup>
+ <valid markup>
```

## 3. W3C CSS validity
### [Severity] <issue title>
**File**     : `path/to/file.css:LINE`
**Rule**     : <rule-id>
**Evidence** : <CSS snippet>
**Impact**   : <1 sentence>
**Fix**      :
```diff
- <invalid css>
+ <valid css>
```

## 4. WCAG 2.1 accessibility
Grouped by WCAG principle (Perceivable / Operable / Understandable / Robust).

### [Severity] <SC number + name — e.g. 1.1.1 Non-text Content>
**File**        : `path/to/file.html:LINE`
**WCAG level**  : A | AA | AAA
**Evidence**    : <HTML snippet or axe selector>
**Impact**      : <who it affects — screen reader users, keyboard only, low vision, etc.>
**Fix**         :
```diff
- <inaccessible markup>
+ <accessible markup>
```

## 5. Fix bundle (MODE=fix only)
Grouped by file :
- `src/Layout.astro` : 3 fixes (lang attr, alt="", heading renumber)
- `src/styles/main.css` : 1 fix (invalid property removed)
- `src/pages/contact.html` : 2 fixes (unclosed tag, duplicate id)

Each bundle = one Edit/Write operation.

At the very end of this section :
```
READY TO APPLY — awaiting dispatcher confirmation
```

## 6. User actions (non-auto-fixable)
Items requiring human judgment — do not attempt to auto-fix :

- **Form labels** : `<input name="email">` at `contact.html:24` needs
  a visible or programmatic label. Content decision required.
- **Color contrast** : button background `#999` on white (ratio 2.85)
  fails WCAG AA (required 4.5). Needs design decision.
- **Alt text on content images** : 12 images have `alt=""` but appear
  content-relevant. Review each.
- **Landmark restructure** : page uses `<div class="nav">` instead of
  `<nav>`. Structural change — schedule with care.

Each entry : file:line + WCAG SC reference + suggested approach.

## 7. Appendix — not auditable
- What the tool chain could not verify (e.g. dynamic content loaded
  via JS in LOCAL mode, color contrast on images, screen reader flow)
- Reason + suggested follow-up (manual test with NVDA/VoiceOver,
  run /validate --full post-deploy, etc.)

## 8. Changes applied (appended by dispatcher after fix confirmation)
<Empty until /validate --fix completes STEP 3>
```

Max 600 lines. Cite file:line or tool output for every finding.
No hand-waving.

---

## STEP 5 — Fix bundle (MODE=fix only)

### Auto-fixable (include in §5)

Conservative allowlist :

| Issue | Auto-fix action |
|---|---|
| `<html>` missing `lang` | Add `lang="en"` (or detected from `<meta http-equiv="content-language">` / `package.json` `i18n`) |
| `<img>` missing `alt` AND clearly decorative (parent has `aria-hidden`, or filename matches `*icon*`/`*decoration*`/`*bg*`) | Add `alt=""` |
| Unclosed void tag (`<br>`, `<hr>`, `<img>`, `<input>`) in XHTML context | Close with ` />` |
| Duplicate `id` values | Suffix `-2`, `-3` on duplicates (keep first) |
| Heading skip h1 → h3 with single intermediate skip | Renumber h3 → h2 (ONLY if unambiguous — skip if multiple possible targets) |
| CSS unknown property with clear typo (e.g. `bakground` → `background`) | Correct typo via Levenshtein match (only if distance ≤ 2 and match unique) |
| Missing `<meta charset>` | Add `<meta charset="UTF-8">` as first child of `<head>` |
| `<title>` empty | Leave flagged — content decision (user action) |

### NOT auto-fixable (include in §6 User actions)

- Form labels (content decision)
- Color contrast (design decision)
- Alt text on content images (content decision)
- Landmark restructure (structural risk)
- `aria-describedby` / `aria-labelledby` target IDs (need context)
- Keyboard handlers on non-semantic elements (`<div onClick>` — refactor needed)
- Heading hierarchy with ambiguous correction (multiple valid fixes)

### Output

At end of §5, emit verbatim :
```
READY TO APPLY — awaiting dispatcher confirmation
```

**Do NOT apply any Edit/Write.** Dispatcher handles STEP 3 of `/validate`.

---

## Rules

- **Single agent, narrow scope.** W3C HTML + W3C CSS + WCAG 2.1 only.
  Drop anything else (meta tags, JSON-LD, perf, security, generic linting).
- **Degrade gracefully.** Missing tools → fall back to static checks.
  Never fail hard. Always produce VALIDATE.md, even in degraded mode.
- **Framework awareness.** For SPA/JS frameworks (Next/Astro/Vite/
  SvelteKit/Nuxt), validate built output (`dist/`, `_site/`, `build/`,
  `out/`), not JSX/TSX source. Note "Validated against built HTML at
  `<BUILD_DIR>`" in §0. If no build output found, warn user.
- **Respect MODE.** `audit` = no modifications. `fix` = prepare bundle,
  STOP, return control via `READY TO APPLY`.
- **Cite evidence.** Every finding : `file:line` + tool output quote.
  Empty findings or hand-waving = bug.
- **One report.** `VALIDATE.md` at project root (or `docs/VALIDATE.md`
  if convention exists). On re-run, move previous content to a
  `## Historique` section — do not overwrite silently.
- **External validators are authoritative.** If validator.nu disagrees
  with `html-validate`, trust validator.nu. If jigsaw disagrees with
  stylelint, trust jigsaw. Flag divergences as a separate finding
  (config drift or tool version mismatch).
- **WCAG level hierarchy.** Level A violations are Critique (blocks
  users). Never downgrade. RGAA 4.1 (France) maps roughly to WCAG 2.1
  AA — report both references when applicable.
- **No auto-fix on content.** Never auto-generate alt text, labels, or
  color choices. These go to §6 User actions.
