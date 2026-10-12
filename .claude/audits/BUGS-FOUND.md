# BUGS-FOUND

- lib/toggle-external.sh:350 (pre-cleanup numbering; `usage()`, now near :370) — usage() prints header lines 3-26 only (`sed -n '3,26p'`); the managed-tool list continues to line 32, so `--help` omits 8 of the 14 tools. Severity: low (help text only). Discovered while: code-clean run 2026-10-12 (B5 audit). Not fixed (cleanup and bugfix are separate concerns).
  FIXED 2026-10-12 (inline on chore/code-clean, no /bugfix pipeline): usage() now prints lines 3 .. closing banner (`sed -n '3,/^# ====/p' | sed '$d'`), no numeric range; --help shows all 14 tools (36 lines).
