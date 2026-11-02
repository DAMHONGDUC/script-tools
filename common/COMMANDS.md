# One command list for every platform

**Every platform's make file answers to the same commands, in the same order** (owner's rule). The owner works across many projects on several platforms; a command named one way in one project and another way in the next is a command that gets forgotten. So the list is fixed here, `common/commands.mk` holds it, and `make help` prints the same lines in every project.

## Three parts

Everything that leaves the machine is one of three commands, and **the first is part of the other two** (owner's rule):

```text
env-<flavor>              install the flavor's config
deploy-be-<flavor>        env, then deploy the backend
release-ios-<flavor>      env, then build the IPA and upload it to TestFlight
release-android-<flavor>  env, then build the release APK and AAB
```

- **Every deploy and every release installs the flavor's config first, by itself.** A file built or a backend deployed against whichever config the checkout last held is the wrong environment with nothing to say so. A project with no flavored config says so and goes on.
- **The backend is its own command, never a step of a release** (owner's rule). A release builds and ships the app; `deploy-be-<flavor>` deploys the backend — Firebase when the project has `.firebaserc`, and without one it says there is nothing to deploy and stops.
- **One release per store, named by the platform**: `release-ios-` and `release-android-`, so the command says where the build goes.

## The rules

- **Every platform defines every command.** One it cannot do still exists and fails with the reason — `make release-ios-prod` on Android says *an IPA is an iOS build* — so a missing command is never mistaken for a typo.
- **Every TestFlight note opens with `<flavor> - <version> (<build>)`** (owner's rule) — `dev - 1.0.0 (1)`, on every platform. It is the default note, and a `NOTE=` is appended under it, never in its place: the flavor and the number are what the TestFlight list does not show.
- **Verb first, flavor last, as a suffix**: `release-ios-prod`, never `release FLAVOR=prod`. The destination is typed, never defaulted.
- **One word per verb, no hyphen inside it**: `setup`, not `set-up`. A hyphen only separates the verb from its qualifier and the flavor (`setup-deep`, `deploy-be-dev`).
- **The list stays minimal** (owner's rule): a command earns a place only if it is typed in every project. Where a platform had a command that came off the list, it still runs, unlisted.
- **A platform's own extras come after the list** (`sms` on Android) and a project's own after those (`pre-build` in a Flutter app); `make help` orders them that way by itself.
- **A renamed command keeps its old name working when the old name still means one thing**, left out of `make help`, so a note or a CI step that still types it does not break. **An old name that would now be a guess fails, printing the name to use**: `release-<flavor>` (which platform? and the backend is its own command now), `build-ipa-<flavor>`, `upload-ipa-<flavor>`.

## The list

| Command | Does | Flutter | Android (Gradle) |
|---|---|---|---|
| `help` | List the commands | ✓ | ✓ |
| `pull` | Project and every submodule to the head of its main branch, fast-forward only; never commits or pushes | `common/pull_latest.sh` | `common/pull_latest.sh` |
| `push` | Every submodule, then the project, on its current branch to `origin`; never forces; `DRY_RUN=1` sends nothing | `common/push_current.sh` | `common/push_current.sh` |
| `setup` | Everything a fresh clone needs before it builds | `set_up.sh` | submodules, Gradle dependencies |
| `setup-deep` | `setup`, after a deeper wipe | `set_up.sh --deep` (Xcode DerivedData) | `./gradlew clean`, then `setup` |
| `test` | Unit tests; `TEST=` narrows them | `TEST=<path>` | `TEST=<ClassName>` |
| `run-<flavor>` | The app in debug on a device | `flutter run` with the flavor's config | installs `<Flavor>Debug`; `make run` without flavors |
| `env-<flavor>` | Install the flavor's config | from `env_assets/` | — Gradle reads it |
| `deploy-be-<flavor>` | Config, then the backend | Firebase if `.firebaserc`; `ONLY=rules\|functions` | — |
| `release-ios-<flavor>` | Config, IPA, TestFlight | `fastlane beta`; `NOTE=` for What to Test | — |
| `release-android-<flavor>` | Config, release APK and AAB into `Release/` | `flutter build apk` + `appbundle` | signed APK + AAB |
| `icon` | Every app icon from the artwork | ✓ | — |
| `icon-strip` | Erase the generator's watermark from the artwork | ✓ | — |

`pull` and `push` are the commands whose recipe is the same everywhere, so `commands.mk` defines them and no platform file repeats them. `ios.mk` and `react_native.mk`, which do not include `commands.mk` yet, carry the same one-line targets.

## Off the list, still running

| Platform | Name | Runs |
|---|---|---|
| Flutter | `gen`, `analyze` | `generate_code.sh` / `analyze_code.sh` |
| Flutter | `set-up`, `deep-set-up` | `setup`, `setup-deep` |
| Flutter | `app-icon`, `app-icon-strip-marker` | `icon`, `icon-strip` |
| Flutter | `build-ios-<flavor>` | the IPA alone, no config step |
| Flutter | `upload-ios-<flavor>` | upload the IPA already built — the retry when TestFlight was not reached |
| Flutter | `deploy-<flavor>` | `deploy-be-<flavor>` |
| Android | `clean`, `analyze` / `lint` | `./gradlew clean` / lint on `VARIANT` |
| Android | `install`, `build` | install / assemble `VARIANT` |
| Android | `apk FLAVOR=<flavor>`, `aab FLAVOR=<flavor>` | one format alone |

## Adding a platform

`react_native/` and `ios/` exist and predate this list: `react_native.mk` has `set-up`, `run-ios`, `run-android` and `release-ios-<env>`, `ios.mk` has `reset-xcode`. **They are not on the list yet**; moving one onto it follows the steps below, with the table after them as the target. A new platform's make file:

1. Sets `PLATFORM := <Name>` and includes `$(SCRIPT_TOOLS)/common/commands.mk` before any target.
2. Defines **every** command in the list but `pull` and `push`, which `commands.mk` defines, a `## ` description on each, and `$(call not_on,<reason>)` as the whole recipe of one it cannot do.
3. Puts every specific pattern (`release-ios-%`) above any general one (`release-%`): make 3.81, the one macOS ships, takes the first pattern that matches.
4. Adds its extras after the list, and no command that means the same as one on the list under another name.

What each command should mean there, so the first file starts from the same list:

| Command | React Native | iOS (Xcode) |
|---|---|---|
| `setup` | `npm ci`, `pod install` | submodules, Swift packages resolved |
| `test` | Jest | `xcodebuild test` |
| `run-<flavor>` | the flavor's scheme or variant on a device | the flavor's scheme on a simulator |
| `env-<flavor>` | the flavor's `.env` | the flavor's xcconfig |
| `deploy-be-<flavor>` | the backend, if the project has one | the backend, if the project has one |
| `release-ios-<flavor>` | the shared fastlane `beta` lane | the shared fastlane `beta` lane |
| `release-android-<flavor>` | Gradle release APK + AAB | — |
