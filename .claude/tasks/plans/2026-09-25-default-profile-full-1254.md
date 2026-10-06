# PLAN — default-profile-full (feat) — REVISED after challenge (r3)
- date: 2026-09-25 | contract: contracts/2026-09-25-default-profile-full-1254.md
- branch: feature/default-profile-full
- r3 (confirmation pass): Step 11 re-applies an existing selection with
  `set "$SEL"` (Steps 2 and 10 re-park gstack / re-link externals on every
  run), `gstack on` messages stop claiming "all gstack", seed lists emil,
  T2b proves `gstack off` trims with no cache, two out-of-scope citers of
  `reset`/`current` join the scope.
- r2: closes correctness BLOCKER 1 / MAJOR 2-3 / MINOR 4-7, robustness
  BLOCKER 1 / MAJOR 2 / MINOR 3-5, simplicity MINOR 1-3. Line numbers dropped
  on purpose: the orchestrator's `chore(21st)` commit lands BEFORE dispatch
  and shifts them — refer to functions and anchors.

## Ground truth the plan is built on (verified on the live tree)

- gstack is OFF by default (BDR-030): a real tree has ZERO gstack symlinks in
  `skills/` and ZERO `gstack__*` parked. `set`/`reset` LINK the listed skills
  from the submodule; `disable_skill gstack` parks only what is present in
  `skills/`. So "parked count == 0" says nothing about which profile is on.
  The old `cmd_current` fast path keyed on that count — it goes away.
- Every `apply` / `set` / `reset` writes `.active-profile`. Therefore: cache
  absent, empty, or legacy `none` ⇔ no profile was ever selected (or the old
  reset ran). That is the ONE signal "no profile selected" keys on, everywhere.
- The 21st pack: staged into `skills-external/21st-*`, symlinked on demand;
  `full` lists the five design skills as `external`; the two publishing
  skills are never listed.

## Approach

- `DEFAULT_PROFILE="full"` declared once in `lib/profile.sh`, right after
  `ACTIVE_CACHE`, comment: the profile in force when none is selected.
- Two tiny cache helpers next to `write_active()`:
  - `read_cache()` → first line of `$ACTIVE_CACHE`, ALL whitespace stripped
    (`tr -d '[:space:]'`, CRLF-proof); empty string when the file is missing.
    Must not trip `set -euo pipefail` (`2>/dev/null || true`).
  - `active_profile()` → `read_cache`, or `$DEFAULT_PROFILE` when that is
    empty or the literal `none`.
  Every reader of the cache in the lib goes through them.
- `cmd_reset` = go to the default profile: `info "Resetting to the default
  profile: $DEFAULT_PROFILE (exclusive — enables its list, parks any non-listed
  gstack or managed item currently on)"` then `cmd_set "$DEFAULT_PROFILE"`
  ([gated] Q1). `cmd_set` → `cmd_apply` → `write_active` already records the
  label. No `write_active "none"` anywhere.
- `cmd_current` becomes LABEL-DRIVEN (this replaces the cross-profile
  best-guess scan and its parked-count fast path — both keyed on a premise
  that is false under BDR-030):
  1. `label="$(active_profile)"`; if `$PROFILES_DIR/$label.profile` is
     missing → `echo "$label (unknown profile — no lib/profiles/$label.profile; run: profile reset)"`, rc 0.
  2. `profile_match "$label"` → prints `<available> <total>` (the existing
     per-entry `skill_status` loop, extracted into a helper: `enabled` /
     `installed` count as available). `pct = available*100/total` (0 when
     total is 0).
  3. `parked` = count of `skills-disabled/gstack__*` (existing find).
  4. Output, ONE line, first word = the label:
     - `read_cache` empty or `none` →
       `"$label (default — not applied yet, ${pct}% of its items enabled; run: profile reset)"`
     - otherwise →
       `"$label (${pct}% match, ${parked} gstack skills disabled)"`
  No "all gstack skills enabled" claim anywhere. `set X` then `current`
  always names X (the SKILL.md "contradiction" failure family disappears).
- `cmd_gstack on`: messages must not claim "all gstack": 0 parked →
  `info "nothing parked — gstack skills are linked per profile (set/apply/reset)"`;
  else `ok "$parked parked gstack skills restored"`. Behaviour unchanged.
- `cmd_gstack off`: `active="$(active_profile)"`; keep the existing "profile
  file missing" error (rc 1) for a cache naming an unknown profile; drop the
  `none` special-case (unreachable now).
- `hooks/statusline.sh`: read the constant once —
  `DEFAULT_PROFILE=$(sed -n 's/^DEFAULT_PROFILE="\([^"]*\)".*/\1/p' "$REPO/lib/profile.sh" 2>/dev/null)`,
  `[ -n "$DEFAULT_PROFILE" ] || DEFAULT_PROFILE=full` (unreadable-lib
  fallback only). `PROFILE=$(head -n1 cache 2>/dev/null | tr -d '[:space:]')`;
  empty or `none` → `$DEFAULT_PROFILE`. No call into profile.sh (speed).
- `install-plugins.sh` ([gated] Q2):
  - Step 8.7: DELETE the unconditional "Default-disabled" park block (the
    `TFD_STATUS` … `toggle-external.sh disable 21st` block and its `else`
    branch, keep the surrounding `echo ""`). Replace by a 3-line comment:
    the pack's state is governed by profiles — the default profile (Step 11)
    turns the five design skills on, the two publishing skills stay parked;
    a re-run never re-parks what a profile or the user enabled.
    Update the Step 8.7 header comment's "installed but DISABLED by default"
    + the trailing "Default policy: pack DISABLED at install time…" lines
    to the same statement (no counts).
  - NEW Step 11 AFTER the Step 10 `link.sh` refresh, BEFORE the `# SUMMARY`
    banner, same banner style as the other steps:
    ```
    # ============================================================
    # STEP 11 — DEFAULT PROFILE
    # ============================================================
    # The profile decides which skills / externals / plugins are on. No
    # selection yet (.active-profile absent, empty or legacy "none" — same
    # rule as lib/profile.sh active_profile()) → apply the default via
    # `profile.sh reset`. An existing selection is re-applied (`set`). Plugin legs
    # are install-immutable (the EXIT guard restores settings.json, BDR-028;
    # the committed enabledPlugins already match the default profile), so
    # only the skill / external legs matter here.
    echo "── Step 11: Default profile ────────────────────────────────"
    echo ""
    if [ -f "$REPO/lib/profile.sh" ]; then
      SEL="$(head -n1 "$REPO/.active-profile" 2>/dev/null | tr -d '[:space:]' || true)"
      case "$SEL" in
        ""|none)
          info "No profile selected — applying the default profile (bash lib/profile.sh reset)..."
          bash "$REPO/lib/profile.sh" reset \
            || warn "default profile not applied — run: bash lib/profile.sh reset"
          ;;
        *)
          # Steps 2 (gstack parked) and 10 (link.sh re-links the design
          # externals) rewrite skill state on every run: re-apply the
          # selection so its state comes back, label unchanged.
          info "Profile kept: $SEL — re-applying it (bash lib/profile.sh set $SEL)..."
          bash "$REPO/lib/profile.sh" set "$SEL" \
            || warn "profile $SEL not re-applied — run: bash lib/profile.sh set $SEL"
          ;;
      esac
    else
      warn "lib/profile.sh not found — skipping the default profile"
    fi
    echo ""
    ```
  - Summary line for the pack, NO counts:
    `🔄 21st skill pack     — 21st.dev CLI skills; design ones follow the profile (full by default), publishing ones on demand (toggle: lib/toggle-external.sh enable 21st)`.
  - NEVER run install-plugins.sh / link.sh / make plugin: `bash -n` + shellcheck.
- Docs (functions by name):
  - `lib/profile.sh` header usage list: `reset` line → "go to the default
    profile (full): enable its list, park non-listed gstack/managed items";
    `current` line → "report the active profile (label + match)".
  - `usage()`: same for the `reset` and `current` lines; EXAMPLES
    `reset # back to the default profile (full)`; NOTE: keep the managed-lists
    sentence (the orchestrator's chore commit already removed "magic").
  - `skills/profile/SKILL.md`: Commands block (`reset` comment, `current`
    comment, `gstack on` comment → "restore parked gstack skills on top of
    the current profile"); one "Default profile" paragraph under Mechanism (`full` in
    force when `.active-profile` is absent/empty/`none`; `reset` applies it;
    a fresh `make plugin` applies it when nothing is selected); Output policy
    after `current` ("label + match %; `default — not applied yet` means run
    `reset`"); Failure-modes: the `set`/`apply` mid-toggle row no longer
    calls `reset` an always-safe recovery (it is a full exclusive `set`):
    "run `current`, then re-run `set <name>` or `reset`"; the
    "`current` says `none` right after a successful `set`" row → replace by
    "`current` names a profile other than the one just set" (cache written
    by another tool / hand edit; show raw output, never hand-patch).
  - Makefile: `profile-reset: ## Go to the default profile (full)`;
    `profile-current: ## Show the active profile (label + match)`.

## Files

- lib/profile.sh — `DEFAULT_PROFILE`, `read_cache()`, `active_profile()`,
  `profile_match()`, `cmd_reset`, `cmd_current` (rewritten), `cmd_gstack`
  off branch, header + `usage()` text.
- hooks/statusline.sh — default from the lib, cache normalisation.
- lib/tests/profile-default.test.sh — NEW. Harness copied from
  profile-set-managed.test.sh (`$FX`, fake `claude` shim logging calls,
  `run()` with both `*_REPO_OVERRIDE`, `check()` + `PASS=/FAIL=` summary,
  exit 1 on any FAIL). Fixture profiles: `full.profile` = `gs-a`, `gs-b`,
  `emil-design-eng external`; `otherish.profile` = `gs-c`. Real-tree seed
  (explicit `mkdir -p`): `$FX/skills`, `$FX/skills-disabled`,
  `$FX/lib/profiles`, `$FX/bin`, `$FX/hooks`,
  `$FX/skills-external/emil-design-eng` (external source, required for T5's
  `emil linked` + `100% match`), `$FX/skills-external/gstack/gs-{a,b,c}`
  each with a `SKILL.md`. gs-a/gs-b/gs-c exist ONLY under
  `skills-external/gstack/`, NOTHING linked in `skills/`, no cache. Copy `hooks/statusline.sh` to `$FX/hooks/` so its
  `$REPO` = `$FX`; statusline runs as `echo '{}' | bash "$FX/hooks/statusline.sh"`.
  - T1 clean seed, no cache → `current` first word `full`, contains
    `default — not applied yet`, does NOT contain `all gstack`.
  - T2 clean seed, no cache → `gstack off` rc 0 (nothing to trim, no error).
  - T2b `ln -s "$FX/skills-external/gstack/gs-c" "$FX/skills/gs-c"`, no cache
    → `gstack off` rc 0; `skills-disabled/gstack__gs-c` exists, `skills/gs-a`
    still absent (untouched). Then `rm` the parked link to return to the
    clean seed.
  - T3 cache `none` (written with a trailing `\r\n`) → `gstack off` rc 0.
  - T4 cache `ghost` (no profile file) → `gstack off` rc 1;
    `current` first word `ghost`, contains `unknown profile`.
  - T5 clean seed → `reset` → cache reads `full`; gs-a and gs-b linked,
    gs-c NOT linked, emil linked; `current` first word `full`, contains
    `100% match`, does NOT contain `not applied`.
  - T6 `set otherish` → `current` first word `otherish` (label-driven, even
    though gs-c is the only gstack on) → then `reset` → gs-c parked
    (`skills-disabled/gstack__gs-c`), gs-a on, cache `full`.
  - T7 `set otherish` then `gstack on` (0 parked, cache `otherish`) →
    `current` first word `otherish`, does NOT contain `default`.
  - T8 statusline, no cache → `profile: full`.
  - T9 statusline, cache `otherish` → `profile: otherish`.
  - T10 statusline, cache `  none \r` → `profile: full`.
  - T11 statusline reads the constant: `sed -i` the fixture's copied
    `lib/profile.sh` to `DEFAULT_PROFILE="otherish"`, no cache →
    `profile: otherish` (proves the sed read, not the literal fallback).
- skills/profile/SKILL.md — as above.
- Makefile — two help strings.
- install-plugins.sh — Step 8.7 park block removed + comments, Step 11,
  summary line.
- agents/plugin-advisor.md — two citers of the old semantics: PHASE 3
  OUTPUT `PROFILE:` line → `[active skill profile — name + match%, or
  "<name> (default — not applied yet …)"]`; the paragraph starting "To
  restore the full skill set:" (through its end) → "To go back to the
  default profile: `bash $HOME/.claude/lib/profile.sh reset` (= `set full`:
  enables full's list, parks non-listed gstack/managed items, toggles the
  managed plugins like any `set`)." Nothing else in the file.
- lib/toggle-external.sh — header comment only: the `bash lib/profile.sh
  reset` line gains `# back to the default profile (full)`.

## Executor guardrails

- Tests use the fixture repo + fake `claude` shim ONLY: never run the real
  `claude plugin …`, never touch this machine's `skills/`, `skills-disabled/`
  or `.active-profile` (there is none today — keep it that way).
- Never run `install-plugins.sh`, `link.sh`, `make plugin`, `make link`.
- Scope = the 8 files of the contract; CHANGELOG/README are doc-sync's job.
- The `none`/empty/absent normalisation is written in three places by
  design (lib helper, statusline, installer): the statusline must stay
  free of any profile.sh call, the installer must not depend on a lib
  function. Each copy carries a one-line comment naming `active_profile()`
  as the reference and uses the same `tr -d '[:space:]'` rule.

## Edge cases

- Cache with trailing whitespace / CRLF → stripped before compare (T3, T10).
- Cache names a profile with no `.profile` file → `gstack off` rc 1 as
  today; `current` says `unknown profile` and points at `reset`.
- `reset` on a real tree: links full's 34 gstack skills from the submodule
  (BDR-030 on-demand), parks nothing unless a non-full gstack/managed item
  was on (docs say exactly that — no "parks 20 skills" claim).
- statusline must stay fast: one `sed` on the lib, no subshell into
  profile.sh; `$REPO/lib/profile.sh` unreadable → literal `full`.
- `set -euo pipefail` in both scripts: every `head` on a maybe-missing file
  carries `2>/dev/null || true`; the installer's `reset` call carries
  `|| warn`.
- `profile_match` total 0 → pct 0, no division by zero.

## Disposition (STEP 0.6)

- honors LRN-020: `full` is the REAL default (reset applies it; install
  applies it when nothing is selected); no label denotes absence; the
  parenthetical carries applied-vs-in-force. `none` sentinel gone.
- honors BDR-017: full stays curated; `reset` docs describe what it enables
  and parks without a fixed count.
- honors BDR-018: `gstack on|off` keeps the label; `off` reads the default
  through `active_profile()`; `current` after `gstack on` names the cached
  label (T7).
- honors BDR-030: `current` no longer infers anything from the parked
  count; tests seed gstack as OFF like a real tree.
- honors BDR-079: `reset` reuses `cmd_set`; no new toggle path.
- honors BDR-093: the pack stays staged + symlinked on demand; its
  install-time park is superseded by the profile rule ([gated] Q2), the
  two publishing skills remain unlisted. Residue scrub is prose only.
- honors BDR-028: the installer's EXIT guard on settings.json is left
  alone; Step 11 documents that plugin legs are install-immutable.
- honors LRN-023 (`cd -P`): untouched.
- NON-BINDING: BDR-007/008/024/025/026/057/059, LRN-022/108/110, BLK-005/006,
  EVAL-002 — context only.
