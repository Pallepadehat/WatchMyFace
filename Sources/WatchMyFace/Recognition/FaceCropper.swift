import CoreGraphics
import CoreImage
import CoreVideo
import FaceKit

/// Cuts a face out of a frame the way face-recognition models were trained to see one.
///
/// The pupils, nose tip and mouth corners are moved onto fixed spots in a square (``FaceAlignment``): turned upright,
/// scaled and centered, so two pictures of a face differ only in the face. In colour, as the model learned faces.
nonisolated enum FaceCropper {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// The aligned face, or `nil` when its landmarks don't line up like a face's (turned too far, half hidden): a
    /// crop like that is no fair picture of anyone, so it isn't measured at all.
    static func crop(_ face: FaceSighting, from pixelBuffer: CVPixelBuffer, size: Int) -> CGImage? {
        guard let points = face.points, let alignment = FaceAlignment.align(points, side: Double(size)),
            alignment.isTrustworthy
        else { return nil }
        let t = alignment.transform
        // Core Image's y points up, like Vision's points and the template, so the transform carries over as is.
        let transform = CGAffineTransform(a: t.a, b: t.b, c: -t.b, d: t.a, tx: t.tx, ty: t.ty)
        // Black where the square reaches past the frame's edge, as the model saw in training.
        let image = CIImage(cvPixelBuffer: pixelBuffer).transformed(by: transform, highQualityDownsample: true)
            .composited(over: CIImage(color: .black))
        return context.createCGImage(image, from: CGRect(x: 0, y: 0, width: size, height: size))
    }
}
