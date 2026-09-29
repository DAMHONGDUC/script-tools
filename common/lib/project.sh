#!/usr/bin/env bash
# Platform-independent helpers for locating a project and reading its settings. Source this file.

# Prints the project root: $PROJECT_ROOT, else the nearest directory at or above $PWD holding one of the marker files.
# Usage: find_project_root settings.gradle.kts settings.gradle
find_project_root() {
  if [ -n "${PROJECT_ROOT:-}" ]; then
    (cd "$PROJECT_ROOT" && pwd)
    return
  fi
  local dir="$PWD" marker
  while [ "$dir" != "/" ]; do
    for marker in "$@"; do
      if [ -e "$dir/$marker" ]; then
        printf '%s\n' "$dir"
        return
      fi
    done
    dir="$(dirname "$dir")"
  done
  echo "No project found above $PWD (looked for: $*); run from the project or set PROJECT_ROOT." >&2
  exit 1
}

# Prints one key from a .properties file without evaluating it as shell code, or the fallback when unset.
# Usage: read_property <file> <key> [fallback]
read_property() {
  local file="$1" key="$2" fallback="${3:-}" value=""
  if [ -f "$file" ]; then
    value="$(grep -E "^[[:space:]]*$key[[:space:]]*=" "$file" | tail -1 | sed -E "s/^[^=]*=[[:space:]]*//; s/[[:space:]]+$//" || true)"
  fi
  printf '%s\n' "${value:-$fallback}"
}

# Prints a setting from <project>/script-tools.properties, the per-project config every script reads.
# Usage: project_setting <project root> <key> [fallback]
project_setting() {
  read_property "$1/script-tools.properties" "$2" "${3:-}"
}

capitalize() {
  printf '%s%s\n' "$(printf '%s' "${1:0:1}" | tr '[:lower:]' '[:upper:]')" "${1:1}"
}
