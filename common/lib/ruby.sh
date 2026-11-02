#!/usr/bin/env bash
# What every platform needs before it runs a Ruby tool (fastlane, CocoaPods). Source this file after log.sh.

# Ruby fixes its default encoding at startup from the locale, so fastlane and CocoaPods fail under LANG=C —
# fastlane on every em dash in a Fastfile (`invalid multibyte character`), CocoaPods with an encoding error.
# A UTF-8 locale already set is kept.
ensure_utf8_locale() {
  case "${LANG:-}" in
    *UTF-8 | *utf8) ;;
    *) LANG=en_US.UTF-8 ;;
  esac
  case "${LC_ALL:-}" in
    '' | *UTF-8 | *utf8) ;;
    *) LC_ALL=en_US.UTF-8 ;;
  esac
  export LANG
  [ -z "${LC_ALL:-}" ] || export LC_ALL
}

# Fails with the fix unless bundler is installed: said before a build spends minutes, not after.
# Usage: require_bundler <folder holding the Gemfile, e.g. ios>
require_bundler() {
  command -v bundle >/dev/null 2>&1 || fail "bundler not found — cd ${1:-.} && bundle install"
}

# Under `bundle exec` (every fastlane lane) Ruby can load only the Gemfile's gems, so a Gemfile with fastlane alone
# leaves `pod` broken and `flutter build ipa` stops on "CocoaPods is installed but broken". When CocoaPods fails here
# but the app has a Podfile, restore the environment bundler saved in BUNDLER_ORIG_*, as Bundler.with_unbundled_env
# does, so the machine's own CocoaPods runs. A bundle that ships CocoaPods, or no bundle at all, is left alone.
# Usage: leave_bundle_without_cocoapods <folder holding the Podfile, e.g. ios>
leave_bundle_without_cocoapods() {
  [ -n "${BUNDLE_GEMFILE:-}" ] || return 0
  [ -f "${1:-.}/Podfile" ] || return 0
  pod --version >/dev/null 2>&1 && return 0

  local var name
  for var in $(compgen -e | grep '^BUNDLER_ORIG_'); do
    name="${var#BUNDLER_ORIG_}"
    if [ "${!var}" = "BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL" ]; then
      unset "$name"
    else
      export "$name=${!var}"
    fi
    unset "$var"
  done
  info "the bundle has no CocoaPods — running the build outside it, with this machine's pod"
}
