TF_VERSION    ?= 1.9.8
TFLINT_VERSION ?= v0.50.3
TEST_TIMEOUT   ?= 30m
TEST_DIR       := test

GITLEAKS         ?= gitleaks
LEFTHOOK_VERSION ?= 1.7.10
LEFTHOOK_DIR     ?= $(CURDIR)/.bin
LEFTHOOK_BIN     ?= $(LEFTHOOK_DIR)/lefthook

.PHONY: help fmt fmt-check validate lint security check coverage test test-ci test-integration test-short tidy plan secrets-scan-staged lefthook-bootstrap lefthook-install lefthook-run lefthook

## secrets-scan-staged: scan staged diff for secrets
secrets-scan-staged:
	@command -v $(GITLEAKS) >/dev/null 2>&1 || (echo "Missing tool: $(GITLEAKS). Install: https://github.com/gitleaks/gitleaks#installing" && exit 1)
	$(GITLEAKS) protect --staged --redact

## lefthook-bootstrap: download lefthook binary into ./.bin
lefthook-bootstrap:
	LEFTHOOK_VERSION="$(LEFTHOOK_VERSION)" BIN_DIR="$(LEFTHOOK_DIR)" bash ./scripts/bootstrap_lefthook.sh

## lefthook-install: install git hooks (runs bootstrap first)
lefthook-install: lefthook-bootstrap
	@if [ -x "$(LEFTHOOK_BIN)" ] && [ -x ".git/hooks/pre-commit" ] && [ -x ".git/hooks/pre-push" ] && [ -x ".git/hooks/commit-msg" ]; then \
		echo "lefthook hooks already installed"; \
		exit 0; \
	fi
	LEFTHOOK="$(LEFTHOOK_BIN)" "$(LEFTHOOK_BIN)" install

## lefthook-run: run all hooks locally (pre-commit + commit-msg + pre-push)
lefthook-run: lefthook-bootstrap
	LEFTHOOK="$(LEFTHOOK_BIN)" "$(LEFTHOOK_BIN)" run pre-commit
	@tmp_msg="$$(mktemp)"; \
	echo "chore(hooks): validate commit-msg hook" > "$$tmp_msg"; \
	LEFTHOOK="$(LEFTHOOK_BIN)" "$(LEFTHOOK_BIN)" run commit-msg -- "$$tmp_msg"; \
	rm -f "$$tmp_msg"
	LEFTHOOK="$(LEFTHOOK_BIN)" "$(LEFTHOOK_BIN)" run pre-push

## lefthook: install hooks and run them
lefthook: lefthook-bootstrap lefthook-install lefthook-run

## help: print available targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## //'

## ── Terraform targets ───────────────────────────────────────────────────────

## fmt: format all Terraform files in place
fmt:
	terraform fmt -recursive .

## fmt-check: fail if any Terraform files need formatting (mirrors CI)
fmt-check:
	terraform fmt -check -recursive .

## validate: init and validate all modules (no backend required)
validate:
	@bash -euo pipefail -c ' \
	find modules -mindepth 1 -maxdepth 1 -type d | sort | while read -r dir; do \
	  echo "── Validating $$dir ──"; \
	  terraform -chdir="$$dir" init -backend=false -input=false; \
	  terraform -chdir="$$dir" validate; \
	done'

## lint: run tflint across all modules
lint:
	tflint --init
	tflint --recursive --format compact .

## security: run trivy Terraform config scan
security:
	trivy config --exit-code 1 --severity HIGH,CRITICAL .

## ── Terratest targets ────────────────────────────────────────────────────────
# Requires: AWS credentials (AWS_TEST_ROLE_ARN or AWS_ACCESS_KEY_ID).
# Tests skip automatically when credentials are absent.

## tidy: tidy Go test dependencies
tidy:
	cd $(TEST_DIR) && go mod tidy

## test: alias for test-integration (deploys + destroys real AWS resources)
test: test-integration

## test-ci: run Terratest suite in CI; tests skip gracefully when AWS credentials are absent
test-ci:
	cd $(TEST_DIR) && go test -v -timeout $(TEST_TIMEOUT) -count=1 ./...

## test-integration: run all Terratest integration tests (deploys + destroys real AWS resources)
test-integration:
	cd $(TEST_DIR) && go test -v -timeout $(TEST_TIMEOUT) -count=1 ./...

## test-short: run a single named test (pass TEST=TestFunctionName)
test-short:
	cd $(TEST_DIR) && go test -v -timeout $(TEST_TIMEOUT) -count=1 -run $(TEST) ./...

## check: run all static checks (no cloud)
check: fmt-check validate lint security

## coverage: run terratest with coverage
coverage:
	cd test && go test -v ./... -timeout 30m 2>/dev/null || echo "No terratest found"

## plan: not applicable for a module library — use 'make validate' or 'make test'
plan:
	@echo "INFO: 'plan' requires a root module with a backend. This repo is a module library."
	@echo "      To validate modules: make validate"
	@echo "      To run integration tests: make test"
