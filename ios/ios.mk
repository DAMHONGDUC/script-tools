# Make targets for an Xcode project. Include it from the project Makefile after setting SCRIPT_TOOLS:
#   SCRIPT_TOOLS := packages/script-tools
#   include $(SCRIPT_TOOLS)/ios/ios.mk
# SCRIPT_TOOLS must be relative to the project root: make cannot handle spaces in paths.

.DEFAULT_GOAL := help
.PHONY: help reset-xcode deep-reset-xcode

help: ## List the targets
	@grep -hE '^[a-z0-9-]+:.*## ' $(MAKEFILE_LIST) | sort -u | awk -F ':.*## ' '{printf "  %-18s %s\n", $$1, $$2}'

reset-xcode: ## Quit Xcode, delete DerivedData, build/ and package caches, regenerate, resolve, reopen
	$(SCRIPT_TOOLS)/ios/reset_xcode.sh

deep-reset-xcode: ## reset-xcode plus the global SwiftPM cache and Xcode user state
	$(SCRIPT_TOOLS)/ios/reset_xcode.sh --all
