import CoreVideo
import FaceKit
import OSLog

/// What one frame showed.
nonisolated struct FrameReading: Sendable {
    let face: FaceSighting
    /// `nil` when the face was found but not measured: too small, turned too far, or its landmarks didn't line up.
    let embedding: FaceEmbedding?
}

/// Camera frame in, face and embedding out: the analyzer, the cropper and the embedder, in that order.
///
/// Stateless, so it's safe to call from the camera's queue.
nonisolated struct FaceRecognizer: Sendable {
    /// What a frame is read for, which sets how good a view of the face it needs before it's measured.
    enum Purpose: Sendable {
        /// Setting up: every angle is wanted, as long as the face lines up.
        case enrollment
        /// Unlocking: only a clear, close, near-frontal look counts. A face turned away or far off is what the model
        /// is worst at, and so where a relative or lookalike would most easily pass.
        case unlock
    }

    /// Fewer pixels than this between the pupils, and the crop would be blown up from too little detail to tell
    /// relatives apart. (The aligned crop puts the pupils 35 pixels apart.)
    static let minimumEyeDistance = 28.0
    /// The most the head may be turned or tilted, in radians, for an unlock frame: about 25 and 20 degrees.
    static let maximumUnlockYaw = 0.44
    static let maximumUnlockPitch = 0.35

    let embedder: any FaceEmbedder

    /// Reads the person at the Mac in this frame, or `nil` if there's nobody (close enough) there.
    func read(_ frame: CameraFrame, for purpose: Purpose, embed: Bool = true) -> FrameReading? {
        do {
            let face = try FaceAnalyzer.primaryFace(in: frame.pixelBuffer, measuringQuality: purpose == .enrollment)
            guard let face else { return nil }
            guard embed, Self.isMeasurable(face, for: purpose) else { return FrameReading(face: face, embedding: nil) }
            let embedding = FaceCropper.crop(face, from: frame.pixelBuffer, size: embedder.inputSize)
                .flatMap { try? embedder.embedding(for: $0) }
            return FrameReading(face: face, embedding: embedding)
        } catch {
            Log.recognition.error("Couldn't read a frame: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func isMeasurable(_ face: FaceSighting, for purpose: Purpose) -> Bool {
        guard let points = face.points, points.eyeDistance >= minimumEyeDistance else { return false }
        guard purpose == .unlock else { return true }
        if let yaw = face.yaw, let pitch = face.pitch {
            return abs(yaw) <= maximumUnlockYaw && abs(pitch) <= maximumUnlockPitch
        }
        // Without Vision's pose, judge the turn by how far the nose tip strays sideways from between the eyes: a
        // quarter of the eye distance is about 25 degrees.
        let eyes = ImagePoint(x: (points.leftEye.x + points.rightEye.x) / 2, y: (points.leftEye.y + points.rightEye.y) / 2)
        let across = (points.rightEye.x - points.leftEye.x, points.rightEye.y - points.leftEye.y)
        let sideways = ((points.noseTip.x - eyes.x) * across.0 + (points.noseTip.y - eyes.y) * across.1) / points.eyeDistance
        return abs(sideways) / points.eyeDistance <= 0.25
    }
}
