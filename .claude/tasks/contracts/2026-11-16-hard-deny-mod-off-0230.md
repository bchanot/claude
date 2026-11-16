# CONTRACT — hard-deny-mod-off (BDR-125 gap audit C7)
- date: 2026-11-16 | flow: hotfix | branch: bugfix/hard-deny-mod-off (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
A7/C7 (BDR-125 gap audit, user choice): settings.json autoMode.hard_deny entry 6 "Disarming the guardrails" gets a mod off-switch clause inserted right after "setting `disableAllHooks`,": "turning a mod off (`\"enabled\": false` in `~/.claude/<mod>.json`, a mod's `enabledPlugins` entry set to false, or `profile.sh disable` of a mod),". Off switches only, never mod paths or sources. Commit only this hunk: the user's uncommitted /model change in settings.json stays out of the commit.

## CLARIFICATIONS
- [gated 2026-11-16] wording "Inline in entry 6"; commit "A7 hunk only" (user answers).
- [internal 2026-11-16] challenge skipped: prose restriction added to the classifier list, no control flow. Off switches only, never paths or sources (2026-10-25 challenge BLOCKER, robustness 1: naming sources would make the classifier refuse all later mod maintenance).

## ACCEPTANCE CRITERIA
1. settings.json still parses and entry 6 carries the clause exactly once.
   CHECK: cd /home/bchanot/Documents/claude && jq -r '.autoMode.hard_deny[6]' settings.json | grep -c 'turning a mod off (`"enabled": false` in `~/.claude/<mod>.json`, a mod'"'"'s `enabledPlugins` entry set to false, or `profile.sh disable` of a mod),'
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
2. hard_deny length unchanged (8), no deny or soft_deny entry removed.
   CHECK: cd /home/bchanot/Documents/claude && jq '.autoMode.hard_deny | length' settings.json
   EXPECT: 8
   EVIDENCE: MET exit=0 marker-found :: 8
3. push-guard suite green.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/push-guard.test.sh </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green

## FILE SCOPE
settings.json (autoMode.hard_deny[6] only).
