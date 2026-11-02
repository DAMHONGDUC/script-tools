#!/usr/bin/env bash
# Shared by every flutter/ script: finds the project, moves into it, resolves the SDK. Source this file.

FLUTTER_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../../common/lib/project.sh
source "$FLUTTER_TOOLS_DIR/../common/lib/project.sh"
# shellcheck source=../../common/lib/log.sh
source "$FLUTTER_TOOLS_DIR/../common/lib/log.sh"
# shellcheck source=../../common/lib/ruby.sh
source "$FLUTTER_TOOLS_DIR/../common/lib/ruby.sh"

# Every path the scripts touch — ios/, functions/, env_assets/, pubspec.yaml — is relative to the app, so move there once.
PROJECT_DIR="$(find_project_root pubspec.yaml)"
cd "$PROJECT_DIR"

# `flutter` is a shell alias for `fvm flutter` on a dev machine, and aliases do not exist inside a script.
if [ -f .fvmrc ] && command -v fvm >/dev/null 2>&1; then
  FL="fvm flutter"
  DT="fvm dart"
else
  FL="flutter"
  DT="dart"
fi

# The flavors every flavored script accepts: FLAVORS in script-tools.properties, default "dev prod".
FLAVORS="$(project_setting "$PROJECT_DIR" FLAVORS "dev prod")"

# Fails with the usage line unless $1 is one of FLAVORS.
# Usage: require_flavor <flavor> "<usage line>"
require_flavor() {
  in_list "$1" "$FLAVORS" && return 0
  fail "usage: $2   (flavor: ${FLAVORS// /, })"
}

# True when the app owns a Firebase backend: `.firebaserc` holds the CLI's project aliases.
has_firebase() { [ -f .firebaserc ]; }

# The checked-in template that declares dart-define config for flavor $1, or nothing.
# `env/<flavor>.example.json` when flavors list different keys, `env/env.example.json` when they share them.
# An app with neither compiles its config in and never gets --dart-define-from-file.
env_template() {
  if [ -f "env/$1.example.json" ]; then
    printf '%s' "env/$1.example.json"
  elif [ -f "env/env.example.json" ]; then
    printf '%s' "env/env.example.json"
  fi
}

# True when pubspec.yaml declares package $1 in any section.
has_dep() { grep -q "^[[:space:]]*$1:" pubspec.yaml; }

# True when $1/package.json defines npm script $2. Missing prints `{}` on npm 10, `undefined` before.
has_npm_script() {
  case "$(cd "$1" && npm pkg get "scripts.$2" 2>/dev/null)" in
    '{}' | undefined | '') return 1 ;;
  esac
  return 0
}


# Runs flutter/dart/bin/<name>.dart, resolving that package the first time.
# `--verbosity=error`: Dart prints "Running build hooks..." to stderr, which task runners label as errors.
# Usage: run_dart_tool <name> [args...]
run_dart_tool() {
  local package="$FLUTTER_TOOLS_DIR/dart" name="$1"
  shift
  if [ ! -f "$package/.dart_tool/package_config.json" ]; then
    (cd "$package" && $DT pub get >/dev/null)
  fi
  $DT run --verbosity=error "$package/bin/$name.dart" "$@"
}

# Installs flavor $1's real config from env_assets/ — the first step of every command that builds or deploys
# (owner's rule), so nothing runs against whichever config the checkout last held. An app with no env_assets/
# keeps no flavored config, and says so rather than skipping silently.
# Usage: install_flavor_config <flavor>
install_flavor_config() {
  if [ -d env_assets ]; then
    bash "$FLUTTER_TOOLS_DIR/prepare_env.sh" "$1"
  else
    info "no env_assets/ — this app keeps no flavored config, nothing to install"
  fi
}
