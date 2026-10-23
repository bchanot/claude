# CONTRACT — settings-deny-patterns
- date: 2026-10-23 | flow: hotfix | branch: bugfix/settings-deny-patterns
- status: active

## REQUEST (verbatim — IMMUTABLE)
oui traite le je ferais la questions suivante ensuite
(context: CLI startup warns 6 settings.json deny rules are ineffective; headless tests proved `Bash(docker run * -v /:*)` and `Bash(git push * :*)` never match, `Write(...)` deny never blocks the Write tool, `Edit(...)` does.)

## CLARIFICATIONS
- [gated 2026-10-23] Additive fix (user pick): add working forms beside the old ones; the push-guard.test.sh T41/T42 non-weakening lock stays untouched, so the 6 dead entries stay and their startup warnings persist.

## ACCEPTANCE CRITERIA
1. settings.json permissions.deny contains `Bash(docker run * -v /:/*)` and `Bash(git push * :**)`, JSON valid, no entry removed.
   CHECK: cd /home/bchanot/Documents/claude && jq -e '.permissions.deny | (index("Bash(docker run * -v /:/*)") and index("Bash(git push * :**)") and index("Bash(docker run * -v /:*)") and index("Bash(git push * :*)"))' settings.json >/dev/null && echo DENY-ADDED
   EXPECT: DENY-ADDED
   EVIDENCE: pending
2. make test green.
   CHECK: cd /home/bchanot/Documents/claude && make test 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: pending

## FILE SCOPE
settings.json
