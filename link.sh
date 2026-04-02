#!/bin/bash

mkdir -p ~/.claude
rm -rf ~/claude/agents ~/claude/skills ~/claude/CLAUDE.md ~/claude/settings.json

ln -sf ~/claude-config/agents    ~/.claude/agents
ln -sf ~/claude-config/skills    ~/.claude/skills
ln -sf ~/claude-config/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf ~/claude-config/settings.json ~/.claude/settings.json