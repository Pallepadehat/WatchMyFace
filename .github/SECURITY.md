# Security Policy

WatchMyFace handles the most sensitive thing on a Mac: the login password. It keeps it in your login keychain, loads it into memory only after Touch ID, and types it into the lock screen when it recognizes your face. It isn't sandboxed, uses Accessibility to type, uses a private window-server API to draw on the lock screen, and updates itself with Sparkle from EdDSA-signed GitHub releases. [docs/SECURITY-MODEL.md](../docs/SECURITY-MODEL.md) explains the design and its limits.

## What isn't a vulnerability

A Mac camera sees in 2D. WatchMyFace can be fooled by a good enough lookalike, photo or video of an enrolled person, and says so during setup. Reports that it can be fooled that way are expected behavior, though better liveness checks are very welcome as pull requests.

## Reporting a vulnerability

Please **don't** open a public issue. Use [GitHub's private vulnerability reporting](https://github.com/Pallepadehat/WatchMyFace/security/advisories/new).

You'll get a response within a week. Fixes are released as soon as they're ready, and reporters are credited unless they'd rather not be.

Especially interesting:

- Any way to read the stored password, or the password in memory, from another process or account.
- Any way to make WatchMyFace type the password anywhere but the lock screen, or while face unlock should be off (not armed, or stopped by a guardrail).
- Any way to get an install to accept an update not signed with the project's Sparkle key.
- Anything that sends data off the Mac. WatchMyFace makes no network requests other than Sparkle's update check.

## Supported versions

Only the latest release receives security fixes.
