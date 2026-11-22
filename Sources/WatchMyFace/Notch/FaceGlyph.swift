import Lottie
import SwiftUI

/// The Face ID glyph: rings that sweep in and spin while looking, then fold into a tick. It's the "Face Unlock"
/// Lottie animation in Resources/FaceUnlock.json, played in pieces:
///
/// | Frames   | What happens                                      | Used for                     |
/// | -------- | ------------------------------------------------- | ---------------------------- |
/// | 15 → 66  | rings sweep in, spin, and settle into one circle  | scanning                     |
/// | 66 → 118 | the circle folds into a tick, which holds         | success                      |
/// | 66       | the settled circle, tinted red                    | failure                      |
///
/// The animation also draws its own notch growing and shrinking ("Face BG"); that layer is hidden, since the real
/// notch is ``NotchView``'s and moves with springs.
struct FaceGlyph: NSViewRepresentable {
    enum Phase: Equatable {
        case idle, scanning, success, failure
    }

    let phase: Phase

    /// The view's size for a ring one point across: the animation's canvas is a lot bigger than its ring, so a
    /// ring `d` across needs a view this many `d`s wide and high.
    static let frameToRing = CGSize(width: 3.05, height: 2.56)

    enum Frames {
        static let scanStart: AnimationFrameTime = 15
        static let scanSettled: AnimationFrameTime = 66
        static let tickHeld: AnimationFrameTime = 118
    }

    /// The animation's own green, and Apple's red for "no match".
    private static let green = LottieColor(r: 0.651, g: 0.973, b: 0.592, a: 1)
    private static let red = LottieColor(r: 1, g: 0.35, b: 0.33, a: 1)
    private static let animation = LottieAnimation.named("FaceUnlock", bundle: .main)

    func makeNSView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(animation: Self.animation)
        view.contentMode = .scaleAspectFit
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.loopMode = .playOnce
        view.setValueProvider(FloatValueProvider(0), keypath: AnimationKeypath(keypath: "Face BG.Transform.Opacity"))
        view.currentFrame = Frames.scanStart
        context.coordinator.apply(phase, to: view)
        return view
    }

    func updateNSView(_ view: LottieAnimationView, context: Context) {
        context.coordinator.apply(phase, to: view)
    }

    /// Whatever size SwiftUI offers. Left to itself, the view asks for the animation's full 440 × 370 canvas.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: LottieAnimationView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 440, height: 370))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var current: Phase?

        func apply(_ phase: Phase, to view: LottieAnimationView) {
            guard phase != current else { return }
            let previous = current
            current = phase
            tint(view, phase == .failure ? FaceGlyph.red : FaceGlyph.green)

            switch phase {
            case .idle:
                view.stop()
                view.currentFrame = Frames.scanStart
            case .scanning:
                view.play(fromFrame: Frames.scanStart, toFrame: Frames.scanSettled, loopMode: .playOnce)
            case .success:
                // Straight from wherever the scan got to: a quick match doesn't wait for the rings to settle.
                let from = previous == .scanning ? max(view.realtimeAnimationFrame, Frames.scanStart) : Frames.scanSettled
                view.play(fromFrame: from, toFrame: Frames.tickHeld, loopMode: .playOnce)
            case .failure:
                view.stop()
                view.currentFrame = Frames.scanSettled
            }
        }

        private func tint(_ view: LottieAnimationView, _ color: LottieColor) {
            view.setValueProvider(ColorValueProvider(color), keypath: AnimationKeypath(keypath: "Circle*.**.Color"))
            view.setValueProvider(ColorValueProvider(color), keypath: AnimationKeypath(keypath: "Tick*.**.Color"))
        }
    }
}
