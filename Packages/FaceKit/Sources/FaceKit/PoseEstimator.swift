import Foundation

/// A point in the camera image, in pixels, with y pointing up (Vision's convention).
public struct ImagePoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Where the head is pointing, worked out from where the nose sits between the eyes.
///
/// Looking straight ahead, the nose is between the eyes and a little below them. Turning moves it towards the side
/// you turn to, tilting up moves it up towards the eyes. Measured in eye-widths, that's independent of how far
/// you sit from the camera, and its direction can't come out backwards. Everyone's "straight ahead" is a bit
/// different (and the camera is rarely dead center), so the first few frames are taken as straight ahead and
/// everything is measured from there.
public struct PoseEstimator: Sendable {
    /// The camera image is shown mirrored (like a mirror, like FaceTime), so "right" in the pose means the right of
    /// the screen, which is the left of the camera's image.
    public var mirrored: Bool
    /// Frames averaged into "straight ahead" before any pose is reported.
    public let calibrationFrames: Int
    /// Converts eye-widths of nose movement to radians, roughly: the nose sits about half an eye-width in front of
    /// the eyes, so it moves about that times the sine of the turn.
    public static let gain = 1.8

    private var samples: [(x: Double, y: Double)] = []
    private var straight: (x: Double, y: Double)?

    public init(mirrored: Bool = true, calibrationFrames: Int = 8) {
        self.mirrored = mirrored
        self.calibrationFrames = calibrationFrames
    }

    public var isCalibrated: Bool { straight != nil }

    /// The pose for one frame, or `nil` while it's still learning what straight ahead looks like (or the eyes are
    /// on top of each other, which no real face does).
    public mutating func pose(leftEye: ImagePoint, rightEye: ImagePoint, nose: ImagePoint) -> HeadPose? {
        let eyeWidth = hypot(rightEye.x - leftEye.x, rightEye.y - leftEye.y)
        guard eyeWidth > 1 else { return nil }
        let between = ImagePoint(x: (leftEye.x + rightEye.x) / 2, y: (leftEye.y + rightEye.y) / 2)
        let offset = (x: (nose.x - between.x) / eyeWidth, y: (nose.y - between.y) / eyeWidth)

        guard let straight else {
            samples.append(offset)
            if samples.count >= calibrationFrames {
                let xs = samples.map(\.x).sorted()
                let ys = samples.map(\.y).sorted()
                straight = (xs[xs.count / 2], ys[ys.count / 2])
            }
            return nil
        }
        let yaw = (offset.x - straight.x) * Self.gain
        return HeadPose(yaw: mirrored ? -yaw : yaw, pitch: (offset.y - straight.y) * Self.gain)
    }

    public mutating func reset() {
        samples = []
        straight = nil
    }
}
