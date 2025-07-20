# Makefile for kdiff project
AGENT=CLAUDE
SCRIPT_NAME = kdiff
ORG_FILE=notes.org
HEADING_TEXT=Context

.PHONY: lint
lint:
	shellcheck $(SCRIPT_NAME)

.PHONY: context
context: $(AGENT).md

$(AGENT).md: notes.org
	@echo "--> Exporting subtree '$(HEADING_TEXT)' from notes.org to $@..."
	@emacs -batch --no-init-file --no-site-file  --load export.el
	@echo "--> Done."
