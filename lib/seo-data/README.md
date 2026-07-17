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
