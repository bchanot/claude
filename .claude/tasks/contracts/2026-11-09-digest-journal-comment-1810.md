# CONTRACT — digest-journal-comment
- date: 2026-11-09 | flow: hotfix | branch: bugfix/digest-journal-comment
- status: active

## REQUEST (verbatim — IMMUTABLE)
G3 from .claude/audits/BUGS-FOUND.md (code-clean 2026-11-09): hooks/session-start.sh:404-408 `_digest_journal` greps `^- ` without skipping HTML comments; templates/memory/journal.md:19-21 holds `- <line …>` bullets inside `<!-- -->`, so a project born from the template prints "- journal: <line 3-5 max>" in the session digest until its first journal write. Fix in the digest (skip lines inside `<!-- … -->` blocks) so the template stays byte-identical (it is copied by onboarder/init-project and memory.sh upgrade). Regression test in lib/tests/session-digest.test.sh with a fixture journal built from templates/memory/journal.md: digest prints no journal line (or the real last entry once one exists). Mark the BUGS-FOUND entry FIXED. make test needs GATES_TIMEOUT=600 + PATH=$HOME/.bun/bin:$PATH.

## CLARIFICATIONS
Q: oracle 2 "shellcheck clean"? / A: corrected to `shellcheck -S warning` (orchestrator, 2026-11-09): develop already exits 1 on info notes (SC1091); the new SC2016 info is the intended literal backticks of SD18-inline-marker.

## ACCEPTANCE CRITERIA
1. Symptom gone: a project whose journal.md is a byte copy of templates/memory/journal.md gets no `- journal:` line in the digest; once a real entry is appended after the comment, the digest shows that entry; the template is unchanged.
   CHECK: cd /home/bchanot/Documents/claude && git diff --quiet develop -- templates/memory/journal.md && make test suite=lib/tests/session-digest.test.sh 2>&1 | tail -1 | grep -q 'all suites green' && grep -q 'SD18' lib/tests/session-digest.test.sh && echo SYMPTOM-GONE
   EXPECT: SYMPTOM-GONE
   EVIDENCE: MET exit=0 marker-found :: SYMPTOM-GONE
2. Build/tests green (full suite, GATES_TIMEOUT=600, bun on PATH); shellcheck clean on hooks/session-start.sh and lib/tests/session-digest.test.sh.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck -S warning hooks/session-start.sh lib/tests/session-digest.test.sh && make test 2>&1 | tail -1 | grep -q 'all suites green' && echo GREEN
   EXPECT: GREEN
   EVIDENCE: MET exit=0 marker-found :: GREEN

## FILE SCOPE
hooks/session-start.sh (`_digest_journal` only), lib/tests/session-digest.test.sh (new SD18 case); bookkeeping: .claude/audits/BUGS-FOUND.md (FIXED line)
