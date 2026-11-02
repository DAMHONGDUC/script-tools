#!/usr/bin/env bash
# Runs the app in debug on a device or simulator for one flavor, with its dart-define config attached.
# Usage: <script-tools>/flutter/run_app.sh <flavor> [flutter run args...]
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

TARGET="${1:-}"
require_flavor "$TARGET" "run_app.sh <flavor> [flutter run args...]"
shift
ENV_FILE="env/$TARGET.json"

# Same rule as build_ipa.sh: a template declares config, so a missing real file is an error, not a silent empty run.
TEMPLATE=$(env_template "$TARGET")
if [ -n "$TEMPLATE" ]; then
  # Existence only — never the contents.
  [ -f "$ENV_FILE" ] || fail "$ENV_FILE is missing — run set_up.sh"
  set -- --dart-define-from-file="$ENV_FILE" "$@"
  info "config: $ENV_FILE (declared by $TEMPLATE)"
else
  info "no env template — this app compiles its config in, no dart-defines"
fi

step "run — $TARGET"
$FL run "$@"
