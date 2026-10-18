#!/usr/bin/env bash
# Builds a signed App Store IPA, uploads it to TestFlight and copies it into <project>/Release/.
# Usage: <submodule path>/react_native/release_ios.sh <env> [note]   (NOTE="..." works too)
#
# fastlane does the build and upload through react_native/fastlane/Fastfile, which the project's
# ios/fastlane/Fastfile imports. Signing and upload read the team id and an App Store Connect API key
# from ios/fastlane/.env, which stays out of git.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
# shellcheck source=../common/lib/release_output.sh
source "$rn_lib_dir/../../common/lib/release_output.sh"

root="$(rn_project_root)"
env="${1:-}"
note="${2:-${NOTE:-}}"
envs="$(project_setting "$root" FLAVORS dev)"
case " $envs " in
  *" $env "*) ;;
  *) fail "Unknown environment: '${env}' (one of: $envs)" ;;
esac

step "release iOS — $env"
[ "$(uname)" = Darwin ] || fail "iOS builds need macOS"
[ -f "$root/ios/fastlane/Fastfile" ] || fail "ios/fastlane/Fastfile is missing; see react_native in the script-tools README"
[ -f "$root/ios/fastlane/.env" ] || fail "ios/fastlane/.env is missing; copy ios/fastlane/.env.example and fill it in"
[ -d "$root/ios/Pods" ] || fail "ios/Pods is missing; run make set-up"

workspace="$(rn_ios_workspace "$root")"
name="$(basename "$workspace" .xcworkspace)"
scheme="$(project_setting "$root" IOS_SCHEME "$name")"
app_identifier="$(rn_ios_app_identifier "$root")"
output_dir="$root/ios/build/release"
info "$app_identifier · ${workspace} · scheme $scheme"

if [ -n "$(git -C "$root" status --porcelain --untracked-files=no)" ]; then
  warn "uncommitted changes go into this build"
fi

rm -rf "$output_dir"
# CocoaPods and fastlane both fail on a non-UTF-8 locale.
(cd "$root/ios" && LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
  RN_WORKSPACE="$(basename "$workspace")" RN_SCHEME="$scheme" RN_APP_IDENTIFIER="$app_identifier" \
  RN_OUTPUT_DIR="$output_dir" RELEASE_ENV="$env" RELEASE_NOTES="$note" \
  bundle exec fastlane ios beta)

version="$(cat "$output_dir/version.txt")"
app_name="$(project_setting "$root" APP_NAME "$(basename "$root")")"
published="$(publish_release_file "$root" "$output_dir/$scheme.ipa" "$env-$app_name-$version" ipa "$env-$app_name-")"
print_release_summary "$published"

done_msg "$env $version is on TestFlight"
