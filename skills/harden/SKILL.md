---
name: harden
description: |
  Web hardening audit — transport (HTTPS/TLS, HTTP→HTTPS redirect, HSTS),
  security headers (CSP, X-Frame-Options, X-Content-Type-Options,
  Referrer-Policy, Permissions-Policy), cookie flags (Secure, HttpOnly,
  SameSite), canonical URLs, custom 404, and server config hardening
  (.htaccess, nginx.conf, netlify.toml, vercel.json, _headers, _redirects,
  wrangler.toml). Dispatches the seo-analyzer agent with a STRICT scope
  filter — no meta/OG/JSON-LD/sitemap/CWV/headings/alt/i18n noise.
  Produces HARDEN.md at project root.
  Trigger: "harden", "web hardening", "ssl audit", "https audit",
  "hsts", "csp", "security headers", "http to https", "redirect audit",
  "htaccess audit", "404 page", "canonical audit", "transport security",
  "durcissement web", "audit sécurité web", "entêtes sécurité".
  For full SEO audit (meta/OG/JSON-LD/sitemap/CWV) → use /seo.
  For AI search / llms.txt / AI crawlers → use /geo.
  For secrets / dependency CVEs / OWASP code-level → use /cso.
argument-hint: [URL] [--fix] [--local|--full] [--no-external]
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

# /harden — web hardening audit

This skill orchestrates a narrow-scope hardening audit: TLS + security
headers + redirects + canonical + custom 404 + server configs. It
reuses the `seo-analyzer` agent with a **strict scope filter** to avoid
producing a full SEO report.

Scope boundary:
- **In**: HTTPS transport, HSTS, CSP, X-Frame-Options, X-Content-Type-Options,
  Referrer-Policy, Permissions-Policy, cookie flags, canonical URL
  correctness, custom 404 (status + presence), `.htaccess` / nginx.conf /
  netlify.toml / vercel.json / `_headers` / `_redirects` / wrangler.toml
  hardening.
- **Out**: meta tags (title/description/OG/Twitter), JSON-LD / Schema.org,
  sitemap.xml, robots.txt directives (except hardening-related rewrites),
  hreflang, i18n, headings, alt attrs, image compression, Core Web Vitals,
  GMB/NAP, content, llms.txt, AI crawlers. Those are owned by `/seo` and
  `/geo`.

If a finding appears in an out-of-scope file (e.g. meta tag duplication),
it is dropped silently — `/harden` stays focused.

## External validators (FULL mode only)

In addition to the code-level + live-curl audit, `/harden` queries three
independent third-party grading services and embeds their verdict in the
report. These are the industry-standard cross-checks users will run
anyway — better to have them inside the report than force the user to
copy-paste URLs.

| Validator | URL | API? | Latency | What it grades |
|---|---|---|---|---|
| **Mozilla Observatory** | observatory.mozilla.org | Yes (v2 JSON) | ~10s | HTTP headers, CSP, HSTS, cookie flags, CORS (score 0-135 + grade A+..F) |
| **SecurityHeaders.com** | securityheaders.com | No (HTML scrape) | ~5s | HTTP security headers (grade A+..F) |
| **SSL Labs** | ssllabs.com/ssltest | Yes (v3 JSON, async) | 1-3 min | TLS config, cipher suites, cert chain (grade A+..F + T for trust issues) |

Skip with `--no-external`. Skipped automatically in LOCAL mode (need a
live URL).

---

## STEP 0 — Collect context

### Parse arguments

- If `$ARGUMENTS` contains an `https?://` URL → capture as `TARGET_URL`.
- Extract `DOMAIN` from `TARGET_URL` : `DOMAIN=${TARGET_URL#http*://}; DOMAIN=${DOMAIN%%/*}`.
- If `$ARGUMENTS` contains `--fix` → `MODE=fix`. Else `MODE=audit` (default).
- If `$ARGUMENTS` contains `--local` → `DEPTH=LOCAL`.
- If `$ARGUMENTS` contains `--full` → `DEPTH=FULL`.
- If neither `--local` nor `--full` but `TARGET_URL` present → default `DEPTH=FULL`.
- If neither and no URL → default `DEPTH=LOCAL`.
- If `$ARGUMENTS` contains `--no-external` → `EXTERNAL=off`. Else `EXTERNAL=on` (default).
- `EXTERNAL` is ignored in LOCAL mode (skipped silently — no URL to scan).

### Detect config files

```bash
ls .htaccess nginx.conf netlify.toml vercel.json wrangler.toml _headers _redirects \
   .well-known/ 2>/dev/null
# Framework-level redirect/header sources
ls next.config.js next.config.mjs next.config.ts \
   astro.config.mjs astro.config.ts \
   middleware.ts middleware.js \
   2>/dev/null
```

Record presence. Missing config files are **not** automatically a problem
— a Next.js app may configure headers via `next.config.js` headers() or
middleware.ts. Don't recommend `.htaccess` on a Next app.

### FULL mode probe (only if DEPTH=FULL)

```bash
# Resolve redirect chain
curl -sI -o /dev/null -w "URL: %{url_effective}\nCODE: %{http_code}\nREDIRS: %{num_redirects}\n" -L "$TARGET_URL"
# Live headers (HTTPS)
curl -sI "https://${TARGET_URL#https://}" | head -40
# HTTP → HTTPS redirect check
curl -sI "http://${TARGET_URL#https://}" | head -10
```

Store raw outputs for the agent.

### Display collected context

```
HARDEN — context
URL          : <url or — (static mode)>
Domain       : <domain or —>
Depth        : LOCAL | FULL
Mode         : audit | fix
External     : on | off (auto-off in LOCAL)
Config files : [.htaccess, nginx.conf, ...] or — none detected
Framework    : [next | astro | wordpress | static-html | other]
```

In `fix` mode, warn: `⚠️  Fixes will be proposed as diffs. Applied only after confirmation.`

---

## STEP 0b — Launch external validators (FULL + EXTERNAL=on only)

Skip this step entirely if `DEPTH=LOCAL` or `EXTERNAL=off`.

Create `.harden-cache/` (gitignored) to store raw scan outputs :

```bash
mkdir -p .harden-cache
grep -q '^\.harden-cache/' .gitignore 2>/dev/null || \
  printf '\n# /harden external scan cache\n.harden-cache/\n' >> .gitignore
```

### 1) SSL Labs — launch in background (slowest, 1-3 min)

Try cached result first (`maxAge=24` returns a scan < 24h old instantly) :

```bash
curl -s --max-time 15 \
  "https://api.ssllabs.com/api/v3/analyze?host=${DOMAIN}&maxAge=24&all=done" \
  > .harden-cache/ssllabs.json
```

Check status :
```bash
jq -r '.status // "ERROR"' .harden-cache/ssllabs.json
```

If `READY` → done, cached hit. Skip background launch.
If `IN_PROGRESS` or `DNS` → a scan is already running — poll in STEP 1.5.
If anything else (ERROR, empty, missing) → start a fresh scan in background :

```bash
curl -s --max-time 15 \
  "https://api.ssllabs.com/api/v3/analyze?host=${DOMAIN}&startNew=on&all=done&ignoreMismatch=on" \
  > .harden-cache/ssllabs.json
```

This only STARTS the scan — the response body contains `status=DNS` or
`status=IN_PROGRESS`. We poll in STEP 1.5 while `seo-analyzer` runs.

### 2) Mozilla Observatory — synchronous, fast (~10s)

API v2 : `POST https://observatory-api.mdn.mozilla.net/api/v2/scan?host=DOMAIN`

```bash
curl -s --max-time 30 -X POST \
  "https://observatory-api.mdn.mozilla.net/api/v2/scan?host=${DOMAIN}" \
  -o .harden-cache/observatory.json
```

Extract headline :
```bash
jq -r '"Grade: \(.grade // "N/A") | Score: \(.score // "N/A") / 135 | Tests passed: \(.tests_passed // 0) / \(.tests_quantity // 0)"' \
  .harden-cache/observatory.json 2>/dev/null \
  || echo "Observatory: FAILED"
```

### 3) SecurityHeaders.com — synchronous HTML scrape (~5s)

No public API. Fetch the HTML report page and extract the grade from the
response markup :

```bash
curl -sL --max-time 30 \
  "https://securityheaders.com/?q=${TARGET_URL}&hide=on&followRedirects=on" \
  > .harden-cache/securityheaders.html
```

Extract grade. The page embeds the grade in a `<div class="score score_X">`
container where `X` is lowercase of A/B/C/D/E/F/R. Fallback patterns in case
they change markup :

```bash
grep -oE 'class="score_[a-f]"' .harden-cache/securityheaders.html | head -1 \
  | sed 's/.*score_\([a-f]\).*/\1/' | tr 'a-f' 'A-F' \
  || grep -oE 'Security Report Summary - [A-F][+]?' .harden-cache/securityheaders.html | head -1
```

If both fail, fall back to WebFetch : `WebFetch(url="https://securityheaders.com/?q=${TARGET_URL}", prompt="extract the letter grade (A+..F) from the 'Security Report Summary' section")`.

Also extract the per-header checklist (X-Frame-Options: present/missing, CSP: present/missing, etc.) from the HTML to feed the seo-analyzer :

```bash
grep -oE '(X-Frame-Options|Strict-Transport-Security|Content-Security-Policy|X-Content-Type-Options|Referrer-Policy|Permissions-Policy)[^<]{0,50}' \
  .harden-cache/securityheaders.html | sort -u > .harden-cache/securityheaders-findings.txt
```

### 4) Write a partial external-scores summary

```bash
{
  echo "# External validators — partial results"
  echo "Domain: ${DOMAIN}"
  echo "Timestamp: $(date -Iseconds)"
  echo
  echo "## Mozilla Observatory"
  jq -r '"Grade: \(.grade // "PENDING")\nScore: \(.score // "PENDING") / 135\nTests: \(.tests_passed // 0)/\(.tests_quantity // 0) passed\nFailed tests: \(.tests_failed // 0)"' \
    .harden-cache/observatory.json 2>/dev/null || echo "FAILED — check .harden-cache/observatory.json"
  echo
  echo "## SecurityHeaders.com"
  echo "Grade: $(grep -oE 'score_[a-f]' .harden-cache/securityheaders.html 2>/dev/null | head -1 | sed 's/score_//' | tr a-f A-F || echo "PENDING")"
  echo "Findings:"
  cat .harden-cache/securityheaders-findings.txt 2>/dev/null || echo "  (none extracted)"
  echo
  echo "## SSL Labs"
  jq -r '"Status: \(.status // "PENDING")\nEndpoints: \(.endpoints | length // 0)\nOverall grade: \(.endpoints[0].grade // "PENDING")"' \
    .harden-cache/ssllabs.json 2>/dev/null || echo "PENDING — poll in STEP 1.5"
} > .harden-cache/external-scores.md
```

### 5) Display to user

```
EXTERNAL VALIDATORS — partial results
Mozilla Observatory : <Grade>  (score / 135)
SecurityHeaders.com : <Grade>
SSL Labs            : <Status — PENDING if still running, grade if READY>

(Full JSON/HTML cached in .harden-cache/ — SSL Labs poll continues during audit.)
```

Do NOT block on SSL Labs here. Continue to STEP 1 immediately — the
seo-analyzer will run in parallel.

---

## STEP 1 — Dispatch seo-analyzer (narrow scope)

Spawn a single seo-analyzer subagent with an explicit IN/OUT scope list.

```
Agent(
  subagent_type="seo-analyzer",
  description="harden — narrow-scope web hardening audit",
  prompt="""
  Dispatched from /harden. NARROW-SCOPE audit — DO NOT produce a full
  SEO report. You are acting as a hardening auditor, not a marketing-SEO
  auditor.

  CONTEXT:
    TARGET_URL       : <url or "none — LOCAL mode">
    DEPTH            : <LOCAL | FULL>
    MODE             : <audit | fix>
    CONFIG_FILES     : <list>
    FRAMEWORK        : <name>
    EXTERNAL_SCORES  : <path to .harden-cache/external-scores.md, or "none — skipped">

  If EXTERNAL_SCORES is provided, READ that file before starting. It
  contains grades from Mozilla Observatory, SecurityHeaders.com, and
  (possibly, if READY) SSL Labs. Use those as independent cross-checks
  of your own findings :
    - If Observatory grade is A/A+ but you found CSP missing in the code
      → re-verify; Observatory is authoritative on live headers
    - If SecurityHeaders grade is F but your code audit says "all good"
      → the deployed config differs from the source — flag it
    - Quote the grades verbatim in the report's "External validators"
      section — do not summarize, do not re-grade

  STRICT SCOPE — audit ONLY these areas:

    1. Transport (HTTPS / TLS)
       - HTTP → HTTPS redirect (301 permanent, no meta-refresh, no JS)
       - Redirect chain length ≤ 1 (no HTTP → www → HTTPS → canonical)
       - TLS version (≥ 1.2, prefer 1.3) — FULL only
       - Cookie flags : Secure, HttpOnly, SameSite=Lax|Strict on auth cookies

    2. HSTS
       - Strict-Transport-Security header present
       - max-age ≥ 31536000 (1 year)
       - includeSubDomains directive
       - preload directive (optional but recommended if eligible)

    3. Security headers
       - Content-Security-Policy : present, no unsafe-inline/unsafe-eval
         unless justified, report-uri/report-to endpoint if available
       - X-Frame-Options : DENY or SAMEORIGIN
       - X-Content-Type-Options : nosniff
       - Referrer-Policy : no-referrer | strict-origin-when-cross-origin
       - Permissions-Policy : restrictive scope (camera=(), microphone=(), etc.)
       - Cross-Origin-Opener-Policy : same-origin (recommended)
       - Cross-Origin-Resource-Policy : same-origin (recommended)

    4. Canonical
       - <link rel="canonical"> present on every HTML page
       - href is ABSOLUTE URL (not relative)
       - Canonical target matches the final URL after redirects
         (no canonical → redirect chain)
       - No conflicting canonical + robots noindex
       - Self-referential canonical on homepage

    5. Error pages (status + presence)
       - Custom 404 page present (not the default server page)
       - 404 route returns status code 404 (not 200 "soft 404")
       - Optional : custom 500 page with status 500
       - ErrorDocument / error_page directive configured

    6. Server config hardening (LOCAL : grep; FULL : verify headers live)
       - .htaccess : RewriteRule for HTTP→HTTPS, Header set CSP/HSTS/etc.,
         ErrorDocument 404, Options -Indexes
       - nginx.conf : return 301 https://, add_header, error_page 404,
         autoindex off
       - netlify.toml / _headers / _redirects : [[headers]] + [[redirects]]
         with status=301 force=true
       - vercel.json : headers[] + redirects[] arrays with permanent=true
       - wrangler.toml / Cloudflare : headers transform rules
       - Framework-native : Next.js next.config headers()/redirects()/
         middleware, Astro astro.config.integrations

  OUT OF SCOPE — DO NOT report any of the following, even if you see it:
    - meta title, description, OG tags, Twitter cards
    - JSON-LD / Schema.org / microdata / RDFa
    - sitemap.xml, image/video sitemaps
    - robots.txt classical directives (User-agent, Disallow for crawl budget)
    - AI crawler directives (GPTBot, ClaudeBot, etc.) — owned by /geo
    - llms.txt, llms-full.txt — owned by /geo
    - hreflang, lang attribute, i18n
    - headings hierarchy, heading content
    - alt attributes, image formats, image compression
    - Core Web Vitals (LCP, INP, CLS), perf budgets
    - GMB, NAP, local SEO, reviews, citations
    - Legal pages (mentions légales, CGV, privacy) — unless the issue is
      a security-header gap on those pages, not their content
    - Content quality, keyword density, readability
    - a11y / WCAG (owned by /onboard a11y dispatch)

  If you detect an out-of-scope issue, DROP IT silently. Do NOT mention
  it even as a "note". Stay focused.

  Mode behavior :
    - MODE=audit : NO file modifications. Report-only. Propose fixes as
      diffs embedded in the report (```diff blocks), but do NOT apply.
    - MODE=fix   : Report issues first, then for each Critique/Haute
      issue produce a concrete diff. STOP and emit
      "READY TO APPLY — awaiting dispatcher confirmation" at the end.
      Do NOT apply any Edit/Write — the dispatcher handles STEP 3.

  OUTPUT — write to <PROJECT_ROOT>/HARDEN.md :

    # Web Hardening Report — <project_name>

    **Date**       : <YYYY-MM-DD>
    **URL**        : <url or "static mode">
    **Depth**      : LOCAL | FULL
    **Mode**       : audit | fix
    **Score**      : XX / 100

    ## 0. Critical alerts
    <only Critique-severity items, 1-line each>

    ## 1. Score breakdown
    | Area              | Score | Status |
    | Transport         | XX/20 | ✅/⚠️/❌ |
    | HSTS              | XX/15 | ... |
    | Security headers  | XX/25 | ... |
    | Canonical         | XX/10 | ... |
    | Error pages       | XX/10 | ... |
    | Config hardening  | XX/20 | ... |

    ## 1.bis External validators (FULL mode only)
    Independent third-party grades. Include verbatim — no re-grading.

    | Validator              | Grade | Detail                              | Link |
    |---|---|---|---|
    | Mozilla Observatory    | <A+>  | <score>/135 — <N>/<M> tests passed  | https://developer.mozilla.org/en-US/observatory/analyze?host=<domain> |
    | SecurityHeaders.com    | <A>   | <missing headers list>              | https://securityheaders.com/?q=<url> |
    | SSL Labs (Qualys)      | <A+>  | TLS <1.3> — <cert-chain-note>       | https://www.ssllabs.com/ssltest/analyze.html?d=<domain> |

    If any validator status is PENDING at write time (SSL Labs timeout),
    note: `⚠️ SSL Labs scan did not finish within timeout — re-run /harden
    in a few minutes for the grade. Live URL: <link>`.

    ### Divergences between code audit and external validators
    If your code-level findings contradict what external validators
    report (e.g. you said "CSP looks good" but Observatory says CSP
    missing), list each divergence here with probable cause (config
    drift, CDN overriding headers, conditional headers, etc.).

    ## 2. Transport (HTTPS/TLS)
    ### [Severity] <issue title>
    **Evidence** : <curl output | fichier:ligne>
    **Impact**   : <1 sentence>
    **Fix**      :
    ```diff
    <concrete diff>
    ```

    ## 3. HSTS
    ## 4. Security headers
    ## 5. Canonical
    ## 6. Error pages
    ## 7. Server config hardening

    ## 8. Fix bundle (MODE=fix only)
    Grouped patches by file :
    - `.htaccess` : <N fixes> (1 bundle)
    - `next.config.js` : <N fixes>
    - ...
    Each bundle = one Edit/Write operation.
    At the end : `READY TO APPLY — awaiting dispatcher confirmation`

    ## 9. Appendix — not auditable
    <what couldn't be checked + why>

  Scoring :
    - 100/100 = no issues at any severity
    - Each Critique : -15
    - Each Haute    : -8
    - Each Moyenne  : -3
    - Each Basse    : -1
    - Clamp [0, 100]

  Severity guide :
    - Critique : HTTP → HTTPS missing, CSP absent on public site,
      cookie without Secure+HttpOnly on auth, soft 404 (200 code on
      missing route), .env in repo with live creds
    - Haute    : HSTS absent or max-age < 1 year, X-Frame-Options missing,
      canonical pointing to a redirect, no custom 404
    - Moyenne  : Referrer-Policy missing, includeSubDomains missing,
      redirect chain length > 1
    - Basse    : preload directive missing, COOP/CORP absent,
      Permissions-Policy not explicit

  Max 600 lines. Cite file:line or curl output for every finding.
  """
)
```

---

## STEP 1.5 — Finalize SSL Labs (FULL + EXTERNAL=on only)

Skip if LOCAL or EXTERNAL=off or if `.harden-cache/ssllabs.json` already shows `status=READY` in STEP 0b.

While seo-analyzer was running, the SSL Labs scan has had ~30-90s of
runtime. Poll with short waits, bounded by a 180s cap. Do NOT use long
leading sleeps — short polls avoid harness sleep-blocking.

```bash
# Poll loop — max 180s total (12 iterations × 15s), exit early on READY/ERROR
for i in $(seq 1 12); do
  curl -s --max-time 15 \
    "https://api.ssllabs.com/api/v3/analyze?host=${DOMAIN}" \
    > .harden-cache/ssllabs.json
  STATUS=$(jq -r '.status // "ERROR"' .harden-cache/ssllabs.json)
  echo "SSL Labs poll $i/12 — status=$STATUS"
  case "$STATUS" in
    READY|ERROR) break ;;
  esac
  sleep 15
done
```

After the loop :
```bash
FINAL_STATUS=$(jq -r '.status // "TIMEOUT"' .harden-cache/ssllabs.json)
if [ "$FINAL_STATUS" = "READY" ]; then
  jq -r '.endpoints[] | "  • \(.ipAddress) — grade \(.grade // "N/A") — \(.statusMessage // "")"' \
    .harden-cache/ssllabs.json
else
  echo "⚠️  SSL Labs did not finalize within 180s (status=$FINAL_STATUS)"
  echo "    Result cached — will auto-hit on re-run via maxAge=24"
fi
```

Update `.harden-cache/external-scores.md` with the final SSL Labs verdict
so the HARDEN.md "External validators" table reflects it. If the user
already read HARDEN.md, they can re-run `/harden <url>` to pick up the
cached (now-READY) SSL Labs result.

---

## STEP 2 — Verify output

```bash
test -s HARDEN.md && wc -l HARDEN.md || echo "MISSING HARDEN.md"
```

If missing or empty :
```
⚠️  seo-analyzer did not produce HARDEN.md. Options:
  A) Retry with same scope
  B) Downgrade to LOCAL and retry (if FULL failed on network)
  C) Abort
```

Extract the score and critical-alert count from HARDEN.md for the console summary.

---

## STEP 3 — Apply fixes (MODE=fix only)

Skip this step if MODE=audit.

If MODE=fix and HARDEN.md ends with `READY TO APPLY — awaiting dispatcher confirmation` :

1. Parse the `## 8. Fix bundle` section from HARDEN.md.
2. Group by file. For each group, show the combined diff to the user.
3. Ask :
   ```
   HARDEN — fix bundle ready

   Files to modify (N) :
     - .htaccess           (3 fixes : HTTP→HTTPS redirect, HSTS, 404 page)
     - next.config.js      (2 fixes : CSP header, X-Frame-Options)

   Options :
     A) Apply all
     B) Review each diff before applying
     C) Apply only Critique severity
     D) Abort — keep HARDEN.md as audit report
   ```
4. On `A` : apply each bundle via Edit (targeted old_string/new_string,
   never full-file Write on shared templates).
5. On `B` : for each diff, show and ask yes/no/skip.
6. On `C` : filter to Critique-only, then behave as `A`.
7. On `D` : stop, leave HARDEN.md untouched.

After applying : append a `## 10. Changes applied` section to HARDEN.md
with commit-ready summary lines.

Never apply fixes without explicit confirmation. Never use `--no-verify`
on git hooks if a pre-commit hook exists and runs during fix application.

---

## STEP 4 — Console summary

```
HARDEN AUDIT COMPLETE
URL              : <url or static>
Depth            : LOCAL | FULL
Mode             : audit | fix
Score            : XX / 100  (<before> → <after> if fix applied)
Critical alerts  : <N>  (voir HARDEN.md § 0)
Report           : HARDEN.md

EXTERNAL VALIDATORS (FULL only) :
  Mozilla Observatory   : <Grade>   (score/135)
  SecurityHeaders.com   : <Grade>
  SSL Labs (Qualys)     : <Grade>   (TLS <version>)
  [if SSL Labs TIMEOUT] ⚠️ re-run /harden <url> in a few minutes — cached

TOP 3 ACTIONS (by severity × exploitability) :
  1. [Critique] <title>
  2. [Haute]    <title>
  3. [Haute]    <title>

NEXT STEPS :
  • /harden <url> --fix          → apply recommended fixes
  • /harden <url> --full          → re-run with live HTTP probing
  • /harden <url> --no-external  → skip third-party scanners (faster)
  • /hotfix <specific issue>     → quick fix on a single finding
  • /seo / /geo / /cso            → complementary audits (other scopes)
```

---

## Rules

- **Scope is non-negotiable.** If you find yourself reporting meta tags,
  sitemap, or JSON-LD, you drifted. Drop it. `/seo` owns that.
- **Single agent dispatch.** No parallel fan-out. Only seo-analyzer is
  needed — it already owns `.htaccess` and security headers per `/seo`
  ownership matrix.
- **Never apply fixes without user confirmation**, even in `--fix`. The
  fix mode prepares the bundle; the dispatcher confirms.
- **LOCAL vs FULL is about data sources**, not scope. Both cover the
  same 6 areas. LOCAL is blind to live HSTS/CSP headers on production.
- **Framework awareness.** Don't recommend `.htaccess` on a Next.js /
  Astro / Cloudflare Pages project. Use the framework-native mechanism
  (next.config.js headers(), astro middleware, _headers).
- **Respect CLAUDE.md architecture rules.** Security headers and redirects
  are non-negotiable defaults per user's global CLAUDE.md — every public
  site must ship them. Flag absence as Critique, not Moyenne.
- **External validators are authoritative on live headers, not the code.**
  If Observatory/SecurityHeaders/SSL Labs and the code audit disagree,
  the external grade reflects the deployed production config — the code
  audit reflects source. Both matter; the divergence itself is a finding
  (config drift, CDN override, conditional middleware). Quote external
  grades verbatim, never re-grade them.
- **SSL Labs can be slow and fail-soft.** 180s poll cap. If TIMEOUT,
  note it in HARDEN.md and move on. Cached result auto-hits on next run
  via `maxAge=24`. Never block the whole audit waiting on SSL Labs.
- **One report file.** `HARDEN.md` at project root (or `docs/HARDEN.md`
  if that convention exists). On re-run, move previous content to a
  `## Historique` section, do not overwrite silently.
