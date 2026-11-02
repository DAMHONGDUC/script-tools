#!/usr/bin/env bash
# One flavor's iOS release: install its config, then build the IPA and ship it to TestFlight. Runs unattended.
# Usage: <script-tools>/flutter/release_ios.sh <flavor> [release note]
#
# It does not set up first: a tree that needs restoring is restored by set_up.sh, on purpose.
# It deploys no backend: that is deploy_backend.sh, its own command (owner's rule).
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

  # Here rather than minutes in, after the config is already installed.
  command -v bundle >/dev/null 2>&1 || fail "bundler not found — cd ios && bundle install"

  # Before the lane, which compares GoogleService-Info.plist with the flavor and builds with its dart-defines.
  step "release $TARGET — 1/2 config"
  install_flavor_config "$TARGET"

  ensure_utf8_locale

  step "release $TARGET — 2/2 ipa and testflight"
  (cd ios && bundle exec fastlane beta flavor:"$TARGET" bump:true)

  done_msg "released $TARGET"
  # bump:true rewrites pubspec.yaml locally, but only CI commits it.
  warn "commit the bumped build number in pubspec.yaml — a local run does not"
}

# `exit` on the same line: it is parsed with the call, so nothing reads the file again after main returns.
main "$@"; exit 0
