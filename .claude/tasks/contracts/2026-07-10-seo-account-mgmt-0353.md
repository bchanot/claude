# CONTRACT — seo-account-mgmt
- date: 2026-07-10 | flow: feat | branch: feature/seo-account-mgmt
- status: active

## REQUEST (verbatim — IMMUTABLE)
"J'aimerais qu'on rajoute quand meme une option au skill pour juste connecter
le compte. du style un argument au skill seo pour fiare un truc du genre /set
seo-connect ou quelque chjose comme cas. Et aussi pouvoir clean la liste des
compte deja enregister. pouvoir supprimer des compte ou tout supprimer"
— design proposal validated by user ("go pour l'un puis l'autre oui"):
`/seo connect [label]` / `/seo accounts` / `/seo forget <label>` /
`/seo forget --all`; tokenstore remove+clear verbs; fetch.sh forget dispatch;
new connect.sh wrapper (sources env internally, usable from any project);
Makefile delegates to it; SKILL.md arg routing + STEP 0 fix; forget output
must state local removal ≠ Google revocation (myaccount.google.com/permissions).

## CLARIFICATIONS
none — request complete (design pre-validated in conversation).

## ACCEPTANCE CRITERIA
1. `python3 lib/seo-data/tokenstore.py remove --file F --label X` deletes only
   label X (others preserved), prints `{"status":"ok","removed":true|false}`,
   never prints a refresh token; atomic write + fcntl lock as set.
2. `python3 lib/seo-data/tokenstore.py clear --file F` empties the store
   (subsequent list → `"accounts": []`), JSON ok, same write discipline.
3. Fail-open preserved on new verbs: bad usage → `{"status":"error",...}` +
   exit 2; unexpected error → degraded JSON (existing _cli try/except covers).
4. `fetch.sh forget --label X` / `forget --all` dispatch to remove/clear
   within the existing contract (JSON stdout, exit 0 ok, exit 2 bad usage);
   `fetch.sh forget` with no/invalid flag → exit 2 + JSON.
5. New `lib/seo-data/connect.sh`: sources `${SEO_DATA_ENV_FILE:-~/.claude/.env}`
   internally (set -a, never echoed), picks venv python else system, execs
   connect.py with passed args; with no creds exits nonzero with the
   "Set GOOGLE_OAUTH_CLIENT_ID/SECRET" gate message (deterministic, offline).
6. Makefile `seo-connect` delegates to connect.sh (env-sourcing duplication
   from caa5bed removed); venv creation + pip install kept before.
7. `skills/seo/SKILL.md` routes `connect [label]` / `accounts` /
   `forget <label>|--all` BEFORE the audit flow (audit `/seo <url>` unchanged);
   forget path includes the Google revocation notice
   (myaccount.google.com/permissions); STEP 0 no longer proposes bare
   `make seo-connect` as the only path (connect.sh tilde path offered).
8. `lib/seo-data/README.md` documents connect.sh, forget verbs, revocation note.
9. `lib/seo-data/seo-data.test.sh` covers: remove keeps others / removed:false
   on missing label / clear empties / redaction on remove / forget via fetch.sh
   (JSON + exit codes, bad usage 2) / connect.sh offline negative path; plus
   wiring locks (connect.sh sources vault, Makefile delegates, SKILL routes,
   README documents). Whole suite + `make test` green.
10. No commit attribution trailers; tilde paths for engine calls in SKILL.md.

## FILE SCOPE
lib/seo-data/tokenstore.py, lib/seo-data/fetch.sh, lib/seo-data/connect.sh (new),
lib/seo-data/seo-data.test.sh, lib/seo-data/README.md, Makefile, skills/seo/SKILL.md
