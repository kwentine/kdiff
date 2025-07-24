# Makefile for kdiff project
SCRIPT_NAME = kdiff
PRESETS_DIR = presets
TESTS_DIR = tests
XDG_CONFIG_HOME ?= $(HOME)/.config
KDIFF_CONFIG_DIR ?= $(XDG_CONFIG_HOME)/kdiff
KDIFF_INSTALL_DIR ?= $(HOME)/.local/bin

# Set to 'n' to avoid overwriting existing destinations
CP_EXTRA_FLAGS=

.PHONY: install
install:
	@echo "Installing $(SCRIPT_NAME) executable in $(KDIFF_INSTALL_DIR)"
	@cp $(CP_EXTRA_FLAGS) bin/$(SCRIPT_NAME) $(KDIFF_INSTALL_DIR)

.PHONY: install-presets
install-presets:
	@echo "Installing presets to $(KDIFF_CONFIG_DIR)"
	@mkdir -p "$(KDIFF_CONFIG_DIR)"
	@cp -r$(CP_EXTRA_FLAGS) $(PRESETS_DIR)/* "$(KDIFF_CONFIG_DIR)/"
	@chmod -R +x "$(KDIFF_CONFIG_DIR)/compare" "$(KDIFF_CONFIG_DIR)/transform"

.PHONY: lint
lint:
	@shellcheck bin/$(SCRIPT_NAME)

.PHONY: test
test:
	@$(TESTS_DIR)/integration.sh
