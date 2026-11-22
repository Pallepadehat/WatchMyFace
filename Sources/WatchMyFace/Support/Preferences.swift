import FaceKit
import Foundation
import Observation

/// Everything you can change in Settings, kept in `UserDefaults`.
///
/// Observable property by property, so a view showing one setting redraws only when that one changes.
@Observable
final class Preferences {
    static let shared = Preferences()

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.scanOnWake: true,
            Key.scanOnLock: false,
            Key.sensitivity: MatchSensitivity.balanced.rawValue,
            Key.requireBlink: false,
            Key.lockedInactivityMinutes: 45,
            Key.hapticsEnabled: true,
            Key.hasCompletedSetup: false,
        ])
        scanOnWake = defaults.bool(forKey: Key.scanOnWake)
        scanOnLock = defaults.bool(forKey: Key.scanOnLock)
        sensitivity = MatchSensitivity(rawValue: defaults.string(forKey: Key.sensitivity) ?? "") ?? .balanced
        requireBlink = defaults.bool(forKey: Key.requireBlink)
        lockedInactivityMinutes = defaults.integer(forKey: Key.lockedInactivityMinutes)
        hapticsEnabled = defaults.bool(forKey: Key.hapticsEnabled)
        hasCompletedSetup = defaults.bool(forKey: Key.hasCompletedSetup)
        cameraID = defaults.string(forKey: Key.cameraID)
    }

    /// Look for a face when the display wakes (opening the lid, a key press on a sleeping Mac).
    var scanOnWake: Bool { didSet { defaults.set(scanOnWake, forKey: Key.scanOnWake) } }
    /// Look for a face right as the screen locks, for when you lock it and stay put.
    var scanOnLock: Bool { didSet { defaults.set(scanOnLock, forKey: Key.scanOnLock) } }
    var sensitivity: MatchSensitivity { didSet { defaults.set(sensitivity.rawValue, forKey: Key.sensitivity) } }
    /// Ask for a blink before unlocking: a photo can't, though a video can.
    var requireBlink: Bool { didSet { defaults.set(requireBlink, forKey: Key.requireBlink) } }
    /// After this long locked, face unlock stops until Touch ID arms it again.
    var lockedInactivityMinutes: Int { didSet { defaults.set(lockedInactivityMinutes, forKey: Key.lockedInactivityMinutes) } }
    var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: Key.hapticsEnabled) } }
    var hasCompletedSetup: Bool { didSet { defaults.set(hasCompletedSetup, forKey: Key.hasCompletedSetup) } }
    /// The camera to use, by `AVCaptureDevice.uniqueID`. `nil` picks the built-in one.
    var cameraID: String? { didSet { defaults.set(cameraID, forKey: Key.cameraID) } }

    var unlockLimits: UnlockPolicy.Limits {
        UnlockPolicy.Limits(lockedInactivity: TimeInterval(lockedInactivityMinutes * 60))
    }

    private enum Key {
        static let scanOnWake = "scanOnWake"
        static let scanOnLock = "scanOnLock"
        static let sensitivity = "sensitivity"
        static let requireBlink = "requireBlink"
        static let lockedInactivityMinutes = "lockedInactivityMinutes"
        static let hapticsEnabled = "hapticsEnabled"
        static let hasCompletedSetup = "hasCompletedSetup"
        static let cameraID = "cameraID"
    }
}
