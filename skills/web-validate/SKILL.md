---
name: web-validate
description: |
  Use when a web project needs W3C HTML/CSS validity or WCAG 2.1
  accessibility audit. Dispatches the validator-analyzer agent, strict
  scope (no meta/security-header noise).
  Triggers: "validate", "w3c", "wcag", "a11y", "accessibility", "axe",
  "pa11y", "accessibilité", "conformité web".
  CSP/HSTS/404 → /harden. Meta/sitemap → /seo. AI engines → /geo.
argument-hint: "[URL] [--fix] [--local|--full] [--no-external]"
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - Agent
  - WebFetch
---

# /web-validate — web standards audit (W3C + WCAG)

## MODEL GATE (blocking — run before any other step)

Run `$HOME/.claude/lib/model-gate.md`. Reflection here (planning, audit
judgment, loop decisions) requires Fable/Opus. Verdict `small` → STOP: the
gate prints the remedy; end the turn — no later step, no dispatch. Nominal
(big) path is silent.

This skill orchestrates a narrow-scope standards audit :

- **W3C HTML validity** — validator.nu API (FULL) or `html-validate` /
  `vnu.jar` (LOCAL) or static fallback.
- **W3C CSS validity** — jigsaw.w3.org/css-validator API (FULL) or
  `stylelint` / `css-tree` (LOCAL) or static fallback.
- **WCAG 2.1 accessibility** — `pa11y` / `@axe-core/cli` / WAVE API
  (FULL) or axe against built HTML (LOCAL) or static checklist.

Scope boundary :

- **In** : HTML syntactic validity (DOCTYPE, required attrs, tag
  nesting, ID uniqueness, heading hierarchy), CSS syntactic validity
  (parsing errors, unknown properties, at-rule misuse), WCAG 2.1 A /
  AA / AAA violations (ARIA, landmarks, contrast, keyboard, SR
  affordances, alt text).
- **Out** : meta tags (title/description/OG), JSON-LD / Schema.org,
  sitemap.xml, robots.txt, llms.txt, security headers (HSTS/CSP),
  cookie flags, Core Web Vitals, image compression, hreflang, i18n
  routing, generic code linting (ESLint, Prettier), TypeScript type
  errors.

If a finding appears in an out-of-scope area (e.g. missing meta
description), the agent drops it silently — `/web-validate` stays focused.

### Relation to other skills

- `/onboard` runs an initial a11y audit at project setup (axe or
  static checklist → `.onboard-audit/a11y.md`). `/web-validate` is the
  **on-demand** equivalent, re-runnable anytime against the current
  codebase, and also covers HTML/CSS validity (which `/onboard` does
  not).
- `/harden` audits security posture (headers, TLS, redirects).
  `/web-validate` audits conformance. They share no findings.
- `/seo` and `/geo` audit indexability. They may flag the same HTML
  features (alt attrs, heading structure) but from a ranking
  perspective. `/web-validate` flags from a **standards** perspective
  (WCAG SC number, W3C rule id). Findings may overlap — both reports
  are still valid.

---

## STEP 0 — Collect context

### Parse arguments

- If `$ARGUMENTS` contains `https?://<url>` → `TARGET_URL`.
- Extract `DOMAIN` from `TARGET_URL` : `DOMAIN=${TARGET_URL#http*://}; DOMAIN=${DOMAIN%%/*}`.
- If `$ARGUMENTS` contains `--fix` → `MODE=fix`. Else `MODE=audit`.
- If `--local` → `DEPTH=LOCAL`. If `--full` → `DEPTH=FULL`.
- If URL present and no depth flag → default `DEPTH=FULL`.
- If no URL and no depth flag → default `DEPTH=LOCAL`.
- If `--no-external` → `EXTERNAL=off`. Else `on`.
- `EXTERNAL` auto-off in LOCAL mode (no URL to scan remotely).

### Detect HTML / CSS files

```bash
HTML_COUNT=$(find . -name "*.html" \
  -not -path "*/node_modules/*" \
  -not -path "*/dist/*" \
  -not -path "*/.next/*" \
  -not -path "*/.validate-cache/*" 2>/dev/null | wc -l)

CSS_COUNT=$(find . -name "*.css" \
  -not -path "*/node_modules/*" \
  -not -path "*/dist/*" \
  -not -path "*/.next/*" 2>/dev/null | wc -l)
```

If both counts are 0 and no URL provided → abort with :
```
⚠️  No HTML or CSS files found and no URL provided. /web-validate needs
   either local files or a live URL. Re-run with --full <url>.
```

### Detect framework

```bash
FRAMEWORK="static"
[ -f astro.config.mjs ] || [ -f astro.config.ts ] && FRAMEWORK="astro"
[ -f next.config.js ] || [ -f next.config.mjs ] || [ -f next.config.ts ] && FRAMEWORK="next"
[ -f vite.config.js ] || [ -f vite.config.ts ] && FRAMEWORK="vite"
[ -f svelte.config.js ] && FRAMEWORK="svelte"
[ -f nuxt.config.js ] || [ -f nuxt.config.ts ] && FRAMEWORK="nuxt"
[ -f vue.config.js ] && FRAMEWORK="vue"
```

For JS frameworks, HTML validity must target built output. Check for
build dir :

```bash
BUILD_DIR=""
for d in dist _site build out public; do
  [ -d "$d" ] && BUILD_DIR="$d" && break
done
```

If framework is JS-based and `BUILD_DIR` is empty, warn :
```
⚠️  Framework detected : <name>. No build output found.
   HTML validity on JSX/TSX source is not meaningful.
   Options :
     1. Run `npm run build` then re-run /web-validate
     2. Use --full <url> to audit production
     3. Continue with partial LOCAL audit (CSS + static WCAG only)
```

### Detect LOCAL tooling

```bash
HAS_HTML_VALIDATE=$(npx --no-install html-validate --version >/dev/null 2>&1 && echo yes || echo no)
HAS_STYLELINT=$(npx --no-install stylelint --version >/dev/null 2>&1 && echo yes || echo no)
HAS_AXE=$(npx --no-install @axe-core/cli --version >/dev/null 2>&1 && echo yes || echo no)
HAS_PA11Y=$(npx --no-install pa11y --version >/dev/null 2>&1 && echo yes || echo no)
HAS_VNU=$([ -f /usr/share/vnu/vnu.jar ] || [ -f /opt/vnu/vnu.jar ] && echo yes || echo no)
```

Missing tools are NOT blockers — agent falls back to remote APIs
(FULL) or static checks.

### Display collected context

```
VALIDATE — context
URL          : <url or — (local mode)>
Domain       : <domain or —>
Depth        : LOCAL | FULL
Mode         : audit | fix
External     : on | off (auto-off in LOCAL)
HTML files   : <N>
CSS files    : <N>
Framework    : <astro | next | vite | svelte | nuxt | vue | static>
Build dir    : <dist/ | _site/ | ... | — none found>
Local tools  : html-validate=<y/n>, stylelint=<y/n>, axe=<y/n>, pa11y=<y/n>, vnu=<y/n>
```

If MODE=fix, warn :
```
⚠️  Fixes proposés comme diffs. Appliqués seulement après confirmation.
```

---

## STEP 1 — Dispatch validator-analyzer

Spawn a single `validator-analyzer` subagent with explicit scope and
collected context :

```
Agent(
  subagent_type="validator-analyzer",
  description="validate — W3C HTML + CSS + WCAG audit",
  prompt="""
  Dispatched from /web-validate. STRICT SCOPE — W3C HTML validity + W3C
  CSS validity + WCAG 2.1 accessibility ONLY.

  CONTEXT:
    TARGET_URL       : <url or "none — LOCAL mode">
    DOMAIN           : <domain or —>
    DEPTH            : <LOCAL | FULL>
    MODE             : <audit | fix>
    EXTERNAL         : <on | off>
    HTML_FILES       : <count>
    CSS_FILES        : <count>
    FRAMEWORK        : <name>
    BUILD_DIR        : <path or "none">
    LOCAL_TOOLS      : html-validate=<y/n>, stylelint=<y/n>, axe=<y/n>, pa11y=<y/n>, vnu=<y/n>

  Execute your spec at $HOME/.claude/agents/validator-analyzer.md
  starting at STEP 1 (skip STEP 0 — context is above).

  OUT OF SCOPE — DROP silently if encountered :
    - meta tags (title/description/OG/Twitter/canonical)
    - JSON-LD / Schema.org / microdata
    - sitemap.xml, robots.txt, llms.txt
    - AI crawler directives
    - security headers (HSTS/CSP/X-Frame-Options/cookie flags)
    - Core Web Vitals, perf budgets
    - hreflang, i18n routing
    - image compression, video formats
    - generic code linting (ESLint, Prettier, TS errors)

  Mode behavior :
    - MODE=audit : NO file modifications. Report-only. Propose fixes
      as diffs in the report (```diff blocks), do NOT apply.
    - MODE=fix   : Report issues, then produce Fix bundle (§5) with
      concrete diffs for auto-fixable items. STOP and emit
      "READY TO APPLY — awaiting dispatcher confirmation" at the end
      of §5. Do NOT apply any Edit/Write — the dispatcher handles STEP 3.

  Output: write <PROJECT_ROOT>/.claude/audits/VALIDATE.md (run `mkdir -p .claude/audits` first) per the structure in your
  spec (sections 0-8, score XX/100).
  """
)
```

---

## STEP 2 — Verify output

```bash
test -s .claude/audits/VALIDATE.md && wc -l .claude/audits/VALIDATE.md || echo "MISSING .claude/audits/VALIDATE.md"
```

If missing or empty :
```
⚠️  validator-analyzer did not produce .claude/audits/VALIDATE.md. Options :
  A) Retry with same scope
  B) Downgrade to LOCAL and retry (if FULL failed on network)
  C) Abort
```

Extract the score and critical-alert count from `.claude/audits/VALIDATE.md` for the
console summary :

```bash
grep -oE '\*\*Score\*\*\s+:\s+[0-9]+ / 100' .claude/audits/VALIDATE.md | head -1
grep -c '^### \[Critique\]' .claude/audits/VALIDATE.md
```

---

## STEP 2b — CHALLENGE THE FIX BUNDLE (MODE=fix only, advisory)
Skip if MODE=audit (no bundle exists). Else, before the STEP 3 gate, harden the bundle:
extract the `## 5. Fix bundle` section from VALIDATE.md to
`.claude/tasks/plans/<date>-<slug>-<HHMM>.md` (a clean, blind-judgeable artifact), then run
`$HOME/.claude/lib/challenge-plan.md` with `PLAN` = that file, `KIND` = `fix-bundle`,
`SCOPE` = the HTML/CSS files each fix touches, `CONSTRAINTS` = the STEP 1 strict scope (W3C
validity + WCAG 2.1) + the conservative auto-fix rule (structural/syntactic only, content →
§6) + the shared-template discipline (targeted Edit, never Write — templates carry /seo +
/geo content). Three blind challengers ask, per fix: will it ACHIEVE conformance / could it
BREAK rendering or regress another SC / is a simpler fix better. This main loop RE-THINKS
every aspect a BLOCKER lands (a named bundle change, or `[deferred <date>]`) and re-challenges
once if the bundle materially changed. Advisory — it sits BEFORE (never replaces) the STEP 3
confirmation; carry its CHALLENGE SUMMARY into that gate.

---

## STEP 3 — Apply fixes (MODE=fix only)

Skip this step if `MODE=audit`.

If `.claude/audits/VALIDATE.md` ends with `READY TO APPLY — awaiting dispatcher confirmation` :

1. Parse the `## 5. Fix bundle` section.
2. Group by file. For each group, show the combined diff to the user.
3. Ask :

```
VALIDATE — fix bundle ready

Files to modify (N) :
  - src/Layout.astro       (3 fixes : lang attr, alt="", heading renumber)
  - src/styles/main.css    (1 fix : invalid property removed)
  - src/pages/contact.html (2 fixes : unclosed tag, duplicate id)

Critical : X | Haute : Y | Moyenne : Z | Basse : W

CHALLENGE SUMMARY (STEP 2b — 3 lenses) :
  BLOCKERs addressed : <n> — <finding → the named bundle change that closes it>
  Deferred (human-ack): <list | none>
  Lenses returned    : correctness / robustness / simplicity (NAME any that failed to return)

Options :
  A) Apply all
  B) Review each diff before applying
  C) Apply only Critique + Haute
  D) Abort — keep .claude/audits/VALIDATE.md as audit report
```

4. On `A` : dispatch each file-group's applier at L1 (execution = sonnet;
   this loop only orchestrates), serially — one applier at a time, appliers
   share files:

   ```
   Agent(subagent_type="hotfixer")
   prompt: "<paste the file-group's bundle items: file, issue, current,
     expected fix>.
     Context: web-validate fix bundle, user-approved scope — no
     confirmation needed. Apply via targeted Edit (old_string/new_string);
     NEVER Write whole files (shared templates carry /seo and /geo
     content — meta tags, JSON-LD). Do NOT commit — apply and self-verify
     only."
   ```

5. On `B` : for each diff, show and ask yes/no/skip; apply approved diffs
   as in `A` (hotfixer dispatch).
6. On `C` : filter to Critique + Haute, then behave as `A`.
7. On `D` : stop, leave `.claude/audits/VALIDATE.md` untouched.

After applying, append a `## 8. Changes applied` section with
commit-ready summary lines :

```markdown
## 8. Changes applied

Date : <ISO-8601>
Files modified : <N>
Fixes applied : <N>

### src/Layout.astro
- [Haute][HTML] Added `lang="en"` to `<html>` (WCAG 3.1.1, W3C required attr)
- [Haute][WCAG AA] Added `alt=""` to decorative icon at line 42
- [Moyenne][HTML] Renumbered h3 → h2 (heading hierarchy, line 67)

### src/styles/main.css
- [Moyenne][CSS] Removed invalid property `bakground` → `background` at line 23

Verification :
- Re-run /web-validate → expected score bump <before> → <after>
- Tests to run : a11y regression (pa11y-ci), visual snapshot
```

Never apply fixes without explicit confirmation.
Never use `--no-verify` on git hooks.

---

## STEP 4 — Console summary

```
VALIDATE AUDIT COMPLETE
URL              : <url or static>
Depth            : LOCAL | FULL
Mode             : audit | fix
Score            : XX / 100  (<before> → <after> if fix applied)
Report           : .claude/audits/VALIDATE.md

BREAKDOWN :
  W3C HTML         : <N errors / M warnings>
  W3C CSS          : <N errors / M warnings>
  WCAG 2.1         : <N A> / <M AA> / <K AAA> violations, <L incomplete>

TOP 3 ACTIONS (by severity × user impact) :
  1. [Critique] <title> — <file:line>
  2. [Haute]    <title>
  3. [Haute]    <title>

NEXT STEPS :
  • /web-validate <url> --fix         → apply recommended fixes
  • /web-validate <url> --full        → re-run with live URL + remote APIs
  • /web-validate --no-external       → skip third-party APIs (faster, LOCAL-like)
  • /harden / /seo / /geo         → complementary audits (other scopes)

Install for better LOCAL coverage :
  npm i -D html-validate stylelint @axe-core/cli pa11y
```

---

## Rules

- **Scope is non-negotiable.** If you find yourself reporting meta
  tags, sitemap, CSP, or JSON-LD, you drifted. Drop it. `/harden`,
  `/seo`, `/geo` own those respectively.
- **Single agent dispatch.** Only `validator-analyzer`. No parallel
  fan-out.
- **Never apply fixes without user confirmation**, even in `--fix`.
  The fix mode prepares the bundle; the dispatcher confirms (A/B/C/D).
- **LOCAL vs FULL is about data sources**, not scope. Both cover the
  same 3 axes. LOCAL may be degraded if local tools missing (agent
  falls back to static checks — flagged "STATIC MODE" in report).
- **Framework awareness.** For SPA/JS frameworks, validate built
  output (`dist/`, `_site/`, `build/`, `out/`), not JSX/TSX source.
  Warn if no build dir present.
- **Public websites must ship WCAG 2.1 AA** (France: RGAA 4.1) when in
  scope. Flag AA violations as Haute, A violations as Critique.
- **External validators are authoritative on live URLs.** validator.nu
  and jigsaw are the W3C backends. If a local tool disagrees with
  them, trust the W3C backend; flag the divergence as a finding.
- **One report file.** `.claude/audits/VALIDATE.md`. On re-run, move
  previous content to a `## Historique` section, do not overwrite
  silently.
- **Cache dir.** `.validate-cache/` (gitignored) stores raw tool
  outputs for debugging. Do not commit.
- **Conservative auto-fix.** Only structural/syntactic fixes with no
  ambiguity. Content decisions (alt text, labels, contrast choices)
  always go to §6 User actions — never auto-applied.
