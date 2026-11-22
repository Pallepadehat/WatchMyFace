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

    @Test func matchesTheClosestEnabledProfile() {
        let alice = FaceProfile(name: "Alice", modelIdentifier: model, samples: [FaceEmbedding([1, 0, 0]), FaceEmbedding([0.9, 0.1, 0])])
        let bob = FaceProfile(name: "Bob", modelIdentifier: model, samples: [FaceEmbedding([0, 1, 0])])
        let matcher = FaceMatcher(threshold: 0.8)

        #expect(matcher.match(FaceEmbedding([0.95, 0.05, 0]), against: [alice, bob], modelIdentifier: model)?.profileID == alice.id)
        #expect(matcher.match(FaceEmbedding([0, 0.98, 0.1]), against: [alice, bob], modelIdentifier: model)?.profileID == bob.id)
        #expect(matcher.match(FaceEmbedding([0, 0, 1]), against: [alice, bob], modelIdentifier: model) == nil)
    }

    @Test func ignoresDisabledProfilesAndOtherModels() {
        var alice = FaceProfile(name: "Alice", modelIdentifier: model, samples: [FaceEmbedding([1, 0])])
        let matcher = FaceMatcher(threshold: 0.5)
        #expect(matcher.match(FaceEmbedding([1, 0]), against: [alice], modelIdentifier: "another-model") == nil)
        alice.isEnabled = false
        #expect(matcher.match(FaceEmbedding([1, 0]), against: [alice], modelIdentifier: model) == nil)
    }

    @Test func bothScoresMustPass() {
        // One sample right on, the rest far off: the best sample passes, the centroid doesn't.
        let lopsided = FaceProfile(
            name: "Lopsided", modelIdentifier: model,
            samples: [FaceEmbedding([1, 0, 0]), FaceEmbedding([0, 1, 0]), FaceEmbedding([0, 0, 1]), FaceEmbedding([0, -1, 0])])
        let score = FaceMatcher(threshold: 0.9).scores(for: FaceEmbedding([1, 0, 0]), against: [lopsided], modelIdentifier: model)
        #expect(score.first?.bestSample ?? 0 > 0.99)
        #expect(score.first?.passes(threshold: 0.9) == false)
    }

    @Test func sensitivityOrdersThresholds() {
        let baseline: Float = 0.6
        #expect(MatchSensitivity.relaxed.threshold(baseline: baseline) < MatchSensitivity.balanced.threshold(baseline: baseline))
        #expect(MatchSensitivity.balanced.threshold(baseline: baseline) < MatchSensitivity.strict.threshold(baseline: baseline))
        #expect(MatchSensitivity.strict.threshold(baseline: baseline) < 1)
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
