# probe4c report (CLI 2.1.318, claude -p haiku, --setting-sources local, --plugin-dir)

Throwaway mod `$CLAUDE_JOB_DIR/tmp/probe4c/mod` (log only in the job tmp; deleted with the job).
Recommendation 0 of the 4c brainstorm (contract `.claude/tasks/contracts/2026-11-04-memory-recall-1859.md`).

| probe | result |
|---|---|
| `$.process.run(['bash', ~/.claude/lib/memory.sh, '-C', <repo>, 'index'], {timeoutMs})` in a hook | works: exit 0, 508 lines (4 registries, `| ID | Date | Title | Status |`), 128 ms |
| `classic.SessionStart` in a mod | fires with `source` startup; `--continue "/compact"` fires `resume` then `compact`; keys: session_id, transcript_path, cwd, source, model, agent_id, agent_type, effort, … |
| `classic.SessionStart` returning `additionalContext` | reaches the model (it quoted `PROBE4C-SESSIONSTART-CONTEXT source=startup`) |
| `tool.call` Bash error answer `{...out, context: [...]}` | reaches the model (it quoted `PROBE4C-TOOL-CONTEXT` as tool-result context); the error answer has no `context` key before the hook adds one |
| `$.model.complete({model: 'claude-haiku-5-5', prompt, maxTokens: 64, effort})` | see below |

haiku rerank latency (prompt = a design question + 30 candidates; same session, sequential):

| variant | prompt chars | input tokens | ms (n=3, + 2 earlier full/low runs: 2494, 7332) | output tokens |
|---|---|---|---|---|
| effort low, ~350 chars per candidate | 10 865 | 3 965 | 1725, 2743, 1790 | 225-258 |
| no effort, same prompt | 10 865 | 3 965 | 2063, 5713, 1938 | 224-302 |
| effort low, ~150 chars per candidate | 4 865 | 2 045 | 2921, 2060, 2755 | 326-394 |

- Median ≈ 2 s; tail 5.7-7.3 s (2 of 11 calls over 5 s, 3 of 11 over 2.7 s). A 3 s bound drops roughly one call in five on this sample.
- `maxTokens: 64` does not cap output tokens (220-400 reported): the model thinks; the request type has no thinking switch. A shorter candidate list does not cut latency.
- Answers were valid candidate IDs every time.
- Cost per recall ≈ 4k input + 0.3k output haiku tokens.

Consequences for the design: decision 4 (superseded reader) = memory.sh through `$.process.run` (single reader, 128 ms, no port); the compact/clear ledger reset hooks `classic.SessionStart`; the 3 s bound is the user's number, its timeout share is measured by the proof harness on the 20 real prompts and put to the gate.
