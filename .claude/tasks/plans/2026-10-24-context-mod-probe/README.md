# context-mod probe (BDR-125 evidence + test bench)

Throwaway mod used 2026-10-23 to prove every lever of the context mod.
Each hook plants a unique canary; a fresh headless session reports
PRESENT/ABSENT per canary, with negative controls.

Run (from the repo root, real context):

    printf '%s\n' "<canary questions>" \
      | claude -p --model haiku --plugin-dir .claude/tasks/plans/2026-10-24-context-mod-probe

Results 2026-10-23: prompt.context drop file (default-language ABSENT,
writing-style PRESENT) + add block; prompt.compose add section;
prompt.section drop `memory`; prompt.submit `context`; tool.call result
`context` (Read); prompt.attachment `skill_listing` rewrite (scrape
ABSENT, seo PRESENT); agent.offer false = agent undispatchable;
command.describe isHidden = typeahead only. The measurement log lists
every block, instruction file, system section and attachment with sizes.
