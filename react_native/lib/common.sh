#!/usr/bin/env bash
# Shared by the react_native/ scripts: project root, settings, iOS project facts. Source this file.
set -euo pipefail

rn_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../common/lib/log.sh
source "$rn_lib_dir/../../common/lib/log.sh"
# shellcheck source=../../common/lib/project.sh
source "$rn_lib_dir/../../common/lib/project.sh"

# The React Native project: $PROJECT_ROOT, else the nearest folder holding script-tools.properties or package.json.
rn_project_root() {
  find_project_root script-tools.properties package.json
}

# The workspace CocoaPods writes under ios/, e.g. ios/MyApp.xcworkspace; IOS_WORKSPACE overrides it.
rn_ios_workspace() {
  local root="$1" workspace
  workspace="$(project_setting "$root" IOS_WORKSPACE "")"
  if [ -z "$workspace" ]; then
    workspace="$(cd "$root" && find ios -maxdepth 1 -name '*.xcworkspace' | head -1)"
  fi
  [ -n "$workspace" ] || fail "No ios/*.xcworkspace; run make set-up, or set IOS_WORKSPACE in script-tools.properties"
  printf '%s\n' "$workspace"
}

# The bundle id: IOS_APP_IDENTIFIER, else the one PRODUCT_BUNDLE_IDENTIFIER in ios/*.xcodeproj.
rn_ios_app_identifier() {
  local root="$1" id
  id="$(project_setting "$root" IOS_APP_IDENTIFIER "")"
  if [ -z "$id" ]; then
    id="$(grep -h 'PRODUCT_BUNDLE_IDENTIFIER = ' "$root"/ios/*.xcodeproj/project.pbxproj 2>/dev/null \
      | sed -E 's/.*= "?([^";]*)"?;.*/\1/' | sort -u)"
    [ "$(printf '%s\n' "$id" | grep -c .)" = 1 ] || fail "Set IOS_APP_IDENTIFIER in script-tools.properties (found: ${id:-none})"
  fi
  printf '%s\n' "$id"
}
