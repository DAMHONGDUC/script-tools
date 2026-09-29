#!/usr/bin/env bash
# Everything a fresh clone needs, in order: wipe build outputs, submodules, dependencies, codegen, env templates.
# Usage: <script-tools>/flutter/set_up.sh [--deep]   (--deep also deletes this project's Xcode DerivedData)
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

DEEP=0
case "${1:-}" in
  --deep) DEEP=1 ;;
  '') ;;
  *) fail "usage: set_up.sh [--deep]" ;;
esac

step "clean"
$FL clean

step "android"
if [ -x android/gradlew ]; then
  (cd android && ./gradlew clean) || warn "gradlew clean failed, continuing"
fi
rm -rf android/.gradle android/build android/app/build

step "ios"
rm -rf ios/.symlinks ios/Flutter/ephemeral

# Only for a build failure the code cannot explain: it costs a full cold build afterwards.
if [ "$DEEP" = 1 ] && [ "$(uname)" = "Darwin" ] && command -v plutil >/dev/null 2>&1; then
  step "xcode deriveddata"
  DERIVED="$HOME/Library/Developer/Xcode/DerivedData"
  if [ -d "$DERIVED" ]; then
    # Matched on the workspace path each cache records, never on the folder name.
    for dir in "$DERIVED"/*/; do
      [ -f "$dir/info.plist" ] || continue
      workspace=$(plutil -extract WorkspacePath raw -o - "$dir/info.plist" 2>/dev/null) || continue
      case "$workspace" in
        "$PROJECT_DIR"/*)
          rm -rf "$dir"
          item "removed $(basename "$dir")"
          ;;
      esac
    done
  fi
fi

# Submodules land on their branch and follow it, rather than sitting detached at the commit the gitlink records.
if [ -f .gitmodules ]; then
  step "submodules"
  git submodule update --init --recursive
  git submodule foreach --quiet --recursive '
    # foreach runs this in a shell of its own where the log helpers do not exist, only the exported colours.
    entry() { printf "%s[%s]:%s %s  ·%s %s\n" "$C_TIME" "$(date +%H:%M:%S)" "$C_OFF" "$C_DIM" "$C_OFF" "$1"; }
    branch=$(git config -f "$toplevel/.gitmodules" "submodule.$name.branch" || echo main)
    if ! git checkout -q "$branch" 2>/dev/null; then
      entry "$name: cannot switch to $branch, left as is"
    elif ! git pull -q --ff-only origin "$branch" 2>/dev/null; then
      entry "$name: on $branch, not fast-forwardable — pull it by hand"
    else
      entry "$name -> $branch"
    fi
  '
fi

step "dependencies"
$FL pub get
# Local packages carry their own tests and analysis, so each resolves on its own too.
for pubspec in packages/*/pubspec.yaml; do
  [ -f "$pubspec" ] || continue
  package="$(dirname "$pubspec")"
  (cd "$package" && $FL pub get)
done
(cd "$FLUTTER_TOOLS_DIR/dart" && $DT pub get >/dev/null)

step "localizations"
$FL gen-l10n

if has_dep build_runner; then
  step "code generation"
  # build_runner 2.15 deletes conflicting outputs by default; passing the old flag warns on every run.
  $DT run build_runner build
else
  info "no build_runner in pubspec.yaml, nothing to generate"
fi

# env/*.json is gitignored (live keys), so a fresh clone has none. Lay down the key-only templates and say so.
step "env config"
MISSING=""
for flavor in $FLAVORS; do
  TEMPLATE=$(env_template "$flavor")
  if [ -z "$TEMPLATE" ]; then
    info "no template for $flavor — this app compiles its config in, nothing to lay down"
  elif [ ! -f "env/$flavor.json" ]; then
    cp "$TEMPLATE" "env/$flavor.json"
    MISSING="$MISSING env/$flavor.json"
  fi
done

# The Firebase CLI reads this at deploy and cannot prompt for it when piped.
if [ -f functions/.env.example ] && [ ! -f functions/.env ]; then
  cp functions/.env.example functions/.env
  MISSING="$MISSING functions/.env"
fi

if [ -d functions ] && command -v npm >/dev/null 2>&1; then
  step "cloud functions"
  (cd functions && npm ci --silent)
fi

# iOS resolves every plugin as a Swift Package on the first build — there is no install step here.

if [ -n "$MISSING" ]; then
  printf '\n'
  warn "created from templates:"
  for f in $MISSING; do
    item "$f"
  done
  warn "fill in the real keys before running"
fi
