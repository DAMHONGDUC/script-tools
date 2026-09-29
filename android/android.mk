# Make targets for a Gradle Android project. Include it from the project Makefile after setting SCRIPT_TOOLS:
#   SCRIPT_TOOLS := packages/script-tools
#   include $(SCRIPT_TOOLS)/android/android.mk
# SCRIPT_TOOLS must be relative to the project root: make cannot handle spaces in paths.

APP_MODULE ?= app
# Variant for build/install/test/lint, e.g. DevDebug for a project with flavors.
VARIANT ?= Debug

GRADLE := ./gradlew
FLAVOR_ENV = $(if $(FLAVOR),FLAVOR=$(FLAVOR))

.DEFAULT_GOAL := help
.PHONY: help build install test lint apk aab sms clean

help: ## List the targets
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | sort -u | awk -F ':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

build: ## Build the VARIANT APK
	$(GRADLE) :$(APP_MODULE):assemble$(VARIANT)

install: ## Install the VARIANT APK on the connected device
	$(GRADLE) :$(APP_MODULE):install$(VARIANT)

test: ## Run unit tests; TEST=<ClassName> runs one class
	$(GRADLE) :$(APP_MODULE):test$(VARIANT)UnitTest $(if $(TEST),--tests '*$(TEST)*')

lint: ## Run Android lint
	$(GRADLE) :$(APP_MODULE):lint$(VARIANT)

apk: ## Signed release APK into Release/; FLAVOR=<flavor> picks a flavor
	$(FLAVOR_ENV) $(SCRIPT_TOOLS)/android/build_release_apk.sh

aab: ## Signed release AAB into Release/; FLAVOR=<flavor> picks a flavor
	$(FLAVOR_ENV) $(SCRIPT_TOOLS)/android/build_release_aab.sh

sms: ## Send a fake SMS to the emulator: SENDER=<number> BODY="<text>"
	@test -n "$(SENDER)" -a -n "$(BODY)" || { echo 'usage: make sms SENDER=<number> BODY="<text>"' >&2; exit 1; }
	adb emu sms send $(SENDER) "$(BODY)"

clean: ## Delete Gradle build outputs
	$(GRADLE) clean
