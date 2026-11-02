# Make targets for a Gradle Android project. Include it from the project Makefile after setting SCRIPT_TOOLS:
#   SCRIPT_TOOLS := packages/script-tools
#   include $(SCRIPT_TOOLS)/android/android.mk
# SCRIPT_TOOLS must be relative to the project root: make cannot handle spaces in paths.
# The command names are the shared list in common/COMMANDS.md — the same in every platform's file.

PLATFORM := Android
include $(SCRIPT_TOOLS)/common/commands.mk

APP_MODULE ?= app
# Variant for analyze/test and the flavorless `run`, e.g. DevDebug for a project with flavors.
VARIANT ?= Debug

GRADLE := ./gradlew
FLAVOR_ENV = $(if $(FLAVOR),FLAVOR=$(FLAVOR))
# The flavor a pattern target was given, capitalized the way Gradle names its tasks: dev -> Dev.
CAP_STEM = $$(printf '%s' '$*' | awk '{ print toupper(substr($$0, 1, 1)) substr($$0, 2) }')

.PHONY: setup setup-deep clean gen analyze test icon icon-strip sms

# Old names, kept working and left out of `make help`: projects and notes still type them.
.PHONY: build install lint apk aab run
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

clean: ## Delete build outputs only
	$(GRADLE) clean

gen: ## Regenerate generated code
	$(call not_on,code generation runs inside the Gradle build)

analyze: ## Run Android lint on VARIANT, the CI gate
	$(GRADLE) :$(APP_MODULE):lint$(VARIANT)

test: ## Run the unit tests; TEST=<ClassName> runs one class
	$(GRADLE) :$(APP_MODULE):test$(VARIANT)UnitTest $(if $(TEST),--tests '*$(TEST)*')

run-%: ## Install the flavor's debug build on the connected device; `make run` without flavors
	$(GRADLE) :$(APP_MODULE):install$(CAP_STEM)Debug

env-%: ## Install the flavor's real config
	$(call not_on,Gradle reads each flavor's config itself)

deploy-%: ## Deploy the backend
	$(call not_on,no backend script for Android projects)

ipa-%: ## Build the flavor's release IPA
	$(call not_on,an IPA is an iOS build)

apk-%: ## Signed release APK into Release/
	FLAVOR=$* $(SCRIPT_TOOLS)/android/build_release_apk.sh

aab-%: ## Signed release AAB into Release/
	FLAVOR=$* $(SCRIPT_TOOLS)/android/build_release_aab.sh

release-%: ## Ship the flavor to its store
	$(call not_on,no Play upload script yet — make aab-<flavor> and upload it in Play Console)

upload-%: ## Upload the build already made to its store
	$(call not_on,no Play upload script yet — upload Release/ in Play Console)

icon: ## Every launcher icon from the app's icon artwork
	$(call not_on,no icon script for Android projects)

icon-strip: ## Erase the generator's watermark from the icon artwork
	$(call not_on,no icon script for Android projects)

sms: ## Send a fake SMS to the emulator: SENDER=<number> BODY="<text>"
	@test -n "$(SENDER)" -a -n "$(BODY)" || { echo 'usage: make sms SENDER=<number> BODY="<text>"' >&2; exit 1; }
	adb emu sms send $(SENDER) "$(BODY)"
