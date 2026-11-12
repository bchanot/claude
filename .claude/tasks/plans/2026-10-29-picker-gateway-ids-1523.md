# Bugfix plan — /model picker never asks its scope (gateway ids + silent passthrough)

Bug report (user, 2026-10-29): "quand je fais un /model ça change pas le fable 5.1 comme ça devrait". Repo /home/bchanot/Documents/claude, `.claude/settings.local.json` pins `"model": "claude-fable-5-1[1m]"`; bare `/model`, pick the "Opus 5.5" row (not Default, user-confirmed); native output "Set model to `Opus 5.5` and saved as your default… settings.local.json pins Fable 5.1 — applies on restart"; no scope question (BDR-127 expects This project / This conversation / Everywhere).

## Diagnosis
1. PROVEN (transcript cdd27037, 2026-10-29T10:27, before a `/login`): the picker listed a gateway (`OpenAI: GPT-6 Astra`, `Anthropic: Claude Opus 5.5`); after each pick the mod logged `model-router: anthropic/openai/gpt-6-astra unknown to the models table; no switch` then `… anthropic/claude-opus-5.5 unknown …` (unknownCall, register.ts:1351, via canonical() at :1393). Gateway ids are provider-prefixed with a dotted version. `knownModel` (register.ts:2134) and `canonical` (:1086) only know `claude-opus-5-5` etc. (DEFAULT_CONFIG.models :270) → `handlePicker` (:2408) returns `next(e)` → native, silent; the main decision also treats the session model as unknown (never switches). The first pick also wrote `"model": "anthropic/claude-opus-5.5[1m]"` into the tracked settings.json (native Everywhere).
2. NOT PROVEN (13:52, after `/login`, label `Opus 5.5` without provider): no deny, no log. `handlePicker` has 4 silent passthrough exits: `e.source !== 'picker'`, `st.off`, non-string or unknown `requested_model`, `surfaces().length === 0`. None logs, so the cause cannot be read.

Prior: BDR-127 (picker scope; live test 2026-10-25 with native ids), LRN-231, BLK-036. None covers the gateway id form.

## Fix plan
1. `mods/model-router/hooks/register.ts`: one normalizer `bareId(id)` used first by `canonical()` and `knownModel()`:
   - strip a leading `anthropic/` (once);
   - if the rest starts with `claude-`, dotted version digits → dashed (`claude-opus-5.5` → `claude-opus-5-5`, `claude-haiku-5.5[1m]` keeps `[1m]` handling as today);
   - anything else unchanged (`anthropic/openai/gpt-6-astra` → `openai/gpt-6-astra`, still unknown → native, as today).
   `fullId()` keeps returning the token AS RECEIVED for a non-alias token (so settings.local.json and the sticky route carry the engine's own id: safest switch target on that account).
2. `handlePicker`: when `e.source === 'picker'` and the hook passes through to native, one `tryLog` line `model-router: picker → native: <reason> (<requested_model|Default>)`, reason ∈ {off, unknown id, Default, no surface}. Not logged for source command/sdk/auto/resume (those have their own paths and would spam).
3. `mods/model-router/hooks/register.test.ts`:
   - picker: `anthropic/claude-opus-5.5` is denied at once and the deferred question comes (regression for cause 1); the question names `anthropic/claude-opus-5.5` (as received); This project writes that id into settings.local.json;
   - `anthropic/openai/gpt-6-astra` passes through (non-Anthropic stays native) and logs `picker → native: unknown id`;
   - each existing PASSTHROUGH row with source picker now asserts its log line; source command/sdk rows assert NO picker log;
   - canonical: `anthropic/claude-opus-5.5` and `anthropic/claude-opus-5.5[1m]` rank like `opus` in the main decision (no "unknown to the models table" line).
4. Proof after merge-ready: user runs `/reload-plugins`, `/model` → Opus 5.5 row: either the question appears, or the new log names the passthrough reason (cause 2 then gets its own bugfix).

## Out of scope
Router-initiated switches on a gateway account (they send `claude-opus-5-5`; acceptance there unverified, named as a risk). The tracked settings.json `model` write by native Everywhere (BDR-131 policy handles it).

## Tests
`make test suite=lib/tests/mods.test.sh` (runs `claude plugin test` on the mod) + full `make test`.
