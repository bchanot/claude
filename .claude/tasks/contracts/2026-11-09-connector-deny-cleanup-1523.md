# CONTRACT — connector-deny-cleanup
- date: 2026-11-09 | flow: ship-feature | branch: chore/connector-deny-cleanup
- status: active

## REQUEST (verbatim — IMMUTABLE)
Cleanup (user-approved 2026-11-09): the claude.ai Higgsfield connectors ("claude.ai higgsfield", "claude.ai Higgsfield AI") were removed at the claude.ai account level by the user on 2026-11-09 (verified headless: only Claude Docs connector left). The `deniedMcpServers` entries in lib/profiles/{audit,dev,minimal,qa,seo}.json are now dead. Remove them and every citer: the census rule in lib/pack-census-fragments.jq (lines ~3, 28-30: "must deny both higgsfield connectors") + its test fixtures in lib/tests/pack-census.test.sh, the comment in lib/pack-census.sh:14, lib/profiles/README.md (lines 5, 11-13), skills/profile/SKILL.md (lines 26, 61-63), CHANGELOG [Unreleased] (known-limit line ~62 + new entry). KEEP the generic deniedMcpServers mechanism in lib/profile.sh / lib/profile-state.jq and its tests (lib/tests/profile.test.sh uses fictional connectors X/Y): it serves any future connector. No new behavior; grep every citer (doctrine-citers census in make test). make test runs with GATES_TIMEOUT=600 and PATH=$HOME/.bun/bin:$PATH (LRN-271). Context: BDR-141, BDR-134, TODO "Cleanup run" item under Context mod queue.

User words (2026-11-09): "merge et on attaque le nettoyage"; flow pick "/ship-feature".

## CLARIFICATIONS
Q: premise, are the connectors really gone (this session still shows them)? / A: this session predates the removal; a fresh headless session after the removal listed only Claude Docs (8 tools), 0 higgsfield tool. Verified by the orchestrator 2026-11-09.
Q: orphaned denies in project settings.local.json? / A: 0 of the projects on this machine carry `deniedMcpServers` (find over ~/ depth 5, analyzer: 0 of 13 in ~/.claude.json); profiles never shipped in a release (absent from v2.0.0 and earlier). Not checked: the manual-push work machine (BDR-111); the CHANGELOG bullet tells it to delete leftover entries by hand. [gated 2026-11-09, robustness challenge]

Q: census connector rule after removal? / A: delete it entirely (no "no deny" invariant); `dn` stays in the identical-fragment check. [gated 2026-11-09]
Q: CHANGELOG for never-released profiles? / A: correct [Unreleased] in place (drop the union known-limit line, trim the 2026-11-02 deny-profile mention, one Changed bullet). [gated 2026-11-09]
Q: union note in skills/profile/SKILL.md? / A: delete it (LRN-270 keeps the fact). [gated 2026-11-09]
Q: design (brainstorm, bounded) approved? / A: yes. [gated 2026-11-09]
Q: (code review) CHANGELOG revert hint miscounts commits? / A: name the merge: "revert the merge of `chore/connector-deny-cleanup` into develop (`git revert -m 1 <merge>`), which restores the denies, their census rule and the docs". [gated 2026-11-09]
Q: (code review) `design` list line purpose? / A: append "; UI and visual design work." [gated 2026-11-09]
Q: (code review) minors? / A: add "(dev, qa and seo denied the connectors at the time)" to the 2026-11-02 measurement line; add a T13 variant: a fragment identical to dev.json except a fictional deny is NOT reported identical. [gated 2026-11-09]

## ACCEPTANCE CRITERIA
1. No profile fragment carries `deniedMcpServers`; positive control: develop's dev.json does (the check can fail).
   CHECK: cd /home/bchanot/Documents/claude && git show develop:lib/profiles/dev.json | jq -e 'has("deniedMcpServers")' >/dev/null && for f in lib/profiles/*.json; do jq -e 'has("deniedMcpServers") | not' "$f" >/dev/null || { echo "still: $f"; exit 1; }; done && echo NO-FRAGMENT-DENY
   EXPECT: NO-FRAGMENT-DENY
   EVIDENCE: MET exit=0 marker-found :: NO-FRAGMENT-DENY
2. No tracked file outside history names the two connectors or the deny-profile list, and the profile docs no longer describe profiles by connector state (the generic `connectors denied:` output label of lib/profile.sh / profile-state.jq and its fictional-connector tests stay); positive control: develop's tree matches both patterns.
   CHECK: cd /home/bchanot/Documents/claude && a='claude\.ai higgsfield|claude\.ai Higgsfield AI|DENY_PROFILES|higgsfield connectors|connecteurs higgsfield' && b='connectors present|connectors denied|deny set' && docs='lib/profiles/README.md skills/profile/SKILL.md lib/tests/pack-census.test.sh' && git grep -q -E "$a" develop -- ':!.claude' ':!skills-external' ':!CHANGELOG.md' && git grep -q -E "$b" develop -- $docs && ! git grep -n -E "$a" -- ':!.claude' ':!skills-external' ':!CHANGELOG.md' && ! git grep -n -E "$b" -- $docs && echo NO-CONNECTOR-CITER
   EXPECT: NO-CONNECTOR-CITER
   EVIDENCE: MET exit=0 marker-found :: NO-CONNECTOR-CITER
3. The generic connector-deny mechanism and its tests are untouched.
   CHECK: cd /home/bchanot/Documents/claude && git diff --quiet develop -- lib/profile.sh lib/profile-state.jq lib/tests/profile.test.sh && grep -q 'managed_connectors' lib/profile.sh && echo MECHANISM-KEPT
   EXPECT: MECHANISM-KEPT
   EVIDENCE: MET exit=0 marker-found :: MECHANISM-KEPT
4. The pack census passes on the real repo and its suite is green.
   CHECK: cd /home/bchanot/Documents/claude && bash lib/pack-census.sh 2>&1 | grep -q '^PACKS OK' && make test suite=lib/tests/pack-census.test.sh 2>&1 | tail -3 | grep -q 'all suites green' && echo CENSUS-OK
   EXPECT: CENSUS-OK
   EVIDENCE: MET exit=0 marker-found :: CENSUS-OK
5. The repo suite stays green (run with GATES_TIMEOUT=600 and PATH=$HOME/.bun/bin:$PATH).
   CHECK: cd /home/bchanot/Documents/claude && make test 2>&1 | tail -3 | grep -q 'all suites green' && echo SUITE-OK
   EXPECT: SUITE-OK
   EVIDENCE: MET exit=0 marker-found :: SUITE-OK
6. Prose citers are rewritten, not just cut: lib/profiles/README.md (`- **name**: text` shape kept for `profile.sh list`, invariants paragraph without the deny clause), skills/profile/SKILL.md, USAGE.md, CHANGELOG `[Unreleased]` (no known-limit line about the union of higgsfield denies, the 2026-11-02 measurement line no longer presents deny profiles as shipped behavior, one entry saying the profiles deny no connector since the account removal); no em-dash in new prose.

7. [gated 2026-11-09] The read-only profile verbs work on the real repo with no fragment deny: `list` prints 9 profiles and no `(no line in lib/profiles/README.md)`; `show dev` says `connectors denied: none`; `diff dev` prints no `connectors denied:` line.
   CHECK: cd /home/bchanot/Documents/claude && l=$(bash lib/profile.sh list) && [ "$(printf '%s\n' "$l" | grep -c -E '^(full|max|minimal|dev|design|web|seo|qa|audit) ')" = 9 ] && ! printf '%s\n' "$l" | grep -q 'no line in lib/profiles/README.md' && bash lib/profile.sh show dev | grep -q 'connectors denied: none' && ! bash lib/profile.sh diff dev | grep -q 'connectors denied:' && echo VERBS-OK
   EXPECT: VERBS-OK
   EVIDENCE: MET exit=0 marker-found :: VERBS-OK
8. [gated 2026-11-09] The identical-fragment check still compares the deny set (`dn` kept), and the census jq no longer reads a `$deny` argument.
   CHECK: cd /home/bchanot/Documents/claude && grep -q '^def dn:' lib/pack-census-fragments.jq && grep -q '\.d == \$e\.value\.d' lib/pack-census-fragments.jq && ! grep -q '\$deny' lib/pack-census-fragments.jq && ! grep -q -- '--arg deny' lib/pack-census.sh && echo DN-KEPT
   EXPECT: DN-KEPT
   EVIDENCE: MET exit=0 marker-found :: DN-KEPT

## FILE SCOPE
lib/profiles/{audit,dev,minimal,qa,seo}.json, lib/pack-census-fragments.jq, lib/pack-census.sh, lib/tests/pack-census.test.sh, lib/profiles/README.md, skills/profile/SKILL.md, USAGE.md, CHANGELOG.md
