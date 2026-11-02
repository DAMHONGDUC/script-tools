#!/usr/bin/env bash
# Flutter Android release build, used by release_android.sh. Source this file after lib/common.sh.
#
# It builds only: the caller installs the flavor's config first (install_flavor_config), once for both formats.

# shellcheck source=../../common/lib/release_output.sh
source "$FLUTTER_TOOLS_DIR/../common/lib/release_output.sh"

# Usage: build_flutter_android apk|aab <flavor> [flutter build args...]
build_flutter_android() {
  local format="$1" target="$2" command artifact
  shift 2
  case "$format" in
    apk) command="apk"; artifact="build/app/outputs/flutter-apk/app-release.apk" ;;
    aab) command="appbundle"; artifact="build/app/outputs/bundle/release/app-release.aab" ;;
    *) fail "unknown format: $format (apk or aab)" ;;
  esac

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

  rm -f "$artifact"
  $FL build "$command" --release "$@"

  # Into Release/ like the Android scripts, one file per flavor and format: dev and prod never replace each other.
  local published
  published="$(publish_release_file "$PROJECT_DIR" "$artifact" "$target-$app_name-${version/+/-}" "$format" "$target-")"
  print_release_summary "$published"
}
