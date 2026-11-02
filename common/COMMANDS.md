# One command list for every platform

**Every platform's make file answers to the same commands, in the same order** (owner's rule). The owner works across many projects on several platforms; a command that is `lint` in one and `analyze` in the next, or `apk FLAVOR=prod` here and `build-ipa-prod` there, is a command that gets forgotten. So the list is fixed here, `common/commands.mk` holds it, and `make help` prints the same lines in every project.

## The rules

- **Every platform defines every command.** One it cannot do still exists and fails with the reason — `make ipa-prod` on Android says *an IPA is an iOS build* — so a missing command is never mistaken for a typo.
- **Verb first, flavor last, as a suffix**: `release-prod`, never `release FLAVOR=prod`. The destination is typed, never defaulted.
- **One word per verb, no hyphen inside it**: `setup`, not `set-up`. A hyphen only separates the verb from the flavor or a qualifier (`setup-deep`, `icon-strip`).
- **The artefact is the verb** when a command builds one file a store takes: `ipa`, `apk`, `aab`.
- **A platform's own extras come after the list** (`sms` on Android) and a project's own after those (`pre-build` in a Flutter app); `make help` orders them that way by itself.
- **A renamed command keeps its old name working**, left out of `make help`, so a note or a CI step that still types it does not break.
- **The list stays minimal** (owner's rule): a command earns a place only if it is typed in every project. `clean`, `gen` and `analyze` were taken off for that reason; where a platform had them they still run, unlisted.

## The list

| Command | Does | Flutter | Android (Gradle) |
|---|---|---|---|
| `help` | List the commands | ✓ | ✓ |
| `setup` | Everything a fresh clone needs before it builds | `set_up.sh` | submodules, Gradle dependencies |
| `setup-deep` | `setup`, after a deeper wipe | `set_up.sh --deep` (Xcode DerivedData) | `./gradlew clean`, then `setup` |
| `test` | Unit tests; `TEST=` narrows them | `TEST=<path>` | `TEST=<ClassName>` |
| `run-<flavor>` | The app in debug on a device | `flutter run` with the flavor's config | installs `<Flavor>Debug`; `make run` without flavors |
| `env-<flavor>` | Install the flavor's real config | from `env_assets/` | — Gradle reads it |
| `deploy-<flavor>` | Deploy the backend | Firebase; `ONLY=rules\|functions` | — |
| `ipa-<flavor>` | Release IPA | ✓ | — |
| `apk-<flavor>` | Release APK | — no script yet | signed, into `Release/` |
| `aab-<flavor>` | Release AAB | — no script yet | signed, into `Release/` |
| `release-<flavor>` | Ship the flavor to its store | config, deploy, TestFlight; `NOTE=` | — no Play upload yet |
| `upload-<flavor>` | Upload a build already made | TestFlight | — |
| `icon` | Every app icon from the artwork | ✓ | — |
| `icon-strip` | Erase the generator's watermark from the artwork | ✓ | — |

## Old names that still work

| Platform | Old | Now |
|---|---|---|
| Flutter | `gen`, `analyze` | off the list; still run `generate_code.sh` / `analyze_code.sh` |
| Android | `clean`, `analyze` | off the list; still run `./gradlew clean` / lint on `VARIANT` |
| Flutter | `set-up`, `deep-set-up` | `setup`, `setup-deep` |
| Flutter | `build-ipa-<flavor>`, `upload-ipa-<flavor>` | `ipa-<flavor>`, `upload-<flavor>` |
| Flutter | `app-icon`, `app-icon-strip-marker` | `icon`, `icon-strip` |
| Android | `lint` | the same lint as `analyze` |
| Android | `install` | `run` (flavorless) / `run-<flavor>` |
| Android | `build` | — assembles `VARIANT`; kept as it was |
| Android | `apk FLAVOR=<flavor>`, `aab FLAVOR=<flavor>` | `apk-<flavor>`, `aab-<flavor>` |

## Adding a platform

React Native and native iOS have no folder yet; each gets one with its first script (README, convention 1). Its make file:

1. Sets `PLATFORM := <Name>` and includes `$(SCRIPT_TOOLS)/common/commands.mk` before any target.
2. Defines **every** command in the list, a `## ` description on each, and `$(call not_on,<reason>)` as the whole recipe of one it cannot do.
3. Adds its extras after the list, and no command that means the same as one on the list under another name.

What each command should mean there, so the first file starts from the same list:

| Command | React Native | iOS (Xcode) |
|---|---|---|
| `setup` | `npm ci`, `pod install` | submodules, Swift packages resolved |
| `test` | Jest | `xcodebuild test` |
| `run-<flavor>` | the flavor's scheme or variant on a device | the flavor's scheme on a simulator |
| `ipa-` / `apk-` / `aab-<flavor>` | each, from its native half | `ipa-` only |
| `release-` / `upload-<flavor>` | the shared fastlane lanes | the shared fastlane lanes |
