# Phase 4b capture noise — 14 days of transcripts (2026-11-04)

Method (plan Task 7, LRN-047): `noise.py` (stdlib, read-only) replays every
Bash `tool_use`/`tool_result` pair of this repo's sessions modified in the
last 14 days through a 1:1 port of the mod's capture rule (`failureLine`,
`normalize`, `redact`), main-loop and sub-agent transcripts separately
(a sub-agent file is attributed to its parent session). Run:
`python3 -I noise.py --seed 42 --samples 30`. Nothing captured is written
here: counts, labels and shares only.

## Counts (default rule, as shipped on the branch)

| scope | files | captured before dedupe | after dedupe per session |
|---|---|---|---|
| main loop | 25 | 28 | 23 |
| sub-agents | 320 | 66 | 58 |
| total | 345 | 94 | 81 |

- 17 of 25 sessions captured nothing; the rest: 2 to 26 entries each.
- Letterless lines dropped: 39 (a `0` from `grep -c`, a bare `#`): the rule
  removes about a third of the raw candidates on its own.
- Distinctive lines taken from an rtk recall trailer: 1 without stripping,
  0 with it (the trailer strip works).

## Human labels on 30 random samples (seed 42)

A sample is **useful** when its line names a failure mode a future session
could meet again and a registry entry would help; **noise** otherwise (a
probe's expected non-zero exit, a `grep` with no match, a `diff`, a last
stdout line that is not an error at all).

| scope | samples | useful | noise |
|---|---|---|---|
| main loop | 5 | 3 | 2 |
| sub-agents | 25 | 2 | 23 |
| total | 30 | 5 (17 %) | 25 (83 %) |

Useful kinds: a shell `unexpected EOF while looking for matching` on a
nested heredoc (twice, BLK-039 territory), two shellcheck findings
(SC2016, SC2059), a line-width check (`N added lines > 80`).

Noise kinds: a command chain whose last segment is `grep`/`diff`/`test`
exiting 1 with the previous command's stdout as last line (8); probe
output such as `rc=0`, `file=`, `== before`, an ID, a size (9); a
`No such file or directory` from `ls`/`cat`/`sed` on a guessed path during
exploration (6); listing or status lines (2).

The noise sits almost entirely in sub-agents (explorers and reviewers
probing with `ls`, `grep -c`, `diff`). The main loop's captures are mostly
real.

## Tightenings measured (whole corpus, applied before dedupe)

| rule | main before/after | sub before/after | sample useful kept | sample noise kept |
|---|---|---|---|---|
| none (shipped) | 28 / 23 | 66 / 58 | 5 / 5 | 25 |
| `probe` | 23 / 18 | 48 / 40 | 5 / 5 | 15 |
| `errorish` | 14 / 11 | 24 / 16 | 5 / 5 | 7 |
| both | 14 / 11 | 22 / 14 | 5 / 5 | 7 |

- `probe`: drop an exit 1 whose last segment starts with `grep`, `egrep`,
  `fgrep`, `rg`, `test`, `diff`, `cmp`, `[`, `[[`.
- `errorish`: keep only a distinctive line matching, case-insensitive,
  `error|fatal|cannot|can't|no such|not found|denied|failed|failure|`
  `unexpected|invalid|exception|traceback|panic|usage:|SC\d{4}|> \d+|assert`.
- The 7 noise samples `errorish` keeps: 5 `No such file or directory`
  probes (4 of them sub-agents), 1 `non-fatal` banner (matches `fatal`),
  1 `cannot access` on a scratch path.

## Gate input (plan Task 7 step 3: noise share > 50 % → propose)

Noise share on the shipped rule: 83 % of samples, 76 % of sub-agent
captures by volume. Above the 50 % line. Proposal for the merge gate,
the user decides (it amends gated answer 2, the capture rule):

- **A (recommended):** add the `errorish` filter to `failureLine`: a
  distinctive line that holds no error-shaped word is no line (same
  treatment as a letterless line). Keeps every useful sample, cuts the
  answer from 81 to 27 entries over 14 days, costs one bounded regex on a
  ≤ 300-char line. Risk: a real failure whose last line has no keyword is
  missed (none seen in the sample; the word list can grow in 4c).
- **B:** A plus no capture in sub-agents (gated answer 2 says main loop
  and sub-agents): 81 → 11 entries, loses the 2 useful sub-agent samples
  (shellcheck and line-width findings a reviewer hit). Not recommended:
  the sub-agent mark and the hotfix exclusion already keep them out of the
  way.
- **C:** ship as is; the CAPITALIZE consumers judge each NEW line. Costs
  attention on ~70 % noise per call.

`probe` alone is not worth its complexity (10 of 25 noise samples).

## Decision (2026-11-04)

Option A accepted by the user at the gate. Implemented as `ERRORISH` in
`failureLine` (`mods/memory/hooks/register.ts`): contract answer 2-amended
and criterion 15. `noise.py --tighten errorish` reproduces the shipped rule (its `failure_line` applies `has_letter`).
