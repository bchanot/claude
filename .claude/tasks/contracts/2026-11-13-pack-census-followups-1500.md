# CONTRACT — pack-census-followups (phase 5 leftovers, block H3)
- date: 2026-11-13 | flow: bugfix | branch: bugfix/pack-census-followups (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
Follow-ups: `lib/pack-census.sh:67` `grep -qx` → `grep -qxF`; fragment top-level key allowlist in `lib/pack-census-fragments.jq` (today only `enabledPlugins` keys are compared).

## CLARIFICATIONS
- [gated 2026-11-13, internal; amended after GATE 1: `model` is a documented fragment key, profile.sh:182/216/226, profiles/README.md:5-6] allowlist = the keys lib/profile.sh reads: `enabledPlugins`, `deniedMcpServers`, `disableClaudeAiConnectors`, `model`; any other top-level key → `RED lib/profiles/<f>: unknown top-level key(s) <k, …>`.

## ACCEPTANCE CRITERIA
1. Fixed-string match on the retired list.
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c 'grep -qxF -- "\$s" "\$REMOVED"' lib/pack-census.sh)$(grep -c 'grep -qx -- ' lib/pack-census.sh)
   EXPECT: 10
   EVIDENCE: MET exit=0 marker-found :: 10
2. Unknown top-level key is RED; the four known keys (incl. `model`) pass.
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c 'unknown top-level key' lib/pack-census-fragments.jq lib/tests/pack-census.test.sh | grep -c ':[1-9]')$(grep -c '"model"' lib/pack-census-fragments.jq)
   EXPECT: 21
   EVIDENCE: MET exit=0 marker-found :: 21
3. Census suite green with the new case; the live profiles pass the allowlist.
   CHECK: cd /home/bchanot/Documents/claude && bash lib/tests/pack-census.test.sh 2>&1 | tail -1
   EXPECT: FAIL=0
   EVIDENCE: MET exit=0 marker-found :: PASS=40 FAIL=0
4. shellcheck -x clean on lib/pack-census.sh; `make test suite=lib/tests/pack-census.test.sh` green.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck -x lib/pack-census.sh && PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/pack-census.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green

## FILE SCOPE
lib/pack-census.sh (:65 one flag), lib/pack-census-fragments.jq (one RED rule), lib/tests/pack-census.test.sh (one case). CHANGELOG → STEP 7. TODO phase 5 line → STEP 8.
