import Foundation

/// One enrolled appearance: you, or you with glasses, or someone else you trust with your Mac.
///
/// It holds embeddings from every angle the enrollment covered. Matching compares a face with the few closest to it,
/// so a face turned a little to the left is compared with the samples taken turned to the left.
public struct FaceProfile: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var isEnabled: Bool
    public let createdAt: Date
    /// Which embedder made the samples. Embeddings from different models can't be compared, so a profile made by
    /// another model never matches (see ``isCompatible(with:)``) and asks to be scanned again.
    public let modelIdentifier: String
    public private(set) var samples: [FaceEmbedding]
    /// How alike this person's own samples are: each sample's similarity to its closest others (as matching would
    /// score it), low end (the 20th percentile). Thresholds are set relative to this rather than a fixed number, so
    /// they suit an embedder that spreads faces far apart as well as one that packs them close.
    public private(set) var baseline: Float?

    public init(
        id: UUID = UUID(), name: String, isEnabled: Bool = true, createdAt: Date = .now, modelIdentifier: String,
        samples: [FaceEmbedding]
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.modelIdentifier = modelIdentifier
        self.samples = samples
        self.baseline = Self.baseline(of: samples)
    }

    static func baseline(of samples: [FaceEmbedding]) -> Float? {
        guard samples.count >= 3 else { return nil }
        let similarities = samples.indices.map { index -> Float in
            var others = samples
            let sample = others.remove(at: index)
            return FaceMatcher.nearest(sample, in: others)
        }.sorted()
        return similarities[similarities.count / 5]
    }

    public func isCompatible(with modelIdentifier: String) -> Bool {
        self.modelIdentifier == modelIdentifier && baseline != nil
    }
}
