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

# The Apple team: IOS_TEAM_ID from the environment, ios/fastlane/.env or script-tools.properties, else the
# team of the one valid Apple Distribution identity in the keychain.
rn_ios_team_id() {
  local root="$1" team teams
  team="${IOS_TEAM_ID:-$(read_property "$root/ios/fastlane/.env" IOS_TEAM_ID "")}"
  team="${team:-$(project_setting "$root" IOS_TEAM_ID "")}"
  if [ -z "$team" ]; then
    teams="$(security find-identity -v -p codesigning 2>/dev/null \
      | sed -nE 's/.*"Apple Distribution: .*\(([A-Z0-9]{10})\)"$/\1/p' | sort -u)"
    case "$(printf '%s\n' "$teams" | grep -c .)" in
      1) team="$teams" ;;
      0) fail "No Apple Distribution identity in the keychain; set IOS_TEAM_ID in ios/fastlane/.env" ;;
      *) fail "Several teams in the keychain ($(echo $teams)); set IOS_TEAM_ID in ios/fastlane/.env" ;;
    esac
  fi
  printf '%s\n' "$team"
}

# Fails naming every key of <file> that is missing or empty, e.g. ios/fastlane/.env.
# Usage: rn_require_keys <file> KEY...
rn_require_keys() {
  local file="$1" key missing=()
  shift
  for key in "$@"; do
    [ -n "${!key:-$(read_property "$file" "$key" "")}" ] || missing+=("$key")
  done
  [ "${#missing[@]}" = 0 ] || fail "Missing in ${file##*/ios/}: ${missing[*]} (see fastlane/.env.example)"
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
