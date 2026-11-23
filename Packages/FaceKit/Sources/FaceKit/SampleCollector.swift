import Foundation

/// Picks which frames of an enrollment become a profile's samples, the way Face ID setup takes two slow circles and
/// keeps the best of what it saw.
///
/// Samples are kept per direction (``PoseBin``), a few per scan. A frame almost identical to one already kept adds
/// nothing, so it only replaces that one if it's sharper; a full direction swaps its blurriest sample for a sharper
/// one. At the end, samples that don't agree with the rest (a landmark slip, someone else leaning in) are dropped.
public struct SampleCollector: Sendable {
    public struct Sample: Sendable {
        public let embedding: FaceEmbedding
        /// Higher is sharper and better lit: Vision's face capture quality, or anything else that ranks frames.
        public let quality: Float
        /// Which scan it came from, counting from 0.
        public let pass: Int
    }

    /// Two frames this alike are the same picture as far as matching goes.
    public static let duplicateSimilarity: Float = 0.97

    public private(set) var samples: [PoseBin: [Sample]] = [:]
    public private(set) var pass = 0

    public init() {}

    /// Samples kept per direction, per scan: most from straight ahead, how you'll usually look at the Mac.
    public static func capacity(of bin: PoseBin) -> Int { bin == .front ? 10 : 4 }

    public func count(in bin: PoseBin, pass: Int? = nil) -> Int {
        (samples[bin] ?? []).filter { pass == nil || $0.pass == pass }.count
    }

    public var totalCount: Int { samples.values.reduce(0) { $0 + $1.count } }

    /// Offers a frame. Returns whether it was kept.
    @discardableResult
    public mutating func offer(_ embedding: FaceEmbedding, quality: Float, in bin: PoseBin) -> Bool {
        let candidate = Sample(embedding: embedding, quality: quality, pass: pass)
        var kept = samples[bin] ?? []
        defer { samples[bin] = kept }

        if let twin = kept.indices.first(where: { kept[$0].embedding.similarity(to: embedding) >= Self.duplicateSimilarity }) {
            guard quality > kept[twin].quality else { return false }
            kept[twin] = candidate
            return true
        }
        let mine = kept.indices.filter { kept[$0].pass == pass }
        if mine.count < Self.capacity(of: bin) {
            kept.append(candidate)
            return true
        }
        guard let worst = mine.min(by: { kept[$0].quality < kept[$1].quality }), quality > kept[worst].quality else {
            return false
        }
        kept[worst] = candidate
        return true
    }

    /// Starts the next scan: its samples are counted (and capped) separately.
    public mutating func nextPass() { pass += 1 }

    public mutating func reset() {
        samples = [:]
        pass = 0
    }

    /// How alike two scans' straight-ahead samples are: the similarity of their centroids. `nil` if either is
    /// missing.
    public func agreement(between first: Int, and second: Int) -> Float? {
        let front = samples[.front] ?? []
        guard let a = FaceEmbedding.centroid(of: front.filter { $0.pass == first }.map(\.embedding)),
            let b = FaceEmbedding.centroid(of: front.filter { $0.pass == second }.map(\.embedding))
        else { return nil }
        return a.similarity(to: b)
    }

    /// Every sample, without the ones that agree with nothing: each is scored as matching would score it (its closest
    /// others), and dropped if that's under `minimumSimilarity`.
    public func finalSamples(minimumSimilarity: Float) -> [FaceEmbedding] {
        let all = samples.values.flatMap { $0 }.map(\.embedding)
        guard all.count > FaceMatcher.neighbors + 1 else { return all }
        return all.indices.compactMap { index in
            var others = all
            let sample = others.remove(at: index)
            return FaceMatcher.nearest(sample, in: others) >= minimumSimilarity ? sample : nil
        }
    }
}
