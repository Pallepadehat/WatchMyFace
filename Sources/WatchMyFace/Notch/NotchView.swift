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
            expandedContent
            notice
        }
        .frame(width: panelWidth, height: bodySize.height, alignment: .top)
        .clipShape(shape)
        // Soft and low, like a sheet's: just enough to lift the panel off whatever's under it.
        .shadow(color: .black.opacity(state == .closed ? 0 : 0.22), radius: 22, y: 10)
        .offset(y: geometry.style == .island ? NotchGeometry.islandTopGap : 0)
        .animation(state == .closed ? NotchGeometry.closeSpring : NotchGeometry.openSpring, value: state)
        .frame(width: geometry.windowSize.width, height: geometry.windowSize.height, alignment: .top)
        .preferredColorScheme(.dark)
    }

    private var panelWidth: CGFloat { bodySize.width + geometry.flare(topRadius: topRadius) }

    /// The row under the housing. It rides the shape's spring: it sharpens, grows and fades in as the panel opens,
    /// and dissolves the same way as it closes, rather than being cut off by the shrinking shape.
    private var expandedContent: some View {
        HStack(spacing: 14) {
            FaceIDGlyph(phase: state.glyphPhase, size: NotchGeometry.glyphSize)
                .background { successGlow }
                .modifier(Pop(trigger: state == .success))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .lineLimit(1)
            // A new message blurs in as the old one blurs out, rather than the two crossfading on top of each other.
            .id(title)
            .transition(.blurReplace)
            Spacer(minLength: 8)
            Image(systemName: state == .success ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(state == .success ? Self.green : .white.opacity(state == .failure ? 0.9 : 0.45))
                .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer), options: .nonRepeating))
                .frame(width: 22)
        }
        .padding(.leading, geometry.flare(topRadius: topRadius) / 2 + 22)
        .padding(.trailing, geometry.flare(topRadius: topRadius) / 2 + 24)
        .frame(width: panelWidth, height: NotchGeometry.contentRowHeight)
        .padding(.top, geometry.style == .notch ? geometry.closedSize.height - 4 : 4)
        .scaleEffect(state.isExpanded ? 1 : 0.6, anchor: .top)
        .blur(radius: state.isExpanded ? 0 : 14)
        .opacity(state.isExpanded ? 1 : 0)
        .allowsHitTesting(false)
    }

    private static let green = Color(red: 0.188, green: 0.82, blue: 0.345)

    private var title: String {
        switch state {
        case .success: "Welcome back, \(Self.firstName)"
        case .failure: "Not Recognized"
        default: "Face ID"
        }
    }

    private var subtitle: String {
        switch state {
        case .success: "Unlocking…"
        case .failure: "Hover here to try again"
        default: "Looking for you…"
        }
    }

    private static let firstName = NSFullUserName().split(separator: " ").first.map(String.init) ?? NSUserName()

    /// A soft green light behind the tick, the way a success lights up on Apple's devices.
    private var successGlow: some View {
        Circle()
            .fill(Self.green)
            .blur(radius: 16)
            .scaleEffect(state == .success ? 1.3 : 0.5)
            .opacity(state == .success ? 0.45 : 0)
            .animation(.easeOut(duration: 0.6), value: state == .success)
    }

    @ViewBuilder
    private var notice: some View {
        let current: NotchNotice? = if case .notice(let notice) = state { notice } else { nil }
        HStack(spacing: 0) {
            Image(systemName: current?.symbol ?? "faceid")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(current?.tint ?? .white)
                .contentTransition(.symbolEffect(.replace))
            Spacer(minLength: geometry.style == .notch ? geometry.closedSize.width : 8)
            Text(current?.text ?? "")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
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
    private static let hold = 0.34
    /// How dark the glass still is at the very bottom: smoky, so the glyph keeps its contrast over any wallpaper.
    private static let bottomTint = 0.42

    var body: some View {
        GeometryReader { proxy in
            let solid = solidHeight.map { min(1, $0 / max(proxy.size.height, 1)) } ?? 1
            let isGlass = solid < 1
            let fadeStart = solid + (1 - solid) * Self.hold
            ZStack {
                Color.clear.glassEffect(.clear.tint(.black.opacity(0.22)), in: shape)
                shape.fill(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: isGlass ? fadeStart : 1),
                            .init(color: .black.opacity(isGlass ? 0.72 : 1), location: isGlass ? fadeStart + (1 - fadeStart) * 0.45 : 1),
                            .init(color: .black.opacity(isGlass ? Self.bottomTint : 1), location: 1),
                        ], startPoint: .top, endPoint: .bottom))
                // A hairline of light along the glass's edge, only where it's glass: higher up it would show as a
                // line against a dark menu bar.
                shape.stroke(
                    LinearGradient(colors: [.white.opacity(0.04), .white.opacity(0.22)], startPoint: .top, endPoint: .bottom),
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

/// A small, springy swell as the tick lands.
private struct Pop: ViewModifier {
    let trigger: Bool

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat(1), trigger: trigger) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(1, duration: 0.12)
                SpringKeyframe(1.08, duration: 0.18, spring: .snappy)
                SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            }
        }
    }
}
