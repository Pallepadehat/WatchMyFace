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

/// The notch's surface. Like the Now Playing panel on macOS 26: solid black where it meets the camera housing (so
/// the housing disappears into it), shading into dark Liquid Glass further down, where you can just make out the
/// wallpaper through it.
struct NotchBackground: View {
    let shape: NotchShape
    /// How far down it stays solid black; `nil` keeps it black all the way (the closed and compact states, which
    /// are mostly housing).
    let solidHeight: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            let solid = solidHeight.map { min(1, $0 / max(proxy.size.height, 1)) } ?? 1
            ZStack {
                Color.clear.glassEffect(.regular.tint(.black.opacity(0.28)), in: shape)
                shape.fill(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: solid),
                            .init(color: .black.opacity(solid < 1 ? 0.3 : 1), location: 1),
                        ], startPoint: .top, endPoint: .bottom))
                // A hairline of light along the glass edge, only where it's glass: it would show as a line against a
                // dark menu bar higher up.
                shape.stroke(.white.opacity(0.14), lineWidth: 1)
                    .mask {
                        LinearGradient(
                            stops: [.init(color: .clear, location: solid), .init(color: .white, location: min(1, solid + 0.35))],
                            startPoint: .top, endPoint: .bottom)
                    }
                    .opacity(solid < 1 ? 1 : 0)
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
