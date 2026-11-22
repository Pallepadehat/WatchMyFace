import Foundation

/// One enrolled appearance: you, or you with glasses, or someone else you trust with your Mac.
///
/// It holds embeddings from every angle the enrollment covered, plus their centroid. Matching looks at both: the
/// centroid is steady, and the closest single sample catches a pose the average blurs away.
public struct FaceProfile: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var isEnabled: Bool
    public let createdAt: Date
    /// Which embedder made the samples. Embeddings from different models can't be compared, so a profile made by
    /// another model never matches (see ``isCompatible(with:)``) and asks to be scanned again.
    public let modelIdentifier: String
    public private(set) var samples: [FaceEmbedding]
    public private(set) var centroid: FaceEmbedding?
    /// How alike this person's own samples are: the similarity a sample has to the centroid of the others, low end
    /// (the 20th percentile). Matching measures a new face against this rather than a fixed number, so it works the
    /// same for an embedder that spreads faces far apart and one that packs them close.
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
        self.centroid = FaceEmbedding.centroid(of: samples)
        self.baseline = Self.baseline(of: samples)
    }

    static func baseline(of samples: [FaceEmbedding]) -> Float? {
        guard samples.count >= 3 else { return nil }
        let similarities = samples.indices.compactMap { index -> Float? in
            var others = samples
            let sample = others.remove(at: index)
            return FaceEmbedding.centroid(of: others)?.similarity(to: sample)
        }.sorted()
        guard !similarities.isEmpty else { return nil }
        return similarities[similarities.count / 5]
    }

    public func isCompatible(with modelIdentifier: String) -> Bool {
        self.modelIdentifier == modelIdentifier && centroid != nil && baseline != nil
    }
}
