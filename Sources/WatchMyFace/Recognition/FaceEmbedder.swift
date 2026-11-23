import CoreGraphics
import CoreML
import FaceKit
import Foundation
import OSLog

/// Turns a cropped face into a ``FaceEmbedding``.
nonisolated protocol FaceEmbedder: Sendable {
    /// Stored with every profile; profiles made by another embedder don't match (see ``FaceProfile/isCompatible(with:)``).
    var modelIdentifier: String { get }
    /// Shown in Settings.
    var displayName: String { get }
    /// The side, in pixels, of the square crop it wants.
    var inputSize: Int { get }
    /// The least similarity that can ever count as a match (``FaceMatcher/floor``).
    var similarityFloor: Float { get }

    func embedding(for face: CGImage) throws -> FaceEmbedding
}

nonisolated enum FaceEmbedderError: LocalizedError {
    case noResult
    case modelLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .noResult: "The face couldn't be measured."
        case .modelLoadFailed(let detail): "The face model couldn't be loaded: \(detail)"
        }
    }
}

/// The embedder to use: your own face-recognition Core ML model if you installed one (see tools/README.md),
/// otherwise the SFace model that ships with the app.
///
/// If neither loads, face unlock doesn't fall back to anything weaker: ``UnavailableEmbedder`` matches nobody.
nonisolated enum FaceEmbedders {
    static func best() -> any FaceEmbedder {
        if let url = CoreMLFaceEmbedder.installedModelURL {
            do {
                return try CoreMLFaceEmbedder(modelURL: url)
            } catch {
                Log.recognition.error("Ignoring the installed face model: \(error.localizedDescription, privacy: .public)")
            }
        }
        do {
            return try CoreMLFaceEmbedder.bundled()
        } catch {
            Log.recognition.fault("The built-in face model didn't load: \(error.localizedDescription, privacy: .public)")
            return UnavailableEmbedder(reason: error.localizedDescription)
        }
    }
}

/// Stands in when no face model loads: measures nothing, so nothing matches and face unlock stays off.
nonisolated struct UnavailableEmbedder: FaceEmbedder {
    let reason: String
    let modelIdentifier = "unavailable"
    let displayName = "None (the face model didn't load)"
    let inputSize = 112
    let similarityFloor: Float = 1

    func embedding(for face: CGImage) throws -> FaceEmbedding {
        throw FaceEmbedderError.modelLoadFailed(reason)
    }
}

/// A face-recognition model in Core ML format: a 112 × 112 RGB face, aligned on five points (``FaceCropper``), in;
/// an embedding out. The app ships SFace (OpenCV Zoo, Apache 2.0, converted by tools/convert_sface.py); you can
/// install another, such as ArcFace.
nonisolated final class CoreMLFaceEmbedder: FaceEmbedder, @unchecked Sendable {
    let modelIdentifier: String
    let displayName: String
    let inputSize = 112
    /// Nothing at or under this cosine similarity ever matches. SFace calls 0.36 "probably the same person" (its
    /// published threshold); unlocking a Mac asks for more than probably. On official portraits, through this same
    /// pipeline, the same person scored 0.65 to 0.99, a father and son 0.33 to 0.49, brothers 0.29 to 0.48, and
    /// strangers 0 to 0.41.
    let similarityFloor: Float = 0.55
    private let model: MLModel
    private let inputName: String
    private let outputName: String

    /// Where to put a model: `~/Library/Application Support/WatchMyFace/Models/FaceEmbedder.mlpackage`.
    static var modelsDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "WatchMyFace/Models", directoryHint: .isDirectory)
    }

    static var installedModelURL: URL? {
        ["FaceEmbedder.mlmodelc", "FaceEmbedder.mlpackage"]
            .map { modelsDirectory.appending(path: $0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// The SFace model in the app's bundle.
    static func bundled() throws -> CoreMLFaceEmbedder {
        guard let url = Bundle.main.url(forResource: "SFace", withExtension: "mlmodelc") else {
            throw FaceEmbedderError.modelLoadFailed("SFace isn't in the app")
        }
        return try CoreMLFaceEmbedder(modelURL: url, identifier: "sface-2021dec-aligned5", name: "SFace (built in)")
    }

    /// Without an `identifier` and `name`, they're made from the file: replacing the model makes old profiles ask
    /// for a rescan.
    init(modelURL: URL, identifier: String? = nil, name: String? = nil) throws {
        do {
            let compiled = modelURL.pathExtension == "mlmodelc" ? modelURL : try MLModel.compileModel(at: modelURL)
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all
            model = try MLModel(contentsOf: compiled, configuration: configuration)
        } catch {
            throw FaceEmbedderError.modelLoadFailed(error.localizedDescription)
        }
        let description = model.modelDescription
        guard let input = description.inputDescriptionsByName.first(where: { $0.value.type == .image })?.key,
            let output = description.outputDescriptionsByName.first(where: { $0.value.type == .multiArray })?.key
        else {
            throw FaceEmbedderError.modelLoadFailed("it needs an image input and an array output")
        }
        inputName = input
        outputName = output
        displayName =
            name ?? (description.metadata[.description] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Core ML face model"
        if let identifier {
            modelIdentifier = identifier
        } else {
            // The file's date stands in for its identity.
            let attributes = try? FileManager.default.attributesOfItem(atPath: modelURL.path)
            let stamp = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            modelIdentifier = "coreml-\(Int(stamp))"
        }
    }

    func embedding(for face: CGImage) throws -> FaceEmbedding {
        guard let constraint = model.modelDescription.inputDescriptionsByName[inputName]?.imageConstraint else {
            throw FaceEmbedderError.noResult
        }
        let value = try MLFeatureValue(cgImage: face, constraint: constraint, options: nil)
        let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: value])
        let result = try model.prediction(from: provider)
        guard let array = result.featureValue(for: outputName)?.multiArrayValue else { throw FaceEmbedderError.noResult }
        let values = (0..<array.count).map { Float(truncating: array[$0]) }
        return FaceEmbedding(values)
    }
}
