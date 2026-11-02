# The one command list every platform speaks. Included by <platform>/<platform>.mk, never by a project directly.
#
# Every platform defines every command below, in this order, so `make help` reads the same in every project
# and nobody has to remember which project calls it what. A command a platform cannot do still exists there and
# says so (`$(call not_on,<reason>)`), instead of being missing. Spec: common/COMMANDS.md.
#
# The platform file sets PLATFORM before including this one.

COMMANDS := help pull setup setup-deep test \
  run-% env-% deploy-be-% release-ios-% release-android-% icon icon-strip

.DEFAULT_GOAL := help
.PHONY: help

# Canonical commands first, in the order above; a platform's or a project's own extras after them.
help: ## List the commands
	@grep -hE '^[a-z0-9%-]+:.*## ' $(MAKEFILE_LIST) \
	  | awk -F ':.*## ' -v order="$(COMMANDS)" \
	    'BEGIN { n = split(order, o, " "); for (i = 1; i <= n; i++) rank[o[i]] = i } \
	     { r = ($$1 in rank) ? rank[$$1] : 900; printf "%03d\t%s\t%s\n", r, $$1, $$2 }' \
	  | sort -u | sort -t "$$(printf '\t')" -k1,1n -k2,2 \
	  | awk -F '\t' '{ t = $$2; gsub(/%/, "<flavor>", t); printf "  %-26s %s\n", t, $$3 }'

# The one command every platform runs the same way, so it is defined here rather than in each platform file.
.PHONY: pull
pull: ## Fast-forward the project and every submodule to the head of its main branch; never commits or pushes
	@bash $(SCRIPT_TOOLS)/common/pull_latest.sh

# The recipe of a command this platform does not have: says why, and fails so a script calling it stops.
# Usage, as a whole recipe line: $(call not_on,<reason>)
not_on = @printf 'make %s: not available on %s — %s\n' '$@' '$(PLATFORM)' '$(1)' >&2; exit 2
