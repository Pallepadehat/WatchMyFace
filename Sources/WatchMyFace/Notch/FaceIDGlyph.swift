import SwiftUI

/// The Face ID glyph, animated the way Face ID animates it:
///
/// - **Idle**: the face: four corner brackets around two eyes, a nose and a smile.
/// - **Scanning**: the features fade, and the brackets bend into four arcs of a circle that spins.
/// - **Success**: the arcs close into a ring, it turns green, and a tick draws itself inside.
/// - **Failure**: back to the face, which shakes its head.
///
/// The trick that makes the morph work: a rounded square whose corner radius is half its side *is* a circle. The
/// brackets are four pieces of one rounded-square outline, centered on its corners, so animating the corner radius
/// from a squircle to a circle turns brackets into arcs, and lengthening the pieces closes the ring.
struct FaceIDGlyph: View {
    enum Phase: Equatable {
        case idle, scanning, success, failure
    }

    let phase: Phase
    var size: CGFloat = 44

    @State private var spinStart = Date.now
    /// Where the arcs were left when spinning stopped, so they settle from there rather than jumping.
    @State private var restingAngle: Double = 0
    @State private var shakeCount = 0

    private var isSpinning: Bool { phase == .scanning || phase == .success }
    private var isFace: Bool { phase == .idle || phase == .failure }

    private static let green = Color(red: 0.188, green: 0.82, blue: 0.345)
    private static let degreesPerSecond = 300.0

    var body: some View {
        let lineWidth = size * 0.068
        let color: Color = phase == .success ? Self.green : .white

        ZStack {
            TimelineView(.animation(paused: !isSpinning)) { context in
                FaceIDBrackets(roundness: isFace ? 0 : 1, length: bracketLength)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                    .rotationEffect(.degrees(angle(at: context.date)))
            }

            FaceIDFeatures()
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .opacity(isFace ? 1 : 0)
                .scaleEffect(isFace ? 1 : 0.6)
                .blur(radius: isFace ? 0 : 3)

            FaceIDCheckmark()
                .trim(from: 0, to: phase == .success ? 1 : 0)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth * 1.15, lineCap: .round, lineJoin: .round))
                .animation(phase == .success ? .easeOut(duration: 0.32).delay(0.22) : .easeOut(duration: 0.15), value: phase)
        }
        .frame(width: size, height: size)
        .modifier(HeadShake(trigger: shakeCount))
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: phase)
        .onChange(of: phase) { old, new in
            if new == .scanning, old != .success { spinStart = .now }
            if !(new == .scanning || new == .success), old == .scanning || old == .success {
                settleSpin()
            }
            if new == .failure { shakeCount += 1 }
        }
    }

    /// How much of the outline each bracket covers: a short corner as a face, an arc with gaps while scanning, and
    /// a quarter (so the four meet) for the closed ring.
    private var bracketLength: Double {
        switch phase {
        case .idle, .failure: 0.115
        case .scanning: 0.17
        case .success: 0.25
        }
    }

    private func angle(at date: Date) -> Double {
        guard isSpinning else { return restingAngle }
        return restingAngle + date.timeIntervalSince(spinStart) * Self.degreesPerSecond
    }

    /// Stops the spin where it is and turns it the short way to the nearest resting position: the brackets look the
    /// same every quarter turn, so that's never more than 45°.
    private func settleSpin() {
        let current = angle(at: .now).truncatingRemainder(dividingBy: 90)
        restingAngle = current
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            restingAngle = current > 45 ? 90 : 0
        }
    }
}

/// The four brackets: pieces of one outline that's a squircle at `roundness` 0 and a circle at 1, each centered on a
/// corner and `length` of the whole outline long.
nonisolated private struct FaceIDBrackets: Shape {
    var roundness: Double
    var length: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(roundness, length) }
        set {
            roundness = newValue.first
            length = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        let radius = side * (0.3 + 0.2 * roundness)
        let outline = Self.outline(of: square, radius: radius)

        var brackets = Path()
        for corner in 0..<4 {
            // The outline starts at the top's middle and runs clockwise, so its corners are at ⅛, ⅜, ⅝ and ⅞.
            let center = 0.125 + 0.25 * Double(corner)
            brackets.addPath(outline.trimmedPath(from: center - length / 2, to: center + length / 2))
        }
        return brackets
    }

    /// A rounded square's outline, from the middle of the top edge, clockwise. Its symmetry is what puts each
    /// corner at the same fraction of the length, whatever the radius.
    private static func outline(of rect: CGRect, radius: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.midX, y: rect.minY), radius: radius)
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

/// Eyes, nose and smile.
nonisolated private struct FaceIDFeatures: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        var path = Path()
        // Eyes.
        path.move(to: point(0.34, 0.33))
        path.addLine(to: point(0.34, 0.42))
        path.move(to: point(0.66, 0.33))
        path.addLine(to: point(0.66, 0.42))
        // Nose: down, then a short step left.
        path.move(to: point(0.5, 0.33))
        path.addLine(to: point(0.5, 0.56))
        path.addLine(to: point(0.44, 0.56))
        // Smile.
        path.move(to: point(0.35, 0.67))
        path.addQuadCurve(to: point(0.65, 0.67), control: point(0.5, 0.79))
        return path
    }
}

/// The tick, drawn short stroke first.
nonisolated private struct FaceIDCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.31, y: rect.minY + rect.height * 0.52))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.45, y: rect.minY + rect.height * 0.66))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.7, y: rect.minY + rect.height * 0.37))
        return path
    }
}

/// "No": the face turns left and right a couple of times, in 3D.
private struct HeadShake: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, angle in
            view.rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(0, duration: 0.08)
                CubicKeyframe(-38, duration: 0.14)
                CubicKeyframe(32, duration: 0.2)
                CubicKeyframe(-20, duration: 0.18)
                CubicKeyframe(10, duration: 0.16)
                CubicKeyframe(0, duration: 0.16)
            }
        }
    }
}

#Preview("Face ID glyph") {
    @Previewable @State var phase = FaceIDGlyph.Phase.idle
    VStack(spacing: 24) {
        FaceIDGlyph(phase: phase, size: 96)
        Picker("Phase", selection: $phase) {
            Text("Idle").tag(FaceIDGlyph.Phase.idle)
            Text("Scanning").tag(FaceIDGlyph.Phase.scanning)
            Text("Success").tag(FaceIDGlyph.Phase.success)
            Text("Failure").tag(FaceIDGlyph.Phase.failure)
        }
        .pickerStyle(.segmented)
    }
    .padding(40)
    .background(.black)
}
