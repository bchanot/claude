---
name: git-pr
description: Analyze all changes on the current branch since it diverged from base (retroactive across sessions), create logical commits, push, and open a draft PR/MR. Works with GitHub, GitLab, Gogs, and Gitea. Never merges — creates a draft for user validation.
argument-hint: [PR title or leave empty for auto-detection]
disable-model-invocation: true
allowed-tools: Read, Bash, Grep, Glob
---

Load and follow strictly:
- .claude/agents/git-workflow.md

Execute the GIT WORKFLOW on the current repository.

User context (optional title or instructions):
$ARGUMENTS
