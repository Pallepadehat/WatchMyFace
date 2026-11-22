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

    /// A face whose nose is `turn` eye-widths to the image's right and `tilt` up, from a straight-ahead pose.
    func pose(_ estimator: inout PoseEstimator, turn: Double, tilt: Double) -> HeadPose? {
        estimator.pose(
            leftEye: ImagePoint(x: 400, y: 500), rightEye: ImagePoint(x: 500, y: 500),
            nose: ImagePoint(x: 450 + turn * 100, y: 440 + tilt * 100))
    }

    @Test func poseNeedsCalibrationFirst() {
        var estimator = PoseEstimator(calibrationFrames: 3)
        #expect(pose(&estimator, turn: 0, tilt: 0) == nil)
        #expect(pose(&estimator, turn: 0, tilt: 0) == nil)
        #expect(pose(&estimator, turn: 0, tilt: 0) == nil)
        #expect(estimator.isCalibrated)
        let straight = pose(&estimator, turn: 0, tilt: 0)
        #expect(straight.map { $0.magnitude < 0.001 } == true)
    }

    @Test func mirroredPoseFollowsTheScreen() throws {
        var estimator = PoseEstimator(calibrationFrames: 1)
        _ = pose(&estimator, turn: 0, tilt: 0)
        // Nose towards the camera image's left: the person turned to their right, which is the screen's right in
        // the mirrored preview.
        let turnedRight = pose(&estimator, turn: -0.2, tilt: 0)
        let right = try #require(turnedRight)
        #expect(right.yaw > 0.3 && abs(right.pitch) < 0.001)
        let tiltedUp = pose(&estimator, turn: 0, tilt: 0.2)
        let up = try #require(tiltedUp)
        #expect(up.pitch > 0.3)

        var unmirrored = PoseEstimator(mirrored: false, calibrationFrames: 1)
        _ = pose(&unmirrored, turn: 0, tilt: 0)
        let unmirroredTurn = pose(&unmirrored, turn: -0.2, tilt: 0)
        #expect(try #require(unmirroredTurn).yaw < 0)
    }

    @Test func poseIgnoresDistance() throws {
        var near = PoseEstimator(calibrationFrames: 1)
        _ = near.pose(leftEye: ImagePoint(x: 0, y: 0), rightEye: ImagePoint(x: 200, y: 0), nose: ImagePoint(x: 100, y: -120))
        let nearPose = near.pose(leftEye: ImagePoint(x: 0, y: 0), rightEye: ImagePoint(x: 200, y: 0), nose: ImagePoint(x: 60, y: -120))
        let nearTurn = try #require(nearPose)
        var far = PoseEstimator(calibrationFrames: 1)
        _ = far.pose(leftEye: ImagePoint(x: 0, y: 0), rightEye: ImagePoint(x: 50, y: 0), nose: ImagePoint(x: 25, y: -30))
        let farPose = far.pose(leftEye: ImagePoint(x: 0, y: 0), rightEye: ImagePoint(x: 50, y: 0), nose: ImagePoint(x: 15, y: -30))
        let farTurn = try #require(farPose)
        #expect(abs(nearTurn.yaw - farTurn.yaw) < 0.0001)
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
