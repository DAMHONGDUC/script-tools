# Make targets for a React Native project. Include it from the project Makefile after setting SCRIPT_TOOLS:
#   SCRIPT_TOOLS := packages/script-tools
#   include $(SCRIPT_TOOLS)/react_native/react_native.mk
# SCRIPT_TOOLS must be relative to the project root: make cannot handle spaces in paths.

.DEFAULT_GOAL := help
.PHONY: help set-up run-ios run-android

help: ## List the targets
	@grep -hE '^[a-z0-9%-]+:.*## ' $(MAKEFILE_LIST) | sort -u | awk -F ':.*## ' '{printf "  %-18s %s\n", $$1, $$2}'

set-up: ## Submodules, pull, npm ci, bundle install, clean pod install [NO_PULL=1]
	bash $(SCRIPT_TOOLS)/react_native/set_up.sh

run-ios: ## Build and open the app in the iOS Simulator [SIMULATOR="iPhone 17 Pro"]
	npx react-native run-ios $(if $(SIMULATOR),--simulator "$(SIMULATOR)")

run-android: ## Build, install and open the app on the emulator or device
	npx react-native run-android

release-ios-%: ## Signed IPA to TestFlight and Release/ for an env in FLAVORS, e.g. release-ios-dev [NOTE="..."]
	bash $(SCRIPT_TOOLS)/react_native/release_ios.sh $* "$(NOTE)"
