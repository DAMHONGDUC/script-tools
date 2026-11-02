#!/usr/bin/env bash
# Flutter Android release build shared by build_apk.sh and build_aab.sh. Source this file after lib/common.sh.
#
# Installs the flavor's config first, the way release_ios.sh does: an APK built against whichever env/ and
# google-services.json the checkout last held is a build of the wrong environment with nothing to say so.

# shellcheck source=../../common/lib/release_output.sh
source "$FLUTTER_TOOLS_DIR/../common/lib/release_output.sh"

# Usage: build_flutter_android apk|aab <flavor> [flutter build args...]
build_flutter_android() {
  local format="$1" target="${2:-}" command artifact
  shift
  case "$format" in
    apk) command="apk"; artifact="build/app/outputs/flutter-apk/app-release.apk" ;;
    aab) command="appbundle"; artifact="build/app/outputs/bundle/release/app-release.aab" ;;
    *) fail "unknown format: $format (apk or aab)" ;;
  esac
  require_flavor "$target" "build_$format.sh <flavor> [flutter build $command args...]"
  shift

  # The config this flavor builds with, installed before anything reads it. A skip is announced, never silent.
  if [ -d env_assets ]; then
    bash "$FLUTTER_TOOLS_DIR/prepare_env.sh" "$target"
  else
    info "no env_assets/ — this app keeps no flavored config, nothing to install"
  fi

  # Same rule as build_ipa.sh: a template declares config, so a missing real file is an error.
  local env_file="env/$target.json" template
  template=$(env_template "$target")
  if [ -n "$template" ]; then
    [ -f "$env_file" ] || fail "$env_file is missing — run set_up.sh"
    set -- --dart-define-from-file="$env_file" "$@"
    info "config: $env_file (declared by $template)"
  else
    info "no env template — this app compiles its config in, no dart-defines"
  fi

  if has_firebase; then
    [ -f android/app/google-services.json ] || fail "android/app/google-services.json is missing — download it from the Firebase console"
  fi

  # Flutter's template signs release with the debug key; Play refuses such a file, so say it before the build.
  if grep -q 'signingConfigs.getByName("debug")' android/app/build.gradle* 2>/dev/null; then
    warn "release is signed with the debug key — fine to install, refused by Play; add a release signingConfig"
  fi

  # Version and build number come from pubspec.yaml, never a flag: a flag ships a number git never saw.
  local version app_name
  version=$(grep '^version:' pubspec.yaml | head -1 | cut -d' ' -f2)
  app_name="$(project_setting "$PROJECT_DIR" APP_NAME "$(basename "$PROJECT_DIR")")"

  step "build $format — $target $version"
  rm -f "$artifact"
  $FL build "$command" --release "$@"

  # Into Release/ like the Android scripts, one file per flavor and format: dev and prod never replace each other.
  local published
  published="$(publish_release_file "$PROJECT_DIR" "$artifact" "$target-$app_name-${version/+/-}" "$format" "$target-")"
  print_release_summary "$published"
  done_msg "built $target $version $format"
}
