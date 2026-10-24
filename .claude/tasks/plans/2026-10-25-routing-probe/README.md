# routing probe (bench for skill auto-routing, 2026-10-25)

A throwaway mod that records the first routing decision of a fresh headless
session and blocks every effect: Skill and Agent calls are recorded then
denied, a code Edit/Write is recorded then denied, doc writes (.md,
`.claude/**`) are allowed, Bash is softly denied, Read/Grep/Glob pass.
Run each case in a throwaway clone (never the real repo), output path in
`ROUTEPROBE_OUT`:

    ROUTEPROBE_OUT=/tmp/r.json claude -p --plugin-dir .claude/tasks/plans/2026-10-25-routing-probe < prompt.txt

`cases.tsv`: id, cwd, expected skills, natural French prompt.

Results 2026-10-25 (opus session model): init-project, close, bugfix,
reconcile, commit-change, cso routed right; explain answered directly;
false-premise prompts refused with facts; "ajoute --dry-run" asked its
questions inline instead of entering /feat; "j'aimerais que doctor.sh
affiche la version de rtk" edited code inline with no skill. Limit: with
Bash denied the model often stops ("environment has no Bash"); a next
version should allow a safe Bash subset in a clone with its origin remote
removed.
History (2026-09-23 → 10-24, 187 sessions): 10 code-writing bug/feature
turns went through a skill, 11 coded inline (all long pasted faunosteo
briefs). Listing: 124 skills, 46 name-only at the default budget;
`SLASH_COMMAND_TOOL_CHAR_BUDGET=60000` → 0 name-only, listing 30k → 47k chars.
