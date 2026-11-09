# Dailio Shorebird

Shorebird is used to publish signed Flutter releases and deliver Dart-only fixes
without waiting for a new store review. It does not replace the API, Firebase,
or the normal `flutter run` development workflow.

## Project setup

The Shorebird CLI is installed locally on Windows and the Dailio app is already
initialized. On a new development machine, sign in with the Shorebird account
that owns this app:

```powershell
shorebird login
shorebird doctor
```

If the project ever needs to be initialized from scratch, run
`shorebird init --display-name "Dailio"` from this directory. It creates
`shorebird.yaml` and adds the file to the Flutter asset list. The generated
`shorebird.yaml` is already present here; its app ID is not a secret. Do not
commit the Shorebird access token.

The repository contains the generated `shorebird.yaml` for the Dailio Shorebird
app. Its app ID is public configuration, not a secret; keep the access token out
of the repository.

## Local release and patch commands

Run these commands from `apps/mobile` after initialization:

```powershell
# First release for a version (requires a store-ready signing configuration)
shorebird release --platforms android
shorebird release --platforms ios

# Dart-only update to an already published release
shorebird patch --platforms android --release-version 1.0.0+1
shorebird patch --platforms ios --release-version 1.0.0+1
```

Patches must not contain native Android/iOS changes. Native changes require a
new store release. iOS releases and patches require macOS/Xcode and the normal
Apple signing setup.

Android release builds load the release keystore configuration from
`android/key.properties`. Keep that file, keystores and passwords out of Git.

### Source versions and patch targets

The source version is now `0.1.22+24`. A patch targets an already installed
release and does not change that release's Android version name/code. For the
current Android base release, use:

```powershell
shorebird patch --platforms android --release-version 0.1.21+23 --build-name 0.1.21 --build-number 23 --track stable
```

The source version `0.1.22+24` is reserved for the next full release. Preserve
the target release's bundled assets and native configuration when patching.

## GitHub Actions

The manual workflow at `.github/workflows/shorebird.yml` supports both release
and patch operations for Android and iOS. Add a repository secret named
`SHOREBIRD_TOKEN`, then use **Actions → Shorebird release or patch → Run
workflow**.

For a patch, provide the exact existing Shorebird release version, such as
`1.0.0+1`. The workflow uses Ubuntu for Android and macOS for iOS.

Before the first production Android release, add the repository's signing setup
to the workflow and keep all keystores/passwords in GitHub encrypted secrets.
