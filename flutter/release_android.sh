#!/usr/bin/env bash
# One flavor's Android release: install its config, then the release APK and AAB into <project>/Release/.
# Usage: <script-tools>/flutter/release_android.sh <flavor> [flutter build args...]
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
source "$FLUTTER_TOOLS_DIR/lib/android_build.sh"

TARGET="${1:-}"
require_flavor "$TARGET" "release_android.sh <flavor> [flutter build args...]"
shift

step "release $TARGET — 1/3 config"
install_flavor_config "$TARGET"

step "release $TARGET — 2/3 apk"
build_flutter_android apk "$TARGET" "$@"

step "release $TARGET — 3/3 aab"
build_flutter_android aab "$TARGET" "$@"

done_msg "released $TARGET for Android — upload Release/ in Play Console"
