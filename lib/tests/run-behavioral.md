# Behavioral check — coupled-capitalize, end-to-end

The deterministic suite (`run-deterministic.sh`, T1–T7) proves `memory-commit.sh`
in isolation. This is the in-vivo whole-chain check: a real dev-flow shape —
code commit, then capitalize writes memory, then the include commits it — with
dangling code present, proving the memory commit is coupled AND surgical.

## Scenario (run on a throwaway repo)

```bash
R="$(mktemp -d)"; cd "$R"
git init -q && git config user.email t@t.t && git config user.name t
mkdir -p .claude/memory .claude/tasks src
printf 'baseline\n' > .claude/memory/decisions.md
git add -A && git commit -qm baseline

# 1) the flow commits CODE
printf 'feature code\n' > src/feature.txt
git add -- src/feature.txt && git commit -qm "feat: the feature"
code_hash="$(git rev-parse --short HEAD)"

# 2) capitalize writes the approved entry (referencing the code hash) + journal
printf '\n## BDR-099 — example\n- Reference: commit %s\n' "$code_hash" >> .claude/memory/decisions.md
printf -- '- did the thing\n' >> .claude/tasks/TODO.md

# 3) a code file is left dangling (must NOT be embarked)
printf 'WIP do not commit\n' > src/dangling.txt

# 4) the include commits the memory surgically
mem_hash="$(bash "$HOME/.claude/lib/memory-commit.sh" commit "chore(memory): BDR-099 — example")"
```

## Expected (assert)

- Exactly TWO commits after baseline: the code commit, then the memory commit.
- The memory commit (`$mem_hash`) contains ONLY `.claude/memory/decisions.md`
  and `.claude/tasks/TODO.md` — never `src/feature.txt` (already committed) or
  `src/dangling.txt` (WIP).
- `src/dangling.txt` is still untracked after the memory commit.
- `$mem_hash` (the memory commit) ≠ `$code_hash` (anchored inside the entry).

If all hold, the chain is coupled (memory committed in the same breath as the
flow) and surgical (no dangling code embarked). This mirrors what feat / hotfix /
bugfix / commit-change do via their capitalize step, and what ship-feature /
init-project do before FINISH.
