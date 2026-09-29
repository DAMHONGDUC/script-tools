#!/usr/bin/env bash
# Analyzes the project and every package under it. Infos fail the run too — the CI gate.
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

step "analyze"
$FL analyze --fatal-infos "$@"
