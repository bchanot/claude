# RUN B — round 2 gaps (GATE 1 ECARTS(2) + GATE 2 findings), 2026-11-11

Apply on top of the current working tree (RUN B edits are in place, uncommitted). Binding plan: .claude/tasks/plans/2026-11-11-advisor-packs-vocabulary-1000.md r3 (RUN B + User decisions [gated]).

## Verifier gaps (must close)
G1. lib/plugin-gate.md step 5: the PROPOSED CHANGES consent prompt (before "Apply these changes? (yes / no / customize)") must say the change is project-wide and persists in `<PROJECT_ROOT>/.claude/settings.local.json`. Today it only appears after the write.
G2. USAGE.md :647 and :710 read "→ DISABLE: pack design, packs gstack (profil dev ou minimal)": `dev` turns pack gstack-dev ON, so the line contradicts itself, and "packs gstack" is a collective gstack OFF. Rewrite both to what the new advisor emits for that scenario (CLI / library, source=default + full): a `↻ SET : dev` line (gate shows what it turns off), no DISABLE of a pack dev enables, never "packs gstack" as a group.

## Transcript accuracy (same class as G2, verifier notes)
G3. USAGE.md :418 and :496 show DISABLE lines from description-only /plugin-check runs before init (source=default + full): the new advisor emits a `↻ SET : <profile>` there (mobile → the profile the RULES give; public website → `web`, which keeps gstack-dev and gstack-browser on), never a REQUEST-only DISABLE. :494 and :548 ENABLE pack design + ui-ux-pro-max that `full` already turns on: show them as KEEP (or covered by the SET target), not ENABLE.
G4. USAGE.md :1091 `"design élaboré" / tokens → ui-ux-pro-max ON`: same rewrite as its twin :231.
G5. USAGE.md :240 keeps the banned frame "n'est pas X : c'est Y": reword as a plain statement (e.g. "GSD v2 est un CLI externe, rien ne se charge dans Claude Code. …"). :704 heading "zéro token inutile": reword without a token claim. Em-dashes inside the rewritten structured transcript lines (:326 tree prefix, :494 template separator, :1055 STEP line) may stay (structured formats, not prose).

## Rule tensions (advisor)
G6. agents/plugin-advisor.md simple/hotfix RULE (:214): a REQUEST-only "simple"/"hotfix" signal drives NO SET and NO DISABLE (both are project-wide, persistent); it recommends the lightweight skill only. `minimal` stays reachable from project-level signals (embedded RULE, WRITING table "narrow session" row).
G7. lib/plugin-gate.md step 4: when `profile.sh -C "<PROJECT_ROOT>" diff <profile>` exits non-zero (no project root yet, e.g. /init-project STEP 0 before git init), print "turns off: unknown (no project root yet)" and continue; step 5 already applies nothing in that case.

## Security findings (GATE 2 PASS, fixed here)
S1 (MEDIUM). lib/plugin-gate.md: the main loop builds every command from the fixed template only; before running ANY command (step-4 diff included) it checks the advisor's token: profile name against the profiles in `lib/profiles/` (`^[a-z0-9][a-z0-9-]*$` and an existing `lib/profiles/<name>.json`), pack against the documented pack list (design, scroll3d, seo, web-validate, gstack-dev, gstack-browser, gstack-design, higgsfield, extras), plugin against the two managed full ids (`ui-ux-pro-max@ui-ux-pro-max-skill`, `pr-review-toolkit@claude-code-plugins`). A token that matches none is printed as rejected and skipped, never pasted into a shell. Tokens are quoted in the template.
S2 (LOW). lib/plugin-gate.md: quote the root everywhere in the templates: `-C "<PROJECT_ROOT>"`, `git -C "<PROJECT_ROOT>" rev-parse --show-toplevel`.
S3 (LOW). agents/plugin-advisor.md: the emitted command form names the token only, the gate builds the command: e.g. `⚡ ENABLE : pack design — <reason> — enable design` (or keep the full form but with `-C "<PROJECT_ROOT>"` and `"$HOME/.claude/lib/profile.sh"` quoted). Pick ONE form and make advisor template, WRITING section and gate agree; the gate never runs the advisor's line verbatim.

## Out-of-scope citer (BDR-100)
C1. skills/onboard/SKILL.md:254 `npm install -g ctx7 && ctx7 setup --claude` → `make plugin` (installs ctx7 and wires find-docs), same as the advisor WARN; only that line.

## Tests
T1. lib/tests/session-banner.test.sh SB10: lock `has` lib/plugin-gate.md 'rejected' (S1) and `gone` lib/plugin-gate.md "-C <PROJECT_ROOT>" (unquoted form, S2) = 1; `gone USAGE.md 'packs gstack \(|DISABLE: pack design, packs gstack'` = 1; `gone skills/onboard/SKILL.md 'ctx7 setup'` = 1. Keep every existing lock green.
