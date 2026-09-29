#!/usr/bin/env bash
# Deploys one flavor's Firebase side: firestore rules, indexes, functions. Does not ask — typing the flavor is the decision.
# Usage: <script-tools>/flutter/deploy_firebase.sh <flavor> [rules|functions]
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ENV_NAME="${1:-}"
require_flavor "$ENV_NAME" "deploy_firebase.sh <flavor> [rules|functions]"

TARGET="${2:-all}"
case "$TARGET" in
  all | rules | functions) ;;
  *) fail "unknown target '$TARGET' — expected: rules, functions, or nothing" ;;
esac

has_firebase || fail "no .firebaserc — this app has no Firebase project to deploy to"

# The repo's own CLI wins: the standalone binary runs predeploy hooks through its bundled npm 8, which dies on
# `npm run lint` with "Cannot read properties of undefined (reading 'stdin')".
FIREBASE="$PWD/functions/node_modules/.bin/firebase"
if [ ! -x "$FIREBASE" ]; then
  command -v firebase >/dev/null 2>&1 ||
    fail "firebase CLI not found — npm --prefix functions install, or https://firebase.google.com/docs/cli"
  FIREBASE=firebase
fi

# Read here so the project is printed before anything is sent, and a missing alias fails.
project_id() {
  sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .firebaserc
}

ENV_ID=$(project_id "$ENV_NAME")
if [ -z "$ENV_ID" ]; then
  warn "no '$ENV_NAME' alias in .firebaserc"
  fail "create it with: firebase use --add"
fi

step "firebase — $ENV_NAME"
info "project: $ENV_ID"
info "cli: $FIREBASE"

# Until prod is its own project both aliases resolve to one id, and a dev deploy is a production deploy.
DEV_ID=$(project_id dev)
PROD_ID=$(project_id prod)
if [ -n "$DEV_ID" ] && [ "$DEV_ID" = "$PROD_ID" ]; then
  warn "dev and prod are the SAME project — this reaches real users"
fi

# The CLI keeps ONE login per machine, so another app's session surfaces as a nameless 403. Checked here, where both
# names are known. A failure to LIST is not a failure to deploy: CI service accounts often cannot list projects.
ACCOUNT=$("$FIREBASE" login:list 2>/dev/null | sed -n 's/^Logged in as //p' | head -1)
if [ -n "$ACCOUNT" ]; then
  info "account: $ACCOUNT"
fi

if VISIBLE_PROJECTS=$("$FIREBASE" projects:list --json 2>/dev/null); then
  case "$VISIBLE_PROJECTS" in
    *"\"$ENV_ID\""*) ;;
    *)
      warn "${ACCOUNT:-the signed-in account} cannot see $ENV_ID — every call would come back 403 with no name attached"
      fail "sign in as the account that owns it (firebase login), or have this one added to the project"
      ;;
  esac
else
  info "projects could not be listed — not a user login, so access was not checked"
fi

# Every deploy passes --project rather than relying on whatever `firebase use` was left on.
if [ "$TARGET" = "all" ] || [ "$TARGET" = "rules" ]; then
  step "rules and indexes"
  "$FIREBASE" deploy --project "$ENV_NAME" --only firestore:rules,firestore:indexes
fi

if [ "$TARGET" = "all" ] || [ "$TARGET" = "functions" ]; then
  # Deploying a build that fails its own tests costs a second deploy to undo. Both scripts are optional.
  step "functions tests"
  if has_npm_script functions build; then
    (cd functions && npm run build)
  else
    info "no build script in functions/package.json, nothing to compile"
  fi

  if has_npm_script functions test; then
    (cd functions && npm test)
  else
    info "no test script in functions/package.json, nothing to run"
  fi

  # Without a cleanup policy the CLI asks for one AFTER a successful deploy, and an unattended run exits non-zero
  # with the functions already live. Tolerated on a project's first deploy, which has no registry repo yet.
  step "artifact cleanup policy"
  "$FIREBASE" functions:artifacts:setpolicy --project "$ENV_NAME" --days 1 --force ||
    warn "no cleanup policy set — first deploy to this project? re-run once it succeeds"

  step "functions"
  "$FIREBASE" deploy --project "$ENV_NAME" --only functions
fi

done_msg "deployed $TARGET to $ENV_NAME"
