# PLAN — design-hook-removal (r1)
- `git rm hooks/design-toolchain-reminder.sh lib/tests/design-toolchain-reminder.test.sh`.
- settings.json: in `hooks.UserPromptSubmit[0].hooks`, delete the object whose command is `bash ~/.claude/hooks/design-toolchain-reminder.sh` (statusMessage "Checking design signals..."); the ctx7-reminder object stays as the array's only entry; JSON valid (`jq .`). Edit with a text edit of those 6 lines, not a jq rewrite (keeps file formatting).
- rules/web-building.md:49-50: "Single source for design routing; the design-toolchain hook reinforces it." → "Single source for design routing." (wrap kept ≤ 80).
- lib/tests/doctrine-citers.test.sh T7c: SUPERSEDED, see r2 T8i below (r1 asked for a count-2 fixture; a one-line fixture gives 1).
- Edge: `.githooks`/link.sh never listed the hook (checked); fast-libs test reads ctx7 only; doctor has no design hook check.
- Disposition: honors BDR-125 phase 1 (path rule = carrier; the always-on pointer line in CLAUDE.global.md stays for new-file turns), BDR-131 measure (0 Reads), cleanup rule (citers patched same branch).

## r2 (correctness FATAL(1), robustness CONCERNS(1), simplicity CONCERNS(1)) — r2 wins over r1
- T7c BLOCKER (all 3 lenses: r1's "count 2" came from TWO hook lines :6 and :78; a one-line fixture gives 1): delete T7c from the T7 "real citers" block; add in the synthetic T8 block a check `T8i-tilde-quoted-label-whole`: `printf '%s\n' '  ~/.claude/rules/web-building.md § "Design work — full toolchain"' > "$FIX/pointer.sh"` (double quotes and em dash byte-for-byte as the retired hook's line 78) then `check T8i-tilde-quoted-label-whole "$(_citers_extract_files "$FIX/pointer.sh" | cut -d: -f3-)" 'rules/web-building.md:Design work — full toolchain'` (exact row: proves the `~/.claude/` prefix is stripped AND the label kept whole). Comment: "the retired design hook's pointer shape: ~ prefix + quoted label" — never the hook's filename (AC4 greps lib/tests).
- Order: edit settings.json FIRST (remove the registration), THEN `git rm` the hook and its test (both paths are live through ~/.claude symlinks; the reverse order makes every open session's prompts exit 127 in between).
- New AC6 (after STEP 6 doc sync): `grep -c design-toolchain ARCHITECTURE.md` → 0.
- Disposition corrected: measurement = journal 2026-10-31 / TODO "Measure the design hook's re-Read cost" (59 fires, 0 Reads), not BDR-131. CAPITALIZE: one BDR via memory.sh superseding BDR-125 Amendment 7's "design hook one-liner" carrier clause and the hook-based heading-durability rationale in BDR-021 / BDR-098 (the always-on CLAUDE.global.md pointer + doctrine-citers census keep the heading pinned).
- Hand-off note: restart open sessions (a session still holding the old hook list logs a non-blocking hook error on each prompt until restarted).

## r3 (confirmation SOLID, 5 MINOR folded; no further challenge)
- T8 block header comment (doctrine-citers.test.sh:143-144) → `T8a-T8i` and the list gains "quoted label kept whole".
- Heading pin corrected: only the "Design work" prefix stays pinned (CLAUDE.global.md:282 citer, census row `rules/web-building.md:Design work`; `_citers_resolve` accepts a prefix + space/—/(/:). The full heading "Design work — full toolchain" loses its last citer, which nothing needs once the hook is gone.
- CAPITALIZE: the superseding BDR also names BDR-130's hook clause ("hook one-liner says Read it", "hook = pointer") in its supersedes/amends line, beside BDR-125 Amendment 7, BDR-021, BDR-098.
