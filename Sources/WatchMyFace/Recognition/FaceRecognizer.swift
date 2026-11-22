import CoreVideo
import FaceKit
import OSLog

/// What one frame showed.
nonisolated struct FrameReading: Sendable {
    let face: FaceSighting
    /// `nil` when the face was found but couldn't be measured (a crop off the edge of the frame).
    let embedding: FaceEmbedding?
}

/// Camera frame in, face and embedding out: the analyzer, the cropper and the embedder, in that order.
///
/// Stateless, so it's safe to call from the camera's queue.
nonisolated struct FaceRecognizer: Sendable {
    let embedder: any FaceEmbedder

    /// Reads the person at the Mac in this frame, or `nil` if there's nobody (close enough) there.
    func read(_ frame: CameraFrame, embed: Bool = true) -> FrameReading? {
        do {
            guard let face = try FaceAnalyzer.primaryFace(in: frame.pixelBuffer) else { return nil }
            guard embed else { return FrameReading(face: face, embedding: nil) }
            let embedding = FaceCropper.crop(face, from: frame.pixelBuffer, size: embedder.inputSize)
                .flatMap { try? embedder.embedding(for: $0) }
            return FrameReading(face: face, embedding: embedding)
        } catch {
            Log.recognition.error("Couldn't read a frame: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
