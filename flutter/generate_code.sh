#!/usr/bin/env bash
# Regenerates localizations and build_runner output.
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

step "localizations"
$FL gen-l10n

if has_dep build_runner; then
  step "code generation"
  # build_runner 2.15 deletes conflicting outputs by default; passing the old flag warns on every run.
  $DT run build_runner build
else
  info "no build_runner in pubspec.yaml, nothing to generate"
fi
