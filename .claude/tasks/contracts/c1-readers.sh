#!/usr/bin/env bash
# GATE 0 oracle, contract context-diet c10: the readers name the lib; no
# tracked doctrine file still cites rules/default-language.md.
set -u
for f in skills/init-project/SKILL.md skills/ship-feature/SKILL.md \
  skills/onboard/SKILL.md agents/interviewer.md agents/scaffolder.md \
  skills/audit-delta/SKILL.md agents/seo-analyzer.md; do
  grep -q 'lib/architecture-defaults.md' "$f" || { echo "no lib in $f"; exit 1; }
done
if git grep -n 'default-language\.md' -- skills agents lib hooks rules templates \
  .claude/rules CLAUDE.global.md ':!lib/tests'; then
  echo "stale default-language.md citer"; exit 1
fi
echo READERS-OK
