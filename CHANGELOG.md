# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-11-22

The first release: face unlock for your Mac, right in the notch.

### Added

- 🙂 **Face unlock in the notch.** Wake your Mac and look at it. The notch grows out of the camera housing, the Face ID
  glyph bends into a spinning ring while it looks, closes into a green tick, the padlock springs open ("Welcome back")
  and your password is typed into the lock screen. When it isn't you, the face shakes its head; hover over the notch
  to try again. On Macs without a notch, it floats as an island at the top of the screen.
- 🪞 **A notch that looks like it belongs.** Shaped like the real camera housing, solid black at the top melting into
  clear Liquid Glass, with a Now Playing–style row: glyph, title, subtitle and padlock. It shows on the lock screen.
- 🔄 **Face ID–style setup.** Move your head slowly to complete a ring of ticks. Add more appearances (glasses, a beard,
  someone you trust) any time in Settings › Faces.
- 🛡️ **Guardrails like face unlock on iPhone.** Armed by Touch ID after every launch, and off again after the Mac has
  been locked for 45 minutes (your choice), after two days, or after five missed scans in a row. The password leaves
  memory the moment it stops.
- 🔐 **Private.** Your password is checked when you save it, kept in your keychain and only in memory while armed.
  Faces are stored as numbers, never pictures, in an encrypted file. Nothing leaves your Mac.
- 🎯 **Recognition that adapts.** Faces are compared on eye-aligned, grey crops, against your setup samples from the
  same angle, with a threshold set from your own face. Add a face-recognition Core ML model for sharper matching.
- ⚙️ **Settings** for when to look (on wake, on lock), which camera, match sensitivity, asking for a blink, trackpad
  taps, opening at login, and updates.
- ⬆️ **Updates** with Sparkle, from signed GitHub releases.

[Unreleased]: https://github.com/Pallepadehat/WatchMyFace/compare/v1.0.0...develop
[1.0.0]: https://github.com/Pallepadehat/WatchMyFace/releases/tag/v1.0.0
