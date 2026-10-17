---
name: explain-diff
effort: high
description: 'Use when the user wants to understand a code change they did not follow closely (a diff, commit, range, branch, merge or PR, often written by an agent) and asks for an explanation, a walkthrough or an HTML page of it. Writes one self-contained HTML file outside the repo: background, intuition with toy data and diagrams, grouped code walkthrough, 5-question interactive quiz. Fights cognitive debt. Triggers: "explain-diff", "explique ce diff", "explique ce qui a été fait", "explain this commit/PR/branch", "walk me through the changes", "pas suivi ce commit", "dette cognitive". Bug hunt on a diff → /code-review; code without a change → /analyze.'
argument-hint: '[sha | A..B | branch | PR# | staged | uncommitted] [project path]'
---

# Explain Diff

Code now lands faster than anyone reads it. An agent writes forty files, the
tests pass, the branch merges, and a month later nobody on the project can
say why a function runs twice. That gap is cognitive debt. This skill pays
it down: it turns one change into a page a reader can study in twenty
minutes and come out of able to own the code.

The page is one self-contained HTML file with four sections (background,
intuition, code, quiz), saved outside the repository so it never pollutes
version control.

## STEP 1 — Resolve the target

Work in the project the user names (`git -C <path>`), else the current one.
Map the argument to a diff:

| Argument | Commits to read | Diff to explain |
|---|---|---|
| `<sha>` | `git log -1 <sha>` | `git show <sha>`; a merge → `git diff <sha>^1 <sha>`, the whole merged branch |
| `A..B` | `git log A..B` | `git diff A...B` |
| `<branch>` | `git log <base>..<branch>` | `git diff <base>...<branch>` |
| `#<n>`, PR | `gh pr view <n>` | `gh pr diff <n>` (GitHub remote with `gh` only, else ask for the branch) |
| `staged` | none | `git diff --cached` |
| `uncommitted` | none | `git diff HEAD`, plus untracked files from `git status --porcelain` |

`<base>` is `develop` when it exists, else `main`, else `master`.

No argument: on a branch ahead of its base, explain `<base>...HEAD`, plus
the uncommitted changes when the tree is dirty. On the base branch itself,
explain the last commit (a merge → the whole merged branch).

Before writing, say in one line what resolved: range, commit count, files,
lines. An empty diff stops the skill: name the target that came out empty.

## STEP 2 — Understand before writing

The diff shows what moved. The explanation needs what it moved inside.

1. Read the whole diff, then the commit messages (`git log --format=%B`).
   They usually hold the why. Follow what they cite when it exists in the
   repo: a design record, a plan, a contract, an issue.
2. Read around the change: the functions it touches, their callers and
   callees, the tests, the module's entry point. Background is about this
   existing system, and the diff alone never shows it.
3. Name the problem the change solves as an observable behaviour: what a
   user, a caller or a test saw before, and what it sees now. New tests are
   the best witness of that.
4. Triage big diffs (roughly over 1500 changed lines or 25 files).
   Generated files, lockfiles, snapshots and vendored code get one line in
   the Code section, not a walkthrough. Group the rest by concern.
5. Keep facts and inferences apart. When nothing in the repo says why,
   write the most plausible reading and mark it as an inference in the page.
6. Never copy a credential-like value (token, key, password, URL with auth)
   into the page. Redact it and warn the user in the reply.

## STEP 3 — Write the explanation

Write in the user's language, the one of their request. Identifiers,
commands and code stay as they are. Aim for classic style with the clarity
and flow of Martin Kleppmann: the writer has seen something and shows it to
a smart reader, concrete before abstract, each section leading into the
next. The user-facing writing rules in context apply as well
(`rules/writing-style.md`: no em-dash, no "not X, it's Y" frame, no filler).

Open with a header and a lead: two or three sentences saying what changed
and why, the version a reader could repeat in one breath. Then four
sections, in this order, on one long page with a table of contents at the
top and no tabs:

1. **Background.** The existing system this change lives in. The reader's
   level is unknown, so start with a deep background for newcomers inside a
   collapsible block marked as skippable, then the narrow background this
   change touches directly.
2. **Intuition.** The essence of the change, not its details. Build it on a
   concrete example with toy data (a guest with id `g-42`, a cache holding
   three entries) and show before and after. Use diagrams generously.
3. **Code.** A high-level walkthrough. Order the changes the way a reader
   understands them, cause before effect and core before plumbing, never by
   file order. For each group: what it does, why, a short excerpt of the
   lines that matter, and the `path:line` to open. End with what the tests
   now prove.
4. **Quiz.** Five multiple-choice questions of medium difficulty. Answering
   needs the substance of the change, not trivia or traps: predict the
   behaviour on a toy input, say why a step is needed, pick where a
   follow-up fix belongs, spot the edge case. Every option, right or wrong,
   carries a one or two sentence explanation.

Callouts mark key concepts, definitions, important edge cases and risks.

### Diagrams

Pick one to three diagram families and reuse them across the page, so the
reader learns the visual language once:

- a simplified mock of the screen the user sees, for UI changes;
- a flow of components with example data on each arrow, for data or calls;
- a row of states, for lifecycle or state-machine changes;
- a before and after pair, for any behaviour change.

Draw them with the HTML primitives of `references/components.md`, or with
inline SVG. Never ASCII art: box-drawing characters break on a phone and say
less than three styled boxes.

## STEP 4 — Build the page

The skill folder is `$HOME/.claude/skills/explain-diff/`.

1. Read `references/components.md` (the snippet catalog), then start from
   a copy of `assets/template.html`.
2. Replace every `{{…}}` placeholder. Section ids stay `background`,
   `intuition`, `code` and `quiz`: the table of contents and the checker
   rely on them.
3. Code goes in `<pre>` blocks, HTML-escaped (`<` as `&lt;`, `>` as `&gt;`,
   `&` as `&amp;`). An unescaped `<T>` generic or JSX tag silently swallows
   the code that follows it.
4. The quiz lives in the `quiz-data` JSON block and the template's script
   renders it. Keep the page self-contained: no CDN, no web font, no remote
   image. It has to open offline from disk a year from now.

## STEP 5 — Save, check, hand over

1. Save to `~/Documents/explanations/<project>/YYYY-MM-DD-<slug>.html`.
   Today's date comes first so the folder sorts by time, `<project>` is the
   basename of the repo and `<slug>` a few kebab-case words naming the
   change. Never inside the project tree. A taken name gets `-2`.
2. Run the checker and fix every FAIL until it exits 0:
   ```bash
   python3 "$HOME/.claude/skills/explain-diff/scripts/check_explanation.py" <file>
   ```
3. Reread the prose against the writing rules and fix what slipped.
4. Reply with the absolute path and its `file://` URL, the one-line summary
   of the change, the inferences the page marks as such, and the secret
   warning if one was redacted. Do not paste the explanation into the chat:
   the page is the deliverable.

## When things go wrong

| Situation | Action |
|---|---|
| Not a git repository | Ask for the project path |
| Target resolves to an empty diff | Stop and name the target |
| PR number without `gh`, or a non-GitHub remote | Ask for the branch name |
| Binary files in the diff | List them in Code, do not walk them |
| Over about 5000 changed lines | Explain the top level, offer one page per commit or folder |
| Checker FAIL | Fix and rerun; never hand over a failing page |
