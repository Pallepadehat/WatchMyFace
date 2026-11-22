# Contributing to WatchMyFace

Thanks for wanting to help! Bug fixes, polish for the notch, better recognition and liveness checks, and new ideas are
all welcome.

## Getting started

1. Fork and clone the repository.
2. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set your team ID. Optional, but without it every
   rebuild is signed differently, and macOS asks for the camera and Accessibility again.
3. Open `WatchMyFace.xcodeproj` in Xcode 27 or later and press **⌘R**. (The app itself runs on macOS 26 and later.)
4. Run the checks: `./scripts/check.sh` (lint, FaceKit's tests, warning-free Release and Debug builds).

## Where things are

```
Sources/WatchMyFace/
  App/          entry point, AppModel (builds and wires everything), Sparkle updater, notch demo
  Camera/       the capture session and the mirrored preview
  Recognition/  Vision face analysis, upright crops, embedders, the scanner
  Security/     Keychain, the password vault (Touch ID), the encrypted face store
  Unlock/       lock and wake events, the unlock coordinator, typing the password
  Notch/        geometry, shape, window, lock screen space, the view and the Face ID glyph
  Onboarding/   setup: permissions, the circle face scan, the password
  Settings/     a file per tab
  MenuBar/      the menu bar icon and panel
  Support/      preferences, logging, launch options, haptics
  Resources/    FaceUnlock.json (the Lottie animation), assets
Packages/FaceKit/  pure logic with tests: matching, guardrails, enrollment coverage, blinks, secrets
```

[docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) explains how they fit together.

## Handy debug flags

Pass them in the scheme, or to the binary:

| Flag | What it does |
| --- | --- |
| `--demo-notch` | Plays the notch through every state (scanning, success, failure, notices) on a loop, no camera needed |
| `--show-setup` | Opens setup even when it's done |
| `--show-settings` | Opens Settings at launch |
| `--start-updater` | Turns on Sparkle, which debug builds leave off |

Watch the app's log (use `/usr/bin/log`, as zsh has a `log` of its own). It never includes the password:

```sh
/usr/bin/log stream --predicate 'subsystem == "com.pallepadehat.WatchMyFace"'
```

## Testing by hand

FaceKit's logic is covered by `swift test`. The camera, the notch and the lock screen need a person, so for anything
that touches them, go through this before opening a pull request:

- [ ] `--demo-notch`: every state looks right, opens with a spring, closes back into the housing.
- [ ] Setup from scratch (`--show-setup`): permissions, the ring fills as you circle your head, a wrong password is refused.
- [ ] Menu › Try Face Unlock: tick for you, red shake for someone else (or a covered camera).
- [ ] Lock (⌃⌘Q), let the display sleep, wake it: the notch shows on the lock screen and unlocks.
- [ ] Lock, look away until it fails: "Try Again"; hover the notch to look again.
- [ ] Quit and relaunch: face unlock is off until Touch ID.

## Branches

| Branch | What it's for |
| --- | --- |
| `develop` | The default branch. All work lands here, through pull requests. |
| `main` | Production. It only ever gets merges from `develop`, and every release is made from it. |
| `feature/…` | New features, for example `feature/blink-hint`. |
| `fix/…` | Bug fixes, for example `fix/notch-on-external-display`. |
| `chore/…` | Everything else: tooling, CI, docs, dependency bumps. |

Both `develop` and `main` are protected: changes go through a pull request, and CI (**Lint**, **FaceKit tests** and
**Build app**) has to pass.

```sh
git switch develop && git pull
git switch -c fix/whatever-you-are-fixing
# …work, commit…
git push -u origin fix/whatever-you-are-fixing
```

Then open a pull request **into `develop`**.

## Code style

- `swift format lint --strict -r Sources Packages/FaceKit scripts` must report nothing; `swift format -i -r …` fixes it.
- No warnings in our own code.
- Logic that doesn't need a camera or a window goes in FaceKit, with tests.
- Comments say why, in plain words. The password is never logged, printed or kept in a `String` longer than needed
  (see `SecretBytes`).

## Making a release

Releases are made by the maintainer from a Mac with the signing certificate, **from `main`**:

1. On `develop`, bump `MARKETING_VERSION` in the Xcode project (Target › General › Version).
2. Move the `[Unreleased]` entries in `CHANGELOG.md` into a new `## [x.y.z] - date` section, add its link at the
   bottom, and merge to `develop` through a pull request.
3. Open a pull request from `develop` into `main` and merge it.
4. Check out `main`, pull, and run `./scripts/release.sh`. It refuses to run on any other branch, runs
   `./scripts/check.sh`, builds and notarizes `WatchMyFace.dmg`, makes the signed `appcast.xml`, tags the commit
   `vx.y.z` and publishes a GitHub release with both. The app and `install.sh` always pick up the newest release.

### One-time setup: notarizing

Notarizing needs a **Developer ID Application** certificate, your team ID in `Config/Local.xcconfig`, and a saved
notarytool login:

```sh
xcrun notarytool store-credentials watchmyface-notary --apple-id <your Apple ID> --team-id <your team ID>
```

Without a Developer ID certificate, run `./scripts/release.sh --without-notarizing`.

### One-time setup: the Sparkle key

Each release's `appcast.xml` is signed with an EdDSA key called `WatchMyFace` in the maintainer's login keychain; its
public half is `SUPublicEDKey` in `Config/Info.plist`. Sparkle's tools come with the package, so build once
(`./scripts/build.sh`), then:

```sh
TOOLS=build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin
$TOOLS/generate_keys --account WatchMyFace -p                              # print the public key
$TOOLS/generate_keys --account WatchMyFace -x watchmyface-sparkle-key.txt  # back up the private key
$TOOLS/generate_keys --account WatchMyFace -f watchmyface-sparkle-key.txt  # restore it on a new Mac
```

**Back the key up** (a password manager), then delete the file. Without it, copies already out there can't update.
Never commit it; `.gitignore` ignores `*sparkle-key*.txt` as a safety net.

## Reporting bugs

Use the [bug report form](https://github.com/Pallepadehat/WatchMyFace/issues/new?template=bug_report.yml). Security
issues go through [private reporting](https://github.com/Pallepadehat/WatchMyFace/security/advisories/new) instead.

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By taking part, you agree to uphold it.
