#!/usr/bin/env bash
# The project and every submodule to the head of its main branch, fast-forward only. Never commits, never pushes.
# Usage: <script-tools>/common/pull_latest.sh   (from the project, or with PROJECT_ROOT set)
#
# Main branch: the project's is origin's main, else master; a submodule's is the branch .gitmodules names, else
# main, else master. A checkout on it moves; one on another branch stays put and only the local main ref moves;
# a detached submodule is put on its branch first. Local changes the move would touch refuse that repo — the
# others still go — and the script fails at the end.
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
  local path branch
  while IFS='|' read -r -u 3 path branch; do
    [ -n "$path" ] || continue
    pull_repo "$path" "$branch" || refused=$((refused + 1))
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

# Moves the local main ref of a checkout on another branch, without switching. $1 label, $2 branch, $3 target sha.
move_ref_only() {
  local label="$1" branch="$2" target="$3" on lhead ahead
  on="$(git symbolic-ref -q --short HEAD || printf 'detached at %s' "$(short HEAD)")"
  if ! lhead="$(git rev-parse -q --verify "refs/heads/$branch")"; then
    git branch -q --track "$branch" "origin/$branch"
    info "$label on $on; local $branch created at $(short "$target"), not switched"
  elif git worktree list --porcelain | grep -qxF "branch refs/heads/$branch"; then
    bad "$label on $on; $branch is checked out in another worktree — pull it there"
    return 1
  elif [ "$lhead" = "$target" ]; then
    info "$label on $on; $branch $(short "$target"), already the latest"
  elif git merge-base --is-ancestor "$target" "$lhead"; then
    ahead="$(git rev-list --count "$target..$lhead")"
    info "$label on $on; $branch $(short "$lhead"), $ahead ahead of origin — nothing to pull"
  elif git merge-base --is-ancestor "$lhead" "$target"; then
    git update-ref -m "pull_latest: fast-forward" "refs/heads/$branch" "$target" "$lhead"
    info "$label on $on; $branch $(short "$lhead") → $(short "$target"), not switched"
  else
    bad "$label local $branch and origin/$branch have diverged — merge or rebase it by hand"
    return 1
  fi
}

# One repo up to its main branch. $1 path from the root ("" for the project), $2 the branch .gitmodules names.
# Prints one line; returns 1 when it refused.
pull_repo() (
  dir="${1:-.}"
  label="$(pad "${1:-$(basename "$root")}" "$width")"
  cd "$root/$dir"
  if ! err="$(git fetch -q origin 2>&1)"; then
    bad "$label cannot fetch origin: ${err##*$'\n'}"
    exit 1
  fi
  branch="$(origin_branch "$2" main master)" || { bad "$label origin has no ${2:+$2, }main or master"; exit 1; }
  target="$(git rev-parse "refs/remotes/origin/$branch")"
  from="$(git rev-parse HEAD)"
  current="$(git symbolic-ref -q --short HEAD || true)"

  if [ -z "$current" ] && [ -n "$1" ]; then
    # A detached submodule goes onto its branch only when the branch holds the commit: nothing goes back or is lost.
    if [ -n "$(git diff --name-only --ignore-submodules=all HEAD)" ]; then
      bad "$label detached with local changes — commit or stash them first"
      exit 1
    fi
    held=0
    git merge-base --is-ancestor HEAD "$target" && held=1
    git rev-parse -q --verify "refs/heads/$branch" >/dev/null &&
      git merge-base --is-ancestor HEAD "refs/heads/$branch" && held=1
    if [ "$held" = 0 ]; then
      bad "$label detached at $(short HEAD), which $branch does not hold — check out the right branch by hand"
      exit 1
    fi
    if git rev-parse -q --verify "refs/heads/$branch" >/dev/null; then
      checkout=(git checkout -q "$branch")
    else
      checkout=(git checkout -q -b "$branch" --track "origin/$branch")
    fi
    if ! err="$("${checkout[@]}" 2>&1)"; then
      bad "$label cannot check out $branch: ${err##*$'\n'}"
      exit 1
    fi
    current="$branch"
  fi

  if [ "$current" != "$branch" ]; then
    move_ref_only "$label" "$branch" "$target" || exit 1
    exit 0
  fi

  head="$(git rev-parse HEAD)"
  if [ "$head" = "$target" ] || git merge-base --is-ancestor "$target" "$head"; then
    ahead="$(git rev-list --count "$target..$head")"
    [ "$ahead" = 0 ] && ahead='' || ahead=", $ahead ahead of origin"
    if [ "$from" = "$head" ]; then
      ok "$label $branch $(short "$head"), already the latest$ahead"
    else
      ok "$label $branch $(short "$from") → $(short "$head")$ahead"
    fi
    exit 0
  fi
  if ! git merge-base --is-ancestor "$head" "$target"; then
    bad "$label $branch and origin/$branch have diverged — merge or rebase it by hand"
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
    bad "$label $count local change(s), e.g. $(printf '%s\n' "$clash" | head -1) — commit or stash first"
    exit 1
  fi
  if ! err="$(git merge -q --ff-only "$target" 2>&1)"; then
    bad "$label cannot fast-forward $branch: ${err##*$'\n'}"
    exit 1
  fi
  ok "$label $branch $(short "$from") → $(short "$target")"
)

width="$(label_width)"

step "pull-all — every repo to the head of its main branch, fast-forward only"
refused=0
pull_repo "" "" || refused=$((refused + 1))
pull_submodules ""

[ "$refused" = 0 ] || fail "$refused repo(s) left as they were — see ✘ above; nothing was committed or pushed"
done_msg "up to date; nothing was committed or pushed"
