#!/usr/bin/env bash
# Installs one flavor's real config from env_assets/ into every path the build, the backend and fastlane read.
# Overwrites: this is how a checkout switches environment.
# Usage: <script-tools>/flutter/prepare_env.sh <flavor>
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

SRC="env_assets"
TARGET="${1:-}"
require_flavor "$TARGET" "prepare_env.sh <flavor>"

# Gitignored, so a clone never has it.
[ -d "$SRC" ] || fail "$SRC/ is missing — restore your own copy"

# `<source under env_assets>|<destination>`, newline separated; no path here has a space.
# Every app keeps these three: the dart-defines, the fastlane credentials, the flavored Info.plist.
PAIRS="
$TARGET.json|env/$TARGET.json
fastlane.env|ios/fastlane/.env
$TARGET-Info.plist|ios/Runner/Info.plist
"

# Demanded only from an app that owns a Firebase backend.
if has_firebase; then
  PAIRS="$PAIRS$TARGET-google-services.json|android/app/google-services.json
$TARGET-GoogleService-Info.plist|ios/Runner/GoogleService-Info.plist
"
fi

# functions/ is where the Firebase CLI reads .env from.
HAS_FUNCTIONS=0
if [ -d functions ]; then
  HAS_FUNCTIONS=1
  PAIRS="$PAIRS$TARGET-function.env|functions/.env
"
fi

# All checked before anything is written.
MISSING=""
for pair in $PAIRS; do
  SRC_FILE="$SRC/${pair%%|*}"
  [ -f "$SRC_FILE" ] || MISSING="$MISSING $SRC_FILE"
done

if [ -n "$MISSING" ]; then
  warn "missing in $SRC/:"
  for f in $MISSING; do
    item "$f"
  done
  fail "nothing was copied"
fi

# Widest source first, so every destination starts in the same column.
WIDTH=0
for pair in $PAIRS; do
  SRC_FILE="$SRC/${pair%%|*}"
  if [ "${#SRC_FILE}" -gt "$WIDTH" ]; then
    WIDTH="${#SRC_FILE}"
  fi
done

step "config — $TARGET"
for pair in $PAIRS; do
  SRC_FILE="$SRC/${pair%%|*}"
  DST_FILE="${pair#*|}"
  mkdir -p "$(dirname "$DST_FILE")"
  cp "$SRC_FILE" "$DST_FILE"
  item "$(pad "$SRC_FILE" "$WIDTH") -> $DST_FILE"
done

done_msg "$TARGET config installed"

if [ "$HAS_FUNCTIONS" = 1 ]; then
  warn "functions/.env reaches the backend only on the next deploy"
fi
