# script-tools

Shell scripts shared across Android, Flutter, iOS and other projects. Add this repository as a Git submodule, e.g. at `packages/script-tools`:

```sh
git submodule add https://github.com/DAMHONGDUC/script-tools.git packages/script-tools
```

## Layout

```text
common/lib/         platform-independent helpers, sourced by platform scripts
  project.sh          find the project root, read script-tools.properties
  space_free_copy.sh  build from a temporary copy when the project path has a space
  release_output.sh   put a build into <project>/Release/ and print its checksum
android/            scripts for Gradle Android projects
  build_release_apk.sh
  build_release_aab.sh
  lib/release.sh      Gradle release build shared by the two scripts
```

Conventions for new scripts:

1. One top-level folder per platform (`android/`, `flutter/`, `ios/`, ...); a folder is added with its first script.
2. Runnable scripts sit directly in the platform folder as `<verb>_<object>.sh`; sourced helpers go in its `lib/`.
3. Anything two platforms need moves to `common/lib/`; platform folders never source each other.
4. Every script finds the project from the current directory (or `PROJECT_ROOT`) and reads its settings from `<project>/script-tools.properties`. Keys shared by all platforms have no prefix; platform-only keys start with the platform name (`ANDROID_`, `FLUTTER_`, `IOS_`).

## Settings

`<project>/script-tools.properties`, every key optional, comments on their own lines:

```properties
# Output file prefix; default: the project folder name.
APP_NAME=my-app
# Flavors, space separated; leave empty when the project has none.
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
```

Add `Release/` to the project's `.gitignore`.

## Android release builds

| Script | Output |
| --- | --- |
| `android/build_release_apk.sh` | `<project>/Release/<APP_NAME>[-<flavor>]-<versionName>-<versionCode>.apk` |
| `android/build_release_aab.sh` | `<project>/Release/<APP_NAME>[-<flavor>]-<versionName>-<versionCode>.aab` |

Each script clears every build output, runs the unit tests, builds the release, replaces the previous file of the same format in `Release/`, and verifies the signature. Signing itself is the project's Gradle `signingConfig`; without the key file the output is reported as unsigned. `FLAVOR=<flavor>` picks a flavor.
