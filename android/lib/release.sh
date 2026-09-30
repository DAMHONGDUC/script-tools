#!/usr/bin/env bash
# Gradle release build shared by build_release_apk.sh and build_release_aab.sh. Source this file.
#
# Clears every build output, runs unit tests, builds the signed release, and replaces the previous file of the
# same flavor and format in <project>/Release/. Settings come from <project>/script-tools.properties (see README.md).
set -euo pipefail

android_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../common/lib/project.sh
source "$android_lib_dir/../../common/lib/project.sh"
# shellcheck source=../../common/lib/space_free_copy.sh
source "$android_lib_dir/../../common/lib/space_free_copy.sh"
# shellcheck source=../../common/lib/release_output.sh
source "$android_lib_dir/../../common/lib/release_output.sh"

# Deletes every module build/ folder and every .cxx native cache, so stale paths cannot break gradle clean.
clear_gradle_outputs() {
  local root="$1" gradle_file
  rm -rf "$root/build"
  while IFS= read -r gradle_file; do
    rm -rf "$(dirname "$gradle_file")/build"
  done < <(find "$root" -path "$root/.git" -prune -o \( -name build.gradle -o -name build.gradle.kts \) -print)
  find "$root" -path "$root/.git" -prune -o -type d -name .cxx -prune -exec rm -rf {} +
}

# Usage: build_android_release apk|aab
build_android_release() {
  local format="$1"
  case "$format" in
    apk|aab) ;;
    *) echo "Unknown format: $format (apk or aab)" >&2; exit 1 ;;
  esac

  local root
  root="$(find_project_root settings.gradle.kts settings.gradle)"
  rerun_from_space_free_copy "$root" "$0"

  local app_name app_module flavors default_flavor test_tasks version_file key_properties
  app_name="$(project_setting "$root" APP_NAME "$(basename "$root")")"
  flavors="$(project_setting "$root" FLAVORS)"
  default_flavor="$(project_setting "$root" DEFAULT_FLAVOR "${flavors%% *}")"
  version_file="$root/$(project_setting "$root" VERSION_FILE env/version.properties)"
  app_module="$(project_setting "$root" ANDROID_APP_MODULE app)"
  test_tasks="$(project_setting "$root" ANDROID_TEST_TASKS ":$app_module:test{Flavor}DebugUnitTest")"
  key_properties="$root/$(project_setting "$root" ANDROID_KEY_PROPERTIES env/key.properties)"

  local flavor="" flavor_title="" variant_dir="release" bundle_dir="release" file_suffix="release"
  if [ -n "$flavors" ]; then
    flavor="${FLAVOR:-$default_flavor}"
    case " $flavors " in
      *" $flavor "*) ;;
      *) echo "Unknown flavor: $flavor (FLAVOR must be one of: $flavors)" >&2; exit 1 ;;
    esac
    flavor_title="$(capitalize "$flavor")"
    variant_dir="$flavor/release"
    bundle_dir="${flavor}Release"
    file_suffix="$flavor-release"
  elif [ -n "${FLAVOR:-}" ]; then
    echo "FLAVOR is set but script-tools.properties lists no FLAVORS" >&2
    exit 1
  fi

  if [ -z "${JAVA_HOME:-}" ] && [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  fi

  cd "$root"

  echo "==> 1/4 Clearing build outputs"
  ./gradlew --stop >/dev/null 2>&1 || true
  clear_gradle_outputs "$root"
  ./gradlew clean

  echo "==> 2/4 Running unit tests"
  # shellcheck disable=SC2086 # ANDROID_TEST_TASKS is a space-separated task list.
  ./gradlew --no-build-cache ${test_tasks//\{Flavor\}/$flavor_title}

  echo "==> 3/4 Building ${flavor}Release $format"
  local outputs="$root/$app_module/build/outputs" artifact
  if [ "$format" = "apk" ]; then
    ./gradlew --no-build-cache ":$app_module:assemble${flavor_title}Release"
    artifact="$outputs/apk/$variant_dir/$app_module-$file_suffix.apk"
    [ -f "$artifact" ] || artifact="$outputs/apk/$variant_dir/$app_module-$file_suffix-unsigned.apk"
  else
    ./gradlew --no-build-cache ":$app_module:bundle${flavor_title}Release"
    artifact="$outputs/bundle/$bundle_dir/$app_module-$file_suffix.aab"
  fi

  local version_name version_code result
  version_name="$(read_property "$version_file" versionName)"
  version_code="$(read_property "$version_file" versionCode)"
  # The flavor leads the name so each flavor keeps its own latest file.
  result="$(publish_release_file "$root" "$artifact" \
    "${flavor:+$flavor-}${app_name}${version_name:+-$version_name}${version_code:+-$version_code}" "$format" \
    "${flavor:+$flavor-}")"

  echo "==> 4/4 Verifying signature"
  if [ ! -f "$key_properties" ]; then
    echo "WARNING: $key_properties not found; the $format is UNSIGNED and cannot be installed or uploaded yet." >&2
  elif [ "$format" = "apk" ]; then
    local sdk build_tools
    sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
    build_tools="$(ls -d "$sdk"/build-tools/* | sort -V | tail -1)"
    "$build_tools/apksigner" verify "$result"
    echo "Signed with the release key from $key_properties"
  else
    # jarsigner exits 0 for an unsigned bundle too, so require its success message.
    "${JAVA_HOME:+$JAVA_HOME/bin/}jarsigner" -verify "$result" | grep -q "jar verified"
    echo "Signed with the release key from $key_properties"
  fi

  print_release_summary "$result"
}
