import Foundation
import Testing

@testable import FaceKit

@Suite("Lining faces up")
struct FaceAlignmentTests {
    /// The template, turned, scaled and moved somewhere in a camera frame.
    func face(rotation: Double, scale: Double, at offset: ImagePoint) -> FacePoints {
        let moved = FaceAlignment.template.map { point in
            ImagePoint(
                x: scale * (cos(rotation) * point.x - sin(rotation) * point.y) + offset.x,
                y: scale * (sin(rotation) * point.x + cos(rotation) * point.y) + offset.y)
        }
        return FacePoints(leftEye: moved[0], rightEye: moved[1], noseTip: moved[2], leftMouth: moved[3], rightMouth: moved[4])
    }

    @Test func undoesTurningScalingAndMoving() throws {
        let points = face(rotation: 0.3, scale: 2.5, at: ImagePoint(x: 600, y: 300))
        let alignment = try #require(FaceAlignment.align(points))
        #expect(alignment.misfit < 0.0001)
        #expect(alignment.isTrustworthy)
        #expect(abs(alignment.transform.scale - 1 / 2.5) < 0.0001)
        #expect(abs(alignment.transform.rotation + 0.3) < 0.0001)
        for (point, goal) in zip(points.all, FaceAlignment.template) {
            let moved = alignment.transform.apply(point)
            #expect(abs(moved.x - goal.x) < 0.001 && abs(moved.y - goal.y) < 0.001)
        }
    }

    @Test func scalesToTheCropSize() throws {
        let points = face(rotation: 0, scale: 1, at: ImagePoint(x: 0, y: 0))
        let alignment = try #require(FaceAlignment.align(points, side: 224))
        #expect(abs(alignment.transform.scale - 2) < 0.0001)
    }

    @Test func distrustsLandmarksThatDontLookLikeAFace() throws {
        var points = face(rotation: 0, scale: 3, at: ImagePoint(x: 400, y: 400))
        // The mouth found where an eye should be: Vision got it wrong, or half the face is hidden.
        points.leftMouth = ImagePoint(x: points.leftEye.x, y: points.leftEye.y + 10)
        let alignment = try #require(FaceAlignment.align(points))
        #expect(!alignment.isTrustworthy)
    }

    @Test func refusesPointsOnOneSpot() {
        let spot = ImagePoint(x: 5, y: 5)
        let points = FacePoints(leftEye: spot, rightEye: spot, noseTip: spot, leftMouth: spot, rightMouth: spot)
        #expect(FaceAlignment.align(points) == nil)
    }
}
