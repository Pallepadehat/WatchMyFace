import CoreGraphics
import CoreVideo
import FaceKit
import Vision

/// A face found in a camera frame, with what the rest of the app needs to know about it.
nonisolated struct FaceSighting: Sendable {
    /// Where it is, in Vision's normalized coordinates (0...1, origin bottom left) of the unmirrored frame.
    let boundingBox: CGRect
    /// The middle of each eye and of the nose, in the frame's pixels (origin bottom left). `nil` when Vision found
    /// the face but not its landmarks.
    let landmarks: Landmarks?
    /// Eye height over width, both eyes averaged; `nil` without landmarks.
    let eyeOpenness: Double?

    struct Landmarks: Sendable {
        /// The eye on the left of the camera's image (the person's right eye).
        let leftEye: ImagePoint
        let rightEye: ImagePoint
        let nose: ImagePoint
    }

    /// How much of the frame's width the face takes up. A face that's too small is someone in the background.
    var prominence: Double { boundingBox.width }
}

/// Finds faces with Vision: where they are, where their eyes and nose are, and how open the eyes are.
nonisolated enum FaceAnalyzer {
    /// Faces narrower than this share of the frame are passers-by, not the person at the Mac. A MacBook's camera is
    /// wide: someone sitting at arm's length takes up about a sixth of its width, and leaning back, a tenth.
    static let minimumProminence = 0.08

    /// Every face in the frame, largest first.
    static func faces(in pixelBuffer: CVPixelBuffer) throws -> [FaceSighting] {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try handler.perform([request])
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        return (request.results ?? [])
            .map { sighting(from: $0, imageSize: size) }
            .sorted { $0.boundingBox.width > $1.boundingBox.width }
    }

    /// The face of the person at the Mac: the largest one, if it's big enough to be them.
    static func primaryFace(in pixelBuffer: CVPixelBuffer) throws -> FaceSighting? {
        try faces(in: pixelBuffer).first { $0.prominence >= minimumProminence }
    }

    private static func sighting(from observation: VNFaceObservation, imageSize: CGSize) -> FaceSighting {
        let landmarks = observation.landmarks
        func center(_ region: VNFaceLandmarkRegion2D?) -> ImagePoint? {
            guard let points = region?.pointsInImage(imageSize: imageSize), !points.isEmpty else { return nil }
            let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            return ImagePoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
        }
        var points: FaceSighting.Landmarks?
        if let first = center(landmarks?.leftEye), let second = center(landmarks?.rightEye), let nose = center(landmarks?.nose) {
            // Vision's "left eye" is the person's left; order them by where they are in the image instead.
            let (left, right) = first.x < second.x ? (first, second) : (second, first)
            points = FaceSighting.Landmarks(leftEye: left, rightEye: right, nose: nose)
        }
        return FaceSighting(boundingBox: observation.boundingBox, landmarks: points, eyeOpenness: eyeOpenness(landmarks))
    }

    private static func eyeOpenness(_ landmarks: VNFaceLandmarks2D?) -> Double? {
        let ratios = [landmarks?.leftEye, landmarks?.rightEye].compactMap { eye -> Double? in
            guard let points = eye?.normalizedPoints, points.count >= 4 else { return nil }
            let xs = points.map(\.x)
            let ys = points.map(\.y)
            guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max(), maxX > minX else {
                return nil
            }
            return Double((maxY - minY) / (maxX - minX))
        }
        guard !ratios.isEmpty else { return nil }
        return ratios.reduce(0, +) / Double(ratios.count)
    }
}
