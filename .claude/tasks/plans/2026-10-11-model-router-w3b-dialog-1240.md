# PLAN r3 — model-router wave 3-B: a dialog with context, model then effort on change (2026-10-11)

r1 → r2 after simplicity CONCERNS(3), robustness FATAL(5), correctness
FATAL(8): all three rejected inline-route rows and dialog edits of phases.
r2 → r3 after the confirmation (correctness CONCERNS(2)). Precedence r3 > r2 > r1. Contract `.claude/tasks/contracts/2026-10-11-model-router-w3b-dialog-1240.md`.
Base = W3-A (22455c0, plan r4, BDR-116). Facts: `agent.offer` payload carries
`description` and `source`; `$.ui.ask` takes 2-4 labels + Other; `cfg.models`
maps the four aliases to ids; each default alias heads one tier (best fable,
big opus, work sonnet, cheap haiku); `readCapped` exists (size cap, stat).

## Decisions
- D1 rows stay PHASE NAMES everywhere (routing.json, projects, override).
  No inline route rows. The dialog's model+effort choice maps to a phase.
- D2 the dialog never edits a phase: T3 offers Later / Keep only, with
  context. Phases change by hand in routing.json + DEFAULT_CONFIG (census
  lock kept). BDR-116 unchanged.
- D3 one description rule for every kind, hardened read, no cache.

## Texts (ASK1)
- `clean(s, n)`: FIRST fold every `\s` and `\p{Z}` (incl. U+2028/2029) to
  a space, THEN strip `\p{Cc}` and `\p{Cf}`, collapse spaces, trim; when
  longer than n code points keep n-1 and append "…" (total ≤ n). Applied to
  every description and `about` (no answer echo anywhere).
- Leads are KEPT as the first words (existing assertions stay valid):
  "First route for /feat — <desc>. Routed to reflect (<about>): claude-fable-5-1
  at high. OK?", "First dispatch of security-auditor — <desc>. Routed to
  verify (<about>): claude-sonnet-5-5 at xhigh. OK?", "First use of
  orchestrate on the main loop — <about>; used by …: … OK?". Without a
  description the " — <desc>" part is omitted; without `about` the
  parenthesis is omitted.
- Skill row desc = `skillDesc($, st, name)`: name must match
  `^[A-Za-z0-9][A-Za-z0-9._:-]*$` (else name only); `readCapped` of
  `${HOME}/.claude/skills/<name>/SKILL.md` (stat kind must be `file`, size
  cap as the override; HOME from `$.env.get`, unset → name only); parse the
  frontmatter `description:` in its five forms (plain, `|`, `>`/`>-`,
  single-quoted with `''`, double-quoted): unquote, join the block lines
  with spaces, cut at the first sentence end (`. ` / `.` at end), then
  clean(…, 140); any failure → name only. Read at ask time, once (the key
  is asked at most once per session). The kind check lives in a
  skill-specific wrapper around `readCapped` (config reads untouched).
- Agent row: the offer description goes through the SAME rule (sentence
  cut + clean 140) WHEN STORED at `agent.offer` (bounded cache
  `Map<type, {source, description}>`); absent → name only.
- Phase (T3): "First use of orchestrate on the main loop — <about>; used by
  <n> rows[, the derived route of dispatches][, <k> prompt rule(s)]:
  claude-fable-5-1 at medium. OK?"; consumers derived: `orchestrate` →
  "the derived route of dispatches" (hardcoded, pushOrchestrate), prompt
  rules counted from `cfg.prompt.filter(r => r.phase === name)` (floor
  rules named "floor rule"). Options ["Later", "Keep"].
- Row options: ["Later", "Keep", "Change"]. At EVERY step the `askOr` LATER
  (dismissed, headless) is checked first and is silent; any other
  non-label answer = Later + toast "answer not recognised, default kept"
  (no echo). `ALTS`, the alt slice in `optionsFor` and the free-text phase
  branch of `decide` are removed.
- Main-row texts keep the real-decision rule (decideFor/mainEffort); spawn
  texts keep spawnTarget + explicit effort.

## Change flow (rows only)
- ASK2 "Which model for `<name>`?": four FIXED labels from the default
  aliases, each with its tier role ("fable (best)", "opus (big)", "sonnet
  (work)", "haiku (cheap)"; role = the tier headed by the alias in
  `cfg.tiers`, "(custom)" when none); Other or an unknown label = Later +
  toast.
- ASK3 "Which effort on <alias>?": the efforts of the phases (in
  `cfg.phases`) whose tier head is the chosen alias, deduplicated and
  sorted ASCENDING by LEVELS (fable: medium high xhigh max; opus: xhigh;
  sonnet: low medium high xhigh; haiku: low) → at most 4 labels (the
  first 4); exactly one → ASK3 skipped; zero → Later + toast "no phase
  uses <alias>"; Other = Later.
- Target phase = the row's CURRENT phase when it matches (alias, effort),
  else the first matching phase in `cfg.phases` order. Same phase as now →
  treated as Keep (no `changed` entry).
- ASK4 scope as W3-A: ["Everywhere", "This project only"], or ["Everywhere",
  "Later"] when there is no repo key.
- After a CHANGE on a MAIN row (T1, never on Keep), computed in
  `confirmSkill` from `skillRow` + `decideFor`: toast "`/<name>` now runs
  <id> at <effort>" plus ", main moves up only: `/route switch on` allows
  a downgrade" when the chosen alias ranks below the session model and the
  switch is off; the new route is re-picked into the current decision
  (T1/T2 as W3-A).
- Storage unchanged from W3-A: `changed.<kind>.<name> = {from (first), to}`,
  `confirmed.<kind>.<name> = to` (strings), `projects[key]` rows.

## `about`
- routing.json: `phases.<name>.about` (≤ 120 chars, clean) on the 11
  phases; loaded into `mem.about: Record<phase, string>` (part of the
  memory rebuilt with the config, so it survives /clear with cfg; never on
  `Route`, never in DEFAULT_CONFIG; the census `code_phase` regex
  untouched); a non-string or overlong `about` is dropped + logged once;
  a phase without `about` → no parenthesis. acceptPhase ignores the key.

## Steps
- [ ] S1 routing.json `about` ×11 (one line each from the W2 phase table);
      loader + map + validation.
- [ ] S2 descriptions: offer cache `{source, description}`; `skillDesc`
      (allowlist, readCapped, kind check, YAML forms, sentence cut); `clean`.
- [ ] S3 ASK1 texts + options Later/Keep/Change; Other → Later + toast;
      dead code removed (`ALTS`, alt slice, free-text branch).
- [ ] S4 change flow ASK2 → ASK3 (derived efforts) → ASK4; target-phase
      rule; same-phase = Keep; main toast with the real decision.
- [ ] S5 `lib/effort-shift.md` dialog lines (≤ 4 changed).
- [ ] S6a migrate the W3-A dialog tests: every `asks([...])` answering a
      phase name at ASK1 becomes Keep or a Change chain (ASK1 → ASK2 →
      [ASK3] → ASK4; the `asked[n]` indexes shift accordingly); option-list
      assertions become Later/Keep/Change (T3 Later/Keep); the lead-text
      assertions (:2266 "First dispatch of feater", :2395 "First use of
      orchestrate on the main loop") stay valid by construction; :1914
      expects the new toast "answer not recognised, default kept"; the two
      free-text tests (:1871 "a free-text phase counts as an alt", :1878
      "equal to the current phase is a Keep") are DELETED (authorized:
      they test the removed branch); "a phase name answer is a Later" kept.
      World/helper extensions: `offerOf` takes a description; the World
      gains a per-path stat `kinds` override and a HOME override (unset).
- [ ] S6b new tests, one per clause: skill text with each YAML form (plain,
      `|`, `>-`, 'sq' with `''`, "dq"), missing SKILL.md → name only, a bad
      name (`../x`) → name only, stat kind ≠ file → name only, a SKILL.md
      over the cap → name only, HOME unset → name only, a 500-char
      description with control, bidi and U+2028 chars → ≤ 140 clean code
      points ending in "…"; a Keep on a main row → no "now runs" toast;
      a Change → the toast with the switch hint; zero-effort alias → Later
      + toast; dismissed ASK2 → silent Later; agent text from the offer
      description; T3 text with `about` and consumers; ASK2 labels; ASK3
      derived efforts per alias (fable 4, opus → skipped, sonnet 4, haiku →
      skipped); security-auditor Change → opus → (skipped) → Everywhere →
      row `judge`, spawn on claude-opus-5-5 at xhigh now; feater Change →
      sonnet → high → `write`; Explore Change → sonnet → medium → stays
      `explore` (current phase wins) → treated as Keep, no `changed`;
      `/feat` Change → sonnet → medium → `implement`, toast names "moves up
      only" with the switch off; Other at ASK1/ASK2/ASK3 → Later + toast,
      nothing written; project scope with the derived phase; `about`
      overlong → dropped + logged.
- Disposition: honors BDR-116 rules (1), (3)-(6) unchanged (rows = phases,
  dialog never edits phases, writers/paths/caps as is); AMENDS its clause
  (2): options become Later/Keep/Change with a model-then-effort chain,
  Other = Later (successor amendment written at CAPITALIZE, append-only); BDR-115 (full ids from `cfg.models`),
  LRN-210 (one clause per test), LRN-212 (live mod: announce dialogs).
- Docs (README/USAGE/CHANGELOG lines on the dialog) drift after this wave:
  STEP 6 doc-sync, out of this contract's scope.

## Challenge ledger (r1 → r2)
- simp 1/2, rob 2/3/4/7/11/12, corr 1/2/3/9/10/12 (inline rows) → D1:
  rows stay phases; efforts derived from the alias's phases; target-phase
  rule with tie-break; same-phase = Keep.
- simp 3, rob 1 BLOCKER/5/6/13, corr 4/5 (T3 phase edits) → D2: T3
  Later/Keep with context; BDR-116 unchanged.
- simp 6, rob 8/9, corr 8 (descriptions) → D3 single rule, five YAML
  forms, hardened read, allowlist, clean() with Cc/Cf and code points.
- simp 7, corr 14 (`about` on Route) → separate map, validated at load.
- simp 8, corr 13 (ASK2 Other, aliases) → fixed four labels, Other = Later.
- simp 9 (dead code) → S3 removal.
- rob 10, corr 6 (main model pick is a placebo) → toast with the real
  decision and the switch hint.
- corr 7 (W3-A tests) → S6a migration step.
- corr 11 (no-key scope) → W3-A behaviour kept ([Everywhere, Later]).
- corr 15 (docs, AC5 oracle) → doc-sync noted; contract AC5 reworded.

## Confirmation ledger (r2 → r3)
- conf 1 (S6a under-listed) → leads kept by construction; toast text,
  deleted free-text tests, `asked[n]` shifts listed.
- conf 2 (read-hardening clauses untested) → S6b tests + World extensions.
- conf 3 (ASK3 order) → ascending by LEVELS; tie-break in `cfg.phases` order.
- conf 4 (clean order, length) → fold first, strip, n-1 + "…".
- conf 5 (dismissed ASK2/3 toasted) → LATER checked first, silent.
- conf 6 (zero efforts, texts, echo) → Later + toast; ASK2/ASK3 texts; no echo.
- conf 7 (toast on Keep) → Change only, computed in confirmSkill.
- conf 8 (BDR-116 clause 2) → amendment at CAPITALIZE.
- conf 9 (`about` across /clear) → in `mem`, rebuilt with cfg.
- conf 10 (agents vs skills rule) → same rule at offer time, bounded.
- conf 11 (hardcoded consumers) → derived from cfg.prompt.
- conf 12 (kind check placement) → skill wrapper around readCapped.
