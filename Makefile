.PHONY: help install link doctor update

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  make %-12s %s\n", $$1, $$2}'

install: link ## Full install: symlinks + prerequisites + plugins
	bash install-plugins.sh

link: ## Create symlinks into ~/.claude/
	bash link.sh

doctor: ## Run setup diagnostic
	bash doctor.sh

update: ## Update config, submodules, plugins, and verify
	bash update-all.sh
