#!/usr/bin/env bash
# One-step setup of a React Native project: submodules, latest code, JS dependencies, then a clean
# CocoaPods install on macOS.
# Usage: <submodule path>/react_native/set_up.sh   (NO_PULL=1 skips `git pull`)
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

root="$(rn_project_root)"
cd "$root"

step "submodules"
git submodule update --init --recursive
git submodule foreach --quiet 'printf "  %s at %s\n" "$sm_path" "$(git rev-parse --short HEAD)"'

if [ -z "${NO_PULL:-}" ]; then
  step "pull"
  # Fast-forward only: never creates a merge commit; stops if the branch has diverged.
  git pull --ff-only
fi

step "JS dependencies"
npm ci

if [ "$(uname)" = Darwin ] && [ -f ios/Podfile ]; then
  step "CocoaPods"
  bundle install
  # A clean install, so pods match package.json after a pull or a branch switch.
  info "removing ios/Pods, ios/Podfile.lock and ios/build"
  rm -rf ios/Pods ios/Podfile.lock ios/build
  ensure_utf8_locale
  (cd ios && bundle exec pod install --repo-update)
else
  warn "skipping CocoaPods: iOS builds need macOS"
fi

done_msg "set up; next: make run-ios or make run-android"
