# Changelog

All notable changes to claude-config will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [1.0.0] — 2025-04-03

### Added
- 6 custom agents: analyzer, interviewer, plugin-advisor, readme-updater, refactorer, scaffolder
- 6 custom skills: analyze, init-project, plugin-check, readme, refactor, ship-feature
- 2 orchestrators with validation gates: init-project (13 steps), ship-feature (8 steps)
- Multi-OS install script (apt/dnf/pacman/brew)
- GStack as git submodule at skills-external/gstack
- Session start hook with plugin toggle status and health check
- Global settings.json with deny/ask/allow permission tiers
- Per-project templates: settings.json, settings.local.json, .claudeignore, project-CLAUDE.md
- Settings reference (SETTINGS.md)
- doctor.sh — full setup diagnostic
- update-all.sh — one-command update for all components
- plugins.lock.json — version pinning for non-marketplace dependencies
- /health skill — run doctor.sh from within Claude Code
- Makefile — unified entry point for install/link/doctor/update

### Security
- deny rules cover: destructive commands, secrets access, privilege escalation,
  code injection (eval, bash -c, xargs), pipe-to-shell, and secrets via bash (cat .env)
- disableBypassPermissionsMode enforced globally
- .claudeignore template with comprehensive exclusions
