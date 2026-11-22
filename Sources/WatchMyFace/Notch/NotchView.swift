import SwiftUI

/// The notch: one shape that springs between the camera housing's size, a wider strip for notices and a panel for
/// the Face ID glyph. Hosted in a fixed-size ``NotchWindow``; only the shape inside moves.
struct NotchView: View {
    let controller: NotchController

    private var state: NotchState { controller.state }
    private var geometry: NotchGeometry { controller.geometry }

    private var bodySize: CGSize {
        switch state {
        case .closed: geometry.closedSize
        case .notice: geometry.compactSize
        case .scanning, .success, .failure: geometry.expandedSize
        }
    }

    private var topRadius: CGFloat { geometry.topRadius(expanded: state.isExpanded) }

    private var shape: NotchShape {
        NotchShape(
            topRadius: topRadius, bottomRadius: geometry.bottomRadius(for: bodySize, expanded: state.isExpanded),
            style: geometry.style)
    }

    var body: some View {
        ZStack(alignment: .top) {
            NotchBackground(shape: shape, solidHeight: state.isExpanded ? geometry.closedSize.height : nil)
            glyph
            notice
        }
        .frame(width: bodySize.width + geometry.flare(topRadius: topRadius), height: bodySize.height)
        .clipShape(shape)
        .shadow(color: .black.opacity(state == .closed ? 0 : 0.35), radius: 14, y: 4)
        .modifier(Shake(trigger: controller.failureCount))
        .offset(y: geometry.style == .island ? NotchGeometry.islandTopGap : 0)
        .animation(state == .closed ? NotchGeometry.closeSpring : NotchGeometry.openSpring, value: state)
        .frame(width: geometry.windowSize.width, height: geometry.windowSize.height, alignment: .top)
        .preferredColorScheme(.dark)
    }

    /// The glyph rides the shape's spring in: it sharpens, grows and fades in as the panel opens, and dissolves the
    /// same way as it closes, rather than being cut off by the shrinking shape.
    private var glyph: some View {
        FaceGlyph(phase: state.glyphPhase)
            .frame(width: NotchGeometry.glyphSize * FaceGlyph.frameToRing.width, height: NotchGeometry.glyphSize * FaceGlyph.frameToRing.height)
            .scaleEffect(state.isExpanded ? 1 : 0.35)
            .blur(radius: state.isExpanded ? 0 : 16)
            .opacity(state.isExpanded ? 1 : 0)
            .modifier(Breathing(isActive: state == .scanning))
            .position(x: (bodySize.width + geometry.flare(topRadius: topRadius)) / 2, y: geometry.glyphCenterY)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var notice: some View {
        let current: NotchNotice? = if case .notice(let notice) = state { notice } else { nil }
        HStack(spacing: 0) {
            Image(systemName: current?.symbol ?? "faceid")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(current?.tint ?? .white)
                .contentTransition(.symbolEffect(.replace))
            Spacer(minLength: geometry.style == .notch ? geometry.closedSize.width : 8)
            Text(current?.text ?? "")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, geometry.flare(topRadius: topRadius) / 2 + 16)
        .frame(height: bodySize.height)
        .opacity(current == nil ? 0 : 1)
        .blur(radius: current == nil ? 8 : 0)
        .scaleEffect(current == nil ? 0.8 : 1)
    }
}

/// The notch's surface, like the Now Playing panel in macOS 26's notch: solid black where it meets the camera
/// housing (so the housing disappears into it), holding black a little further, then melting into clear Liquid Glass
/// at the bottom, where the wallpaper shows through, bent by the glass's edge.
struct NotchBackground: View {
    let shape: NotchShape
    /// How far down it's the housing's black; `nil` keeps it black all the way (the closed and compact states, which
    /// are mostly housing).
    let solidHeight: CGFloat?

    /// Of what's below the housing, the share that stays black before the glass begins.
    private static let hold = 0.3
    /// How dark the glass still is at the very bottom.
    private static let bottomTint = 0.14

    var body: some View {
        GeometryReader { proxy in
            let solid = solidHeight.map { min(1, $0 / max(proxy.size.height, 1)) } ?? 1
            let isGlass = solid < 1
            let fadeStart = solid + (1 - solid) * Self.hold
            ZStack {
                Color.clear.glassEffect(.clear.tint(.black.opacity(0.12)), in: shape)
                shape.fill(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: isGlass ? fadeStart : 1),
                            .init(color: .black.opacity(isGlass ? 0.55 : 1), location: isGlass ? fadeStart + (1 - fadeStart) * 0.45 : 1),
                            .init(color: .black.opacity(isGlass ? Self.bottomTint : 1), location: 1),
                        ], startPoint: .top, endPoint: .bottom))
                // A hairline of light along the glass's edge, only where it's glass: higher up it would show as a
                // line against a dark menu bar.
                shape.stroke(
                    LinearGradient(colors: [.white.opacity(0.05), .white.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
                .mask {
                    LinearGradient(
                        stops: [.init(color: .clear, location: fadeStart), .init(color: .white, location: 1)],
                        startPoint: .top, endPoint: .bottom)
                }
                .opacity(isGlass ? 1 : 0)
            }
        }
    }
}

/// A slow breathe while scanning, so the glyph reads as looking, not frozen.
private struct Breathing: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content.phaseAnimator(isActive ? [1.0, 0.94] : [1.0]) { view, scale in
            view.scaleEffect(scale).opacity(scale == 1 ? 1 : 0.7)
        } animation: { _ in
            .easeInOut(duration: 0.55)
        }
    }
}

/// The macOS password field's "no" shake.
private struct Shake: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat(0), trigger: trigger) { view, offset in
            view.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                for (index, offset) in [-12.0, 10, -8, 6, -3, 0].enumerated() {
                    SpringKeyframe(offset, duration: index == 5 ? 0.12 : 0.06)
                }
            }
        }
    }
}
