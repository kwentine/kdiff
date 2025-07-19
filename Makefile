# Makefile for kdiff project

SCRIPT_NAME = kdiff

.PHONY: lint
lint:
	shellcheck $(SCRIPT_NAME)
