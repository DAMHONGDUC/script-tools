#!/usr/bin/env bash
# Installs one flavor's config, then deploys its backend. Without a backend, says so and stops.
# Usage: <script-tools>/flutter/deploy_backend.sh <flavor> [rules|functions]
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

TARGET="${1:-}"
require_flavor "$TARGET" "deploy_backend.sh <flavor> [rules|functions]"

# Before the deploy, not after: it reads functions/.env, which only the config step puts there.
install_flavor_config "$TARGET"

if ! has_firebase; then
  info "no .firebaserc — this app runs no Firebase backend, nothing to deploy"
  exit 0
fi

bash "$FLUTTER_TOOLS_DIR/deploy_firebase.sh" "$@"
