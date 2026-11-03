# probe4b report (CLI 2.1.317, claude -p, haiku, --setting-sources local)
Raw log: /home/bchanot/.claude/jobs/8573ce6f/tmp/probe4b/log.jsonl (per case: log.cN.jsonl; full streams: out.cN.jsonl)
Mod loaded: init event plugins list contains {"name":"probe4b","source":"probe4b@inline","version":"0.1.0"}.

| case | isError | keys of out | deny | text | gitOperation | classic events |
|---|---|---|---|---|---|---|
| C1 false | true | ref,result,text,isError,isReadOnly | none (undefined) | "Exit code 1" | n/a (result is a string) | PostToolUseFailure (error "Exit code 1", is_interrupt false) |
| C2 echo SECRET (deny rule) | true | ref,result,text,isError | none | "Permission to use Bash with command echo SECRET has been denied." | n/a | none (no PermissionDenied) |
| C3 git merge -h (ask, auto) | true | ref,result,text,isError | none | "Claude requested permissions to use Bash, but you haven't granted it yet." | n/a | none |
| C4 ls /nonexistent-dir | true | ref,result,text,isError,isReadOnly | none | "Exit code 2\nls: cannot access '/nonexistent-dir': No such file or directory" | n/a | PostToolUseFailure (error = same text) |
| C5 echo>f && git add && git commit | true | ref,result,text,isError | none | "This Bash command contains multiple operations. The following parts require approval: echo hi, git add f.txt, git commit" | n/a (never ran) | none |
| C5b git commit --allow-empty -qm ... (extra, single command) | undefined (key absent) | ref,result,text | none | "(Bash completed with no output)" | absent (undefined) | PostToolUse |
| C6 bash commit.sh | undefined (absent) | ref,result,text | none | "(Bash completed with no output)" | absent | PostToolUse |
| C7 printf TOKEN=abc123 | undefined (absent) | ref,result,text,isReadOnly | none | "TOKEN=abc123" | absent | PostToolUse |

Non-error result: typeof result = "object", with stdout, stderr, interrupted (false), returnCodeInterpretation absent, gitOperation absent. C7 stdout = "TOKEN=abc123" (trailing newline trimmed), stderr "". Error result: typeof result = "string" (same as text).
PostToolUse keys: session_id, transcript_path, cwd, scratchpad_dir, prompt_id, permission_mode, agent_id, agent_type, effort, hook_event_name, tool_name, tool_input, tool_response, tool_use_id, duration_ms.
PostToolUseFailure keys: same minus tool_response, plus error, is_interrupt.
Not logged: tool_response contents (only keys).

Surprises
- The permission-denied results carry no `deny` field: they are isError results with the denial in text. PermissionDenied never fired (C2 rule deny, C3 ask).
- C3: init permissionMode was "auto", yet the ask rule yielded a "haven't granted" error, no classifier approval in -p.
- C5: Bash(*) did not cover the compound command (&&, redirect): split into parts needing approval, nothing ran. C5b added as a single-command substitute; commit succeeded, quiet output.
- gitOperation never present, even on real commits (C5b, C6). With -q the commit prints nothing; untested without -q.
- isError is absent (not false) on success; isReadOnly present only for some commands (false, ls, printf), absent for git commit / bash script.
- Hook parsing quirk: validator rejects on(name) with a variable event name and $ passed to non-top-level functions; needed literal event names and top-level function declarations.
