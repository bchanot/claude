---
paths: ["docs/superpowers/**", ".audit/**"]
# static-check: skip
---

# Transient planning artifacts

`docs/superpowers/specs/**` and `docs/superpowers/plans/**` are run-time
artifacts of a feature pipeline (subagent briefs, reviewer references).
They are committed DURING the run (the SDD worktree + reviewers read them
from disk — NOT gitignored), then AUTO-PURGED by `gitflow finish` on a
`feature`/`bugfix` branch, before the merge, so develop's tip stays clean
(BDR-065, `lib/gitflow.sh` `_gitflow_purge_transient`). The feature commits
stay reachable from develop, so `git show <sha>:docs/…` is still the archive.
Opt out with `GITFLOW_PURGE_TRANSIENT=0`. NOT in scope: `.claude/tasks/{contracts,plans}`
(durable, versioned, referenced by decisions.md). Durable knowledge goes to
`.claude/memory/` registries, never to these files. Derived scan/audit
outputs (`.audit/**`) are gitignored and never committed, even redacted
(LRN-124).
