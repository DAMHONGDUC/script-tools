#!/usr/bin/env bash
# Helpers for the scripts that walk the project and its submodules (pull_latest.sh, push_current.sh). Source this
# file from the project root, after log.sh.

short() { git rev-parse --short "$1"; }

# "1 commit", "2 commits". $1 the count, $2 the word.
plural() { [ "$1" = 1 ] && printf '1 %s' "$2" || printf '%s %ss' "$1" "$2"; }

# Both scripts print one table row per repo under a dim header, the mark in log.sh's gutter:
#
#   [10:22:36]:     REPO                     BRANCH   COMMIT             STATUS
#   [10:22:36]:   ✔ tuku-shop                feature  21ac69d            up to date
#   [10:22:38]:   ✔ packages/script-tools    main     299ceb2 → 4c1d0e2  pulled 2 commit(s), was on side

# Column widths, each the longest entry plus two: repo paths, branch names (the checked-out ones, the ones
# .gitmodules names, master), and two short ids with an arrow. Sets w_repo, w_branch and w_commit. A submodule
# a pull adds later may run past them.
table_widths() {
  local entry
  w_repo=$(($(basename "$PWD" | wc -c) + 1))
  w_branch=8
  while read -r entry; do
    [ "${#entry}" -lt $((w_repo - 1)) ] || w_repo=$((${#entry} + 2))
  done < <(
    git submodule foreach --quiet --recursive 'echo "$displaypath"'
    git config -f .gitmodules --get-regexp '\.path$' 2>/dev/null | cut -d' ' -f2-
  )
  while read -r entry; do
    [ "${#entry}" -lt $((w_branch - 1)) ] || w_branch=$((${#entry} + 2))
  done < <(
    git symbolic-ref -q --short HEAD || echo '(detached)'
    git submodule foreach --quiet --recursive 'git symbolic-ref -q --short HEAD || echo "(detached)"'
    git config -f .gitmodules --get-regexp '\.branch$' 2>/dev/null | cut -d' ' -f2-
  )
  entry="$(short HEAD)"
  w_commit=$((${#entry} * 2 + 5))
}

# One row: repo, branch, commit, status. Goes inside ok/bad, which add the mark.
row() { printf '%s%s%s%s' "$(pad "$1" "$w_repo")" "$(pad "$2" "$w_branch")" "$(pad "$3" "$w_commit")" "$4"; }

table_header() { _line '   ' '' "$C_DIM$(row REPO BRANCH COMMIT STATUS)$C_OFF"; }

# The closing count, its mark in the rows' gutter so it reads as the table's last line. $1 the count, $2 the
# note after it. Exits 1 when a repo was refused.
table_footer() {
  if [ "$refused" = 0 ]; then
    _line '  ✔' "$C_OK" "$1; $2"
  else
    _line '  ✘' "$C_BAD" "$1, $refused refused — see ✘ above; $2" >&2
    exit 1
  fi
}

# Counts one repo's outcome from its exit status: 0 unchanged, 2 moved, anything else refused.
same=0 moved=0 refused=0
tally() {
  case "$1" in
    0) same=$((same + 1)) ;;
    2) moved=$((moved + 1)) ;;
    *) refused=$((refused + 1)) ;;
  esac
}
