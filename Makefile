SHELL := /usr/bin/env bash

.PHONY: help test lint secret-scan markdownlint check

help:
	@printf '%s\n' \
	  'make test          Run Bash tests' \
	  'make lint          Run ShellCheck' \
	  'make secret-scan   Scan for secrets and private data' \
	  'make markdownlint  Validate Markdown when markdownlint-cli2 is installed' \
	  'make check         Run all available quality checks'

test:
	@./tests/run.sh

lint:
	@command -v shellcheck >/dev/null 2>&1 || { echo 'shellcheck is required'; exit 127; }
	@find scripts tests -type f -name '*.sh' -print0 | xargs -0 shellcheck -x -P SCRIPTDIR

secret-scan:
	@./tests/test-no-secrets.sh

markdownlint:
	@command -v markdownlint-cli2 >/dev/null 2>&1 || { echo 'markdownlint-cli2 is required'; exit 127; }
	@markdownlint-cli2 '**/*.md' '#.git'

check: lint test secret-scan
	@if command -v markdownlint-cli2 >/dev/null 2>&1; then \
	  markdownlint-cli2 '**/*.md' '#.git'; \
	else \
	  echo 'markdownlint-cli2 not installed; Markdown lint deferred to CI'; \
	fi
