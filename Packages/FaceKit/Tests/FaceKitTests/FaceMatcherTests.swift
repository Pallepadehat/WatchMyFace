import Foundation
import Testing

@testable import FaceKit

@Suite("Embeddings and matching")
struct FaceMatcherTests {
    let model = "test-model"

    @Test func embeddingsAreNormalized() {
        let embedding = FaceEmbedding([3, 4])
        #expect(abs(embedding.values[0] - 0.6) < 0.0001)
        #expect(abs(embedding.values[1] - 0.8) < 0.0001)
        #expect(abs(embedding.similarity(to: embedding) - 1) < 0.0001)
    }

    @Test func zeroAndMismatchedEmbeddingsMatchNothing() {
        #expect(FaceEmbedding([0, 0]).similarity(to: FaceEmbedding([1, 0])) == 0)
        #expect(FaceEmbedding([1, 0]).similarity(to: FaceEmbedding([1, 0, 0])) == 0)
        #expect(FaceEmbedding.centroid(of: [FaceEmbedding([1, 0]), FaceEmbedding([1, 0, 0])]) == nil)
        #expect(FaceEmbedding.centroid(of: []) == nil)
    }

    @Test func centroidPointsBetweenSamples() throws {
        let centroid = try #require(FaceEmbedding.centroid(of: [FaceEmbedding([1, 0]), FaceEmbedding([0, 1])]))
        #expect(abs(centroid.values[0] - centroid.values[1]) < 0.0001)
    }

    /// Samples scattered a little around `direction`, like enrollment frames of one person.
    func samples(around direction: [Float], spread: Float = 0.05, count: Int = 8) -> [FaceEmbedding] {
        (0..<count).map { index in
            FaceEmbedding(direction.enumerated().map { axis, value in value + spread * sin(Float(index * 7 + axis * 3)) })
        }
    }

    @Test func baselineNeedsAFewSamples() {
        #expect(FaceProfile(name: "One", modelIdentifier: model, samples: [FaceEmbedding([1, 0])]).baseline == nil)
        let profile = FaceProfile(name: "Many", modelIdentifier: model, samples: samples(around: [1, 0, 0, 0]))
        #expect((profile.baseline ?? 0) > 0.9)
    }

    @Test func matchesTheClosestEnabledProfile() {
        let alice = FaceProfile(name: "Alice", modelIdentifier: model, samples: samples(around: [1, 0, 0, 0]))
        let bob = FaceProfile(name: "Bob", modelIdentifier: model, samples: samples(around: [0, 1, 0, 0]))
        let matcher = FaceMatcher(sensitivity: .balanced, floor: 0.3)

        #expect(matcher.match(FaceEmbedding([1, 0.02, 0, 0]), against: [alice, bob], modelIdentifier: model)?.profileID == alice.id)
        #expect(matcher.match(FaceEmbedding([0.01, 1, 0.02, 0]), against: [alice, bob], modelIdentifier: model)?.profileID == bob.id)
        #expect(matcher.match(FaceEmbedding([0, 0, 1, 0]), against: [alice, bob], modelIdentifier: model) == nil)
        // Halfway between the two is neither.
        #expect(matcher.match(FaceEmbedding([1, 1, 0, 0]), against: [alice, bob], modelIdentifier: model) == nil)
    }

    @Test func ignoresDisabledProfilesAndOtherModels() {
        var alice = FaceProfile(name: "Alice", modelIdentifier: model, samples: samples(around: [1, 0]))
        let matcher = FaceMatcher(sensitivity: .relaxed, floor: 0)
        #expect(matcher.match(FaceEmbedding([1, 0]), against: [alice], modelIdentifier: "another-model") == nil)
        alice.isEnabled = false
        #expect(matcher.match(FaceEmbedding([1, 0]), against: [alice], modelIdentifier: model) == nil)
    }

    @Test func theFloorAlwaysHolds() {
        // Samples all over the place make a low baseline; the floor still keeps strangers out.
        let scattered = FaceProfile(name: "Scattered", modelIdentifier: model, samples: samples(around: [1, 0, 0], spread: 1.5))
        let matcher = FaceMatcher(sensitivity: .relaxed, floor: 0.8)
        #expect(matcher.threshold(for: scattered) ?? 0 >= 0.8)
    }

    @Test func bothScoresMustPass() {
        let score = FaceScore(profileID: UUID(), centroid: 0.7, bestSample: 0.99, threshold: 0.8)
        #expect(!score.passes)
        #expect(abs(score.margin + 0.1) < 0.0001)
    }

    @Test func sensitivityOrdersThresholds() {
        let baseline: Float = 0.9
        #expect(MatchSensitivity.relaxed.threshold(baseline: baseline) < MatchSensitivity.balanced.threshold(baseline: baseline))
        #expect(MatchSensitivity.balanced.threshold(baseline: baseline) < MatchSensitivity.strict.threshold(baseline: baseline))
        #expect(MatchSensitivity.strict.threshold(baseline: baseline) == baseline)
    }

    @Test func streakNeedsTheSameProfileInARow() {
        let alice = UUID()
        let bob = UUID()
        var streak = MatchStreak(required: 3)
        streak.record(alice)
        streak.record(alice)
        #expect(!streak.isSatisfied)
        streak.record(bob)
        #expect(streak.count == 1)
        streak.record(bob)
        streak.record(nil)
        #expect(streak.count == 0)
        streak.record(alice)
        streak.record(alice)
        streak.record(alice)
        #expect(streak.isSatisfied && streak.profileID == alice)
    }
}
