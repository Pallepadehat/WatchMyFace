# How WatchMyFace keeps your password safe

WatchMyFace has to know your login password: macOS gives apps no way to approve a login, so it unlocks the way you do,
by typing into the lock screen. This page explains where that password lives, when it's usable, and what face unlock
can't protect against.

## What it can't do

**A Mac camera sees in 2D.** Face ID projects thousands of infrared dots to measure a face in 3D. A MacBook's camera
sees a flat picture, so anything that looks enough like you to the camera could unlock your Mac: a close lookalike, a
high-quality photo or a video. "Ask for a blink" in Settings stops a still photo, not a video. A face-recognition model tells most relatives apart
(see [ARCHITECTURE.md](ARCHITECTURE.md#thresholds-that-adapt)), and you can block someone who looks a lot like you in
Settings › Faces, but no 2D camera tells identical twins apart. Use WatchMyFace where
that risk is acceptable to you, and not on a Mac that holds anything you'd need Face ID–grade protection for.

It only ever unlocks the lock screen. It can't approve `sudo`, unlock passwords in apps or System Settings, Apple Pay
or anything else that asks for Touch ID or your password.

## Where the password lives

| When | Where | Protected by |
| --- | --- | --- |
| At rest | Your login keychain, service `com.pallepadehat.WatchMyFace` | The keychain's encryption, and its access list: only WatchMyFace, signed the same way, can read it without your password. `WhenUnlockedThisDeviceOnly`: never synced or backed up to another Mac. |
| Armed | WatchMyFace's memory, in one buffer (`SecretBytes`) | Loaded only after Touch ID (or your password). Overwritten with zeros (`memset_s`) the moment face unlock stops. |
| Typing | Keyboard events to the lock screen | Posted at the HID event tap, the same path as the keyboard. The UTF-16 copy used for the events is zeroed right after. |

The password is checked with Open Directory when you save it, so a wrong one is never typed (which would count as a
failed login). It's never logged, and never leaves your Mac.

## When face unlock works

Face unlock is **armed** by Touch ID, after every launch. While armed, these guardrails stop it, after which you type
your password once and use Touch ID to arm it again:

- **Locked too long.** The Mac sat locked longer than your limit (45 minutes by default).
- **Armed too long.** Two days since Touch ID armed it, as Touch ID itself asks for your password then.
- **Too many misses.** Five failed scans in a row in one stretch of being locked.

When one trips, the password is wiped from memory right away (a timer checks every minute while locked), not at the
next scan. A guardrail that tripped while locked stays tripped after you unlock with your password: the app can't see
what you typed, so only Touch ID re-arms it.

The rules live in `Packages/FaceKit/Sources/FaceKit/UnlockPolicy.swift`, with tests.

## Your face

A profile is a list of embeddings (numbers), never a picture. Profiles are stored in
`~/Library/Application Support/WatchMyFace/Faces.sealed`, encrypted with AES-GCM under a 256-bit key kept in your
keychain. Camera frames are read in memory and dropped; nothing is recorded.

## Permissions and private APIs

- **Camera**, to see you. Only on while scanning or during setup.
- **Accessibility**, to post the keystrokes.
- **Not sandboxed**: Accessibility keystrokes and the lock screen window don't work in the sandbox.
- **A private SkyLight API** (`LockScreenSpace`) draws the notch above the lock screen. If a macOS update removes it,
  the notch just doesn't show there; unlocking still works.

## Updates

Sparkle checks the appcast on the latest GitHub release once a day. Updates must be signed with the project's EdDSA
key and by the same Developer ID as the installed app.

Found a problem? See [SECURITY.md](../.github/SECURITY.md).
