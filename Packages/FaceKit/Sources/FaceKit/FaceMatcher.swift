import Foundation

/// How alike a face seen by the camera is to one profile.
public struct FaceScore: Equatable, Sendable {
    public let profileID: UUID
    /// Similarity to the profile's centroid.
    public let centroid: Float
    /// Similarity to the profile's closest single sample.
    public let bestSample: Float
    /// What both have to reach, for this profile.
    public let threshold: Float

    public init(profileID: UUID, centroid: Float, bestSample: Float, threshold: Float) {
        self.profileID = profileID
        self.centroid = centroid
        self.bestSample = bestSample
        self.threshold = threshold
    }

    /// Both have to clear the bar: the centroid alone lets a lookalike in on an average, the best sample alone lets
    /// one lucky frame in.
    public var passes: Bool { centroid >= threshold && bestSample >= threshold }

    /// How far the weaker of the two scores is over (or, negative, under) the threshold.
    public var margin: Float { min(centroid, bestSample) - threshold }
}

/// Compares what the camera sees with the enrolled profiles.
///
/// Each profile gets its own threshold, from how alike its enrollment samples were (``FaceProfile/baseline``) and
/// the chosen ``MatchSensitivity``, never lower than ``floor``.
public struct FaceMatcher: Sendable {
    public var sensitivity: MatchSensitivity
    /// The least similarity that can ever count as a match, whatever the profile. Depends on the embedder.
    public var floor: Float

    public init(sensitivity: MatchSensitivity, floor: Float) {
        self.sensitivity = sensitivity
        self.floor = floor
    }

    public func threshold(for profile: FaceProfile) -> Float? {
        guard let baseline = profile.baseline else { return nil }
        return max(floor, sensitivity.threshold(baseline: baseline))
    }

    /// Every enabled, compatible profile's score, best first by how far it clears its own threshold.
    public func scores(for embedding: FaceEmbedding, against profiles: [FaceProfile], modelIdentifier: String)
        -> [FaceScore]
    {
        profiles
            .filter { $0.isEnabled && $0.isCompatible(with: modelIdentifier) }
            .compactMap { profile -> FaceScore? in
                guard let centroid = profile.centroid, let threshold = threshold(for: profile) else { return nil }
                let best = profile.samples.map { $0.similarity(to: embedding) }.max() ?? -1
                return FaceScore(
                    profileID: profile.id, centroid: centroid.similarity(to: embedding), bestSample: best, threshold: threshold)
            }
            .sorted { $0.margin > $1.margin }
    }

    /// The profile this face belongs to, if any clears its threshold.
    public func match(_ embedding: FaceEmbedding, against profiles: [FaceProfile], modelIdentifier: String)
        -> FaceScore?
    {
        scores(for: embedding, against: profiles, modelIdentifier: modelIdentifier).first { $0.passes }
    }
}

/// How strict matching is, as people think of it rather than as a number.
public enum MatchSensitivity: String, CaseIterable, Codable, Sendable {
    /// Unlocks more readily, in poor light or at an angle. Lets lookalikes in more readily too.
    case relaxed
    case balanced
    /// Needs a face about as alike as the enrollment's own samples were.
    case strict

    /// The threshold for a profile whose samples were `baseline` alike: some share of the way from there down
    /// towards zero similarity, measured in the room between the baseline and a perfect match.
    public func threshold(baseline: Float) -> Float {
        let room = 1 - baseline
        switch self {
        case .relaxed: return baseline - room * 0.6
        case .balanced: return baseline - room * 0.3
        case .strict: return baseline
        }
    }
}

/// Requires the same profile to match several frames in a row before anything is unlocked, so one odd frame (motion
/// blur, a flash of light) can't do it on its own.
public struct MatchStreak: Sendable {
    public let required: Int
    public private(set) var profileID: UUID?
    public private(set) var count = 0

    public init(required: Int) {
        self.required = max(1, required)
    }

    public var isSatisfied: Bool { count >= required }

    /// Adds a frame's result: a match for the same profile extends the streak, anything else starts it over.
    public mutating func record(_ match: UUID?) {
        guard let match else {
            reset()
            return
        }
        if match == profileID {
            count += 1
        } else {
            profileID = match
            count = 1
        }
    }

    public mutating func reset() {
        profileID = nil
        count = 0
    }
}
