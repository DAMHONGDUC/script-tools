# Make targets for a Gradle Android project. Include it from the project Makefile after setting SCRIPT_TOOLS:
#   SCRIPT_TOOLS := packages/script-tools
#   include $(SCRIPT_TOOLS)/android/android.mk
# SCRIPT_TOOLS must be relative to the project root: make cannot handle spaces in paths.
# The command names are the shared list in common/COMMANDS.md — the same in every platform's file.

PLATFORM := Android
include $(SCRIPT_TOOLS)/common/commands.mk

APP_MODULE ?= app
# Variant for test, lint and the flavorless `run`, e.g. DevDebug for a project with flavors.
VARIANT ?= Debug

GRADLE := ./gradlew
FLAVOR_ENV = $(if $(FLAVOR),FLAVOR=$(FLAVOR))
# The flavor a pattern target was given, capitalized the way Gradle names its tasks: dev -> Dev.
CAP_STEM = $$(printf '%s' '$*' | awk '{ print toupper(substr($$0, 1, 1)) substr($$0, 2) }')

.PHONY: setup setup-deep test icon icon-strip sms

# Old names, kept working and left out of `make help`: projects and notes still type them.
# clean and analyze are off the shared list too (owner's rule: the list stays minimal) and still run.
.PHONY: build install lint apk aab run clean analyze
clean:
	$(GRADLE) clean
analyze:
	$(GRADLE) :$(APP_MODULE):lint$(VARIANT)
build:
	$(GRADLE) :$(APP_MODULE):assemble$(VARIANT)
install run:
	$(GRADLE) :$(APP_MODULE):install$(VARIANT)
lint: analyze
apk:
	$(FLAVOR_ENV) $(SCRIPT_TOOLS)/android/build_release_apk.sh
aab:
	$(FLAVOR_ENV) $(SCRIPT_TOOLS)/android/build_release_aab.sh

setup: ## Submodules, then resolve every Gradle dependency
	git submodule update --init --recursive
	$(GRADLE) :$(APP_MODULE):dependencies --refresh-dependencies --quiet > /dev/null

setup-deep: clean setup ## setup after deleting every build output

test: ## Run the unit tests; TEST=<ClassName> runs one class
	$(GRADLE) :$(APP_MODULE):test$(VARIANT)UnitTest $(if $(TEST),--tests '*$(TEST)*')

run-%: ## Install the flavor's debug build on the connected device; `make run` without flavors
	$(GRADLE) :$(APP_MODULE):install$(CAP_STEM)Debug

env-%: ## Install the flavor's real config
	$(call not_on,Gradle reads each flavor's config itself)

deploy-be-%: ## Install the flavor's config, then deploy its backend
	$(call not_on,no backend script for Android projects)

release-ios-%: ## Build the IPA and upload it to TestFlight
	$(call not_on,an IPA is an iOS build)

release-android-%: ## Signed release APK and AAB into Release/
	FLAVOR=$* $(SCRIPT_TOOLS)/android/build_release_apk.sh
	FLAVOR=$* $(SCRIPT_TOOLS)/android/build_release_aab.sh

icon: ## Every launcher icon from the app's icon artwork
	$(call not_on,no icon script for Android projects)

icon-strip: ## Erase the generator's watermark from the icon artwork
	$(call not_on,no icon script for Android projects)

sms: ## Send a fake SMS to the emulator: SENDER=<number> BODY="<text>"
	@test -n "$(SENDER)" -a -n "$(BODY)" || { echo 'usage: make sms SENDER=<number> BODY="<text>"' >&2; exit 1; }
	adb emu sms send $(SENDER) "$(BODY)"
