.PHONY: help install plugin link doctor update new-skill profile profile-list profile-current profile-reset onboard test scan-secrets seo-connect

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  make %-14s %s\n", $$1, $$2}'

install: ## First-time setup: install Claude Code + auth + symlinks + plugins
	bash install.sh

plugin: ## Install prerequisites + all plugins
	bash install-plugins.sh

link: ## Create/update symlinks into ~/.claude/
	bash link.sh

doctor: ## Run setup diagnostic
	bash doctor.sh

update: ## Update Claude Code, config, submodules, plugins, and verify
	bash update-all.sh

onboard: link ## Onboard an existing project (run from the project directory)
	@echo "Open Claude Code in your project directory and run: /onboard"
	@echo "Or with hints: /onboard Python FastAPI monorepo"

seo-connect: ## Connect a Google account for /seo FULL (creates venv, OAuth consent)
	@python3 -m venv "$$HOME/.claude/.venv-seo-data"
	@"$$HOME/.claude/.venv-seo-data/bin/pip" install -q -r lib/seo-data/requirements.txt
	@bash -c 'read -r -p "Label for this account (e.g. client-a): " label; \
	 bash lib/seo-data/connect.sh --label "$$label"'

test: ## Run deterministic tests (lib/tests/*.test.sh + lib/gitflow-test.sh + lib/tests/run-*.sh)
	@fail=0; for t in lib/tests/*.test.sh lib/seo-data/*.test.sh lib/gitflow-test.sh lib/tests/run-*.sh; do \
		echo "== $$t"; \
		case "$$(basename "$$t")" in \
			run-release-candidate.sh) RC_WORK=$$(mktemp -d) RC_TAG=1 bash "$$t" || fail=1 ;; \
			*) bash "$$t" || fail=1 ;; \
		esac; done; exit $$fail

scan-secrets: ## Gitleaks sweep: this repo's history + ~/.claude (job7 backstop). Extra repos: make scan-secrets repos="path1 path2"
	@command -v gitleaks >/dev/null 2>&1 || { echo "gitleaks not installed — https://github.com/gitleaks/gitleaks"; exit 1; }
	@mkdir -p .audit
	@fail=0; \
	echo "== this repo (git history) =="; \
	gitleaks git . -c .gitleaks.toml --no-banner --redact -f json -r .audit/scan-secrets-repo.json || fail=1; \
	echo "== ~/.claude (dir scan) =="; \
	gitleaks dir "$$HOME/.claude" -c .gitleaks.toml --no-banner --redact -f json -r .audit/scan-secrets-claude-home.json || fail=1; \
	for r in $(repos); do \
		echo "== $$r (git history) =="; \
		gitleaks git "$$r" -c .gitleaks.toml --no-banner --redact -f json -r ".audit/scan-secrets-$$(basename "$$r").json" || fail=1; \
	done; \
	echo "Reports: .audit/scan-secrets-*.json (already redacted — safe to inspect/commit)"; \
	exit $$fail

profile: ## Run profile.sh (usage: make profile cmd="set design")
	@bash lib/profile.sh $(cmd)

profile-list: ## List skill profiles (design, dev, qa, audit, minimal)
	@bash lib/profile.sh list

profile-current: ## Detect which skill profile is currently active
	@bash lib/profile.sh current

profile-reset: ## Re-enable all gstack skills (undo any profile set)
	@bash lib/profile.sh reset

new-skill: ## Create a new skill scaffold (usage: make new-skill name=myskill)
	@test -n "$(name)" || (echo "Usage: make new-skill name=myskill" && exit 1)
	@mkdir -p agents skills/$(name)
	@if [ ! -f agents/$(name).md ]; then \
		printf -- '---\nname: $(name)\ndescription: <what this agent does — keep under 200 chars>\ntools: Read, Grep, Glob, Bash\nmodel: sonnet\n---\n\n# $(name)\n\n## ROLE\n<role>\n\n## TASKS\n- <task>\n\n## RULES\n- <rule>\n\n## OUTPUT\n```\n<format>\n```\n' > agents/$(name).md; \
		echo "✅ Created agents/$(name).md"; \
	else echo "⚠️  agents/$(name).md already exists"; fi
	@if [ ! -f skills/$(name)/SKILL.md ]; then \
		printf -- '---\nname: $(name)\ndescription: <what this skill does — front-load key use case, max 250 chars>\nargument-hint: <what to pass>\ndisable-model-invocation: true\nallowed-tools: Read, Grep, Glob, Bash\n---\n\nLoad and follow strictly:\n- .claude/agents/$(name).md\n\nExecute on:\n\n$$ARGUMENTS\n' > skills/$(name)/SKILL.md; \
		echo "✅ Created skills/$(name)/SKILL.md"; \
	else echo "⚠️  skills/$(name)/SKILL.md already exists"; fi
	@echo "   Edit both files, then run: bash link.sh"
