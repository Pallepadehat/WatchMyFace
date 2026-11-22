import Foundation
import Testing

@testable import FaceKit

@Suite("Unlock guardrails")
struct UnlockPolicyTests {
    let start = Date(timeIntervalSinceReferenceDate: 0)

    func minutes(_ minutes: Double) -> Date { start.addingTimeInterval(minutes * 60) }

    @Test func needsArmingFirst() {
        var policy = UnlockPolicy()
        #expect(policy.block(at: start) == .notArmed)
        policy.arm(at: start)
        #expect(policy.allowsUnlock(at: start))
        policy.disarm()
        #expect(policy.block(at: start) == .notArmed)
    }

    @Test func stopsAfterSittingLockedTooLong() {
        var policy = UnlockPolicy()
        policy.arm(at: start)
        policy.screenLocked(at: minutes(10))
        #expect(policy.allowsUnlock(at: minutes(54)))
        #expect(policy.block(at: minutes(56)) == .lockedTooLong)
    }

    @Test func repeatedLockNotificationsKeepTheFirstTime() {
        var policy = UnlockPolicy()
        policy.arm(at: start)
        policy.screenLocked(at: minutes(0))
        policy.screenLocked(at: minutes(40))
        #expect(policy.block(at: minutes(46)) == .lockedTooLong)
    }

    @Test func aTrippedRuleOutlivesTheUnlock() {
        var policy = UnlockPolicy()
        policy.arm(at: start)
        policy.screenLocked(at: start)
        // Typed the password after an hour away: face unlock stays off until Touch ID arms it again.
        policy.screenUnlocked(at: minutes(60))
        policy.screenLocked(at: minutes(61))
        #expect(policy.block(at: minutes(62)) == .lockedTooLong)
        policy.arm(at: minutes(63))
        #expect(policy.allowsUnlock(at: minutes(63)))
    }

    @Test func usingTheMacUnlockedDoesNotCountAsInactivity() {
        var policy = UnlockPolicy()
        policy.arm(at: start)
        policy.screenLocked(at: minutes(5))
        policy.screenUnlocked(at: minutes(6))
        // Three hours of work, then a lock: fine.
        policy.screenLocked(at: minutes(186))
        #expect(policy.allowsUnlock(at: minutes(190)))
    }

    @Test func stopsAfterTwoDaysArmed() {
        var policy = UnlockPolicy()
        policy.arm(at: start)
        #expect(policy.block(at: start.addingTimeInterval(49 * 3600)) == .armedTooLong)
    }

    @Test func stopsAfterTooManyFailedScans() {
        var policy = UnlockPolicy(limits: .init(maximumFailedScans: 3))
        policy.arm(at: start)
        policy.screenLocked(at: start)
        policy.scanFailed(at: start)
        policy.scanFailed(at: start)
        #expect(policy.allowsUnlock(at: start))
        policy.scanFailed(at: start)
        #expect(policy.block(at: start) == .tooManyFailures)
        policy.screenUnlocked(at: minutes(1))
        #expect(policy.block(at: minutes(1)) == .tooManyFailures)
    }

    @Test func failuresResetOnUnlock() {
        var policy = UnlockPolicy(limits: .init(maximumFailedScans: 3))
        policy.arm(at: start)
        policy.screenLocked(at: start)
        policy.scanFailed(at: start)
        policy.scanFailed(at: start)
        policy.screenUnlocked(at: start)
        policy.screenLocked(at: start)
        policy.scanFailed(at: start)
        #expect(policy.allowsUnlock(at: start))
    }

    @Test func expiryIsTheEarlierLimit() {
        var policy = UnlockPolicy()
        #expect(policy.expiry(at: start) == nil)
        policy.arm(at: start)
        #expect(policy.expiry(at: start) == start.addingTimeInterval(48 * 3600))
        policy.screenLocked(at: minutes(1))
        #expect(policy.expiry(at: minutes(2)) == minutes(46))
    }
}
