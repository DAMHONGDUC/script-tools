#!/usr/bin/env bash
# Erases the image generator's watermark from the app icon artwork, in place.
# Its own command, not a step of generate_app_icon.sh: it runs once per new artwork, the icons many times after.
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

SOURCE=${APP_ICON_SOURCE:-assets/images/app_icon.png}
[ -f "$SOURCE" ] || fail "no $SOURCE — the 1024x1024 artwork goes there"

step "strip marker"
# Via a temp beside the original: writing over its own input is how a half-written file becomes the only copy.
run_dart_tool strip_icon_marker "$SOURCE" "$SOURCE.tmp"
mv "$SOURCE.tmp" "$SOURCE"

info "check the corner at full size, then regenerate the icons"
done_msg "marker stripped from $SOURCE"
