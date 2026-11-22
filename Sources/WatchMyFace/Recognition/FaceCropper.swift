import CoreGraphics
import CoreImage
import CoreVideo
import FaceKit

/// Cuts a face out of a frame the same way every time, so two pictures of a face differ only in the face.
///
/// It's aligned on the eyes: turned so they're level, scaled so they're always the same distance apart, and cut
/// tight around eyes, nose and mouth, leaving out the background and most of the hair, which would otherwise weigh
/// as much as the face. In grey, so the colour of the light (a warm lamp, a blue screen) counts for nothing.
nonisolated enum FaceCropper {
    /// The square's side, in eye distances: from just outside the eyes to just under the mouth.
    private static let sideInEyeWidths = 2.3
    /// How far below the eyes the square's center is, in eye distances: about where the nose tip is.
    private static let centerBelowEyes = 0.45

    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func crop(_ face: FaceSighting, from pixelBuffer: CVPixelBuffer, size: Int) -> CGImage? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let landmarks = face.landmarks else { return looseCrop(face, image, size: size) }

        let left = CGPoint(x: landmarks.leftEye.x, y: landmarks.leftEye.y)
        let right = CGPoint(x: landmarks.rightEye.x, y: landmarks.rightEye.y)
        let eyeWidth = hypot(right.x - left.x, right.y - left.y)
        guard eyeWidth > 4 else { return looseCrop(face, image, size: size) }
        let tilt = atan2(right.y - left.y, right.x - left.x)
        let between = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
        // "Below the eyes" along the face's own down, which is tilted with it (y points up in Core Image).
        let center = CGPoint(
            x: between.x + sin(tilt) * eyeWidth * centerBelowEyes, y: between.y - cos(tilt) * eyeWidth * centerBelowEyes)
        let side = eyeWidth * sideInEyeWidths
        let scale = CGFloat(size) / side

        // Move the face's center to the origin, level the eyes, scale to size, then put the center in the middle.
        let transform = CGAffineTransform(translationX: CGFloat(size) / 2, y: CGFloat(size) / 2)
            .scaledBy(x: scale, y: scale)
            .rotated(by: -tilt)
            .translatedBy(x: -center.x, y: -center.y)
        return render(image.transformed(by: transform), size: size)
    }

    /// Without landmarks: a square around Vision's box.
    private static func looseCrop(_ face: FaceSighting, _ image: CIImage, size: Int) -> CGImage? {
        let extent = image.extent
        let box = face.boundingBox
        let side = max(box.width * extent.width, box.height * extent.height) * 1.1
        let center = CGPoint(x: box.midX * extent.width, y: box.midY * extent.height)
        let scale = CGFloat(size) / side
        let transform = CGAffineTransform(translationX: CGFloat(size) / 2, y: CGFloat(size) / 2)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -center.x, y: -center.y)
        return render(image.transformed(by: transform), size: size)
    }

    private static func render(_ image: CIImage, size: Int) -> CGImage? {
        let grey = image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.05])
        return context.createCGImage(grey, from: CGRect(x: 0, y: 0, width: size, height: size))
    }
}
