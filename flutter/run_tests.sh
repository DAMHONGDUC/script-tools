#!/usr/bin/env bash
# Runs flutter test; arguments pass through, so a path runs just that file or folder.
# Usage: <script-tools>/flutter/run_tests.sh [test/features/x/y_test.dart ...]
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

step "test ${*:-(whole suite)}"
$FL test "$@"
