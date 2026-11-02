#!/usr/bin/env bash
# Deletes the app's build outputs and nothing else — no pub get, no codegen. set_up.sh is the full reset.
# Usage: <script-tools>/flutter/clean_build.sh
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

step "clean"
$FL clean
done_msg "build outputs deleted"
