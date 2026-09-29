#!/usr/bin/env bash
# Native toolchains such as ndk-build cannot handle spaces in paths. Source this file.

# When the project path has a space, re-runs the calling script against a temporary space-free copy of the
# project, then exits with that run's status; otherwise returns and the caller continues in place.
# The copy sees PROJECT_ROOT (the copy) and RELEASE_OUTPUT_DIR (<original project>/Release), and is deleted
# afterwards because it holds the project's local secrets.
# Usage: rerun_from_space_free_copy <project root> "$0"
rerun_from_space_free_copy() {
  local root="$1" entry_script="$2" copy status
  [[ "$root" == *" "* ]] || return 0

  copy="$(mktemp -d)"
  if [[ "$copy" == *" "* ]]; then
    echo "The temporary directory $copy has a space too; set TMPDIR to a path without spaces." >&2
    exit 1
  fi
  trap 'rm -rf "$copy"' EXIT
  echo "==> Project path has a space; building from copy $copy"
  rsync -a --exclude .git --exclude build --exclude .gradle --exclude .cxx --exclude .kotlin \
    --exclude .dart_tool --exclude Pods --exclude DerivedData --exclude Release "$root/" "$copy/"

  # A separate process keeps set -e in force; a function call under || would disable it.
  set +e
  PROJECT_ROOT="$copy" RELEASE_OUTPUT_DIR="$root/Release" bash "$entry_script"
  status=$?
  set -e
  [ ! -x "$copy/gradlew" ] || "$copy/gradlew" -p "$copy" --stop >/dev/null 2>&1 || true
  exit "$status"
}
