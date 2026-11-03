#!/usr/bin/env bash
# Every submodule onto the head of its main branch, the project to the head of its current branch, fast-forward
# only. Never commits, never pushes.
# Usage: <script-tools>/common/pull_latest.sh   (from the project, or with PROJECT_ROOT set)
#
# A submodule's main branch is the one .gitmodules names, else main, else master; one on another branch, or
# detached, is checked out on it first. The project stays on its branch and pulls origin's branch of that name.
# Local changes the move would touch refuse that repo — the others still go — and the script fails at the end.
set -eu
lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "$lib/log.sh"
source "$lib/repos.sh"

root="$(cd "${PROJECT_ROOT:-$PWD}" && git rev-parse --show-toplevel 2>/dev/null)" || fail "not inside a git repository"
cd "$root"

# The submodules of the repo at $1 (a path from the root ending in /, "" for the project), one level, as
# "<path from the root>|<branch .gitmodules names>".
list_submodules() {
  local base="$1" key path name
  [ -f "$root/$base.gitmodules" ] || return 0
  git config -f "$root/$base.gitmodules" --get-regexp '^submodule\..*\.path$' | while read -r key path; do
    name="${key#submodule.}"
    name="${name%.path}"
    # Fresh clone: a submodule never initialised has no checkout to move yet. Only those: an update of the
    # others would detach them at the commit the parent records.
    [ -e "$root/$base$path/.git" ] || git -C "$root/$base" submodule update -q --init -- "$path" >&2
    printf '%s|%s\n' "$base$path" "$(git config -f "$root/$base.gitmodules" "submodule.$name.branch" || true)"
  done
}

# Pulls every submodule of the repo at $1, then theirs. Each repo's list is read after it moved, so a submodule
# the pull just added is pulled too. Fd 3, so no git command inside reads the list as its stdin.
pull_submodules() {
  local path branch rc
  while IFS='|' read -r -u 3 path branch; do
    [ -n "$path" ] || continue
    rc=0
    pull_repo "$path" "$branch" || rc=$?
    tally "$rc"
    pull_submodules "$path/"
  done 3<<<"$(list_submodules "$1")"
}

# The first of the given branches origin has, after the fetch.
origin_branch() {
  local branch
  for branch in "$@"; do
    [ -n "$branch" ] || continue
    if git rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null; then
      printf '%s\n' "$branch"
      return
    fi
  done
  return 1
}

# Staged, unstaged and untracked paths. Submodule pointers are left out: each submodule is a repo of its own here.
local_changes() {
  {
    git diff --name-only --ignore-submodules=all HEAD
    git ls-files --others --exclude-standard
  } | sed '/^$/d' | sort -u
}

# One repo up to the latest. $1 path from the root ("" for the project), $2 the branch .gitmodules names.
# A submodule goes onto its main branch first; the project stays on its current branch. Prints one row; exits
# 0 when nothing moved, 2 when it pulled, 1 when it refused.
pull_repo() (
  repo="${1:-$(basename "$root")}"
  cd "$root/${1:-.}"
  from="$(git rev-parse HEAD)"
  current="$(git symbolic-ref -q --short HEAD || true)"
  on="${current:-(detached)}"
  was=''
  if ! err="$(git fetch -q origin 2>&1)"; then
    bad "$(row "$repo" "$on" "$(short HEAD)" "cannot fetch origin: ${err##*$'\n'}")"
    exit 1
  fi

  if [ -z "$1" ]; then
    if [ -z "$current" ]; then
      bad "$(row "$repo" "$on" "$(short HEAD)" "detached — check out a branch first")"
      exit 1
    fi
    branch="$current"
    if ! git rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null; then
      ok "$(row "$repo" "$branch" "$(short HEAD)" "not on origin — nothing to pull")"
      exit 0
    fi
  elif ! branch="$(origin_branch "$2" main master)"; then
    bad "$(row "$repo" "$on" "$(short HEAD)" "origin has no ${2:+$2, }main or master")"
    exit 1
  fi
  target="$(git rev-parse "refs/remotes/origin/$branch")"

  if [ -n "$1" ] && [ "$current" != "$branch" ]; then
    # Switching: any local change refuses, and a detached commit goes only where the branch holds it, so
    # nothing is left behind. A commit on another branch stays on that branch.
    if [ -n "$(git diff --name-only --ignore-submodules=all HEAD)" ]; then
      bad "$(row "$repo" "$on" "$(short HEAD)" "local changes — commit or stash them before switching to $branch")"
      exit 1
    fi
    if [ -z "$current" ]; then
      held=0
      git merge-base --is-ancestor HEAD "$target" && held=1
      git rev-parse -q --verify "refs/heads/$branch" >/dev/null &&
        git merge-base --is-ancestor HEAD "refs/heads/$branch" && held=1
      if [ "$held" = 0 ]; then
        bad "$(row "$repo" "$on" "$(short HEAD)" "$branch does not hold this commit — put it on a branch first")"
        exit 1
      fi
    fi
    if git worktree list --porcelain | grep -qxF "branch refs/heads/$branch"; then
      bad "$(row "$repo" "$on" "$(short HEAD)" "$branch is checked out in another worktree — pull it there")"
      exit 1
    fi
    if git rev-parse -q --verify "refs/heads/$branch" >/dev/null; then
      checkout=(git checkout -q "$branch")
    else
      checkout=(git checkout -q -b "$branch" --track "origin/$branch")
    fi
    if ! err="$("${checkout[@]}" 2>&1)"; then
      bad "$(row "$repo" "$on" "$(short HEAD)" "cannot check out $branch: ${err##*$'\n'}")"
      exit 1
    fi
    was=", was on ${current:-detached $(short "$from")}"
    from="$(git rev-parse HEAD)"
  fi

  head="$(git rev-parse HEAD)"
  if [ "$head" = "$target" ] || git merge-base --is-ancestor "$target" "$head"; then
    ahead="$(git rev-list --count "$target..$head")"
    [ "$ahead" = 0 ] && ahead='' || ahead=", $ahead ahead of origin"
    ok "$(row "$repo" "$branch" "$(short "$head")" "up to date$ahead$was")"
    exit 0
  fi
  if ! git merge-base --is-ancestor "$head" "$target"; then
    bad "$(row "$repo" "$branch" "$(short "$head")" "diverged from origin — merge or rebase it by hand$was")"
    exit 1
  fi

  # The project refuses only on changes the pull would overwrite; a submodule on any change.
  if [ -n "$1" ]; then
    clash="$(git diff --name-only --ignore-submodules=all HEAD)"
  else
    clash="$(comm -12 <(local_changes) <(git diff --name-only "$head" "$target" | sort -u))"
  fi
  if [ -n "$clash" ]; then
    count="$(printf '%s\n' "$clash" | wc -l | tr -d ' ')"
    bad "$(row "$repo" "$branch" "$(short "$head")" \
      "$(plural "$count" "local change"), e.g. $(printf '%s\n' "$clash" | head -1) — commit or stash first")"
    exit 1
  fi
  if ! err="$(git merge -q --ff-only "$target" 2>&1)"; then
    bad "$(row "$repo" "$branch" "$(short "$head")" "cannot fast-forward: ${err##*$'\n'}")"
    exit 1
  fi
  ok "$(row "$repo" "$branch" "$(short "$from") → $(short "$target")" \
    "pulled $(plural "$(git rev-list --count "$from..$target")" commit)$was")"
  exit 2
)

table_widths

step "pull — submodules to their main branch, the project on its current branch"
table_header
rc=0
pull_repo "" "" || rc=$?
tally "$rc"
pull_submodules ""

table_footer "$moved pulled, $same up to date" "nothing was committed or pushed"
