import Foundation

/// How alike a face seen by the camera is to one profile.
public struct FaceScore: Equatable, Sendable {
    public let profileID: UUID
    /// The average similarity to the profile's closest samples (``FaceMatcher/neighbors`` of them): the ones taken
    /// at about the same angle, rather than an average over every angle.
    public let similarity: Float
    /// What it has to reach, for this profile.
    public let threshold: Float

    public init(profileID: UUID, similarity: Float, threshold: Float) {
        self.profileID = profileID
        self.similarity = similarity
        self.threshold = threshold
    }

    public var passes: Bool { similarity >= threshold }

    /// How far over (or, negative, under) the threshold it is.
    public var margin: Float { similarity - threshold }
}

/// Compares what the camera sees with the enrolled profiles.
///
/// Each profile gets its own threshold, somewhere between ``floor`` (how alike the embedder finds two different
/// people) and the profile's ``FaceProfile/baseline`` (how alike its own samples are), depending on the
/// ``MatchSensitivity``.
public struct FaceMatcher: Sendable {
    /// Averaging over a couple of the closest samples, not just the closest, keeps one odd sample from deciding.
    public static let neighbors = 2

    public var sensitivity: MatchSensitivity
    /// About how alike the embedder finds faces of two different people. Nothing at or under it ever matches.
    public var floor: Float

    public init(sensitivity: MatchSensitivity, floor: Float) {
        self.sensitivity = sensitivity
        self.floor = floor
    }

    public func threshold(for profile: FaceProfile) -> Float? {
        guard let baseline = profile.baseline else { return nil }
        return sensitivity.threshold(baseline: baseline, floor: floor)
    }

    /// Every enabled, compatible profile's score, best first by how far it clears its own threshold.
    public func scores(for embedding: FaceEmbedding, against profiles: [FaceProfile], modelIdentifier: String)
        -> [FaceScore]
    {
        profiles
            .filter { $0.isEnabled && $0.isCompatible(with: modelIdentifier) }
            .compactMap { profile -> FaceScore? in
                guard let threshold = threshold(for: profile) else { return nil }
                let similarity = Self.nearest(embedding, in: profile.samples)
                return FaceScore(profileID: profile.id, similarity: similarity, threshold: threshold)
            }
            .sorted { $0.margin > $1.margin }
    }

    /// The profile this face belongs to, if any clears its threshold.
    public func match(_ embedding: FaceEmbedding, against profiles: [FaceProfile], modelIdentifier: String)
        -> FaceScore?
    {
        scores(for: embedding, against: profiles, modelIdentifier: modelIdentifier).first { $0.passes }
    }

    /// The average similarity of `embedding` to its ``neighbors`` closest `samples`.
    static func nearest(_ embedding: FaceEmbedding, in samples: [FaceEmbedding]) -> Float {
        let closest = samples.map { $0.similarity(to: embedding) }.sorted(by: >).prefix(neighbors)
        guard !closest.isEmpty else { return -1 }
        return closest.reduce(0, +) / Float(closest.count)
    }
}

/// How strict matching is, as people think of it rather than as a number.
public enum MatchSensitivity: String, CaseIterable, Codable, Sendable {
    /// Unlocks more readily, in poor light or at an angle. Lets lookalikes in more readily too.
    case relaxed
    case balanced
    /// Needs a face nearly as alike as the enrollment's own samples were to each other.
    case strict

    /// How far from the stranger level (`floor`) towards the profile's own `baseline` the threshold sits. Never at
    /// the baseline itself: enrollment frames are taken seconds apart in the same light, so they're more alike than
    /// you'll ever be to them in other light later.
    public func threshold(baseline: Float, floor: Float) -> Float {
        let share: Float
        switch self {
        case .relaxed: share = 0.4
        case .balanced: share = 0.55
        case .strict: share = 0.7
        }
        return floor + max(0, baseline - floor) * share
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
