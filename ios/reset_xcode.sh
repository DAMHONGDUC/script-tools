#!/usr/bin/env bash
# Deep reset of the Xcode project you run it from, for stale errors and stuck package resolution.
# Usage: <submodule path>/ios/reset_xcode.sh [--all]
#   --all  also clears the global SwiftPM cache and the project's Xcode user state (breakpoints, open tabs)
set -euo pipefail
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common/lib" && pwd)"
source "$LIB/log.sh"
source "$LIB/project.sh"

all=false
if [ "${1:-}" = "--all" ]; then
  all=true
fi

root="$(find_project_root project.yml script-tools.properties)"
cd "$root"

project="$(project_setting "$root" IOS_PROJECT "")"
if [ -z "$project" ]; then
  project="$(find . -maxdepth 1 -name '*.xcodeproj' | head -1 | sed 's#^\./##')"
fi
[ -n "$project" ] || fail "No .xcodeproj in $root; set IOS_PROJECT in script-tools.properties"
name="${project%.xcodeproj}"
scheme="$(project_setting "$root" IOS_SCHEME "$name")"
packages_dir="$(project_setting "$root" IOS_PACKAGES_DIR "Packages")"

step "reset Xcode — $name"

if pgrep -x Xcode >/dev/null; then
  info "quitting Xcode"
  osascript -e 'quit app "Xcode"'
  sleep 2
fi

info "deleting DerivedData/$name-*"
rm -rf "$HOME"/Library/Developer/Xcode/DerivedData/"$name"-*

info "deleting build/ and local package caches"
rm -rf build
if [ -d "$packages_dir" ]; then
  for package in "$packages_dir"/*/; do
    rm -rf "${package}.build" "${package}.swiftpm"
  done
fi

if [ "$all" = true ]; then
  warn "--all: global SwiftPM cache and Xcode user state"
  rm -rf "$HOME/Library/Caches/org.swift.swiftpm"
  rm -rf "$project/xcuserdata" "$project/project.xcworkspace/xcuserdata"
fi

if [ -f project.yml ]; then
  info "regenerating with xcodegen"
  xcodegen generate --quiet
fi

info "resolving packages for scheme $scheme"
xcodebuild -project "$project" -scheme "$scheme" -resolvePackageDependencies >/dev/null

info "opening $project"
open "$project"

done_msg "Xcode reset; build with ⌘B"
