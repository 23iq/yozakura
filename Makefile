SHELL := /bin/bash

# Yozakura Go backend binary and the compositor daemon it supervises (both
# at the repo root, gitignored). DAEMON mirrors backend/pkg/brand.Daemon.
BINARY := yozakura
DAEMON := yozd
BACKEND_DIR := backend

GO ?= go
GOFLAGS ?=
PY ?= python3

.PHONY: all build vet lint run nix clean dev install \
	schema check parse-qml lint-qml fmt-check fmt lint-go lint-sh lint-py \
	test test-js test-py test-go audit baseline

all: build

## build: compile the Go backend into $(BINARY) and the compositor daemon
##        into $(DAEMON), side by side at the repo root
build:
	@cd $(BACKEND_DIR) && $(GO) build $(GOFLAGS) -o ../$(BINARY) ./cmd/$(BINARY)
	@cd $(BACKEND_DIR) && $(GO) build $(GOFLAGS) -o ../$(DAEMON) ./cmd/$(DAEMON)
	@echo "Built ./$(BINARY) ./$(DAEMON)"

## vet: run go vet on the backend
vet:
	@cd $(BACKEND_DIR) && $(GO) vet ./...

## schema: regenerate the settings catalog assets/schema/*.schema.json (JSON
##         Schema 2020-12) from config/defaults, config/meta and the settings
##         schema, and the config adapters config/adapters/*.qml from
##         config/defaults + config/meta/AdapterTypes.js + config/CoreBinds.js;
##         the schema-fresh audit fails when either is stale
schema:
	@node tools/schema/gen_schema.cjs
	@node tools/config/gen_adapters.cjs

## lint: all linters (QML, Go, shell, Python) without tests/audit
lint: lint-qml lint-go lint-sh lint-py

# ---------------------------------------------------------------------------
# Quality gate. `make check` must be green before a change is done (AGENTS.md).
# Optional tools that are missing are reported as SKIP, never as failures.
# BASE=<ref> sets the diff base for "changed files" (default origin/main).
# ---------------------------------------------------------------------------

## check: run every gate below and print a summary (CHECKS="a b" for a subset)
check:
	@tools/check.sh $(CHECKS)

## parse-qml: syntax-check every QML and JS file (hard fail, no baseline)
parse-qml:
	@$(PY) tools/lint/qmllint.py --parse

## lint-qml: qmllint with qs.* import resolution; fails on findings not in the baseline
lint-qml:
	@$(PY) tools/lint/qmllint.py

## fmt-check: qmlformat + gofmt; new/clean files must stay formatted
fmt-check:
	@$(PY) tools/lint/fmt_check.py

## fmt: format failing files (or FILES="a.qml b.go")
fmt:
	@$(PY) tools/lint/fmt_check.py --fix $(FILES)

## lint-go: go vet + staticcheck (baselined)
lint-go:
	@$(PY) tools/lint/golint.py

## lint-sh: shellcheck on scripts/*.sh, install.sh and git hooks
lint-sh:
	@$(PY) tools/lint/scripts_lint.py sh

## lint-py: ruff on scripts/, tests/ and tools/ (config: ruff.toml)
lint-py:
	@$(PY) tools/lint/scripts_lint.py py

## test: node, python (PySide6) and go test suites
test:
	@$(PY) tools/lint/run_tests.py js py go
test-js:
	@$(PY) tools/lint/run_tests.py js
test-py:
	@$(PY) tools/lint/run_tests.py py
test-go:
	@$(PY) tools/lint/run_tests.py go

## audit: dead files, config schema, translations, snapshot keys, monoliths (ARGS=--json)
audit:
	@$(PY) tools/audit/audit.py $(AUDIT_ARGS) $(ARGS)

## baseline: re-record qmllint/staticcheck/format baselines (justify in the commit!)
baseline:
	@$(PY) tools/lint/qmllint.py --update-baseline
	@$(PY) tools/lint/golint.py --update-baseline
	@$(PY) tools/lint/fmt_check.py --update-baseline

## run: build and launch the shell (the yozakura binary itself is the
##       daemon; it supervises Quickshell, $(DAEMON) and wl-paste children)
run: build
	@./$(BINARY)

## dev: alias for run
dev: build
	@./$(BINARY)

## nix: build the backend package via Nix (NixOS / Nix installs)
nix:
	@cd $(BACKEND_DIR) && git -C .. add backend 2>/dev/null; nix build '.#packages.$(shell uname -m)-linux.backend' --no-link --print-out-paths

## install: build, sudo install both binaries, then remove the local copies
install: build
	sudo install $(BINARY) $(DAEMON) /usr/local/bin/
	rm -f $(BINARY) $(DAEMON)

## clean: remove the compiled binary
clean:
	@rm -f $(BINARY) $(DAEMON)
	@echo "Removed ./$(BINARY) ./$(DAEMON)"
