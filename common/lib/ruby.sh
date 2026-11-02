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
