import CoreGraphics
import CoreImage
import CoreVideo

/// Cuts a face out of a frame the same way every time, so two pictures of a face differ only in the face: a square
/// around it with a little margin, turned upright, at a fixed size.
nonisolated enum FaceCropper {
    /// The margin around Vision's box, as a share of its size: enough to keep the jaw and forehead.
    private static let margin = 0.25
    private static let context = CIContext(options: [.useSoftwareRenderer: false, .cacheIntermediates: false])

    static func crop(_ face: FaceSighting, from pixelBuffer: CVPixelBuffer, size: Int) -> CGImage? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = image.extent
        let box = face.boundingBox
        let side = max(box.width * extent.width, box.height * extent.height) * (1 + 2 * margin)
        let center = CGPoint(x: (box.midX) * extent.width, y: (box.midY) * extent.height)

        // Turn the face upright around its own center, then cut the square out.
        let upright = image.transformed(
            by: CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: -face.roll)
                .translatedBy(x: -center.x, y: -center.y))
        let square = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
        let scale = CGFloat(size) / side
        let output = upright.cropped(to: square)
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: -square.minX, y: -square.minY))
        return context.createCGImage(output, from: CGRect(x: 0, y: 0, width: size, height: size))
    }
}
