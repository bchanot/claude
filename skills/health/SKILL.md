---
name: health
description: Run setup diagnostic — check symlinks, plugins, permissions, token budget
argument-hint: (no arguments needed)
disable-model-invocation: true
allowed-tools: Bash
---

Run the health check script and report findings to the user:

```bash
bash ~/.claude/doctor.sh
```

After displaying the output:
- If errors are found, suggest the specific fix commands shown in the output.
- If only warnings, note them but confirm the setup is functional.
- If all checks pass, confirm the setup is healthy.
