# script-tools

Shell scripts shared across Android, Flutter, iOS and other projects. Add this repository as a Git submodule, e.g. at `packages/script-tools`:

```sh
git submodule add https://github.com/DAMHONGDUC/script-tools.git packages/script-tools
```

## Layout

```text
common/             what every platform shares
  commands.mk         the one command list every platform's make file includes
  COMMANDS.md         that list, what each command means per platform, and the old names
  pull_latest.sh      `make pull-all` on every platform: project + submodules to their main branch heads
  push_current.sh     `make push-all` on every platform: submodules, then the project, on their current branches
common/lib/         platform-independent helpers, sourced by platform scripts
  project.sh          find the project root, read script-tools.properties, in_list for flavor checks
  ruby.sh             before fastlane or CocoaPods: ensure_utf8_locale, require_bundler, leave_bundle_without_cocoapods
  space_free_copy.sh  build from a temporary copy when the project path has a space
  release_output.sh   put a build into <project>/Release/ and print its checksum
  log.sh              timestamped, coloured step/info/warn/fail lines
  repos.sh            the label column and short ids for the two scripts above
android/            scripts for Gradle Android projects
  build_release_apk.sh
  build_release_aab.sh
  android.mk          make targets for the project Makefile — the shared command list
  lib/release.sh      Gradle release build shared by the two scripts
flutter/            scripts for Flutter apps (iOS release via fastlane, Firebase backend)
  set_up.sh ...       one per command, see "Flutter scripts"
  flutter.mk          make targets for the project Makefile — the shared command list
  lib/common.sh       project root, fvm-aware FL/DT, flavor and project checks
  lib/android_build.sh  release APK/AAB build used by release_android.sh
  dart/               Dart package for the icon image tools (bin/*.dart)
  fastlane/Fastfile   shared iOS lanes: beta, upload, preflight, certificates
ios/                scripts for native Xcode projects
  reset_xcode.sh      deep reset of the project's Xcode state
  ios.mk              make targets for the project Makefile
react_native/       scripts for React Native apps (CocoaPods, iOS release via fastlane)
  set_up.sh           submodules, pull, npm ci, clean pod install
  release_ios.sh      signed IPA to TestFlight and Release/
  react_native.mk     make targets for the project Makefile
  lib/common.sh       project root, workspace and bundle id lookup
  fastlane/Fastfile   shared iOS lane: beta
  fastlane/env.example  the keys ios/fastlane/.env needs
```

Conventions for new scripts:

1. One top-level folder per platform (`android/`, `flutter/`, `ios/`, ...); a folder is added with its first script.
2. Runnable scripts sit directly in the platform folder as `<verb>_<object>.sh`; sourced helpers go in its `lib/`. A script every platform runs unchanged sits in `common/`.
3. Anything two platforms need moves to `common/lib/` — including logic two platforms wrote out by hand under different names (a locale guard, a flavor check), found by searching for the pattern, not only the function name; platform folders never source each other.
4. Every script finds the project from the current directory (or `PROJECT_ROOT`) and reads its settings from `<project>/script-tools.properties`. Keys shared by all platforms have no prefix; platform-only keys start with the platform name (`ANDROID_`, `FLUTTER_`, `IOS_`).

## Settings

`<project>/script-tools.properties`, every key optional, comments on their own lines:

```properties
# Output file prefix; default: the project folder name.
APP_NAME=my-app
# Flavors, space separated; leave empty when the project has none.
# flutter/ scripts default to "dev prod".
FLAVORS=dev prod
# Flavor used when FLAVOR is unset; default: the first of FLAVORS.
DEFAULT_FLAVOR=prod
# File holding versionName and versionCode.
VERSION_FILE=env/version.properties

# Gradle module that builds the app.
ANDROID_APP_MODULE=app
# Unit test tasks run before the release build, space separated; {Flavor} becomes the capitalized flavor.
ANDROID_TEST_TASKS=:app:test{Flavor}DebugUnitTest
# Release signing file the Gradle signingConfig reads; the scripts only check that it exists.
ANDROID_KEY_PROPERTIES=env/key.properties

# Xcode project in the root; default: the only *.xcodeproj there.
IOS_PROJECT=MyApp.xcodeproj
# Scheme used to resolve packages; default: the project name.
IOS_SCHEME=MyApp
# Folder of local Swift packages whose .build/ and .swiftpm/ are cleared; default: Packages.
IOS_PACKAGES_DIR=Packages
# react_native/: workspace under ios/; default: the only ios/*.xcworkspace.
IOS_WORKSPACE=ios/MyApp.xcworkspace
# react_native/: bundle id of the upload; default: the one PRODUCT_BUNDLE_IDENTIFIER in ios/*.xcodeproj.
IOS_APP_IDENTIFIER=com.example.myapp
```

Add `Release/` to the project's `.gitignore`.

## Pulling the latest

`make pull-all` (`common/pull_latest.sh`) brings the project and every submodule, nested ones too, to the head of its main branch, fast-forward only. It never commits and never pushes, and prints one line per repo: `<path>  <branch> <from> → <to>`.

| Repo is | It does |
| --- | --- |
| on its main branch | fast-forwards it: `main cb67a84 → d00d123` |
| on another branch | leaves the checkout, moves only the local main ref: `on feature; main 5d668da → 9f0c1e2, not switched` |
| a detached submodule | checks out its branch, then fast-forwards — only when that branch already holds the detached commit |
| ahead of `origin` | nothing to pull: `main ae7991e, already the latest, 1 ahead of origin` |
| diverged, or dirty | refuses that repo; the others still go, then the command exits 1 |

Main branch: the project's is `origin`'s `main`, else `master`; a submodule's is its `.gitmodules` `branch`, else `main`, else `master`. The project refuses only on local changes the pull would touch; a submodule refuses on any. A submodule never initialised is initialised first.

## Pushing

`make push-all` (`common/push_current.sh`) pushes every submodule, nested ones too, then the project, each on the branch it has checked out, to `origin`. Deepest first, so no gitlink reaches `origin` before the commit it points at. It never forces and never commits; uncommitted files are named, not pushed. `DRY_RUN=1` runs `git push --dry-run` and sends nothing.

| Repo is | It does |
| --- | --- |
| ahead of `origin` on its branch | pushes it: `main ae7991e → 169e788 (1 commit(s))` |
| on a branch `origin` does not have | creates it there and sets the upstream: `feature/x new on origin at f995f9a` |
| level with or behind `origin` | nothing to push: `main 561955b, already on origin` |
| missing commits `origin` has | refuses — `make pull-all` or rebase first; never forced |
| a detached submodule | fine when `origin` already holds the commit, refused otherwise |
| recording a submodule commit no branch on `origin` holds | refused by git's own `--recurse-submodules=check` |

A refused repo leaves the others to go, then the command exits 1.

## Android release builds

| Script | Output |
| --- | --- |
| `android/build_release_apk.sh` | `<project>/Release/[<flavor>-]<APP_NAME>-<versionName>-<versionCode>.apk` |
| `android/build_release_aab.sh` | `<project>/Release/[<flavor>-]<APP_NAME>-<versionName>-<versionCode>.aab` |

Each script clears every build output, runs the unit tests, builds the release, replaces the previous file of the same flavor and format in `Release/`, and verifies the signature. Signing itself is the project's Gradle `signingConfig`; without the key file the output is reported as unsigned. `FLAVOR=<flavor>` picks a flavor.

## Android make targets

Project `Makefile` (paths relative to the project root, since make cannot handle spaces):

```make
SCRIPT_TOOLS := packages/script-tools
# Variant for test, lint and the flavorless `make run`; default Debug.
VARIANT := DevDebug
include $(SCRIPT_TOOLS)/android/android.mk
```

The commands are the shared list in [`common/COMMANDS.md`](common/COMMANDS.md); `make help` prints them. Android does: `pull-all`, `push-all`, `setup`, `setup-deep`, `test [TEST=<ClassName>]`, `run-<flavor>` (installs `<Flavor>Debug`; `make run` without flavors), `release-android-<flavor>` (`build_release_apk.sh` then `build_release_aab.sh`), plus its own `sms SENDER=<number> BODY="<text>"`. The rest of the list says why it is not available here.

## Flutter scripts

Setting up a new project: [`flutter/ADOPTION_SPEC.md`](flutter/ADOPTION_SPEC.md).
Moving an app off the old `packages/system_design/tool/` + melos layout: [`flutter/MIGRATE_FROM_SYSTEM_DESIGN.md`](flutter/MIGRATE_FROM_SYSTEM_DESIGN.md).

Run from the project root (or set `PROJECT_ROOT`); each finds the nearest `pubspec.yaml` and works there. Flavored scripts accept only a flavor listed in `FLAVORS`.

| Script | Does |
| --- | --- |
| `flutter/set_up.sh [--deep]` | Wipe build outputs, submodules onto their branch, `pub get` (app, `packages/*`, the packages nested in one — `packages/*/packages/*` —, `flutter/dart`), l10n, build_runner, env templates, `npm ci` in `functions/`; `--deep` also deletes the project's Xcode DerivedData |
| `flutter/generate_code.sh` | l10n + build_runner |
| `flutter/analyze_code.sh` | `flutter analyze --fatal-infos` |
| `flutter/run_tests.sh [path...]` | `flutter test`, scoped to the paths given |
| `flutter/prepare_env.sh <flavor>` | Copy `env_assets/` into `env/`, `ios/`, `android/`, `functions/` |
| `flutter/deploy_firebase.sh <flavor> [rules\|functions]` | Firestore rules + indexes, functions (tested first) |
| `flutter/build_ipa.sh <flavor> [args]` | `flutter build ipa` with `env/<flavor>.json` as dart-defines |
| `flutter/release_ios.sh <flavor> [note]` | `prepare_env` → fastlane `beta` (builds the IPA, uploads to TestFlight); deploys no backend |
| `flutter/upload_ipa.sh <flavor>` | fastlane `upload` of the IPA already built |
| `flutter/run_app.sh <flavor> [args]` | `flutter run` with `env/<flavor>.json` as dart-defines |
| `flutter/deploy_backend.sh <flavor> [rules\|functions]` | `prepare_env` → `deploy_firebase.sh` when `.firebaserc` exists, else says there is nothing to deploy |
| `flutter/release_android.sh <flavor> [args]` | `prepare_env` → `flutter build apk` → `appbundle`, each into `Release/<flavor>-<APP_NAME>-<version>-<build>.<apk\|aab>` |
| `flutter/generate_app_icon.sh` | Launcher icons + rounded launch images from `assets/images/app_icon.png` (`APP_ICON_SOURCE`) |
| `flutter/strip_icon_marker.sh` | Erase the generator's watermark from that artwork, in place |

The iOS lanes are imported, never copied — `ios/fastlane/Fastfile`:

```ruby
import "../../packages/script-tools/flutter/fastlane/Fastfile"
sd_ios_app(team_id: "…", targets: [{ name: "Runner", bundle_id: "…" }])
```

| Argument | What it is |
| --- | --- |
| `team_id` | The Apple Developer team; used for signing and the export plist. |
| `targets` | **Ordered.** The first is the app, whose bundle id every upload and TestFlight query uses; the rest are extensions (profile + export entry, never uploaded alone). |
| `entitlements` | Path under `ios/`, optional. Given, the lane checks the profile carries every key before the build. |
| `flavors` | Default `%w[dev prod]`: the values `flavor:` accepts and the `.firebaserc` aliases it looks up. |
| `script_tools` / `design_system` | Submodule paths from the repo root; default `packages/script-tools`, `packages/flutter-system-design-kit`. |

No `.firebaserc` means no backend: `deploy_backend.sh` says there is nothing to deploy and the lane skips the flavored-config check, both announced. A lane defined below the import overrides the shared one of the same name.

## Flutter make targets

```make
SCRIPT_TOOLS := packages/script-tools
include $(SCRIPT_TOOLS)/flutter/flutter.mk
```

The commands are the shared list in [`common/COMMANDS.md`](common/COMMANDS.md); `make help` prints them.

| Target | Runs |
| --- | --- |
| `make` / `make help` | Lists the commands |
| `make pull-all` | `common/pull_latest.sh` |
| `make push-all [DRY_RUN=1]` | `common/push_current.sh` |
| `make setup` / `setup-deep` | `set_up.sh` / `set_up.sh --deep` |
| `make test [TEST=<path>]` | `run_tests.sh` |
| `make run-<flavor>` | `run_app.sh` |
| `make env-<flavor>` | `prepare_env.sh <flavor>` |
| `make deploy-be-<flavor> [ONLY=rules\|functions]` | `deploy_backend.sh` |
| `make release-ios-<flavor> [NOTE="..."]` | `release_ios.sh` |
| `make release-android-<flavor>` | `release_android.sh` |
| `make icon` / `icon-strip` | `generate_app_icon.sh` / `strip_icon_marker.sh` |

Every deploy and release installs the flavor's config first. Off the list and still running: `gen`, `analyze`, `build-ios-<flavor>` and `upload-ios-<flavor>` (the two halves of `release-ios-`, for a retry), `deploy-<flavor>` and the old `set-up` / `app-icon` names. `build-ipa-`, `upload-ipa-` and `release-<flavor>` fail with the name to use instead. `common/COMMANDS.md` lists them all.

`flutter.mk` and `android.mk` both include `common/commands.mk`; include one per Makefile.

## iOS scripts

Run from the project root (or set `PROJECT_ROOT`); the root is the nearest folder holding `project.yml` or `script-tools.properties`.

| Script | Does |
| --- | --- |
| `ios/reset_xcode.sh [--all]` | Quit Xcode, delete the project's DerivedData, `build/` and every local package's `.build/` / `.swiftpm/`, run `xcodegen` when `project.yml` exists, resolve packages, reopen the project; `--all` also clears the global SwiftPM cache and the project's Xcode user state |

## iOS make targets

```make
SCRIPT_TOOLS := packages/script-tools
include $(SCRIPT_TOOLS)/ios/ios.mk
```

| Target | Runs |
| --- | --- |
| `make` / `make help` | Lists the targets |
| `make pull-all` | `common/pull_latest.sh` |
| `make push-all [DRY_RUN=1]` | `common/push_current.sh` |
| `make reset-xcode` / `deep-reset-xcode` | `reset_xcode.sh` / `reset_xcode.sh --all` |

`ios.mk` defines `help` like the others; include one platform file per Makefile.

## React Native scripts

Run from the project root (or set `PROJECT_ROOT`); the root is the nearest folder holding `script-tools.properties` or `package.json`.

| Script | Does |
| --- | --- |
| `react_native/set_up.sh` | `git submodule update --init --recursive`, `git pull --ff-only` (skipped with `NO_PULL=1`), `npm ci`, then on macOS `bundle install`, removes `ios/Pods`, `ios/Podfile.lock`, `ios/build` and runs `pod install --repo-update` with a UTF-8 locale |
| `react_native/release_ios.sh <env> [note]` | Checks the setup, runs fastlane `ios beta` (archive, automatic App Store signing, TestFlight upload), copies the IPA to `<project>/Release/<env>-<APP_NAME>-<version>-<build>.ipa`. `<env>` must be listed in `FLAVORS` (default `dev`) |

The build number is TestFlight's latest for the version plus one, passed to the build as `CURRENT_PROJECT_VERSION` only, so the project file never changes. Signing is automatic: the App Store Connect API key lets Xcode create the certificate and profiles without an Apple ID logged into Xcode.

The lane is imported, never copied — `ios/fastlane/Fastfile`:

```ruby
import "../../packages/script-tools/react_native/fastlane/Fastfile"
```

Secrets go in `ios/fastlane/.env`, which fastlane loads on its own; copy [`react_native/fastlane/env.example`](react_native/fastlane/env.example) and add `**/fastlane/.env` and `**/fastlane/*.p8` to the project's `.gitignore`.

| Key | What it is |
| --- | --- |
| `IOS_TEAM_ID` | Apple Developer team id |
| `ASC_KEY_ID`, `ASC_ISSUER_ID` | App Store Connect API key (role App Manager) |
| `ASC_KEY_FILEPATH` | The `AuthKey_<id>.p8`, relative to `ios/fastlane/` or absolute |
| `ASC_KEY_CONTENT` | Or, in CI, the `.p8` content base64 encoded |

The project needs `gem 'fastlane'` in its `Gemfile`.

## React Native make targets

```make
SCRIPT_TOOLS := packages/script-tools
include $(SCRIPT_TOOLS)/react_native/react_native.mk
```

| Target | Runs |
| --- | --- |
| `make` / `make help` | Lists the targets |
| `make pull-all` | `common/pull_latest.sh` |
| `make push-all [DRY_RUN=1]` | `common/push_current.sh` |
| `make set-up [NO_PULL=1]` | `set_up.sh` |
| `make run-ios [SIMULATOR="iPhone 17 Pro"]` | `npx react-native run-ios` |
| `make run-android` | `npx react-native run-android` |
| `make release-ios-<env> [NOTE="..."]` | `release_ios.sh <env>` |

`react_native.mk` defines `help` like the others; include one platform file per Makefile.

`ios/` and `react_native/` came before the shared command list and keep their own names for now (`reset-xcode`, `set-up`, `run-ios`, `release-ios-<env>`); `common/COMMANDS.md` says what each should become.
