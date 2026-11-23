import Foundation
import Testing

@testable import FaceKit

@Suite("Choosing enrollment samples")
struct SampleCollectorTests {
    /// A frame of one face: `axis` plus a little noise that's different for every index, the way frames of one
    /// person scatter around their face. (SplitMix64, so the noise is the same on every run.)
    func frame(_ index: Int, axis: Int = 0) -> FaceEmbedding {
        FaceEmbedding(
            (0..<12).map { dimension in
                var z = UInt64(index * 1000 + dimension + 1) &* 0x9E37_79B9_7F4A_7C15
                z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
                z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
                z ^= z >> 31
                let noise = Float(Double(z >> 11) / Double(1 << 53) * 2 - 1)
                return (dimension == axis ? 1 : 0) + 0.3 * noise
            })
    }

    @Test func skipsNearDuplicatesUnlessSharper() {
        var collector = SampleCollector()
        let kept1 = collector.offer(frame(1), quality: 0.5, in: .front)
        #expect(kept1)
        let kept2 = collector.offer(frame(1), quality: 0.4, in: .front)
        #expect(!kept2)
        #expect(collector.count(in: .front) == 1)
        let kept3 = collector.offer(frame(1), quality: 0.9, in: .front)
        #expect(kept3)
        #expect(collector.count(in: .front) == 1)
        #expect(collector.samples[.front]?.first?.quality == 0.9)
    }

    @Test func aFullDirectionSwapsItsBlurriestForSharper() {
        var collector = SampleCollector()
        let capacity = SampleCollector.capacity(of: .left)
        for index in 0..<capacity { collector.offer(frame(index), quality: Float(index) / 10 + 0.1, in: .left) }
        let kept4 = collector.offer(frame(50), quality: 0.05, in: .left)
        #expect(!kept4)
        let kept5 = collector.offer(frame(51), quality: 0.95, in: .left)
        #expect(kept5)
        #expect(collector.count(in: .left) == capacity)
        #expect(collector.samples[.left]?.map(\.quality).min() == 0.2)
    }

    @Test func eachScanGetsItsOwnRoom() {
        var collector = SampleCollector()
        let capacity = SampleCollector.capacity(of: .front)
        for index in 0..<capacity { collector.offer(frame(index), quality: 0.5, in: .front) }
        collector.nextPass()
        for index in 100..<(100 + capacity) { collector.offer(frame(index), quality: 0.5, in: .front) }
        #expect(collector.count(in: .front) == 2 * capacity)
        #expect(collector.count(in: .front, pass: 1) == capacity)
    }

    @Test func twoScansOfOneFaceAgreeAndOfTwoFacesDont() throws {
        var same = SampleCollector()
        var swapped = SampleCollector()
        for index in 0..<6 {
            same.offer(frame(index), quality: 0.5, in: .front)
            swapped.offer(frame(index), quality: 0.5, in: .front)
        }
        same.nextPass()
        swapped.nextPass()
        for index in 20..<26 {
            same.offer(frame(index), quality: 0.5, in: .front)
            swapped.offer(frame(index, axis: 2), quality: 0.5, in: .front)
        }
        #expect(try #require(same.agreement(between: 0, and: 1)) > 0.9)
        #expect(try #require(swapped.agreement(between: 0, and: 1)) < 0.5)
        #expect(SampleCollector().agreement(between: 0, and: 1) == nil)
    }

    @Test func dropsSamplesThatAgreeWithNothing() {
        var collector = SampleCollector()
        let outlier = FaceEmbedding((0..<12).map { $0 == 11 ? 1 : 0 })
        for index in 0..<8 { collector.offer(frame(index), quality: 0.5, in: .front) }
        collector.offer(outlier, quality: 0.9, in: .up)
        let kept = collector.finalSamples(minimumSimilarity: 0.5)
        #expect(kept.count == 8)
        #expect(!kept.contains(outlier))
    }
}
