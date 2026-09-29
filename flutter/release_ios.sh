#!/usr/bin/env bash
# One flavor end to end: install its config, deploy its backend, ship to TestFlight. Runs unattended.
# Usage: <script-tools>/flutter/release_ios.sh <flavor> [release note]
#
# It does not set up first: a tree that needs restoring is restored by set_up.sh, on purpose.
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

# Everything runs inside `main` because the shell reads a script by byte offset as it runs it: fastlane holds that
# offset ~25 minutes, and an edit to this file meanwhile resumes mid-line. A function body is parsed whole.
main() {
  TARGET="${1:-}"
  require_flavor "$TARGET" "release_ios.sh <flavor> [release note]"

  # Travels as an environment variable, never a fastlane argument: spaces would split it and a backtick would run.
  RELEASE_NOTES="${2:-${RELEASE_NOTES:-}}"
  export RELEASE_NOTES

  # The fallback is composed by the lane: the build number is settled inside it.
  if [ -n "$RELEASE_NOTES" ]; then
    info "release note: $RELEASE_NOTES"
  else
    info "no note given — the lane attaches \"$TARGET - <version> (<build>)\""
  fi

  # Here rather than 25 minutes in, with the backend already deployed.
  command -v bundle >/dev/null 2>&1 || fail "bundler not found — cd ios && bundle install"

  # Which steps this app has. A skip is always announced by name; none is silent.
  HAS_CONFIG=0
  [ -d env_assets ] && HAS_CONFIG=1
  HAS_BACKEND=0
  has_firebase && HAS_BACKEND=1

  # TestFlight is the one step every app has. Only steps that RUN are counted.
  TOTAL=$((HAS_CONFIG + HAS_BACKEND + 1))
  DONE=0
  phase() {
    DONE=$((DONE + 1))
    step "release $TARGET — $DONE/$TOTAL $1"
  }

  # The order is the point: config must be in the tree before the deploy reads functions/.env and before the lane
  # compares GoogleService-Info.plist with the flavor.
  if [ "$HAS_CONFIG" = 1 ]; then
    phase config
    bash "$FLUTTER_TOOLS_DIR/prepare_env.sh" "$TARGET"
  else
    info "no env_assets/ — this app keeps no flavored config, nothing to install"
  fi

  if [ "$HAS_BACKEND" = 1 ]; then
    phase firebase
    bash "$FLUTTER_TOOLS_DIR/deploy_firebase.sh" "$TARGET"
  else
    info "no .firebaserc — this app runs no Firebase backend, nothing to deploy"
  fi

  ensure_utf8_locale

  phase testflight
  (cd ios && bundle exec fastlane beta flavor:"$TARGET" bump:true)

  done_msg "released $TARGET"
  # bump:true rewrites pubspec.yaml locally, but only CI commits it.
  warn "commit the bumped build number in pubspec.yaml — a local run does not"
}

# `exit` on the same line: it is parsed with the call, so nothing reads the file again after main returns.
main "$@"; exit 0
