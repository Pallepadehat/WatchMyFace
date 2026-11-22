import Foundation

/// A face, reduced to a list of numbers by an embedder: two pictures of the same person land close together, two
/// different people further apart. Always stored at unit length, so comparing two is a plain dot product.
public struct FaceEmbedding: Codable, Hashable, Sendable {
    public let values: [Float]

    /// Normalizes `values` to unit length. A zero vector stays zero (and matches nothing).
    public init(_ values: [Float]) {
        let length = sqrt(values.reduce(0) { $0 + $1 * $1 })
        self.values = length > 0 ? values.map { $0 / length } : values
    }

    public var dimension: Int { values.count }

    /// Cosine similarity, from -1 (opposite) through 0 (unrelated) to 1 (identical). Embeddings of different sizes
    /// come from different models and are never similar.
    public func similarity(to other: FaceEmbedding) -> Float {
        guard values.count == other.values.count, !values.isEmpty else { return 0 }
        var dot: Float = 0
        for index in values.indices {
            dot += values[index] * other.values[index]
        }
        return dot
    }

    /// The direction the embeddings agree on: their sum, normalized. `nil` for none, or for a mix of sizes.
    public static func centroid(of embeddings: [FaceEmbedding]) -> FaceEmbedding? {
        guard let dimension = embeddings.first?.dimension, embeddings.allSatisfy({ $0.dimension == dimension }) else {
            return nil
        }
        var sum = [Float](repeating: 0, count: dimension)
        for embedding in embeddings {
            for index in sum.indices {
                sum[index] += embedding.values[index]
            }
        }
        return FaceEmbedding(sum)
    }
}
