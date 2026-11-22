import Foundation

/// Notices a blink from how open the eyes are, frame by frame.
///
/// Openness is the eye's height over its width (the "eye aspect ratio"), averaged over both eyes. Rather than one
/// fixed cutoff, which suits nobody's eyes in particular, it learns this face's open-eye ratio as it goes and calls a
/// blink when the ratio drops well under it and comes back. A printed photo never does that; a screen playing a video
/// can, which is why this is an extra hurdle and not a guarantee.
public struct BlinkDetector: Sendable {
    /// How far under the open-eye ratio counts as closed.
    public let closedFraction: Double
    /// Frames of history the open-eye ratio is taken from.
    public let window: Int
    private var recent: [Double] = []
    private var isClosed = false
    public private(set) var blinks = 0

    public init(closedFraction: Double = 0.6, window: Int = 30) {
        self.closedFraction = closedFraction
        self.window = window
    }

    /// Adds one frame's eye openness. Returns true on the frame a blink completes (the eyes open again).
    @discardableResult
    public mutating func record(openness: Double) -> Bool {
        defer {
            recent.append(openness)
            if recent.count > window { recent.removeFirst() }
        }
        // Needs a few frames to know what open looks like.
        guard recent.count >= 4 else { return false }
        let open = recent.sorted()[recent.count * 3 / 4]
        guard open > 0 else { return false }

        if !isClosed, openness < open * closedFraction {
            isClosed = true
        } else if isClosed, openness > open * (closedFraction + 1) / 2 {
            isClosed = false
            blinks += 1
            return true
        }
        return false
    }

    public mutating func reset() {
        recent = []
        isClosed = false
        blinks = 0
    }
}
