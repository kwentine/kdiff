# Makefile for kdiff project
SCRIPT_NAME = kdiff
PRESETS_DIR = presets
TESTS_DIR = tests

# Install configuration
PREFIX ?= $(HOME)/.local
DESTDIR ?=
KDIFF_INSTALL_DIR ?= $(DESTDIR)$(PREFIX)/bin
XDG_CONFIG_HOME ?= $(HOME)/.config
KDIFF_CONFIG_DIR ?= $(XDG_CONFIG_HOME)/kdiff

# Set to 'n' to avoid overwriting existing destinations
CP_EXTRA_FLAGS ?=

.PHONY: all
all:
	@echo "Nothing to build. Use 'make install' to install."

.PHONY: install
install:
	@echo "Installing $(SCRIPT_NAME) executable to $(KDIFF_INSTALL_DIR)/$(SCRIPT_NAME)"
	@install -D -m 0755 bin/$(SCRIPT_NAME) "$(KDIFF_INSTALL_DIR)/$(SCRIPT_NAME)"

.PHONY: install-presets
install-presets:
	@echo "Installing presets to $(KDIFF_CONFIG_DIR)"
	@mkdir -p "$(KDIFF_CONFIG_DIR)"
	@cp -r$(CP_EXTRA_FLAGS) $(PRESETS_DIR)/* "$(KDIFF_CONFIG_DIR)/"
	@chmod -R +x "$(KDIFF_CONFIG_DIR)/compare" "$(KDIFF_CONFIG_DIR)/transform"

.PHONY: uninstall
uninstall:
	@echo "Removing $(SCRIPT_NAME) from $(KDIFF_INSTALL_DIR)"
	@rm -f "$(KDIFF_INSTALL_DIR)/$(SCRIPT_NAME)"

.PHONY: uninstall-presets
uninstall-presets:
	@echo "Removing presets from $(KDIFF_CONFIG_DIR)"
	@rm -rf "$(KDIFF_CONFIG_DIR)"

.PHONY: lint
lint:
	@shellcheck bin/$(SCRIPT_NAME)

.PHONY: test
test:
	@$(TESTS_DIR)/integration.sh
