import CoreGraphics
import CoreVideo
import FaceKit
import Vision

/// A face found in a camera frame, with what the rest of the app needs to know about it.
nonisolated struct FaceSighting: Sendable {
    /// Where it is, in Vision's normalized coordinates (0...1, origin bottom left) of the unmirrored frame.
    let boundingBox: CGRect
    /// Which way it's pointing, as seen in the mirrored preview.
    let pose: HeadPose
    /// Head tilt, in radians, for straightening the crop.
    let roll: Double
    /// Eye height over width, both eyes averaged; `nil` without landmarks.
    let eyeOpenness: Double?

    /// How much of the frame's width the face takes up. A face that's too small is someone in the background.
    var prominence: Double { boundingBox.width }
}

/// Finds faces with Vision: where they are, which way they point, and how open the eyes are.
nonisolated enum FaceAnalyzer {
    /// Faces narrower than this share of the frame are passers-by, not the person at the Mac.
    static let minimumProminence = 0.16

    /// Vision reports yaw as the camera sees it. The preview, and so the enrollment ring, is mirrored, so a turn to
    /// the right of the screen is the opposite of Vision's sign. Pitch needs no flip.
    private static let yawSign = -1.0
    private static let pitchSign = 1.0

    /// Every face in the frame, largest first.
    static func faces(in pixelBuffer: CVPixelBuffer) throws -> [FaceSighting] {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try handler.perform([request])
        return (request.results ?? [])
            .map(sighting)
            .sorted { $0.boundingBox.width > $1.boundingBox.width }
    }

    /// The face of the person at the Mac: the largest one, if it's big enough to be them.
    static func primaryFace(in pixelBuffer: CVPixelBuffer) throws -> FaceSighting? {
        try faces(in: pixelBuffer).first { $0.prominence >= minimumProminence }
    }

    private static func sighting(from observation: VNFaceObservation) -> FaceSighting {
        FaceSighting(
            boundingBox: observation.boundingBox,
            pose: HeadPose(
                yaw: yawSign * (observation.yaw?.doubleValue ?? 0),
                pitch: pitchSign * (observation.pitch?.doubleValue ?? 0)),
            roll: observation.roll?.doubleValue ?? 0,
            eyeOpenness: eyeOpenness(observation.landmarks)
        )
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
