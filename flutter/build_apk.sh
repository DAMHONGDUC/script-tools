#!/usr/bin/env bash
# Builds the flavor's release APK into <project>/Release/, after installing the flavor's config.
# Usage: <script-tools>/flutter/build_apk.sh <flavor> [flutter build args...]
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
source "$FLUTTER_TOOLS_DIR/lib/android_build.sh"
build_flutter_android apk "$@"
