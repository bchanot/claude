# Gitflow aiguillage — branch on a protected base before writing

Flows that WRITE — code, OR standalone memory/doc work — must NEVER commit on a
protected base (`main`/`develop`). Run this check **before editing any file**.

```bash
bash "$HOME/.claude/lib/gitflow.sh" protected-base && echo PROTECTED || echo WORKING
```

- **WORKING** (`feature/*`, `bugfix/*`, `hotfix/*`, `chore/*`, or any non-protected
  branch) → proceed; you commit in place on this branch. Nothing changes.
- **PROTECTED** (`main`/`develop`) → branch first, do NOT commit here:
  ```bash
  bash "$HOME/.claude/lib/gitflow.sh" start <YOUR-TYPE> <short-kebab-name>
  ```
  `<short-kebab-name>` derived from the request. Then do the work on the new branch.

The caller passes its TYPE:

| Caller | TYPE | Base |
|--------|------|------|
| `/feat` | `feature` | develop |
| `/bugfix` | `bugfix` | develop |
| `/hotfix` | `hotfix` | main |
| `/capitalize` · `/close` · `/prune-memory` · `/reconcile` | `chore` | develop |

The `chore` row = **standalone memory/doc work**: the registry / TODO / doc
reconciliation & curation skills, run OUTSIDE an assistance flow. Inside `/feat`
`/bugfix` `/hotfix` `/ship-feature` a working branch already exists (this check
returns WORKING) and the memory commit rides it. The aiguillage only fires when
such a skill is invoked directly on `main`/`develop` — i.e. memory IS the work,
with no code branch to follow. That is the leak it closes: the `.claude/**` hook
exemption still lets a *manual* memory commit through on a protected base, but a
skill-driven one now branches to `chore/*` first.

**Never run `gitflow finish`** — these flows commit, they do not merge. Integration
is a separate, human-gated step (the `gitflow` skill).

Note: `hotfix` branches off **main** (prod) even when invoked from `develop` — that
is the gitflow definition of a hotfix. For a dev-scoped small fix, use `/bugfix`
(branches off develop).
