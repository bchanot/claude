# seo-data — GSC + CrUX data layer for `/seo` FULL audits

Small, isolated engine that gives the `/seo` skill real Google data instead of
guesses: **Search Console** (queries, positions, indexation) and **CrUX**
(Core Web Vitals *field* data — real users, not lab simulation). It knows
nothing about SEO scoring; it only turns Google APIs into normalized JSON.
The `seo-analyzer` agent consumes that JSON in STEP 4 (Core Web Vitals) and
the new "Performance GSC" subsection; the `/seo` skill selects the account
and property in STEP 0 of a FULL audit (not needed for LOCAL).

Multi-account by design: the token store is keyed by a user-chosen label, and
every call takes `--account`/`--property` explicitly. Two audits running at
the same time (two sites, two sessions) never share mutable state — nothing
is written to disk during an audit, only at `make seo-connect`.

## Setup

One-time per Google account:

```bash
make seo-connect                                        # from the claude-config repo
bash ~/.claude/lib/seo-data/connect.sh --label <label>  # from ANY directory (venv must exist)
```

`make seo-connect` creates `~/.claude/.venv-seo-data/` (isolated venv, deps
pinned in `requirements.txt`), installs `google-auth`,
`google-auth-oauthlib`, `requests`, then delegates to `connect.sh`. The
wrapper sources `~/.claude/.env` internally, prefers the venv python, and
runs `connect.py`: it opens a browser for OAuth consent and takes a
**label** (e.g. `client-a`) to key the account — pick a name, not an email,
since the store never stores or requests the account's email. Once the venv
exists, `connect.sh` alone connects further accounts from anywhere (the
`/seo connect [label]` skill verb uses exactly this path).

Before running it, set these 3 keys in `~/.claude/.env` (the canonical
vault; `link.sh` only symlinks the repo's `.env` to it and warns with a
`cp .env.example .env` hint if it's missing — it never creates the vault
itself):

```bash
GOOGLE_OAUTH_CLIENT_ID=<your-client-id>.apps.googleusercontent.com
GOOGLE_OAUTH_CLIENT_SECRET=<your-client-secret>
CRUX_API_KEY=<your-crux-api-key>
```

- `GOOGLE_OAUTH_CLIENT_ID` / `GOOGLE_OAUTH_CLIENT_SECRET` — OAuth2 "Desktop
  app" credentials from the Google Cloud Console (APIs & Services →
  Credentials). Shared across every account you connect; the OAuth scope
  requested is `https://www.googleapis.com/auth/webmasters.readonly` only
  — read-only Search Console, nothing can be modified or deleted via this
  token.
- `CRUX_API_KEY` — a Chrome UX Report API key (restrict it to CrUX +
  PageSpeed in the Console). Get one at
  https://developer.chrome.com/docs/crux/api. No OAuth involved: CrUX is
  public field data, gated by API key only, independent of any connected
  account.

`make seo-connect` is idempotent and rerunnable — connecting a second
account just runs it again with a different label; reusing an existing
label prompts to overwrite.

## `fetch.sh` contract

`lib/seo-data/fetch.sh` is the one stable entrypoint analyzers call. It
sources `~/.claude/.env`, prefers the isolated venv (falls back to system
`python3` for stdlib-only paths), dispatches to `google_seo.py` or
`tokenstore.py`, and never prints a secret to stdout or stderr.

```bash
fetch.sh accounts
  → {"status":"ok","accounts":[{"label":"…","properties":[…],"granted_at":"…"}]}   # [] if none connected

fetch.sh crux    --url https://ex.com [--strategy mobile|desktop]
  → {"status":"ok","source":"crux","lcp_p75_ms":…,"inp_p75_ms":…,"cls_p75":…}      # a missing metric omits its key
  → {"status":"degraded","reason":"no_crux_key"|"no_field_data"|"rate_limited"}
  # a 404 on page-level data retries at origin-level before degrading

fetch.sh queries --account client-a --property sc-domain:ex.com [--days 90] [--dim query|page]
  → {"status":"ok","source":"gsc","dimension":"query","rows":[{"key":"…","clicks":…,"impressions":…,"ctr":…,"position":…}]}
  → {"status":"degraded","reason":"no_credentials"|"token_revoked"|"network_error"|"rate_limited"}

fetch.sh inspect --account client-a --property … --url https://ex.com/page
  → {"status":"ok","source":"gsc","indexed":true,"coverage":"…","last_crawl":"…",
     "rich_results":{"verdict":"PASS|FAIL|NEUTRAL|VERDICT_UNSPECIFIED|ABSENT",
                     "types":[{"type":"FAQ","items":2,"errors":2,"warnings":1,
                               "issues":["Missing field 'acceptedAnswer'"]}]}}
  → {"status":"degraded","reason":"…"}

  rich_results rides the SAME URL-Inspection response — Google already sends
  it, `inspect` used to discard it. No extra call, quota or OAuth scope.
  It is the only programmatic structured-data validation in the system.
    • verdict PARTIAL is never emitted — the API reserves it as unused.
    • verdict ABSENT is SYNTHETIC (not a Google enum): the API omits
      richResultsResult entirely when it detects no rich results. Surfaced
      as a value rather than a missing key, because a caller cannot tell an
      absent key apart from a check that never ran. ABSENT = "none
      detected", never "invalid".
    • errors/warnings count issue INSTANCES; issues[] is deduped — the same
      issueMessage repeats across every affected item.

fetch.sh cannibal --account client-a --property … [--days 90] [--rows 1000]
  → {"status":"ok","source":"gsc","days":90,"rows_scanned":1000,"capped":true,
     "conflict_count":12,
     "conflicts":[{"query":"plombier paris","pages":3,"total_impressions":2400,
                   "urls":[{"url":…,"clicks":…,"impressions":…,"position":…}]}]}
  → {"status":"degraded","reason":"…"}                # no account → NOT auditable

  Keyword cannibalisation from Google's own data: queries where 2+ of OUR
  pages compete. Groups query+page rows; conflicts ranked by total
  impressions, and within each the strongest page first. `capped:true` means
  the row window was full — more conflicts exist past the cut, say so.
  Same auth, same quota family, no new scope: the API always accepted several
  dimensions at once, this engine only ever asked for one.
    • NOT the 30/70 duplication rule. This is a SERP fact Google measured.
      30/70 is content similarity, which has no data source here — doing it
      naively (compare two same-template pages without stripping nav/footer)
      returns ~95% similar for every site, a confident false positive. It stays
      an LLM judgement, labelled as one.
    • `queries` now takes `--dim query,page` (comma-separated) and `--rows`.
      Rows gained a `keys` list; `key` stays as keys[0], so the single-dim
      consumer is untouched.

fetch.sh sitemap --url https://ex.com/sitemap.xml
  → {"status":"ok","source":"sitemap","index":false,"count":86,"dropped":0,
     "urls":["https://ex.com/", …]}
  → {"status":"ok","index":true,"children_total":4,"children_read":4,
     "children_failed":0,"count":312,…}          # <sitemapindex>, one level deep
  → {"status":"degraded","reason":"fetch_failed"|"parse_failed"|"no_urls"
                                  |"unsafe_xml_dtd"}

  No auth, no Google, no venv: stdlib only (urllib + xml.etree + gzip).
  Gives STEP 9's COVERAGE line the denominator it was told to print and never
  had, and STEP 5 a real sampling frame. Dedupes, strips whitespace, handles
  .xml.gz. Caps: 50 children of an index, 50k URLs, 20 MB read — each cut is
  REPORTED (children_skipped / truncated), never silent.

    • NOT a security boundary. urllib fetches these, so nothing here reaches a
      shell. The CONSUMER interpolates them into curl, so seo-analyzer runs
      lib/url-guard.sh at the point of use — same contract as the sameAs check.
      A second copy of the guard here would only drift.
    • `unsafe_xml_dtd`: a sitemap NEVER has a DTD (sitemaps.org is <?xml?> then
      <urlset xmlns=>). Any doctype/entity is refused BEFORE parsing. xml.etree
      does not expand external entities, but it IS billion-laughs-vulnerable —
      1 KB expands to gigabytes, and the 20 MB read ceiling bounds the input,
      not the expansion. Refusing the construct beats depending on parser
      internals AND keeps this stdlib-only; defusedxml would drag in a venv for
      a document type that has no legitimate DTD.

fetch.sh rendercheck --url https://ex.com/
  → {"status":"ok","verdict":"server-rendered"|"client-rendered"|"partial",
     "body_text_chars":7650,"h1_in_html":1,"jsonld_in_html":9,
     "meta_description_in_html":true,"html_bytes":132447,
     "warning":"…"}                       # warning only when not server-rendered

  R2, the honest half of the SPA call. seo-analyzer has always recorded
  `RENDERING: SSR/SSG/SPA` and never acted on it; this is the signal it acts
  on. Verdict comes from what the server SENT — package.json cannot tell a
  React SPA from a Next.js SSR app.
    • client-rendered → the agent REFUSES to score On-page (N/A, not zero: a
      zero says "your on-page is bad", N/A says "we could not see it"). Every
      curl-based meta/H1/JSON-LD check would report "missing" against a site
      that is fine once hydrated — false findings, and a bundle that "fixes"
      tags which already exist.
    • Does NOT render JS. No Playwright, no Chromium, no venv. Refusing IS the
      finding.
    • Script/style text is not page text: measured 7 chars on a React shell
      whose inline window.__INITIAL_STATE__ is large. Without that, a 200 KB
      bundle reads as a rich page.
    • Measured 2026-07-17: zenquality 7650 chars/1 h1/9 jsonld and
      lavageangels356 13973/1/1 → server-rendered; a Vite shell → 7/0/0.

fetch.sh linkgraph --url https://ex.com/sitemap.xml [--max 500]
  → {"status":"ok","source":"linkgraph","pages_crawled":86,"pages_failed":0,
     "total_internal_links":2015,"capped":false,"max_depth":2,
     "orphans":[…],"beyond_3_clicks":[…],"unreachable":[…]}
  → {"status":"ok",…,"orphans_withheld":true,"reason_withheld":"crawl incomplete…"}
  → {"status":"degraded","reason":"no_links_in_html"|"no_pages_fetched"|…}

  Answers seo-analyzer.md:613 ("reachable within 3 clicks?") and :616 ("orphan
  pages?") — asked since forever, never computed. Stdlib only (urllib +
  html.parser + urljoin), no auth. Measured: 24 pages in 2.7s, 86 in 3.8s.
    • EXHAUSTIVE OR NOTHING. Orphans cannot be sampled: proving no inbound
      link means having read every other page. If the crawl is capped or any
      page failed, orphans are WITHHELD, never truncated — a false orphan
      sends a client fixing what is not broken.
    • no_links_in_html = a JS-rendered site, not a link-less one. Every page
      would read as orphaned, so it REFUSES rather than report that. Does not
      render JS by design (see the R1/R2 arbitration).
    • Filters what a link graph must never hold: assets (seen live:
      /css/main.css?v=1778157313), #anchors, mailto:/tel:/javascript:, other
      hosts. Normalises the trailing slash so /blog and /blog/ are one node
      rather than a phantom orphan pair.
    • Mock is pages.json ({url: html}), not a single page.html: one fixture
      cannot express a graph — every node would carry identical links.

fetch.sh score --findings <path.json | ->
  → {"status":"ok","axes":{"technical":{"score_20":17.8,"weight":0.2,
       "weight_renormalised":0.2857,"findings":2}},
     "na":["off-page","on-page"],"weights_renormalised":true,"global_20":17.6}
  → {"status":"error","reason":"unknown severity: 'bogus'"|"bad_findings_json"}

  I7. /harden has a real scale (SKILL.md:435: -15/-8/-3/-1, clamp [0,100]);
  /seo had none, so every axis was FELT and two runs over identical code could
  disagree — while /client-handover gates on 17/20. Same scale here, /5 into
  /20, one vocabulary across the family.
    • The split: WHICH findings exist and how severe each is stays the LLM's
      judgement. The addition is not. Same findings in, same score out.
    • affected/sampled shift severity ONE step: >=50% of the sample escalates,
      a single page de-escalates. A defect on 1 of 12 pages is not the defect
      on 12 of 12.
    • status:"na" → axis EXCLUDED, remaining weights renormalised. This is
      R2's rule (client-rendered on-page) and I1's (unauditable off-page),
      computed rather than done by hand. N/A is not a zero, and the engine
      will not let it act like one.
    • Malformed input is an error, never a silently wrong number — unlike the
      fetch verbs, a degrade here would mean bad input, not a network fact.

fetch.sh schema_gen <reservation|order|discussion|profile> [flags] [--script-tag]
  → {"status":"ok","source":"schema_gen","type":"<@type>","jsonld":{…}}
  → {"status":"error","reason":"bad_usage"}          # a REQUIRED flag omitted
  → {"status":"degraded","reason":"…"}               # a required flag given, empty

  fetch.sh schema_gen reservation --provider "Marea NYC" \
    --start 2026-06-04T19:30:00-04:00 --party-size 4
  fetch.sh schema_gen order --merchant "Acme Pizza" --order-url https://acme.example/order
  fetch.sh schema_gen discussion --headline "…" --author "Sara Park" \
    --url https://forum.example.com/t/123 --date 2026-05-12T14:00:00Z
  fetch.sh schema_gen profile --name "Daniel Agrici" --url https://agricidaniel.com/about \
    --same-as https://github.com/AgriciDaniel --knows-about "SEO" "Schema markup"

  Adapted from claude-seo's `schema_generate.py` (MIT) into this contract.
  Our system only AUDITS existing markup elsewhere; this is the one verb
  that GENERATES it — deterministic JSON-LD skeletons for the four v2
  high-leverage Schema.org types, so geo-analyzer's G2 batch stops
  hand-writing markup by hand. It only generates STRUCTURE: unknown field
  VALUES are the caller's job, `[À COMPLÉTER]` for anything unconfirmed —
  this verb never invents a sameAs, an email, or a business name.
    • Stdlib only, no network, no auth — runs even without the venv.
    • `--script-tag` wraps the cleaned jsonld in
      `<script type="application/ld+json">…</script>` under a `script` key,
      still inside the `ok` envelope. It must be given AFTER the type
      (`schema_gen reservation … --script-tag`, not before) — argparse
      subcommand flags only parse after their subcommand.
    • Never emits a JSON `null`: fields left unset are omitted from the
      `jsonld` object entirely rather than serialised as `null`.
    • A REQUIRED flag omitted → `{"status":"error","reason":"bad_usage"}`,
      exit 2 (bad usage, like every other verb). A required flag GIVEN but
      empty (argparse cannot catch that) → `{"status":"degraded",...}`,
      exit 0 — fail-open, never a traceback.

fetch.sh content_quality [--file <path.txt>] < text_on_stdin
  → {"status":"ok","source":"content_quality","filler_score":0,"ai_pattern_score":0,
     "information_density":1.0,"overall_quality":90,"flags":[],
     "matches":{"filler":[],"ai_patterns":[]}}
  → {"status":"degraded","reason":"empty_input"|"<file error>"}

  fetch.sh content_quality --file article.txt
  printf '%s' "$BODY_TEXT" | fetch.sh content_quality

  Adapted from claude-seo's `content_quality.py` (MIT) into this contract.
  100% deterministic — regex/word-lists (QRG §4.6 filler phrases + a
  Wikipedia "AI Cleanup" catalogue of LLM-typical phrasings, CC BY-SA 4.0),
  no LLM call, no network. Reads the text to score from `--file <path>` or,
  when `--file` is `-` or omitted, from stdin — the same idiom `score.py`
  uses for `--findings`.
    • **ADVISORY, NOT A VERDICT.** The output never claims "this text is
      AI-written" — modern generative tools can pass every heuristic here,
      and human writers use some of these phrases too. `flags` are
      candidates for HUMAN REVIEW, never an automatic finding. geo-analyzer
      STEP 8 (Content Shape for AI) treats `overall_quality`/`flags` as ONE
      measured input that INFORMS the axis; the axis itself stays an LLM
      judgement (30/70, Definition Lead), never replaced by this score.
    • `filler_score`/`ai_pattern_score` (0-100, higher = worse) count
      phrase-list hits scaled per 1000 tokens; `information_density`
      (0.0-1.0) is entities + numbers per 100 tokens; `overall_quality`
      (0-100, higher is better) is the weighted composite (also folds in a
      bigram-repetition penalty even though that score isn't itself a
      top-level field). `flags` fires at fixed thresholds: `filler`,
      `ai-patterns`, `low-density`, `repetitive`.
    • Stdlib only (argparse/json/re/sys/collections/typing) — runs even
      without the venv. Empty/whitespace-only input degrades rather than
      returning a false zero-value "ok": an empty analysis is not a result.
    • This is filler/AI-pattern SHAPE, not fact-checking — a text can be
      dense and well-cited yet still wrong; that stays a human/LLM call.

fetch.sh drift --url https://ex.com/sitemap.xml [--max 500]
  → {"status":"ok","baseline":true,"captured":"…","pages":24,"store":"…"}
  → {"status":"ok","baseline":false,"since":"…","gone":[…],"new":[…],
     "regressions":[{"url":…,"field":"canonical","was":"…","now":null}],
     "changes":[{"url":…,"field":"title","was":"…","now":"…"}]}

  On-page drift between audits. seo-analyzer.md:1365 keeps only "date + score
  + key changes" as PROSE the LLM writes about its own previous prose: lossy,
  unreproducible, machine-uncomparable. So "the redesign silently dropped 40
  canonicals" stays invisible. This snapshots title/description/canonical/
  robots/h1_count/jsonld_types per URL and diffs them.
    • NOT rank tracking (the common misread of this feature elsewhere).
      Positions come from GSC `queries`. This is regression detection.
    • Runs over the WHOLE sitemap, never a sample: a drift over a sample that
      changes between runs compares nothing.
    • LOSING a signal = regression. CHANGING one = change, possibly intended —
      the agent judges that, the engine only says which kind it is.
    • Store: ~/.claude/seo-data/drift/<host>.json, 0700, written via
      os.replace — never a half-written baseline. Corrupt store → treated as
      a first run rather than crashing the audit.

fetch.sh forget --label client-a
  → {"status":"ok","removed":true|false}          # false = label wasn't in the store

fetch.sh forget --all
  → {"status":"ok","cleared":<n>}                 # n = accounts removed
```

Rules that hold for every subcommand:

- **JSON always on stdout, never empty.** Even an unexpected error (HTTP
  403/5xx, timeout, DNS failure) prints
  `{"status":"degraded","reason":"unexpected_error"}` — never a raw
  traceback.
- **`status` is `"ok"` or `"degraded"` on exit 0; `"error"` on exit 2.**
  Analyzers branch on this field; `"error"` only shows up on bad usage,
  `reason` is informational otherwise.
- **Exit code 0 on `ok` and on `degraded`.** The engine never fails the
  process just because Google data isn't available — that's a normal,
  expected outcome the analyzer handles by falling back. **Exit code 2**
  is reserved for bad usage: unknown subcommand, missing required flag,
  invalid argument — those paths emit `{"status":"error",...}` instead.
- **`--store` is accepted uniformly** by every subcommand for consistent
  `fetch.sh` dispatch, even though `crux` ignores it (CrUX needs no
  account).
- **Never prints a secret.** No env var, refresh token, or access token
  ever reaches stdout or stderr, including in error paths.

Two env vars exist for testing, never for normal use:
`SEO_DATA_ENV_FILE` overrides which env file is sourced (tests point it at
`/dev/null` so a real `~/.claude/.env` on the machine can never leak into a
test run), and `SEO_DATA_DEBUG=1` re-enables stderr for local debugging
(stderr is suppressed by default so library warnings can't leak a secret
into an agent's context).

## Token store

`~/.claude/seo-data/tokens.json` — refresh tokens, keyed by the label chosen
at `make seo-connect`, one entry per connected account:

```json
{
  "version": 1,
  "accounts": {
    "client-a": {
      "refresh_token": "<opaque>",
      "scopes": ["https://www.googleapis.com/auth/webmasters.readonly"],
      "granted_at": "2026-07-09T12:00:00+00:00",
      "properties": ["sc-domain:site-a.com", "https://www.site-a.com/"]
    }
  }
}
```

Security posture:

- **File `0600`, directory `0700`.** `tokenstore.save_account` re-asserts
  both permissions on every write.
- **Written only at `connect` time, atomically.** `tmp` → `fsync` →
  `os.replace` (atomic rename), under an exclusive `fcntl` lock, so two
  simultaneous `make seo-connect` runs can't corrupt the file. Audits never
  write to this file — access tokens are exchanged in memory and never
  persisted, so two audits running concurrently never contend on it.
- **Keyed by label, not email.** Identifying accounts by email would
  require widening the OAuth scope just for identification; the label the
  user picks at connect time is sufficient and keeps the scope at
  `webmasters.readonly` only (least privilege).
- **Refresh tokens are redacted from `list`.** `fetch.sh accounts` (and
  `tokenstore.py list`) return label, properties, and `granted_at` only —
  the `refresh_token` field is intentionally never included in that output.
- **Allowlisted in gitleaks.** The store lives under `~/.claude/`, outside
  this repo, so it's never committed directly — but `make scan-secrets`
  also sweeps `~/.claude` for stray copies of secrets. `.gitleaks.toml` has
  an explicit `[allowlist].paths` entry for
  `(^|/)\.claude/seo-data/tokens\.json$`, the same treatment
  `~/.claude/.env` already gets, so a legitimate local secret store doesn't
  drown real findings in false positives.
- **Also gitignored** (`.venv-seo-data/` and `seo-data/tokens.json` in
  `.gitignore`) as a second, belt-and-suspenders guard in case a relative
  path ever put either under the repo tree.
- **Removal is local-only.** `fetch.sh forget --label <x>` / `--all` (the
  `/seo forget` skill verb) deletes the stored refresh token — it does NOT
  revoke the OAuth grant at Google's end. For a real revocation, visit
  https://myaccount.google.com/permissions with the account concerned and
  remove the app's access; the deleted local token then becomes useless
  everywhere, including to anyone who copied it beforehand.

## Graceful degradation

Missing API key, no connected account, or a revoked/expired token is a
**normal outcome, not a failure**:

- No `CRUX_API_KEY` → `crux` returns `{"status":"degraded","reason":"no_crux_key"}`.
- No account connected, or the store has no refresh token for the given
  `--account` → `queries`/`inspect` return
  `{"status":"degraded","reason":"no_credentials"}`.
- Refresh token revoked at Google's end → `{"status":"degraded","reason":"token_revoked"}`
  (a transient network blip during refresh is classified
  `"network_error"` instead, so a flaky connection never forces the user
  back through OAuth).
- Rate limited (HTTP 429) on any Google API → `{"status":"degraded","reason":"rate_limited"}`.

In every case: **exit code 0**, valid JSON on stdout, no crash. The `/seo`
FULL audit continues on the anonymous PageSpeed API (lab data) instead of
CrUX field data, and the report surfaces the fix as a user action:
`make seo-connect`. `doctor.sh` also flags both non-fatally as `WARN`: a
missing `CRUX_API_KEY` warns on its own, while no connected Google account
is the one that names `make seo-connect`.

## Testing

```bash
make test
# or, to run only this engine's suite:
bash lib/seo-data/seo-data.test.sh
```

The suite is network-free: `google_seo.py` reads fixtures from
`lib/seo-data/fixtures/` (`crux_mobile.json`, `gsc_queries.json`,
`gsc_inspect.json`) whenever `SEO_DATA_MOCK_DIR` is set, instead of calling
Google's APIs. Degradation paths run with real env vars unset (`env -u
CRUX_API_KEY`, `env -u SEO_DATA_MOCK_DIR`) to exercise the no-key/no-creds
branches deterministically. Every `fetch.sh` invocation in the tests also
sets `SEO_DATA_ENV_FILE=/dev/null` so a machine with a live
`~/.claude/.env` never lets real credentials leak into a test run.
