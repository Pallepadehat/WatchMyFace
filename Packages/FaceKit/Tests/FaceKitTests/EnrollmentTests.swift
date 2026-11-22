import Foundation
import Testing

@testable import FaceKit

@Suite("Enrollment, blinks and secrets")
struct EnrollmentTests {
    @Test func clockAnglesGoClockwiseFromTwelve() {
        #expect(abs(HeadPose(yaw: 0, pitch: 0.3).clockAngle) < 0.0001)
        #expect(abs(HeadPose(yaw: 0.3, pitch: 0).clockAngle - .pi / 2) < 0.0001)
        #expect(abs(HeadPose(yaw: 0, pitch: -0.3).clockAngle - .pi) < 0.0001)
        #expect(abs(HeadPose(yaw: -0.3, pitch: 0).clockAngle - 3 * .pi / 2) < 0.0001)
    }

    @Test func straightAheadLightsNothing() {
        var coverage = EnrollmentCoverage()
        let lit = coverage.record(HeadPose(yaw: 0.01, pitch: 0))
        #expect(lit.isEmpty)
        #expect(coverage.hasFrontal)
        #expect(coverage.fraction == 0)
    }

    @Test func aTurnLightsTicksAroundItsDirection() {
        var coverage = EnrollmentCoverage(tickCount: 64, spread: 3)
        let lit = coverage.record(HeadPose(yaw: 0, pitch: 0.4))
        #expect(lit == [61, 62, 63, 0, 1, 2, 3])
        // The same direction again lights nothing new.
        let again = coverage.record(HeadPose(yaw: 0.01, pitch: 0.4))
        #expect(again.count <= 1)
    }

    @Test func aFullCircleCompletesTheRing() {
        var coverage = EnrollmentCoverage(tickCount: 64, spread: 3)
        coverage.record(HeadPose(yaw: 0, pitch: 0))
        for step in 0..<32 {
            let angle = Double(step) / 32 * 2 * .pi
            coverage.record(HeadPose(yaw: sin(angle) * 0.35, pitch: cos(angle) * 0.35))
        }
        #expect(coverage.isComplete)
        coverage.reset()
        #expect(coverage.fraction == 0 && !coverage.hasFrontal)
    }

    @Test func poseBins() {
        #expect(PoseBin(HeadPose(yaw: 0, pitch: 0)) == .front)
        #expect(PoseBin(HeadPose(yaw: 0, pitch: 0.4)) == .up)
        #expect(PoseBin(HeadPose(yaw: 0.4, pitch: 0)) == .right)
        #expect(PoseBin(HeadPose(yaw: -0.3, pitch: -0.3)) == .downLeft)
        // Between straight and turned: neither, so it isn't filed under the wrong one.
        #expect(PoseBin(HeadPose(yaw: 0.14, pitch: 0)) == nil)
    }

    @Test func blinkIsADipAndARecovery() {
        var detector = BlinkDetector()
        let results = [Double](repeating: 0.3, count: 10) + [0.1, 0.08, 0.29]
        let completed = results.map { detector.record(openness: $0) }
        #expect(completed == [Bool](repeating: false, count: 12) + [true])
        #expect(detector.blinks == 1)
    }

    @Test func steadyEyesNeverBlink() {
        var detector = BlinkDetector()
        for index in 0..<100 { detector.record(openness: 0.3 + Double(index % 3) * 0.01) }
        #expect(detector.blinks == 0)
    }

    @Test func secretsAreWiped() {
        let secret = SecretBytes(utf8: "hunter2")
        #expect(secret.count == 7)
        #expect(secret.withBytes { String(decoding: $0, as: UTF8.self) } == "hunter2")
        secret.wipe()
        #expect(secret.withBytes { $0.count } == 0)
        secret.wipe()
    }
}
