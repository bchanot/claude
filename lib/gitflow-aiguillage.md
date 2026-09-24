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
| `/hotfix` | `hotfix` on main · `bugfix` on develop | main · develop |
| `/seo` aggressive · `/web-validate --fix` | `feature` | develop |
| `/capitalize` · `/close` · `/prune-memory` · `/reconcile` | `chore` | develop |
| `/doc` · `/refactor` | `chore` | develop |
| `/commit-change` | asks the user (`feature` / `bugfix` / `chore`) before `start` — a branch name is a public name | develop |

The `chore` rows = **standalone memory/doc/hygiene work**: the registry / TODO /
doc reconciliation & curation skills (+ `/refactor`), run OUTSIDE an assistance flow. Inside `/feat`
`/bugfix` `/hotfix` `/ship-feature` a working branch already exists (this check
returns WORKING) and the memory commit rides it. The aiguillage only fires when
such a skill is invoked directly on `main`/`develop` — i.e. memory IS the work,
with no code branch to follow. That is the leak it closes: the `.claude/**` hook
exemption still lets a *manual* memory commit through on a protected base, but a
skill-driven one now branches to `chore/*` first.

**Integration is human-gated by default** — these flows commit, they do not merge.
EXCEPTION: `/capitalize` + `/close` auto-persist their memory-only commit (finish →
develop + push) when THEY branched a `chore/*` off develop this run (BDR-068 — a
scoped [[LRN-069]] exception; see the capitalize skill's STEP 5C). `/prune-memory`
+ `/reconcile` stay fully human-gated: never run `gitflow finish` from them.

Note: a `hotfix/*` branch forks off **main** (prod) and fans out to main + develop
at finish — that is the gitflow definition of a hotfix. Invoked from `develop`,
`/hotfix` therefore starts a `bugfix/*` (off develop): a `hotfix/*` there would
miss develop's code and later merge to prod. The small-fix routing is unchanged;
only the branch type follows the base.
