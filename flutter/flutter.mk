# Make targets for a Flutter project. Include it from the project Makefile after setting SCRIPT_TOOLS:
#   SCRIPT_TOOLS := packages/script-tools
#   include $(SCRIPT_TOOLS)/flutter/flutter.mk
# SCRIPT_TOOLS must be relative to the project root: make cannot handle spaces in paths.
# Flavored targets take the flavor as a suffix (release-ios-dev), so the destination is typed, never defaulted.
# Store targets name their platform too: build-ios-, release-ios-, upload-ios-<flavor>.

FLUTTER_SCRIPTS := $(SCRIPT_TOOLS)/flutter
# Every script finds the project from here, whatever directory make was started in.
export PROJECT_ROOT := $(CURDIR)

.DEFAULT_GOAL := help
.PHONY: help set-up deep-set-up gen analyze test app-icon app-icon-strip-marker

help: ## List the targets
	@grep -hE '^[a-z0-9%-]+:.*## ' $(MAKEFILE_LIST) | sort -u | sed 's/%/<flavor>/' | awk -F ':.*## ' '{printf "  %-26s %s\n", $$1, $$2}'

set-up: ## Wipe build outputs, then submodules, pub get, codegen, env templates
	@bash $(FLUTTER_SCRIPTS)/set_up.sh

deep-set-up: ## set-up, plus this project's Xcode DerivedData
	@bash $(FLUTTER_SCRIPTS)/set_up.sh --deep

gen: ## Regenerate localizations and build_runner output
	@bash $(FLUTTER_SCRIPTS)/generate_code.sh

analyze: ## flutter analyze --fatal-infos, the CI gate
	@bash $(FLUTTER_SCRIPTS)/analyze_code.sh

test: ## flutter test; TEST=<path> runs one file or folder
	@bash $(FLUTTER_SCRIPTS)/run_tests.sh $(TEST)

app-icon: ## Every launcher and launch screen icon from assets/images/app_icon.png
	@bash $(FLUTTER_SCRIPTS)/generate_app_icon.sh

app-icon-strip-marker: ## Erase the generator's watermark from the icon artwork, in place
	@bash $(FLUTTER_SCRIPTS)/strip_icon_marker.sh

env-%: ## Install the flavor's real config from env_assets/
	@bash $(FLUTTER_SCRIPTS)/prepare_env.sh $*

deploy-%: ## Deploy Firebase rules, indexes, functions; ONLY=rules|functions
	@bash $(FLUTTER_SCRIPTS)/deploy_firebase.sh $* $(ONLY)

build-ios-%: ## iOS: build the flavor's release IPA into build/ios/ipa
	@bash $(FLUTTER_SCRIPTS)/build_ipa.sh $*

release-ios-%: ## iOS: config, Firebase deploy, TestFlight; NOTE="..." for What to Test
	@bash $(FLUTTER_SCRIPTS)/release_ios.sh $* "$(NOTE)"


upload-ios-%: ## iOS: upload build/ios/ipa to TestFlight without rebuilding
	@bash $(FLUTTER_SCRIPTS)/upload_ipa.sh $*

# Old names fail loudly with the new one instead of guessing. Unlisted in help, and last in the file so make 3.81
# (which takes the first matching pattern, not the most specific) still picks the -ios- rules above.
release-%:
	@echo "error: name the platform — make release-ios-$*" >&2; exit 2

build-ipa-%:
	@echo "error: renamed — make build-ios-$*" >&2; exit 2

upload-ipa-%:
	@echo "error: renamed — make upload-ios-$*" >&2; exit 2
