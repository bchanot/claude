# Commit message: project convention first, else short

Run before composing ANY commit message (flow or ad-hoc). Read-only lookup:

```bash
git config --get commit.template
ls CONTRIBUTING* commitlint.config.* .commitlintrc* .gitmessage 2>/dev/null
grep -n -i -m3 -E "commit (message|convention)|conventional commit" \
  README* CONTRIBUTING* CLAUDE.md .claude/rules/* docs/* 2>/dev/null
```

## 1. A convention is documented

Hit in the project's own files (README, CONTRIBUTING, project `CLAUDE.md`,
`.claude/` rules, commitlint config, commit template) → follow it to the
letter: format, language, length, scope list. Nothing below applies.

Read each grep hit before trusting it. The git log is NOT a convention: it
can carry the verbosity this file removes.

## 2. No convention: short

- Subject `<type>(<scope>): <what>`, 72 chars max. Types: feat, fix,
  refactor, chore, docs, test, perf, style.
- Optional body: one or two sentences on why. Whole message 50 words max.
- Medium technical level: say the behavior and its cause. No file lists,
  line numbers, step-by-step of the diff or internal identifiers. A reader
  who knows the stack follows without opening the diff.

```
fix(auth): reject expired refresh tokens

The refresh check compared the expiry in seconds against milliseconds, so
expired tokens passed. Both sides now use seconds.
```

Out of scope: `chore(memory)` and `docs:` commits made by
`memory-commit.sh` / `doc-commit.sh`, already one line by their own style.
