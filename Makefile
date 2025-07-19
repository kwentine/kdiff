# Makefile for kdiff project

SCRIPT_NAME = kdiff

.PHONY: lint
lint:
	shellcheck $(SCRIPT_NAME)

.PHONY: format
format:
	shfmt -w -i 4 -ci $(SCRIPT_NAME)