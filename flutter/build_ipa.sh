#!/usr/bin/env bash
# Builds an iOS release archive for one flavor, with its dart-define config attached.
# Usage: <script-tools>/flutter/build_ipa.sh <flavor> [flutter build ipa args...]
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

TARGET="${1:-}"
require_flavor "$TARGET" "build_ipa.sh <flavor> [flutter build ipa args...]"
shift
ENV_FILE="env/$TARGET.json"

# Every flavor goes to TestFlight, and app-store is the only method App Store Connect accepts.
EXPORT_METHOD="app-store"

# `--export-method` makes Flutter generate the ExportOptions.plist itself, and that generator maps the MAIN bundle
# id only — so a caller with extensions passes its own plist, and then the method is not added.
EXPORT_PLIST_GIVEN=0
for arg in "$@"; do
  case "$arg" in
    --export-options-plist | --export-options-plist=*) EXPORT_PLIST_GIVEN=1 ;;
  esac
done

if [ "$EXPORT_PLIST_GIVEN" -eq 0 ]; then
  set -- --export-method "$EXPORT_METHOD" "$@"
fi

# The template declares that the app HAS dart-define config, so a missing real file is an error; an app with no
# template compiles its config in and never gets --dart-define-from-file. Dropping the flag by mistake ships an IPA
# whose Firebase config is empty, which crashes on the first FirebaseAuth.instance naming nothing useful.
TEMPLATE=$(env_template "$TARGET")
if [ -n "$TEMPLATE" ]; then
  # Existence only — never the contents.
  [ -f "$ENV_FILE" ] || fail "$ENV_FILE is missing — run set_up.sh"
  set -- --dart-define-from-file="$ENV_FILE" "$@"
  info "config: $ENV_FILE (declared by $TEMPLATE)"
else
  info "no env template — this app compiles its config in, no dart-defines"
fi

# Gitignored, and a build input of the Runner target rather than a runtime lookup. On CI it is written from a secret.
GSP="ios/Runner/GoogleService-Info.plist"
if has_firebase; then
  [ -f "$GSP" ] || fail "$GSP is missing — download it from the Firebase console"
fi

# `flutter build ipa` re-resolves the Swift package graph against github on every archive and drops that step's
# output, so an unreachable github surfaces ~40 s in with the reason cut off. Resolving here first keeps the reason
# and leaves flutter nothing to fetch. Four attempts: a filtered network times out on some connects, not all.
SPM_PINS="ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [ -f "$SPM_PINS" ]; then
  # The same directory flutter hands the archive as -clonedSourcePackagesDirPath.
  SPM_CLONE_DIR="$PWD/build/ios/SourcePackages"
  SPM_LOG=$(mktemp)
  SPM_OK=0

  # No -workspace and no -scheme, exactly as flutter runs it: a scheme would resolve a different graph.
  for _ in 1 2 3 4; do
    if (cd ios && xcrun xcodebuild -resolvePackageDependencies -clonedSourcePackagesDirPath "$SPM_CLONE_DIR") \
      >"$SPM_LOG" 2>&1; then
      SPM_OK=1
      break
    fi
  done

  if [ "$SPM_OK" -eq 0 ]; then
    grep -E 'fatal:|error:|Couldn' "$SPM_LOG" | while IFS= read -r spm_line; do
      item "$spm_line"
    done
    rm -f "$SPM_LOG"
    fail "swift package resolution failed four times, and every remote package comes from github.com. Connect to a VPN and run this again."
  fi

  rm -f "$SPM_LOG"
  info "swift packages: resolved into $SPM_CLONE_DIR"
fi

# Every flavor writes the same folder under the same filename, so a stale IPA would pass for this build's.
IPA_DIR="build/ios/ipa"
rm -rf "$IPA_DIR"

# Version and build number are edited in pubspec.yaml, never passed as a flag: a flag ships a number git never saw.
VERSION=$(grep '^version:' pubspec.yaml | head -1 | cut -d' ' -f2)

step "build ipa — $TARGET $VERSION"
$FL build ipa --release "$@"

done_msg "built $TARGET $VERSION into $IPA_DIR"
warn "bump version: in pubspec.yaml before the next build — App Store Connect refuses a number it has seen"
