# Make targets for a React Native project. Include it from the project Makefile after setting SCRIPT_TOOLS:
#   SCRIPT_TOOLS := packages/script-tools
#   include $(SCRIPT_TOOLS)/react_native/react_native.mk
# SCRIPT_TOOLS must be relative to the project root: make cannot handle spaces in paths.

.DEFAULT_GOAL := help
.PHONY: help set-up run-ios run-android ports kill-all-ports devices devices-ios devices-android

help: ## List the targets
	@grep -hE '^[a-z0-9%-]+:.*## ' $(MAKEFILE_LIST) | sort -u | awk -F ':.*## ' '{printf "  %-18s %s\n", $$1, $$2}'

set-up: ## Submodules, pull, npm ci, bundle install, clean pod install [NO_PULL=1]
	bash $(SCRIPT_TOOLS)/react_native/set_up.sh

run-ios: ## Build and open the app on a specific device or simulator [DEVICE=<UDID>] [SIMULATOR="iPhone 17 Pro"]
	npx react-native run-ios \
		$(if $(DEVICE),--udid "$(DEVICE)") \
		$(if $(SIMULATOR),--simulator "$(SIMULATOR)")

run-android: ## Build, install and open the app on a specific device or emulator [DEVICE=<adb serial>]
	$(if $(DEVICE),-@adb -s $(DEVICE) reverse tcp:8081 tcp:8081)
	npx react-native run-android $(if $(DEVICE),--deviceId $(DEVICE))

release-ios-%: ## Signed IPA to TestFlight and Release/ for an env in FLAVORS, e.g. release-ios-dev [NOTE="..."]
	bash $(SCRIPT_TOOLS)/react_native/release_ios.sh $* "$(NOTE)"

ports: ## Show node/adb/java/watchman processes that are listening
	@lsof -iTCP -sTCP:LISTEN -n -P | grep -E "node|adb|java|watchman" || echo "No process is listening"

kill-all-ports: ## Find every node/adb/java/watchman process that is listening on a port and kill it
	@PIDS=$$(lsof -iTCP -sTCP:LISTEN -n -P | grep -E "node|adb|java|watchman" | awk '{print $$2}' | sort -u); \
	if [ -n "$$PIDS" ]; then \
		lsof -iTCP -sTCP:LISTEN -n -P | grep -E "node|adb|java|watchman" | awk '{printf "Killing %s (PID %s) on %s\n", $$1, $$2, $$9}'; \
		echo "$$PIDS" | xargs kill -9; \
		echo "Done"; \
	else \
		echo "No listening process found"; \
	fi

devices: devices-android devices-ios ## List booted/connected Android and iOS devices

devices-android: ## List running Android emulators and connected devices (adb serial)
	@echo "== Android =="
	@adb devices -l | awk 'NR>1 && $$2=="device"' | grep . || echo "No running Android device"

devices-ios: ## List booted iOS simulators and connected iPhones
	@echo "== iOS simulators (booted) =="
	@xcrun simctl list devices booted | grep -E "iPhone|iPad" || echo "No booted simulator"
	@echo "== iOS physical devices (connected) =="
	@xcrun xctrace list devices 2>/dev/null | sed -n '/== Devices ==/,/== Simulators ==/p' | grep -vE "^==|^$$|Mac" || echo "No connected iPhone"