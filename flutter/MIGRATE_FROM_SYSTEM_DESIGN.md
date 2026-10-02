# Migrating an app off `packages/system_design/tool/`

For an app that still has the old layout: the design system submodule at
`packages/system_design` (repo `system_design`, now renamed
`flutter-system-design-kit`), scripts in its `tool/`, and commands as
`melos run <name>`. After this the app looks like `ADOPTION_SPEC.md` describes.
Hand this file to whoever (or whatever agent) does the work; every step is a
command or an exact replacement.

## 0. Before starting

| Check | Why |
|---|---|
| `flutter-system-design-kit` and `script-tools` are pushed, `main` includes kit commit `99c0501` (tool/ removed) and script-tools `flutter/` | The app's new gitlinks point there; an unpushed commit fails clone and CI with `not our ref` |
| `git -C packages/system_design status` is clean and its HEAD is on the remote | The submodule is re-cloned in step 1; local-only work there would be lost |
| Diff the app's `packages/system_design/tool/` against `script-tools/flutter/` | The app may sit on an older kit commit, or carry local edits. Anything app-specific must move into the app (§5), not be lost |
| Note the app's flavors (`grep -o '"[a-z]*"' .firebaserc`, `ls env/*.example.json`) | Not `dev prod` → needs `script-tools.properties` (step 6) |

## 1. Submodules

```bash
git submodule deinit -f packages/system_design
git rm -f packages/system_design
rm -rf .git/modules/packages/system_design
git submodule add -b main https://github.com/DAMHONGDUC/flutter-system-design-kit packages/flutter-system-design-kit
git submodule add -b main https://github.com/DAMHONGDUC/script-tools packages/script-tools
```

Re-adding beats `git mv`: the submodule's name, URL and `.git/modules` path all
match the new name, with no hand-edited gitdir.

## 2. Files to change

| File | Before | After |
|---|---|---|
| `pubspec.yaml` | `path: packages/system_design` | `path: packages/flutter-system-design-kit` (the package is still `system_design`; no Dart import changes) |
| `Makefile` (new) | — | `SCRIPT_TOOLS := packages/script-tools` + `include $(SCRIPT_TOOLS)/flutter/flutter.mk` |
| `melos.yaml` | `scripts:` block, 13 one-liners into `tool/` | delete the block; keep `name`, `packages`, `ide` for bootstrap, or drop melos entirely if CI does not bootstrap |
| `ios/fastlane/Fastfile` | `import "../../packages/system_design/tool/fastlane/Fastfile"` | `import "../../packages/script-tools/flutter/fastlane/Fastfile"` |
| `.github/workflows/*.yml` | `sh packages/system_design/tool/gen.sh` / `analyze.sh` / `test.sh` | `bash packages/script-tools/flutter/generate_code.sh` / `analyze_code.sh` / `run_tests.sh` |
| CI "submodule checked out" guard | tests `packages/system_design/pubspec.yaml` | tests `packages/flutter-system-design-kit/pubspec.yaml` and `packages/script-tools/flutter/lib/common.sh` |
| `.gitignore` comments | `melos run set-up`, `melos run prepare-env-dev\|prod` | `make set-up`, `make env-dev\|env-prod` |
| `ios/Gemfile` comment | mentions `tool/…` | `script-tools' flutter/build_ipa.sh` |

## 3. Name mapping (for docs, comments, messages)

Apply in this order — longer patterns first — across `*.md`, `*.yml`,
`ios/fastlane/*`, `.gitignore`. Leave dated plans and changelogs as history.

| Old | New |
|---|---|
| `sh packages/system_design/tool/analyze.sh` | `make analyze` |
| `sh packages/system_design/tool/gen.sh` | `make gen` |
| `sh packages/system_design/tool/test.sh` | `make test` (`make test TEST=<path>` for one file) |
| `sh packages/system_design/tool/prepare-env.sh dev` | `make env-dev` |
| `sh packages/system_design/tool/build-ipa.sh prod` | `make build-ipa-prod` |
| `packages/system_design/tool/fastlane/Fastfile` | `packages/script-tools/flutter/fastlane/Fastfile` |
| `packages/system_design/tool/` | `packages/script-tools/flutter/` |
| `packages/system_design` | `packages/flutter-system-design-kit` |
| `melos run set-up` / `deep-set-up` | `make set-up` / `make deep-set-up` |
| `melos run prepare-env-dev` | `make env-dev` |
| `melos run deploy-firebase-prod` | `make deploy-prod` |
| `melos run deploy-firebase-prod rules` | `make deploy-prod ONLY=rules` |
| `melos run release-dev` | `make release-dev` (`NOTE="…"` for What to Test) |
| `melos run upload-ipa-dev` | `make upload-ipa-dev` |
| `melos run gen-app-icon` / `gen-app-icon-strip-marker` | `make app-icon` / `make app-icon-strip-marker` |
| `set-up.sh`, `deep-set-up.sh` | `set_up.sh`, `set_up.sh --deep` |
| `gen.sh`, `analyze.sh`, `test.sh` | `generate_code.sh`, `analyze_code.sh`, `run_tests.sh` |
| `prepare-env.sh`, `deploy-firebase.sh`, `build-ipa.sh` | `prepare_env.sh`, `deploy_firebase.sh`, `build_ipa.sh` |
| `release.sh`, `upload-ipa.sh` | `release_ios.sh`, `upload_ipa.sh` |
| `gen-app-icon.sh`, `gen-app-icon-strip-marker.sh` | `generate_app_icon.sh`, `strip_icon_marker.sh` |
| `_common.sh`, `_clean.sh` | `flutter/lib/common.sh`; the wipe is the top of `set_up.sh` |

Then this must print nothing:

```bash
grep -rnE "system_design/tool|packages/system_design|melos run|_common\.sh|prepare-env\.sh|build-ipa\.sh" \
  --exclude-dir=build --exclude-dir=.dart_tool --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=packages .
```

## 4. Behaviour that changed

| What | Before | After |
|---|---|---|
| Shell | POSIX `sh`, run by melos | `bash`, run by make |
| Project root | three levels above the script, or `MELOS_ROOT_PATH` | `PROJECT_ROOT` (the Makefile sets it), else nearest `pubspec.yaml` above the cwd |
| Accepted flavors | hard-coded `dev\|prod` | `FLAVORS` in `script-tools.properties`, default `dev prod` |
| `pub get` in set-up | app + `packages/system_design` | app + every `packages/*/pubspec.yaml` + `script-tools/flutter/dart` |
| Icon Dart tools | resolved through the kit's `image` dev dependency | own package `script-tools/flutter/dart`, `pub get` on first run |
| Deep set-up | `MELOS_CLEAN_DERIVED=1` | `set_up.sh --deep` |
| Melos `scripts:` | the command list | gone; `make` lists the commands |
| CI build-number bump | stages `pubspec.yaml` + `packages/system_design` | stages `pubspec.yaml` + both submodule paths |

## 5. App-specific differences

| The app has | Do |
|---|---|
| flavors other than dev/prod | `script-tools.properties` at the root: `FLAVORS=dev staging prod`, and `flavors: %w[dev staging prod]` in `sd_ios_app` |
| submodules somewhere other than `packages/` | `sd_ios_app(..., script_tools: "<path>", design_system: "<path>")` and `SCRIPT_TOOLS := <path>` |
| an edit to an old `tool/` script that only this app needs | a lane override below the import in `ios/fastlane/Fastfile`, or an app-local make target in its own `Makefile` — never a fork of the shared script |
| an edit every app needs | commit it to script-tools first, then bump the gitlink |
| no Firebase / no `env_assets/` / no `functions/` | nothing; those steps are skipped by name |

## 6. Verify

| Command | Expected |
|---|---|
| `make` | the target list |
| `make env-nope` | `usage: prepare_env.sh <flavor> (flavor: dev, prod)` |
| `fvm flutter pub get` | resolves `system_design` from the new path |
| `make analyze` | `No issues found!` |
| `make test TEST=<one small test>` | passes |
| `cd ios && bundle exec fastlane lanes` | lists `beta`, `upload`, `preflight`, `certificates` |

`make env-<flavor>` overwrites `ios/Runner/Info.plist`; run it on a clean tree.

## 7. Commit

1. Code and config: submodules, `pubspec.*`, `Makefile`, `melos.yaml`, CI,
   `ios/fastlane`, `.gitignore`, non-rule docs — e.g.
   `chore: tooling - scripts move to the script-tools submodule, commands become make targets`.
2. If the app keeps agent rule files (`CLAUDE.md`, `docs/rules/`), those in a
   commit of their own.
3. Push order: script-tools and the kit (if changed), then the app.
