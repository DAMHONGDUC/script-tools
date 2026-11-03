#!/usr/bin/env bash
# Every submodule, then the project, pushed to origin on the branch each has checked out. Never forces, never commits.
# Usage: <script-tools>/common/push_current.sh   (from the project, or with PROJECT_ROOT set; DRY_RUN=1 pushes nothing)
#
# Deepest submodules first, the project last, so no gitlink reaches origin before the commit it points at; every
# push also runs with --recurse-submodules=check, which makes git itself refuse one that would. A branch origin
# has commits of that the checkout lacks is refused — pull first. A detached submodule is fine when origin already
# holds its commit, refused otherwise. A refused repo leaves the others to go, then the script fails at the end.
set -eu
lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "$lib/log.sh"
source "$lib/repos.sh"

root="$(cd "${PROJECT_ROOT:-$PWD}" && git rev-parse --show-toplevel 2>/dev/null)" || fail "not inside a git repository"
cd "$root"

# A dry run leaves out the submodule check: the submodules it "pushed" are still missing from origin.
opts=(--recurse-submodules=check)
[ -n "${DRY_RUN:-}" ] && opts=(--dry-run)

# One repo's current branch to origin. $1 path from the root ("" for the project). Prints one row; exits 0 when
# nothing was sent, 2 when it pushed, 1 when it refused.
push_repo() (
  repo="${1:-$(basename "$root")}"
  cd "$root/${1:-.}"
  local_head="$(git rev-parse HEAD)"
  dirty="$(git status --porcelain --ignore-submodules=all | wc -l | tr -d ' ')"
  [ "$dirty" = 0 ] && dirty='' || dirty=", $(plural "$dirty" "uncommitted file") not pushed"

  if ! branch="$(git symbolic-ref -q --short HEAD)"; then
    if ! err="$(git fetch -q origin 2>&1)"; then
      bad "$(row "$repo" "(detached)" "$(short HEAD)" "cannot fetch origin: ${err##*$'\n'}")"
      exit 1
    fi
    if [ -n "$(git branch -r --contains HEAD 2>/dev/null)" ]; then
      ok "$(row "$repo" "(detached)" "$(short HEAD)" "up to date$dirty")"
      exit 0
    fi
    bad "$(row "$repo" "(detached)" "$(short HEAD)" "origin does not have this commit — check out a branch first")"
    exit 1
  fi

  if ! remote="$(git ls-remote origin "refs/heads/$branch" 2>&1)"; then
    bad "$(row "$repo" "$branch" "$(short HEAD)" "cannot reach origin: ${remote##*$'\n'}")"
    exit 1
  fi
  remote="${remote%%[[:space:]]*}"
  if [ "$remote" = "$local_head" ]; then
    ok "$(row "$repo" "$branch" "$(short HEAD)" "up to date$dirty")"
    exit 0
  fi
  # origin's tip unknown here, or not under this one: origin has commits the checkout lacks.
  known=0
  [ -n "$remote" ] && git cat-file -e "$remote^{commit}" 2>/dev/null && known=1
  if [ -n "$remote" ] && ! { [ "$known" = 1 ] && git merge-base --is-ancestor "$remote" HEAD; }; then
    if [ "$known" = 1 ] && git merge-base --is-ancestor HEAD "$remote"; then
      ok "$(row "$repo" "$branch" "$(short HEAD)" \
        "$(plural "$(git rev-list --count "HEAD..$remote")" commit) behind origin — nothing to push$dirty")"
      exit 0
    fi
    bad "$(row "$repo" "$branch" "$(short HEAD)" "origin has commits this branch lacks — make pull (or rebase) first")"
    exit 1
  fi

  upstream=()
  git rev-parse -q --verify "$branch@{upstream}" >/dev/null 2>&1 || upstream=(--set-upstream)
  if ! err="$(git push -q "${opts[@]}" ${upstream[@]+"${upstream[@]}"} \
    origin "$branch:refs/heads/$branch" 2>&1)"; then
    case "$err" in
      *"not be found on any remote"*)
        reason="it records a submodule commit no branch on origin holds — push that commit's branch first" ;;
      *) reason="$(printf '%s\n' "$err" | grep -m1 -iE 'error|reject|fatal' || printf '%s' "${err##*$'\n'}")" ;;
    esac
    bad "$(row "$repo" "$branch" "$(short HEAD)" "push refused: $reason")"
    exit 1
  fi
  if [ -n "$remote" ]; then
    commit="$(short "$remote") → $(short HEAD)"
    sent="pushed $(plural "$(git rev-list --count "$remote..HEAD")" commit)"
  else
    commit="$(short HEAD)"
    sent="new branch on origin"
  fi
  ok "$(row "$repo" "$branch" "$commit" "$sent$dirty")"
  exit 2
)

table_widths

step "push — every repo on its current branch, submodules first${DRY_RUN:+ (dry run)}"
table_header
# foreach lists parents before their children; reversed, every submodule goes before the repo that records it.
while read -r -u 3 path; do
  [ -n "$path" ] || continue
  rc=0
  push_repo "$path" || rc=$?
  tally "$rc"
done 3< <(git submodule foreach --quiet --recursive 'echo "$displaypath"' | sed '1!G;h;$!d')
rc=0
push_repo "" || rc=$?
tally "$rc"

summary="$moved pushed${DRY_RUN:+ (dry run — nothing sent)}, $same up to date"
[ "$refused" = 0 ] || fail "$summary, $refused refused — see ✘ above; nothing was forced"
done_msg "$summary; nothing was forced"
