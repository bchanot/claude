# Gitflow aiguillage — assistance flows branch on a protected base

Assistance flows (`/feat`, `/bugfix`, `/hotfix`) commit IN PLACE on a working
branch — the frequent case, behavior unchanged. But they must NEVER commit code
on a protected base (`main`/`develop`). Run this check **before editing any
file**. The caller passes its TYPE: feat→`feature`, bugfix→`bugfix`,
hotfix→`hotfix`.

```bash
bash "$HOME/.claude/lib/gitflow.sh" protected-base && echo PROTECTED || echo WORKING
```

- **WORKING** (`feature/*`, `bugfix/*`, `hotfix/*`, or any non-protected branch)
  → proceed; you commit in place on this branch. Nothing changes.
- **PROTECTED** (`main`/`develop`) → branch first, do NOT commit here:
  ```bash
  bash "$HOME/.claude/lib/gitflow.sh" start <YOUR-TYPE> <short-kebab-name>
  ```
  `<short-kebab-name>` derived from the request. Then do the work on the new branch.

**Never run `gitflow finish`** — assistance flows commit, they do not merge.
Integration is a separate, human-gated step (the `gitflow` skill).

Note: `hotfix` branches off **main** (prod) even when invoked from `develop` —
that is the gitflow definition of a hotfix. For a dev-scoped small fix, use
`/bugfix` (branches off develop).
