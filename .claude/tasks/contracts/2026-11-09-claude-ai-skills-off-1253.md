# CONTRACT — claude-ai-skills-off
- date: 2026-11-09 | flow: feat | branch: feature/claude-ai-skills-off
- status: active

## REQUEST (verbatim — IMMUTABLE)
L1 context diet (user-approved 2026-11-09): global `skillOverrides` in tracked settings.json (= ~/.claude/settings.json) setting the 19 claude.ai-synced skills to "off": docs, pptx, google-workspace, xlsx, computer-use, docx, built-in-browser, chrome-browser, prompt-engineer, anthropic-skills:deep-research, veille-emploi, pdf, morning, skill-creator, dossier-location, import-memory, saas-concil, cv-rewriter, cv-diagnoser. Global so a plain `claude` (no profile = full, user requirement) gets it too. Measured: −3.7k tokens (full 32.2k→28.5k headless); proven from a settings.local.json scope (scratchpad scope-probe: 0 synced skills listed). A project re-enables one with "on" in its settings.local.json. SLASH_COMMAND_TOOL_CHAR_BUDGET stays 50000. Not in scope: Higgsfield connectors (user removes them on claude.ai; dead deniedMcpServers cleanup is a later run). Docs: CHANGELOG Unreleased, lib/profiles/README.md or SETTINGS.md where settings env/listing budget is described. Raw measures: /home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/b681969c-a00d-4b27-8e53-ded169faf56f/scratchpad/ctx/.

User words (2026-11-09, conversation): "ok pour l1 et l3"; "j'avais dit qu'on doit avoir par defaut le profile full. donc il faudrait si on lance claude tout court, que ca prenne full comme profil".

## CLARIFICATIONS
Q: where does skillOverrides live (profile fragments vs global settings.json)? / A: global — a plain `claude` must behave as full; fragments are not read without a profile. [gated 2026-11-09]
Q: Higgsfield claude.ai connectors? / A: user removes them on claude.ai; out of this run. [gated 2026-11-09]
Q: doc target (REQUEST names lib/profiles/README.md or SETTINGS.md)? / A: README.md § Settings and permissions (the settings hierarchy lives there; no other doc but CHANGELOG describes the listing budget); delegated — default taken by the orchestrator after the correctness challenge. [gated 2026-11-09]

## ACCEPTANCE CRITERIA
1. `settings.json` gains a top-level `skillOverrides` object holding exactly the 19 names of the REQUEST, each `"off"`; every other top-level key is byte-identical in value to `develop`; the file stays valid JSON.
   CHECK: cd /home/bchanot/Documents/claude && want='["anthropic-skills:deep-research","built-in-browser","chrome-browser","computer-use","cv-diagnoser","cv-rewriter","docs","docx","dossier-location","google-workspace","import-memory","morning","pdf","pptx","prompt-engineer","saas-concil","skill-creator","veille-emploi","xlsx"]' && [ "$(jq -c '.skillOverrides|keys' settings.json)" = "$want" ] && [ "$(jq -c '[.skillOverrides[]]|unique' settings.json)" = '["off"]' ] && [ "$(jq -S -c 'del(.skillOverrides)' settings.json)" = "$(git show develop:settings.json | jq -S -c .)" ] && echo SKILLOVERRIDES-OK
   EXPECT: SKILLOVERRIDES-OK
   EVIDENCE: MET exit=0 marker-found :: SKILLOVERRIDES-OK
2. Live effect: a headless `/context` at the repo root (output holds the `| Skills |` row) lists no `claude.ai sync` skill; positive control and per-key merge proof: from a scratch project whose `.claude/settings.local.json` is `{"skillOverrides":{"docx":"on"}}`, a headless `/context` lists exactly ONE `claude.ai sync` skill and it is `docx` (a wholesale replace of the user map would list 19).
   CHECK: cd /home/bchanot/Documents/claude && a=$(timeout 120 claude -p "/context" --output-format json </dev/null 2>/dev/null | jq -r .result) && printf '%s\n' "$a" | grep -q '^| Skills |' && [ "$(printf '%s\n' "$a" | grep -c 'claude.ai sync')" = 0 ] && P=/home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/b681969c-a00d-4b27-8e53-ded169faf56f/scratchpad/ctx/merge-probe && mkdir -p "$P/.claude" && (cd "$P" && git init -q) && printf '{"skillOverrides":{"docx":"on"}}\n' > "$P/.claude/settings.local.json" && b=$(cd "$P" && timeout 120 claude -p "/context" --output-format json </dev/null 2>/dev/null | jq -r .result) && printf '%s\n' "$b" | grep -q '^| Skills |' && [ "$(printf '%s\n' "$b" | grep -c 'claude.ai sync')" = 1 ] && [ "$(printf '%s\n' "$b" | grep -c '^| docx | claude.ai sync')" = 1 ] && echo SYNC-OFF-OK
   EXPECT: SYNC-OFF-OK
   EVIDENCE: MET exit=0 marker-found :: SYNC-OFF-OK
3. The repo suite stays green.
   CHECK: cd /home/bchanot/Documents/claude && make test 2>&1 | tail -3 | grep -q 'all suites green' && echo SUITE-OK
   EXPECT: SUITE-OK
   EVIDENCE: MET exit=0 marker-found :: SUITE-OK
4. README.md § "Settings and permissions" says, in a short paragraph, that `settings.json` turns the claude.ai-synced skills off through `skillOverrides` (why: listing cost, measured on the full profile 2026-11-09: 32.2k → 28.5k headless), that the list is by name (a skill synced later stays listed until its name is added; a same-named skill elsewhere is hidden too), and that a project re-enables one with `"<name>": "on"` under `skillOverrides` in its `.claude/settings.local.json`; no hardcoded skill count. CHANGELOG.md `[Unreleased]` `### Changed` gains one bullet with the same facts, the measured figures, the CLI version measured (2.1.319) and "check `claude --version` on another machine before pulling". No em-dash in the new prose.

## FILE SCOPE
settings.json, README.md (§ Settings and permissions only), CHANGELOG.md ([Unreleased] only)
