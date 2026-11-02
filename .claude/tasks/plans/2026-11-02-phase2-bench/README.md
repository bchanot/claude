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

## Results 2026-11-02 (gate)
Every control RAN, every row ran in `auto` (permissionMode column). Approved (approved.txt): 16 ask, 7 deny (the rtk read twins are generated in Task 6, shape proven by R1/R2).
Not approved: `Bash(bash "*gitflow.sh" finish*)` (M3q RAN: the matcher does not take a quote inside the pattern; M3x shows `Bash(bash *gitflow.sh finish*)` already asks on the quoted call-site form `bash "$HOME/…/gitflow.sh" finish`, so the gate holds without it); `Bash(gitflow_finish*)` (M5 RAN: the sourced-function form is not caught, residual); `Bash(bash -s*)` (S4 RAN: `… | bash -s` is not caught, residual); A1b `Bash(awk *system*)` passed but A1 (narrower) is kept.
H0 RAN: `head -5 .env` escapes `Bash(head .env)` natively, so the flag forms are needed.
rtk.tsv: every ask-row command is rc 1 for `rtk rewrite` (no rewrite), M7 rc 3 (passed through since Task 2): no rtk twin needed for the asks.
G1: an ask hit inside a headless sub-agent raised 8 permission requests and never ran.
