#!/usr/bin/env bash
# Helpers for the scripts that walk the project and its submodules (pull_latest.sh, push_current.sh). Source this
# file from the project root, after log.sh.

short() { git rev-parse --short "$1"; }

# The width of the label column: the project's folder name or the longest submodule path, plus one. A submodule
# a pull adds later may run past it.
label_width() {
  local width path
  width=$(($(basename "$PWD" | wc -c)))
  while read -r path; do
    [ "${#path}" -ge "$width" ] && width=$((${#path} + 1))
  done < <(
    git submodule foreach --quiet --recursive 'echo "$displaypath"'
    git config -f .gitmodules --get-regexp '\.path$' 2>/dev/null | cut -d' ' -f2-
  )
  printf '%s\n' "$width"
}
