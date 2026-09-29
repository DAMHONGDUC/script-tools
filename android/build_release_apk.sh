#!/usr/bin/env bash
# Builds the signed release APK of the Android project you run it from and puts it in <project>/Release/.
# Usage: <submodule path>/android/build_release_apk.sh  (FLAVOR=<flavor> to pick a flavor; see README.md)
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/release.sh"
build_android_release apk
