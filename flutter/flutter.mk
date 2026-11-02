# Make targets for a Flutter project. Include it from the project Makefile after setting SCRIPT_TOOLS:
#   SCRIPT_TOOLS := packages/script-tools
#   include $(SCRIPT_TOOLS)/flutter/flutter.mk
# SCRIPT_TOOLS must be relative to the project root: make cannot handle spaces in paths.
# Flavored targets take the flavor as a suffix (release-dev), so the destination is typed, never defaulted.
# The command names are the shared list in common/COMMANDS.md — the same in every platform's file.

PLATFORM := Flutter
include $(SCRIPT_TOOLS)/common/commands.mk

FLUTTER_SCRIPTS := $(SCRIPT_TOOLS)/flutter
# Every script finds the project from here, whatever directory make was started in.
export PROJECT_ROOT := $(CURDIR)

.PHONY: setup setup-deep test icon icon-strip

# Old names, kept working and left out of `make help`: projects and notes still type them.
# The two patterns come first and run their script directly: make 3.81, the one macOS ships, takes the first
# pattern that matches, and `upload-%` would otherwise read `upload-ipa-prod` as the flavor `ipa-prod`.
build-ipa-%:
	@bash $(FLUTTER_SCRIPTS)/build_ipa.sh $*

upload-ipa-%:
	@bash $(FLUTTER_SCRIPTS)/upload_ipa.sh $*

.PHONY: set-up deep-set-up app-icon app-icon-strip-marker
set-up: setup
deep-set-up: setup-deep
app-icon: icon
app-icon-strip-marker: icon-strip

# Off the shared list (owner's rule: the list stays minimal), still run: docs and the definition of done type them.
.PHONY: gen analyze
gen:
	@bash $(FLUTTER_SCRIPTS)/generate_code.sh
analyze:
	@bash $(FLUTTER_SCRIPTS)/analyze_code.sh

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

deploy-%: ## Deploy the backend (Firebase rules, indexes, functions); ONLY=rules|functions
	@bash $(FLUTTER_SCRIPTS)/deploy_firebase.sh $* $(ONLY)

ipa-%: ## Build the flavor's release IPA into build/ios/ipa
	@bash $(FLUTTER_SCRIPTS)/build_ipa.sh $*

apk-%: ## Install the flavor's config, then its release APK into Release/
	@bash $(FLUTTER_SCRIPTS)/build_apk.sh $*

aab-%: ## Install the flavor's config, then its release AAB into Release/
	@bash $(FLUTTER_SCRIPTS)/build_aab.sh $*

release-%: ## Ship the flavor: config, backend deploy, TestFlight; NOTE="..." for What to Test
	@bash $(FLUTTER_SCRIPTS)/release_ios.sh $* "$(NOTE)"

upload-%: ## Upload the build already made to TestFlight, without rebuilding
	@bash $(FLUTTER_SCRIPTS)/upload_ipa.sh $*

icon: ## Every launcher and launch screen icon from assets/images/app_icon.png
	@bash $(FLUTTER_SCRIPTS)/generate_app_icon.sh

icon-strip: ## Erase the generator's watermark from the icon artwork, in place
	@bash $(FLUTTER_SCRIPTS)/strip_icon_marker.sh
