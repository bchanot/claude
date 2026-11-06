# 4c plan r1 challenge (2026-11-04) — synthesis for the r2 revision (paused for the extract-guard /feat)

Verdicts: correctness CONCERNS(5), robustness CONCERNS(4), simplicity CONCERNS(1). No BLOCKER. Full reports in the session transcript; findings to apply in r2:
- Budget: reset the main key's `spent` on every composer non-mid-turn prompt, not only on trigger prompts; test recall → ordinary prompt → known error injected (corr 1, rob 1).
- Digest: read open BLK through `bash memory.sh -C <root> index blocker` (titles + status word, 17 ms) instead of sourcing reconcile.sh (`set -uo pipefail` leaks, `$_repo_dir` unset, no titles, 296-420 ms); run the digest in a subshell `( … ) 2>/dev/null || true`; lib path from `$(dirname "${BASH_SOURCE[0]}")/../lib`; read stdin at the top of the script behind `command -v timeout jq`; char-safe cuts (non-ASCII SD6) (corr 2, 8, 13; rob 2, 13; simp 1).
- Test world: `boot` gains a `process.run` bottom driven by a World field (default literal index stdout matching REGS: BLK-001 open, LRN-002 superseded) so IDX1, the order test, NT1b keep their meaning; IDX3 re-anchored; SR3-5 set throw / exit 2 / hang (corr 3).
- Regexes: no `$` after bounded captures (heading `[^\n]{0,300}`, label `.{0,2000}` as prefixes); tests at 2001 chars and a 320-char heading; entriesOf IDs == parseIndex IDs on this repo (corr 4, rob 5, rob 6).
- Harness: main-loop files with `entrypoint == "cli"` only; haiku from a `mktemp -d` cwd with the spike's isolation (`--setting-sources local`, tools off); latency from `duration_api_ms`, labelled upper bound; import `isTrigger`, `IDLE_MS`, rules, and an exported `buildFailure`/`failureKey`; reuse noise.py `pairs_of`/`find_files` as the walk reference; report n beside each share, < 10 injected = "insufficient sample" (corr 5, 12, 15; rob 4; simp 5).
- Latency stacking: load registries once per prompt.submit, shared by note and recall; skip `process.run` when no registry file was read; consecutive-failure pause for the rerank modelled on the router's (3 fails → cooldown) (rob 3).
- Switch: `{"recall": false}` alone must not log SWITCH_INVALID for an absent `enabled` (corr 6).
- `input/output error` → `<path> error` after normalize, or run deErrno before PATH; ER case (corr 7, rob 14).
- Ledger scope: clear by session id at session.end; `classic.SessionStart` with `agent_id` resets only that agent's key; use `$.session.id()`; one call site for context start (classic.SessionStart startup|clear|compact), not session.start (corr 9, simp 4); missing `lastPrompt` = not idle (rob 10).
- Log: `saveProject` persists `log`; sweep keeps it or a separate `l:<root>` key; test injection → capture → log kept (corr 11, rob 8).
- Concurrency: check-and-record of `seen`/`spent` synchronous after the last await; two-concurrent-failures test (rob 9).
- Loader: `loadRegistries($, root, names)`; 4b callers keep two files and their `index:` line; recall reads three; `parseIndex` returns `{status, title}` and titles come from memory.sh (simp 2, 3).
- Status unavailable: index all entries for the advisory NEW/known label in memory_pending; injections stay off (rob 7).
- Task 4 split into 4a (switch, log store, ledger) and 4b (trigger, rerank) (simp 7).
- Docs: plugin.json description and register.ts header comment; no version bump (simp 6, corr 14).
- Live safety: Task 0 tells the user that `"recall": false` in `~/.claude/memory.json` is the kill switch during the build (rob 11); Task 10 headless recipe copies LRN-260 (`GITFLOW_NO_PUSH=1`, `--allowedTools`) (rob 12); sub-agent delivery of the known line checked headless or listed as residual (corr 10).
