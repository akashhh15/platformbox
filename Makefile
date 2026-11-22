# Cloud Platform in a Box — developer entry points.
#
# Local-first: `make up` and `make down` manage a local kind cluster, not AWS.
# The AWS production path is optional and must be run by a human.

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

ifeq ($(OS),Windows_NT)
  VENV_BIN := .venv/Scripts
  PYTHON ?= python
else
  VENV_BIN := .venv/bin
  PYTHON ?= python3
endif

TOOLS_BIN := tools/bin
export PATH := $(CURDIR)/$(VENV_BIN):$(CURDIR)/$(TOOLS_BIN):$(PATH)

.PHONY: help tools tools-check pre-commit-install fmt lint validate scan test check \
        terraform-test contract workflows-validate local-up local-down up down demo \
        gitops-validate local-smoke aws-plan aws-apply clean

##@ General

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nCloud Platform in a Box\n\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

tools: ## Install or refresh the pinned local toolchain (Windows Git Bash)
	@bash scripts/install-tools.sh

tools-check: ## Verify required tools are installed
	@bash scripts/check-tools.sh

pre-commit-install: ## Install the git hooks
	pre-commit install --install-hooks
	pre-commit install --hook-type commit-msg

##@ Quality gates

fmt: ## Apply formatting fixes to all files
	@echo "==> Applying formatting (pre-commit)"
	@pre-commit run --all-files || true
	@pre-commit run --all-files

lint: workflows-validate ## Run all linters and format checks
	@echo "==> Linting (pre-commit)"
	pre-commit run --all-files

workflows-validate: ## Validate GitHub and GitLab CI configuration offline
	@bash scripts/validate-workflows.sh

validate: terraform-test gitops-validate contract ## Validate Terraform, Kubernetes and GitOps manifests
	@echo "==> All validation gates passed."

terraform-test: ## Run Terraform mock-provider contract tests (no AWS calls)
	@echo "==> Terraform contract tests (mock provider)"
	@for dir in infra/bootstrap infra/modules/ecr infra/modules/budgets infra/modules/irsa; do \
		echo "    $$dir"; \
		(cd "$$dir" && terraform test -no-color >/dev/null); \
	done

contract: ## Assert overlay parity and the documented local/AWS substitutions
	@bash scripts/apps-contract.sh

scan: ## Run secret and IaC security scans
	@echo "==> Secret scan (gitleaks)"
	@if git rev-parse --verify HEAD >/dev/null 2>&1; then \
		gitleaks git --redact --verbose --no-banner; \
	else \
		echo "No git history yet; gitleaks history scan skipped."; \
	fi
	@echo "==> IaC scan (checkov)"
	@bash scripts/checkov.sh -d . --compact --quiet

test: ## Run unit and integration tests
	@if [ -d apps/api/tests ]; then (cd apps/api && PYTHONPATH=src pytest -q); fi
	@if [ -d apps/worker/tests ]; then (cd apps/worker && PYTHONPATH=src pytest -q); fi
	@if [ ! -d apps/api/tests ] && [ ! -d apps/worker/tests ]; then \
		echo "Not implemented until Phase 2 (application tests)."; \
	fi

check: lint validate scan test ## Run every quality gate (the phase definition of done)

##@ Local platform (zero cost)

local-up: ## Create the local kind cluster and install the platform
	@bash scripts/local-up.sh

local-down: ## Delete the local kind cluster
	@bash scripts/local-down.sh

up: ## Create the local platform after an explicit confirmation
	@printf '%s\n' "This will create a local kind cluster and install the platform."
	@printf '%s\n' "It creates no AWS resources and costs \$0."
	@read -r -p "Continue? [y/N] " ans; case "$$ans" in [yY]|[yY][eE][sS]) ;; *) echo "Aborted."; exit 1;; esac
	@$(MAKE) local-up

down: ## Delete the local platform after an explicit confirmation
	@printf '%s\n' "This will delete the local kind cluster and everything running in it."
	@printf '%s\n' "It does not touch AWS. Any local data in the cluster will be lost."
	@read -r -p "Continue? [y/N] " ans; case "$$ans" in [yY]|[yY][eE][sS]) ;; *) echo "Aborted."; exit 1;; esac
	@$(MAKE) local-down

demo: ## Run the five-minute local demo
	@echo "Not implemented until Phase 8 (progressive delivery demo)."

##@ Validation and optional AWS path

gitops-validate: ## Render and validate every Kustomize overlay and Helm chart
	@bash scripts/gitops-validate.sh

local-smoke: ## Deploy the app on kind with local Postgres, Redis and fake secrets
	@bash scripts/local-smoke.sh

aws-plan: ## Optional: plan the AWS production path (creates no resources)
	@echo "Not implemented until Phase 1 (Terraform)."

aws-apply: ## Optional: apply the AWS path (COSTS MONEY; human only)
	@printf '%s\n' "WARNING: this creates paid AWS resources."
	@printf '%s\n' "The default project path is local-first and costs \$0."
	@read -r -p "Type 'apply-aws' to continue: " ans; [ "$$ans" = "apply-aws" ] || { echo "Aborted."; exit 1; }
	@echo "Not implemented until Phase 1 (Terraform)."

##@ Housekeeping

clean: ## Remove local caches (safe)
	rm -rf .pytest_cache .ruff_cache htmlcov .coverage coverage.xml
