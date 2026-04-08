---
name: health
description: Run setup diagnostic — check symlinks, plugins, permissions, token budget
argument-hint: (no arguments needed)
disable-model-invocation: true
allowed-tools: Bash
---

Run the health check script:

```bash
bash $HOME/.claude/doctor.sh 2>/dev/null || {
  REPO=$(dirname "$(readlink "$HOME/.claude/CLAUDE.md" 2>/dev/null)" 2>/dev/null)
  bash "$REPO/doctor.sh"
}
```

After displaying the doctor.sh output:
- **CRITICAL token (>30%)** → suggest `/plugin-check` to disable unused plugins; list the heaviest ones.
- **WARNING token (>15%)** → note which toggle plugins are active and not needed.
- **Errors (symlinks, agents)** → show the exact fix command (`bash link.sh`).
- **Warnings only** → confirm setup is functional, note any action recommended.
- **All pass** → confirm healthy and operational.
