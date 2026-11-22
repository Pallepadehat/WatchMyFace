import CoreGraphics
import CoreML
import FaceKit
import Foundation
import OSLog
import Vision

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

/// The embedder to use: a face-recognition Core ML model if one's installed (see tools/README.md), Apple's general
/// image feature print otherwise.
nonisolated enum FaceEmbedders {
    static func best() -> any FaceEmbedder {
        if let url = CoreMLFaceEmbedder.installedModelURL {
            do {
                return try CoreMLFaceEmbedder(modelURL: url)
            } catch {
                Log.recognition.error("Ignoring the installed face model: \(error.localizedDescription, privacy: .public)")
            }
        }
        return FeaturePrintEmbedder()
    }
}

/// Apple's Vision feature print: built in, nothing to install, and good at "is this the same picture of the same
/// thing". It isn't trained on faces in particular, so it tells people apart by a smaller margin than a face model
/// does; profile calibration (``FaceProfile/baseline``) is what makes it usable.
nonisolated struct FeaturePrintEmbedder: FaceEmbedder {
    let modelIdentifier = "vision-featureprint-v2"
    let displayName = "Apple Vision feature print"
    let inputSize = 224
    let similarityFloor: Float = 0.6

    func embedding(for face: CGImage) throws -> FaceEmbedding {
        let request = VNGenerateImageFeaturePrintRequest()
        request.imageCropAndScaleOption = .scaleFill
        try VNImageRequestHandler(cgImage: face).perform([request])
        guard let observation = request.results?.first else { throw FaceEmbedderError.noResult }
        return FaceEmbedding(observation.floatValues)
    }
}

/// A face-recognition model in Core ML format (such as ArcFace, converted with tools/convert_model.py): 112×112 RGB
/// image in, an embedding out. Much better at telling people apart than the feature print.
nonisolated final class CoreMLFaceEmbedder: FaceEmbedder, @unchecked Sendable {
    let modelIdentifier: String
    let displayName: String
    let inputSize = 112
    let similarityFloor: Float = 0.35
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

    init(modelURL: URL) throws {
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
        let name = (description.metadata[.description] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Core ML face model"
        displayName = name
        // The file's size and date stand in for its identity: replacing the model makes old profiles ask for a rescan.
        let attributes = try? FileManager.default.attributesOfItem(atPath: modelURL.path)
        let stamp = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        modelIdentifier = "coreml-\(Int(stamp))"
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

extension VNFeaturePrintObservation {
    /// The feature print's numbers as `Float`s, whatever type Vision stored them as.
    nonisolated var floatValues: [Float] {
        switch elementType {
        case .double:
            data.withUnsafeBytes { Array($0.bindMemory(to: Double.self).prefix(elementCount)).map(Float.init) }
        default:
            data.withUnsafeBytes { Array($0.bindMemory(to: Float.self).prefix(elementCount)) }
        }
    }
}
