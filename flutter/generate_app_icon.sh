#!/usr/bin/env bash
# One source PNG to every icon the app ships: launcher sizes plus rounded launch screen copies for iOS and Android.
# Reads $APP_ICON_SOURCE, default assets/images/app_icon.png, and nothing else — no generated copy sits in between.
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

SOURCE=${APP_ICON_SOURCE:-assets/images/app_icon.png}
LAUNCH_DIR=ios/Runner/Assets.xcassets/LaunchImage.imageset
ANDROID_RES_DIR=android/app/src/main/res
IOS_PROJECT=ios/Runner.xcodeproj/project.pbxproj

# Checked first: both steps read it, so a missing original fails before half a launcher set is written.
[ -f "$SOURCE" ] || fail "no $SOURCE — the 1024x1024 artwork goes there"

# $1 = pixel size, $2 = file name. The launch storyboard's image view cannot clip, so the corners are baked in.
launch_icon() {
  run_dart_tool round_icon_corners "$SOURCE" "$LAUNCH_DIR/$2" "$1"
}

# $1 = density, $2 = pixel size. A transparent rounded tile works on legacy Android and inside Android 12's splash mask.
android_launch_icon() {
  local dir="$ANDROID_RES_DIR/drawable-$1"
  mkdir -p "$dir"
  run_dart_tool round_icon_corners "$SOURCE" "$dir/launch_image.png" "$2"
}

step "launcher icons"
# Config is the `flutter_launcher_icons:` block in pubspec.yaml.
$DT run flutter_launcher_icons

# flutter_launcher_icons 0.14.4 rewrites every ASSETCATALOG setting after it sees an xcconfig line; only APPICON_NAME should change.
if [ -f "$IOS_PROJECT" ]; then
  sed 's/ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon;/ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;/' \
    "$IOS_PROJECT" >"$IOS_PROJECT.tmp"
  mv "$IOS_PROJECT.tmp" "$IOS_PROJECT"
fi

step "launch screen"
launch_icon 112 LaunchImage.png
launch_icon 224 'LaunchImage@2x.png'
launch_icon 336 'LaunchImage@3x.png'
android_launch_icon mdpi 112
android_launch_icon hdpi 168
android_launch_icon xhdpi 224
android_launch_icon xxhdpi 336
android_launch_icon xxxhdpi 448

done_msg "icons regenerated from $SOURCE"
