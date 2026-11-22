import Foundation

/// The guardrails around face unlock, modeled on the ones Apple put on face unlock for devices without Face ID:
///
/// - It works only after a recent Touch ID (or password) check, which "arms" it.
/// - It stops after the Mac has sat locked for a while (45 minutes by default): whoever comes back to a Mac locked
///   that long types the password once.
/// - It stops after a long stretch armed (48 hours, as Touch ID asks for the password then too).
/// - It stops after a few failed scans in a row, until the password is typed.
///
/// A value type that's handed the time, so every rule is testable without waiting.
public struct UnlockPolicy: Equatable, Sendable {
    public struct Limits: Equatable, Sendable {
        /// How long the Mac may sit locked before face unlock stops.
        public var lockedInactivity: TimeInterval
        /// How long one Touch ID check keeps face unlock armed, however it's used.
        public var maximumArmed: TimeInterval
        /// Failed scans in a row, in one stretch of being locked, before face unlock stops.
        public var maximumFailedScans: Int

        public init(lockedInactivity: TimeInterval = 45 * 60, maximumArmed: TimeInterval = 48 * 3600, maximumFailedScans: Int = 5) {
            self.lockedInactivity = lockedInactivity
            self.maximumArmed = maximumArmed
            self.maximumFailedScans = maximumFailedScans
        }
    }

    /// Why face unlock isn't available right now.
    public enum Block: Equatable, Sendable {
        /// Never armed since launch, or disarmed by hand.
        case notArmed
        /// Locked for longer than ``Limits/lockedInactivity``.
        case lockedTooLong
        /// Armed for longer than ``Limits/maximumArmed``.
        case armedTooLong
        /// ``Limits/maximumFailedScans`` failed scans in a row.
        case tooManyFailures
    }

    public var limits: Limits
    public private(set) var armedAt: Date?
    public private(set) var lockedAt: Date?
    public private(set) var failedScans = 0
    /// Set once a rule trips; only arming again (Touch ID) clears it, so face unlock never quietly comes back.
    public private(set) var tripped: Block?

    public init(limits: Limits = Limits()) {
        self.limits = limits
    }

    /// `nil` when face unlock may run now, otherwise why it may not.
    public func block(at now: Date) -> Block? {
        if let tripped { return tripped }
        guard let armedAt else { return .notArmed }
        if now.timeIntervalSince(armedAt) > limits.maximumArmed { return .armedTooLong }
        if let lockedAt, now.timeIntervalSince(lockedAt) > limits.lockedInactivity { return .lockedTooLong }
        if failedScans >= limits.maximumFailedScans { return .tooManyFailures }
        return nil
    }

    public func allowsUnlock(at now: Date) -> Bool { block(at: now) == nil }

    /// After a successful Touch ID check: everything starts over.
    public mutating func arm(at now: Date) {
        armedAt = now
        failedScans = 0
        tripped = nil
    }

    public mutating func disarm() {
        armedAt = nil
        tripped = nil
        failedScans = 0
    }

    /// The screen locked. A second lock notification while already locked keeps the first time.
    public mutating func screenLocked(at now: Date) {
        if lockedAt == nil { lockedAt = now }
    }

    /// The screen unlocked, by face or by password. A rule that tripped while locked stays tripped: the person typed
    /// the password at the lock screen, which the app can't see, so arming again takes Touch ID.
    public mutating func screenUnlocked(at now: Date) {
        if tripped == nil, let block = block(at: now), block != .notArmed { tripped = block }
        lockedAt = nil
        failedScans = 0
    }

    public mutating func scanFailed(at now: Date) {
        failedScans += 1
        if tripped == nil, failedScans >= limits.maximumFailedScans { tripped = .tooManyFailures }
    }

    /// When face unlock will stop by itself if nothing else happens, for showing "armed until…".
    public func expiry(at now: Date) -> Date? {
        guard allowsUnlock(at: now), let armedAt else { return nil }
        let armedLimit = armedAt.addingTimeInterval(limits.maximumArmed)
        guard let lockedAt else { return armedLimit }
        return min(armedLimit, lockedAt.addingTimeInterval(limits.lockedInactivity))
    }
}
