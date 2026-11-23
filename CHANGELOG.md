# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- 🧠 **A real face-recognition model.** Faces are now measured by SFace, a face-recognition network that ships in the
  app, instead of Apple's general-purpose image feature print, which saw close relatives as nearly the same person.
  On official portraits, a father and son now score 0.33–0.49 and the same person 0.65–0.99, against an unlock floor
  of 0.55. Existing faces are marked "Made with another face model": scan them again.
- 📐 **Faces lined up like the model expects**: pupils, nose tip and mouth corners moved onto fixed spots, in colour.
  Landmarks that don't fit a face's shape aren't measured at all.
- 🎯 **Only a clear look unlocks**: the head within about 25° of straight, close enough for detail, and three
  matching frames in a row instead of two. Thresholds are stricter at every sensitivity.
- 🔒 If the face model can't load, face unlock stays off rather than falling back to something weaker.

### Added

- 🔁 **Two scans, like Face ID.** Setup now takes two slow circles with the head ("First scan complete", then again),
  for about four times as many samples, from more angles and light. Both scans must look like the same face, or it
  starts over.
- 🔍 **Close up.** The face has to fill a good part of the camera during setup ("Move a little closer"), so the samples
  carry the detail that tells relatives apart.
- ✨ **Only the sharpest frames.** Vision rates every setup frame; near-duplicates are skipped, a sharper frame replaces
  the blurriest one, and samples that agree with nothing are dropped before saving.
- 🚫 **Block someone.** Settings › Faces › Block Someone… scans a person who must never unlock your Mac, such as a
  parent or sibling. Anyone who looks more like them than like you is turned away.

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
