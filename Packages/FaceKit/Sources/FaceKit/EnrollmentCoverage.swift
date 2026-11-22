import Foundation

/// Where a head is pointing, in radians, as seen in the (mirrored) camera preview: `yaw` is positive turned towards
/// the right of the screen, `pitch` positive tilted up.
public struct HeadPose: Equatable, Sendable {
    public var yaw: Double
    public var pitch: Double

    public init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = pitch
    }

    /// How far from looking straight ahead, in radians.
    public var magnitude: Double { (yaw * yaw + pitch * pitch).squareRoot() }

    /// Clockwise from 12 o'clock, 0 ..< 2π: the direction of the turn, as a point on a clock face.
    public var clockAngle: Double {
        let angle = atan2(yaw, pitch)
        return angle < 0 ? angle + 2 * .pi : angle
    }
}

/// "Move your head slowly to complete the circle": which of the ring's ticks the head has pointed at so far.
///
/// The ring is a clock face of ``tickCount`` ticks, the first at 12 o'clock. Turning the head far enough
/// (``minimumTurn``) in a direction lights the ticks around that direction, ``spread`` either side, so a slow
/// circle with the head fills the ring without having to hit every tick exactly.
public struct EnrollmentCoverage: Equatable, Sendable {
    public let tickCount: Int
    /// The turn, in radians, that counts as looking in a direction rather than straight ahead.
    public let minimumTurn: Double
    /// Ticks lit either side of the one pointed at.
    public let spread: Int
    public private(set) var covered: Set<Int> = []
    /// Set once the head has been seen looking straight ahead, which the ring alone doesn't need but matching does.
    public private(set) var hasFrontal = false

    public init(tickCount: Int = 64, minimumTurn: Double = 0.16, spread: Int = 3) {
        self.tickCount = tickCount
        self.minimumTurn = minimumTurn
        self.spread = spread
    }

    public var fraction: Double { Double(covered.count) / Double(tickCount) }
    public var isComplete: Bool { covered.count == tickCount && hasFrontal }

    /// The tick a pose points at, or `nil` while the head is (nearly) straight.
    public func tick(for pose: HeadPose) -> Int? {
        guard pose.magnitude >= minimumTurn else { return nil }
        let index = Int((pose.clockAngle / (2 * .pi) * Double(tickCount)).rounded())
        return index % tickCount
    }

    /// Records a pose. Returns the ticks it newly lit, for animating just those.
    @discardableResult
    public mutating func record(_ pose: HeadPose) -> Set<Int> {
        if pose.magnitude < minimumTurn * 0.5 { hasFrontal = true }
        guard let center = tick(for: pose) else { return [] }
        var lit: Set<Int> = []
        for offset in -spread...spread {
            let index = ((center + offset) % tickCount + tickCount) % tickCount
            if covered.insert(index).inserted { lit.insert(index) }
        }
        return lit
    }

    public mutating func reset() {
        covered = []
        hasFrontal = false
    }
}

/// The handful of directions an enrollment keeps face samples from: straight ahead and eight around it. Keeping a
/// few from each, rather than every frame, gives matching every angle without a pile of near-identical samples.
public enum PoseBin: Int, CaseIterable, Codable, Sendable {
    case front, up, upRight, right, downRight, down, downLeft, left, upLeft

    public init?(_ pose: HeadPose, minimumTurn: Double = 0.16) {
        if pose.magnitude < minimumTurn * 0.75 {
            self = .front
            return
        }
        guard pose.magnitude >= minimumTurn else { return nil }
        let sector = Int((pose.clockAngle / (2 * .pi) * 8).rounded()) % 8
        self.init(rawValue: sector + 1)
    }
}
