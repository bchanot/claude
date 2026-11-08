---
name: memory-feedback
effort: high
description: Run only when the user asks for it ("memory feedback", "label recall", "recall precision", "is memory recall useful", "feedback mémoire", or after they mention the banner's memory feedback line). Labels each injected registry entry relevant or irrelevant from the transcript, samples misses, reports precision and the phase 4d gates. NOT registry curation (that is /prune-memory).
---

# /memory-feedback — label recall injections, read the gates

Phase 4d (BDR-125). The memory mod logs every recall ask; transcripts live
7 days, so this runs weekly. Claude labels, the user spot-checks. Redacted
text stays in the scratchpad; `~/.claude/memory-feedback/` keeps IDs, enums
and repo tags only, never in git.

## STEP 1 — WORKSHEET

```bash
BUN="$(command -v bun || echo "$HOME/.bun/bin/bun")"
MFD="$(cd -P "$HOME/.claude/lib" && pwd)/memory-feedback"
CFG="$(cd -P "$HOME/.claude/lib/.." && pwd)"   # this config repo
[ -x "$BUN" ] || echo "memory-feedback: bun not found"
(cd "$MFD" && "$BUN" reader.ts worksheet "<scratchpad dir, absolute>")
```

Any non-zero rc → print the message and stop (`store file unreadable`:
retry once after a few seconds; `bun not found`: tell the user). Running
from `$MFD` keeps the current repo's bun config out. `0 records` → go to
STEP 5 (no spot check: it records the run only).

## STEP 2 — LABEL

Read `<dir>/worksheet.md`. Fill the third column of the skeleton
`<dir>/labels-draft.tsv` for every line:
- `relevant`: the entry bears on what the prompt asked or what the reply
  did; `irrelevant` otherwise. Judge the entry against the ask, not the
  reply's quality.
- A proof, bench or recall-testing session: replace that item's lines by
  one `<item>	-	test` line.
Lost items have no line.

## STEP 3 — SPOT CHECK

```bash
BUN="$(command -v bun || echo "$HOME/.bun/bin/bun")"
MFD="$(cd -P "$HOME/.claude/lib" && pwd)/memory-feedback"
(cd "$MFD" && "$BUN" reader.ts sample "<dir>")
```

Each shell block resolves its own paths: a Bash call is a fresh shell.
Show the 5 picked entries to the user in one AskUserQuestion: the prompt
gist in your own words (never a secret), the entry title, your label; the
user confirms or flips each. Apply the flips to the draft (LRN-168).

## STEP 4 — MISSES

On up to 5 prompt items whose outcome is injected or none, search the
registries of that item's repo, whose absolute path is in the item header
(`bash ~/.claude/lib/memory.sh -C <path> index` + entry bodies) for live entries that bore on the ask and were not
injected. Each one: `<item>	<id>	missed	<cause>`, cause `no-overlap` (no
content word shared with the prompt) or `overlap`. A searched item with no
miss: `<item>	-	checked`. Example line: `3	LRN-901	missed	no-overlap`.

## STEP 5 — APPLY

```bash
BUN="$(command -v bun || echo "$HOME/.bun/bin/bun")"
MFD="$(cd -P "$HOME/.claude/lib" && pwd)/memory-feedback"
(cd "$MFD" && "$BUN" reader.ts apply "<dir>")
```

rc 1 `draft refused: <reason>` → fix the draft, rerun. It prints
FEEDBACK.md: show the gate lines and the Actions list to the user.

## STEP 6 — A GATE REACHED FOR THE FIRST TIME

Only when the output ends with a `NEW: …` line:
1. Propose the verdict as an EVAL entry (counts and shares from
   FEEDBACK.md, no prompt text, no other repo's name) and each Action as a
   TODO line of this config repo; the user approves each. Actions naming
   another repo's tag (noisy, promotion) are shown to the user to run
   /prune-memory there; they are never written here.
2. Write approved entries per `lib/capitalize-commit.md` § WRITE (this
   repo only), in one shell block:
   `CFG="$(cd -P "$HOME/.claude/lib/.." && pwd)"`, then
   `bash "$CFG/lib/memory.sh" -C "$CFG" add eval …` (a decided action also
   gets `add decision`), TODO lines in `$CFG/.claude/tasks/TODO.md`; then
   commit per `lib/capitalize-commit.md` § DO (run from `$CFG`).
Thresholds live in `lib/memory-feedback/thresholds.ts`; never tune them
here (BDR-100).

## RULES
- Never paste prompt or reply text into a registry, the TODO or a commit.
- Never commit `~/.claude/memory-feedback/` or the scratchpad files.
- Never run apply on labelled items without the spot check of STEP 3.
