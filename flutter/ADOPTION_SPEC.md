# Adopting the flutter/ scripts in a project

Everything a Flutter app needs to run `make set-up`, `make release-dev` and the
rest from this repo. Nothing here is copied into the app: the app adds two
submodules, a two-line `Makefile`, and the files that say what the app *is*.
`../README.md` is the reference per script; this file is the checklist.

## 1. What the app ends up with

```text
<app>/
  Makefile                         2 lines, includes flutter/flutter.mk
  script-tools.properties          optional; only when flavors are not "dev prod"
  pubspec.yaml                     system_design: path: packages/flutter-system-design-kit
  packages/
    flutter-system-design-kit/     submodule (widgets)       — optional
    script-tools/                  submodule (these scripts) — required
  env/dev.example.json             committed, keys only     — optional
  env_assets/                      gitignored, real config  — optional
  ios/fastlane/Fastfile            import + sd_ios_app(...)
  ios/fastlane/{Appfile,Matchfile} the app's ids
  ios/Gemfile                      gem "fastlane"
  .firebaserc + functions/         only with a Firebase backend
```

Every row marked optional is detected, not demanded: a missing one is skipped
with a line saying so (no `.firebaserc` → "no Firebase backend, nothing to
deploy"), never failed.

## 2. Steps

| # | Do | Exact value |
|---|---|---|
| 1 | Add script-tools | `git submodule add -b main https://github.com/DAMHONGDUC/script-tools packages/script-tools` |
| 2 | Add the design kit (if used) | `git submodule add -b main https://github.com/DAMHONGDUC/flutter-system-design-kit packages/flutter-system-design-kit` |
| 3 | Depend on the kit | `pubspec.yaml` → `system_design:` / `path: packages/flutter-system-design-kit` |
| 4 | Root `Makefile` | see §3 |
| 5 | Flavors other than dev/prod | `script-tools.properties` → `FLAVORS=dev staging prod` |
| 6 | Ignore secrets | `.gitignore` → `env/*.json`, `!env/*.example.json`, `env_assets/`, `ios/fastlane/.env`, `ios/Runner/GoogleService-Info.plist`, `android/app/google-services.json`, `functions/.env` |
| 7 | Env config (if dart-defines) | commit `env/<flavor>.example.json` with keys and empty values; `set_up.sh` copies it to `env/<flavor>.json` when missing |
| 8 | Real config per machine | fill `env_assets/` with the files in §4 |
| 9 | iOS lanes | `ios/fastlane/Fastfile` per §5, plus `Appfile`, `Matchfile`, `ios/Gemfile`, `bundle install` |
| 10 | CI | §6 |
| 11 | Check | `make`, then `make set-up`, then `make analyze` |

## 3. Makefile

```make
# Short names for the shared scripts in packages/script-tools/flutter. `make` lists them.
SCRIPT_TOOLS := packages/script-tools
include $(SCRIPT_TOOLS)/flutter/flutter.mk
```

`SCRIPT_TOOLS` is relative: make cannot handle a space in a path. Include
`flutter.mk` or `android.mk`, not both — each defines `help` and `test`.

| Target | Example | Runs |
|---|---|---|
| `set-up` / `deep-set-up` | `make set-up` | wipe, submodules on their branch, `pub get` (app + `packages/*`), l10n, build_runner, env templates, `npm ci` |
| `gen` / `analyze` | `make analyze` | l10n + build_runner / `flutter analyze --fatal-infos` |
| `test` | `make test TEST=test/features/attacks/log_flow_test.dart` | `flutter test <path>` |
| `env-<flavor>` | `make env-dev` | `env_assets/` → the paths in §4 |
| `deploy-<flavor>` | `make deploy-prod ONLY=rules` | rules + indexes, then functions after their tests |
| `build-ipa-<flavor>` | `make build-ipa-dev` | `flutter build ipa --dart-define-from-file=env/dev.json` → `build/ios/ipa/` |
| `release-<flavor>` | `make release-dev NOTE="new paywall"` | env → deploy → `fastlane beta` (bumps the build number) |
| `upload-ipa-<flavor>` | `make upload-ipa-dev` | `fastlane upload` of the IPA already built |
| `app-icon` | `make app-icon` | launcher icons + rounded launch images from `assets/images/app_icon.png` |

## 4. env_assets/ — what `make env-<flavor>` copies

Example for `dev`. Every source is checked before anything is copied.

| Source in `env_assets/` | Destination | When |
|---|---|---|
| `dev.json` | `env/dev.json` | always |
| `fastlane.env` | `ios/fastlane/.env` | always |
| `dev-Info.plist` | `ios/Runner/Info.plist` | always |
| `dev-google-services.json` | `android/app/google-services.json` | `.firebaserc` exists |
| `dev-GoogleService-Info.plist` | `ios/Runner/GoogleService-Info.plist` | `.firebaserc` exists |
| `dev-function.env` | `functions/.env` | `functions/` exists |

`fastlane.env` holds `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILEPATH` (the
`.p8` path), `MATCH_GIT_URL`, `MATCH_PASSWORD`, and optionally
`FIREBASE_APP_ID_IOS` for dSYM upload.

## 5. ios/fastlane/Fastfile

```ruby
import "../../packages/script-tools/flutter/fastlane/Fastfile"

sd_ios_app(
  team_id: "ABCDE12345",
  targets: [
    { name: "Runner", bundle_id: "com.example.app", entitlements: "Runner/Runner.entitlements" },
    { name: "AppWidgetExtension", bundle_id: "com.example.app.AppWidgetExtension" },
  ],
)
```

| Argument | Default | Meaning |
|---|---|---|
| `team_id` | — | Apple Developer team |
| `targets` | — | **Ordered**: the first is the app and the bundle id every upload uses; the rest are extensions |
| `flavors` | `%w[dev prod]` | values `flavor:` accepts; must match `FLAVORS` and the `.firebaserc` aliases |
| `script_tools` | `packages/script-tools` | where `build_ipa.sh` is |
| `design_system` | `packages/flutter-system-design-kit` | whose commit the CI bump records |

Lanes: `beta` (build + upload), `upload` (upload only), `preflight` (checks,
no build), `certificates` (match). A lane of the same name below the import
overrides the shared one for this app only.

**Never archive from Xcode or `gym`.** Neither passes
`--dart-define-from-file`, so the IPA ships with empty config and crashes on
the first Firebase call. `beta` always builds through `build_ipa.sh`.

## 6. CI (GitHub Actions)

```yaml
- uses: actions/checkout@v4
  with:
    submodules: recursive
- name: Follow the submodules' branches
  run: git submodule update --remote --recursive
- run: bash packages/script-tools/flutter/generate_code.sh
- run: bash packages/script-tools/flutter/analyze_code.sh
- run: bash packages/script-tools/flutter/run_tests.sh
```

A release job writes the secrets (`ENV_<FLAVOR>_JSON` → `env/<flavor>.json`,
`GOOGLE_SERVICE_INFO_PLIST_<FLAVOR>`, `ASC_KEY_ID`, `ASC_ISSUER_ID`,
`ASC_KEY_CONTENT` base64, `MATCH_GIT_URL`, `MATCH_PASSWORD`,
`MATCH_GIT_BEARER_AUTHORIZATION`) and runs
`cd ios && bundle exec fastlane beta flavor:prod bump:true` with
`LANG=en_US.UTF-8`. With `bump:true` on CI the lane commits `pubspec.yaml` and
both submodule gitlinks back to the branch.

**Push the submodules before the app.** A gitlink to an unpushed commit fails
checkout with `not our ref`.

## 7. Migrating from the old tool/ + melos setup

| Before | After |
|---|---|
| `packages/system_design/tool/*.sh` | `packages/script-tools/flutter/*.sh` (`set-up.sh` → `set_up.sh`, `gen.sh` → `generate_code.sh`, `build-ipa.sh` → `build_ipa.sh`, …) |
| `melos run release-dev` | `make release-dev` |
| `melos run prepare-env-dev` | `make env-dev` |
| `melos run deploy-firebase-prod rules` | `make deploy-prod ONLY=rules` |
| `melos run gen-app-icon` | `make app-icon` |
| `import "../../packages/system_design/tool/fastlane/Fastfile"` | `import "../../packages/script-tools/flutter/fastlane/Fastfile"` |
| `sh` (POSIX, run by melos) | `bash`, project found from `PROJECT_ROOT` or the nearest `pubspec.yaml` |
| `scripts:` in `melos.yaml` | removed; melos, if kept, only bootstraps |

## 8. Done when

| Check | Expected |
|---|---|
| `make` | the target list prints |
| `make env-qa` | refused: `usage: prepare_env.sh <flavor> (flavor: dev, prod)` |
| `make set-up` | ends without `✘`; lists any env file it created from a template |
| `make analyze` | `No issues found!` |
| `cd ios && bundle exec fastlane lanes` | shows `beta`, `upload`, `preflight`, `certificates` |
