# CONTRACT — model-scope-dialog
- date: 2026-10-25 | flow: feat | branch: feature/model-scope-dialog (from develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
/model scope dialog in model-router (TODO "Before phase 0"). Fact (docs model-config): `/model <name>` always writes `model` to user settings.json (tracked here); picker key `s` = session only; project `model` honored at launch. Mod: `command.run` on `model` with args → `$.ui.ask` "This project / This conversation / Everywhere": project = `model` in `.claude/settings.local.json` + sticky route now; conversation = sticky route only (`/route model=`); everywhere = native passthrough. No args → native picker untouched; `-p` or no surface → passthrough. Files: register.ts, register.test.ts, lib/effort-shift.md. Doctor keeps the tracked ≠ opus warning.

## CLARIFICATIONS
- Pass A: none — request complete (outcome, scope, constraints all named).
- Verified before planning: `command.run` fires on core commands too ("Core is the engine's command", types 2.1.306 l.4365-4378); a guard that fails is skipped and the command runs (fail-open = passthrough, matches BDR-125 "injections fail open"). `$.fs.write` creates the file and its directories. `$.session.root()` = project root (a shell `cd` never moves it). `$.config.set` has no scope argument, so the per-project write goes through `$.fs.write` on `<root>/.claude/settings.local.json`.
- [gated 2026-10-25] Dismissed vs headless = SPLIT (user pick): `$.session.surfaces()` empty (plain `-p`, no surface) → native passthrough BEFORE any dialog; the dialog rejected (Esc, dismissed) or answered with free text → cancel: nothing written, nothing routed, output `model: no scope chosen, nothing changed`.
- [gated 2026-10-25] A name the router does not know (`isModelName` false: `default`, `opusplan`, free text) → native passthrough, no dialog (user pick).
- [gated 2026-10-25] The id written to `.claude/settings.local.json` is the FULL id (alias resolved through `cfg.models`; a full id or a `[1m]` variant kept verbatim) (user pick, LRN-203).
- [after the challenge, 2026-10-25] "known name" = the router's TABLE (alias or a full id listed in `cfg.models`, `[1m]` stripped for the test); a shape-only id (`claude-opus-5-6`) is unknown → native (C10). The two non-native answers mirror a native user switch: sticky model route + run slot dropped, a prior sticky effort kept (C6/R4/R11). Everywhere drops a prior sticky model first (C4/R3). Project tree treated as untrusted: links refused (R5). Cause words fixed, never error messages (R6). Fail-open to native only before an answer (C3/R1). Confirmation pass K1-K14 folded (created = success, FsStat kind `dir`, `[1m]` note, bare token routed, no shared flag, partial-state text, absent = exists false, own reader with fixed words, pin note before the question, tier dropped too, kit `dirs` map, awaited show, `haiku[1m]` native, worktree limit documented). Deferred: engine gitignore behaviour on a created settings.local.json (R13), live hot-switch on a local `model` change (R15/C12) → LRN-212 live check.

## ACCEPTANCE CRITERIA
1. `/model <name>` typed by the person (origin `composer`), one token whose `[1m]`-stripped form is an alias of `cfg.models` or one of its full ids, opens one `$.ui.ask` with exactly the options `This project`, `This conversation`, `Everywhere` (that order), header `model-router`; the question names the full id (alias resolved through `cfg.models`, `[1m]` kept) and ends with "where?"; when the local settings file already holds a string `model`, a line before the final question says that at launch here the project pin wins over Everywhere (value through `clean()`).
2. Answer `This project`: `<root>/.claude/settings.local.json` holds `"model": "<full id>"` (`[1m]` verbatim), every other key preserved (2-space indent, trailing newline), the file created when absent (success text + `file created: keep it gitignored`, no toast), an existing `.claude` directory (`kind: 'dir'`) accepted; `st.userMain.route.model` = the bare token (as `/route model=` stores it), a prior sticky effort kept, `st.runMain` = null; the native command does NOT run; the output names the file, says how to undo (remove the `model` key), and never promises `[1m]` on the route (note `[1m] follows the session's variant` when the token or the session carries it).
3. Answer `This conversation`: same sticky slot change as 2, no file written anywhere, native does not run.
4. Answer `Everywhere`: `next(e)` passthrough with args unchanged; any sticky model OR tier from an earlier answer or `/route` is dropped first (its effort kept); no file written.
5. Passthrough with no dialog: no args; more than one token; origin not `composer`; a name not in the table (`default`, `opusplan`, shape-only `claude-opus-5-6`, free text, `haiku[1m]`); `st.off`; `st.asking !== null`; `$.session.surfaces()` empty. `ensureConfig` runs before the gates. A dismissed dialog (`askOr` → `Later`) or a free-text answer = cancel: nothing written, nothing routed, output `model: no scope chosen, nothing changed`.
6. The project write refuses, without throwing: a `.claude` or `settings.local.json` that is a symlink or not a directory/regular file; a file that is not JSON or not a JSON object; a read over `MAX_CONFIG_BYTES`; an fs error (a rejecting `stat` or `read` on an existing path is an fs error, never "absent"). Then: toast + output with a FIXED cause word (never `err.message` or `String(err)`), the sticky route still set, the file untouched. "Absent" = `$.fs.exists` false AND `$.fs.stat` rejecting; a path whose `stat` answers `isLink` (a dangling link included) is refused as a link, never "absent" (GATE 2 MEDIUM, 2026-10-25: `exists` may follow links). Same order for `.claude`.
7. The `model` hook's `.catch` uses the warnOnce key `command.run model` and passes through (`next(e)`); the post-answer section runs inside its own try/catch that returns `{ text: 'model failed (<kind>); … check /route show and .claude/settings.local.json' }`, so native never runs after an answer.
8. Tests in `register.test.ts` cover each line of criteria 1-7 (the plan's list), including `fable[1m]` and `claude-fable-5-1[1m]`, the conversation → everywhere sequence, the post-answer throw, and the kit carve-out: `installWrite` accepts exactly `${ROOT}/.claude/settings.local.json` and stays loud for every other path.
9. Mod suite green: validate --strict and `claude plugin test`.
   CHECK: make test suite=lib/tests/mods.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
10. `lib/effort-shift.md` documents the dialog (scopes, what each writes, the two non-native answers set a sticky route and drop the run slot, Esc = nothing, no args / unknown name / headless = native) and l.53 is amended; lines ≤ 80 columns.
   CHECK: a=$(grep -c 'This conversation' lib/effort-shift.md); b=$(awk 'length($0)>80' lib/effort-shift.md | wc -l); echo "doc=$a/$b"
   EXPECT: doc=1/0
   EVIDENCE: MET exit=0 marker-found :: doc=1/0
11. README.md: l.139 names the scope dialog beside "a user `/model`" and the routing.json writes bullet names the `/model` → This project write of `.claude/settings.local.json`.
   CHECK: a=$(grep -c 'this project, this conversation, everywhere' README.md); b=$(grep -c 'This project writes `model` into' README.md); echo "readme=$a/$b"
   EXPECT: readme=1/1
   EVIDENCE: MET exit=0 marker-found :: readme=1/1
12. Full suite green.
   CHECK: make test 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
13. The diff touches only the FILE SCOPE.
   CHECK: git diff --name-only develop -- . ':!.claude' | grep -vcE '^(mods/model-router/hooks/register.ts|mods/model-router/hooks/register.test.ts|lib/effort-shift.md|README.md)$' | sed 's/^/n=/'
   EXPECT: n=0
   EVIDENCE: MET exit=0 marker-found :: n=0
14. No new lint or test suppression in the diff.
   CHECK: git diff -U0 develop -- . ':!.claude' | grep -E '^\+' | grep -cE 'eslint-disable|@ts-ignore|@ts-expect-error|shellcheck disable' | sed 's/^/n=/'
   EXPECT: n=0
   EVIDENCE: MET exit=0 marker-found :: n=0
15. `canonical()` is not used on the `/model` path (it strips `[1m]`); `fullId()` resolves the written id.
   CHECK: python3 -I -c "import re;s=open('mods/model-router/hooks/register.ts').read();i=s.index('async function handleModelCommand');j=s.index('\n}\n',i);print('canon=%d'%s[i:j].count('canonical('))"
   EXPECT: canon=0
   EVIDENCE: MET exit=0 marker-found :: canon=0

## FILE SCOPE
- mods/model-router/hooks/register.ts
- mods/model-router/hooks/register.test.ts
- lib/effort-shift.md
- README.md (l.139 and the routing.json writes bullet)
