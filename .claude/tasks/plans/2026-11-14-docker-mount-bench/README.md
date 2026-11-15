# docker host-root mount deny bench

Proves which deny-rule shapes catch a docker host-root mount before any lands
in `settings.json` (TODO.md:89, plan 2026-11-14-docker-mount-deny-1400.md r3).
Same method as ../2026-11-02-phase2-bench (run.sh and bench.sh copied
unchanged: paths are relative to the script dir).

## Method

`bench.sh [id...]` reads `cases.tsv` (`id kind rule cmd want`, tab-separated,
`\n` in `cmd` is a newline, `\\` a backslash). Analogue: `echo` stands for
`docker`, nothing is mounted. One isolated headless run per row (`claude -p
--model haiku --tools Bash`, auto mode, only the bench settings), a no-rule
control per DENIED row. `results.tsv` is append-only, last row per id wins.

## Prefixes (the 4 spellings of the binary)

`echo ` (typed), `rtk echo ` (rtk rc 0 rewrite), `*/rtk echo ` (absolute rtk),
`*/echo ` (absolute binary). The cmd for the absolute forms is
`/home/u/.local/bin/rtk echo ...` and `/usr/bin/echo ...`. No bare leading
`*` (it would deny any command that merely mentions the text).

## Shapes (suffix after the prefix)

- S1 `* /:/*` : `-v /:/x`, `--volume /:/x`, `-itv /:/x`, any subcommand
- S2 `*=/:/*` : `-v=/:/x`, `--volume=/:/x`
- S3 `* -v/:/*` : attached `-v/:/x`
- S4 `*source=/,*`, S5 `*src=/,*`, S6 `*source=/ *`, S7 `*src=/ *` : `--mount`

Row ids: `Sn-pK` positive per shape and prefix (K = 0..3 in the order above);
`Sn-<spelling>` extra spellings; `N*` negatives (want RAN: `/srv`, `/srv/`,
`~/dev/`, psql `-v`, mount of `/srv`, a `grep` mention); `M*` MEASURE rows.

## Verdict rules

- Gating row: DENIED rows must be DENIED, RAN rows must be RAN, and every
  control RAN, permissionMode `auto`.
- MEASURE rows are read, never gated: M1 and M2 multi-line continuation, M3
  quoted `--mount "..."`, M4 and M5 the legacy `Bash(echo run -v /:*)` on
  `-v /srv:/x` and `-v /:/x`, M6 quoted `-v "/:/x"`.
- A shape with a gating row off its want is not added (all 4 prefixes) and
  goes to the TODO residual list.
