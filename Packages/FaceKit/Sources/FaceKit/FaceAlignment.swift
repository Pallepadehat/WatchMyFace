import Foundation

/// Five points on a face, in the camera image's pixels (y up): what face-recognition models are aligned on.
public struct FacePoints: Equatable, Sendable {
    /// On the left of the camera's image (the person's right).
    public var leftEye: ImagePoint
    public var rightEye: ImagePoint
    public var noseTip: ImagePoint
    /// The corner of the mouth on the left of the image.
    public var leftMouth: ImagePoint
    public var rightMouth: ImagePoint

    public init(leftEye: ImagePoint, rightEye: ImagePoint, noseTip: ImagePoint, leftMouth: ImagePoint, rightMouth: ImagePoint) {
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.noseTip = noseTip
        self.leftMouth = leftMouth
        self.rightMouth = rightMouth
    }

    public var all: [ImagePoint] { [leftEye, rightEye, noseTip, leftMouth, rightMouth] }

    public var eyeDistance: Double { hypot(rightEye.x - leftEye.x, rightEye.y - leftEye.y) }
}

/// Turning, scaling and moving, without stretching or mirroring: `x' = a·x − b·y + tx`, `y' = b·x + a·y + ty`.
public struct SimilarityTransform: Equatable, Sendable {
    public var a: Double
    public var b: Double
    public var tx: Double
    public var ty: Double

    public init(a: Double, b: Double, tx: Double, ty: Double) {
        self.a = a
        self.b = b
        self.tx = tx
        self.ty = ty
    }

    public var scale: Double { hypot(a, b) }
    public var rotation: Double { atan2(b, a) }

    public func apply(_ point: ImagePoint) -> ImagePoint {
        ImagePoint(x: a * point.x - b * point.y + tx, y: b * point.x + a * point.y + ty)
    }

    /// The transform that moves `source` points closest to `target` points (least squares), or `nil` if the source
    /// points all sit on one spot.
    public static func fitting(_ source: [ImagePoint], to target: [ImagePoint]) -> SimilarityTransform? {
        guard source.count == target.count, source.count >= 2 else { return nil }
        let count = Double(source.count)
        let sourceMean = ImagePoint(x: source.map(\.x).reduce(0, +) / count, y: source.map(\.y).reduce(0, +) / count)
        let targetMean = ImagePoint(x: target.map(\.x).reduce(0, +) / count, y: target.map(\.y).reduce(0, +) / count)
        var spread = 0.0
        var dot = 0.0
        var cross = 0.0
        for (p, q) in zip(source, target) {
            let px = p.x - sourceMean.x
            let py = p.y - sourceMean.y
            let qx = q.x - targetMean.x
            let qy = q.y - targetMean.y
            spread += px * px + py * py
            dot += px * qx + py * qy
            cross += px * qy - py * qx
        }
        guard spread > 1e-9 else { return nil }
        let a = dot / spread
        let b = cross / spread
        return SimilarityTransform(
            a: a, b: b,
            tx: targetMean.x - (a * sourceMean.x - b * sourceMean.y),
            ty: targetMean.y - (b * sourceMean.x + a * sourceMean.y))
    }
}

/// Lines a face up the way face-recognition models (ArcFace, SFace and their kin) were trained on: a 112-pixel
/// square with the eyes, nose tip and mouth corners on fixed spots.
public enum FaceAlignment {
    /// The standard ArcFace template, for a 112 × 112 crop, with y pointing up like the camera image (the published
    /// numbers have y pointing down: 112 − y).
    public static let template: [ImagePoint] = [
        ImagePoint(x: 38.2946, y: 112 - 51.6963),
        ImagePoint(x: 73.5318, y: 112 - 51.5014),
        ImagePoint(x: 56.0252, y: 112 - 71.7366),
        ImagePoint(x: 41.5493, y: 112 - 92.3655),
        ImagePoint(x: 70.7299, y: 112 - 92.2041),
    ]
    public static let templateSide = 112.0

    /// How far off the template the points may land after the best fit, on average, as a share of the crop. Further
    /// than that, the face is turned too far, half hidden, or Vision put the landmarks in the wrong place, and the
    /// crop wouldn't be a fair picture of the face.
    public static let maximumMisfit = 0.075

    public struct Alignment: Equatable, Sendable {
        /// From the camera image's pixels to the crop's.
        public let transform: SimilarityTransform
        /// Average distance from the template after fitting, as a share of the crop's side.
        public let misfit: Double

        public var isTrustworthy: Bool { misfit <= FaceAlignment.maximumMisfit }
    }

    /// How to move `points` onto the template in a crop of `side` pixels.
    public static func align(_ points: FacePoints, side: Double = templateSide) -> Alignment? {
        let factor = side / templateSide
        let target = template.map { ImagePoint(x: $0.x * factor, y: $0.y * factor) }
        guard let transform = SimilarityTransform.fitting(points.all, to: target) else { return nil }
        let error = zip(points.all, target).map { point, goal in
            let moved = transform.apply(point)
            return hypot(moved.x - goal.x, moved.y - goal.y)
        }
        let misfit = error.reduce(0, +) / Double(error.count) / side
        return Alignment(transform: transform, misfit: misfit)
    }
}
