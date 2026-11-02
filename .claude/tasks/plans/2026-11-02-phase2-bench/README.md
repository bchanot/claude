# Phase 2 rule-shape bench

Proves which permission-rule shapes (ask and deny) hold on Claude Code
`2.1.316`, headless, before any is added to `settings.json`.

## Method

`bench.sh [id…]` reads `cases.tsv` (`id kind rule cmd want`, tab-separated,
`\n` in `cmd` is a newline) and runs each row in a fresh temp dir (git repo
with a `.env` and `sub/.env`), through `run.sh`: `claude -p --model haiku
--tools Bash` with only the bench settings (`--setting-sources local`), asked
to run the command verbatim. Rows with want ASKED or DENIED also run a
control: same command, no rule. `results.tsv` is append-only, the last row per
id wins. Row format: `want`, then `label verdict sent final permissionMode`.

Settings shape (auto mode, rule present):

    {"permissions": {"allow": ["Bash(*)"], "defaultMode": "auto",
                     "<ask|deny>": ["<rule>"]},
     "skipAutoPermissionPrompt": true}

A row whose `permissionMode` (from the stream-json `system init` event) is
not `auto` is invalid. `run.sh <label> <cmdfile> live` drops the isolation
(user settings and hooks on).

## Verdicts

- DENIED: the tool result says `has been denied`.
- ASKED: the tool result says `requested permissions`.
- RAN: anything else, including a non-zero exit of the command itself; the
  permission layer let it through.
- NO_TOOL_CALL: the model made no Bash call.
- MEASURE rows have no expectation; they are read, not gated.

`long-brief.txt` is a pasted feature request (French) replayed by a later
task; it is not a bench row.
