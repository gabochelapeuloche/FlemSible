PROFILE ?= 1.35_base

build: ## Build pre-baked base image for PROFILE
	bash tools/build-base-image.sh $(PROFILE)

deploy: ## Deploy a cluster (ARGS="--cp-number 1 --w-number 1" to override)
	bash main.sh --version $(PROFILE) $(ARGS)

teardown: ## Delete all cluster VMs for PROFILE
	bash tools/teardown.sh --version $(PROFILE)

check: ## Run smoke test against the running cluster
	bash tools/check-cluster.sh --version $(PROFILE)

test: ## Run the unit test suite
	bash tests/run_tests.sh

dry-run: ## Preview what deploy would do without running anything
	bash main.sh --version $(PROFILE) --dry-run $(ARGS)

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: build deploy teardown check test dry-run help
.DEFAULT_GOAL := help
