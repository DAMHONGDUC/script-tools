#!/usr/bin/env bash
# Uploads the IPA already in build/ios/ipa, without rebuilding — for a release that built and then failed to upload.
# Usage: <script-tools>/flutter/upload_ipa.sh <flavor>
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

TARGET="${1:-}"
require_flavor "$TARGET" "upload_ipa.sh <flavor>"

IPA_DIR="build/ios/ipa"
# Named before fastlane spends a minute on App Store Connect to say the same thing.
ls "$IPA_DIR"/*.ipa >/dev/null 2>&1 || fail "no .ipa in $IPA_DIR — run release_ios.sh $TARGET"

command -v bundle >/dev/null 2>&1 || fail "bundler not found — cd ios && bundle install"

ensure_utf8_locale

step "upload $TARGET"
for ipa in "$IPA_DIR"/*.ipa; do
  item "$ipa"
done
# No notes: the lane composes "<flavor> - <version> (<build>)" itself.
(cd ios && bundle exec fastlane upload flavor:"$TARGET")

done_msg "uploaded $TARGET to TestFlight"
