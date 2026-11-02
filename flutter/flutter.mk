# Make targets for a Flutter project. Include it from the project Makefile after setting SCRIPT_TOOLS:
#   SCRIPT_TOOLS := packages/script-tools
#   include $(SCRIPT_TOOLS)/flutter/flutter.mk
# SCRIPT_TOOLS must be relative to the project root: make cannot handle spaces in paths.
# Flavored targets take the flavor as a suffix (release-ios-dev), so the destination is typed, never defaulted.
# The command names are the shared list in common/COMMANDS.md — the same in every platform's file.
#
# make 3.81, the one macOS ships, takes the FIRST pattern that matches: every specific pattern (release-ios-%,
# deploy-be-%, build-ipa-%) sits above the old general names (release-%, deploy-%) at the end of this file.

PLATFORM := Flutter
include $(SCRIPT_TOOLS)/common/commands.mk

FLUTTER_SCRIPTS := $(SCRIPT_TOOLS)/flutter
# Every script finds the project from here, whatever directory make was started in.
export PROJECT_ROOT := $(CURDIR)

.PHONY: setup setup-deep test icon icon-strip

setup: ## Wipe build outputs, then submodules, pub get, codegen, env templates
	@bash $(FLUTTER_SCRIPTS)/set_up.sh

setup-deep: ## setup, plus this project's Xcode DerivedData
	@bash $(FLUTTER_SCRIPTS)/set_up.sh --deep

test: ## Run the tests; TEST=<path> runs one file or folder
	@bash $(FLUTTER_SCRIPTS)/run_tests.sh $(TEST)

run-%: ## Run the app in debug with the flavor's config
	@bash $(FLUTTER_SCRIPTS)/run_app.sh $*

env-%: ## Install the flavor's real config from env_assets/
	@bash $(FLUTTER_SCRIPTS)/prepare_env.sh $*

deploy-be-%: ## Install the flavor's config, then deploy its backend (Firebase if any); ONLY=rules|functions
	@bash $(FLUTTER_SCRIPTS)/deploy_backend.sh $* $(ONLY)

release-ios-%: ## Install the flavor's config, build the IPA, upload to TestFlight; NOTE="..." for What to Test
	@bash $(FLUTTER_SCRIPTS)/release_ios.sh $* "$(NOTE)"

release-android-%: ## Install the flavor's config, build the release APK and AAB into Release/
	@bash $(FLUTTER_SCRIPTS)/release_android.sh $*

icon: ## Every launcher and launch screen icon from assets/images/app_icon.png
	@bash $(FLUTTER_SCRIPTS)/generate_app_icon.sh

icon-strip: ## Erase the generator's watermark from the icon artwork, in place
	@bash $(FLUTTER_SCRIPTS)/strip_icon_marker.sh

# Off the shared list (owner's rule: the list stays minimal), still run: docs and the definition of done type them.
.PHONY: gen analyze
gen:
	@bash $(FLUTTER_SCRIPTS)/generate_code.sh
analyze:
	@bash $(FLUTTER_SCRIPTS)/analyze_code.sh

# Old names, kept working and left out of `make help`: projects and notes still type them.
.PHONY: set-up deep-set-up app-icon app-icon-strip-marker
set-up: setup
deep-set-up: setup-deep
app-icon: icon
app-icon-strip-marker: icon-strip

# The IPA alone, and the upload of one already built — what release-ios-% does in one go, kept for a retry.
build-ipa-%:
	@bash $(FLUTTER_SCRIPTS)/build_ipa.sh $*
upload-ipa-%:
	@bash $(FLUTTER_SCRIPTS)/upload_ipa.sh $*

# Last, below every specific pattern. The old release did both halves, so it still does.
deploy-%:
	@bash $(FLUTTER_SCRIPTS)/deploy_backend.sh $* $(ONLY)
release-%:
	@bash $(FLUTTER_SCRIPTS)/deploy_backend.sh $*
	@bash $(FLUTTER_SCRIPTS)/release_ios.sh $* "$(NOTE)"
