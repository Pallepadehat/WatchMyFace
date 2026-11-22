import SwiftUI

/// The notch's silhouette: a body with Apple's continuous ("squircle") bottom corners, and, in notch style, inverted
/// top corners that flare out into the menu bar the way the camera housing itself does.
///
/// The body is inset by `topRadius` on each side to leave room for the flares, so a shape drawn `w` wide has a body
/// `w - 2 × topRadius` wide (see ``NotchGeometry/flare(topRadius:)``). Both radii animate.
nonisolated struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var style: NotchStyle = .notch

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        switch style {
        case .notch: notchPath(in: rect)
        case .island: islandPath(in: rect)
        }
    }

    private func notchPath(in rect: CGRect) -> Path {
        let flare = max(0, min(topRadius, rect.width / 4, rect.height / 2))
        let body = rect.insetBy(dx: flare, dy: 0)
        let bottom = max(0, min(bottomRadius, body.width / 2, body.height))

        var path = Path()
        path.addPath(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: bottom, bottomTrailingRadius: bottom, topTrailingRadius: 0,
                style: .continuous
            ).path(in: body))

        // The flares: the space between the screen's top edge, the body's side and a concave curve. They overlap
        // the body by half a point, so the two never show a hairline seam where they meet.
        let overlap: CGFloat = 0.5
        var left = Path()
        left.move(to: CGPoint(x: rect.minX, y: rect.minY))
        left.addQuadCurve(to: CGPoint(x: body.minX, y: rect.minY + flare), control: CGPoint(x: body.minX, y: rect.minY))
        left.addLine(to: CGPoint(x: body.minX + overlap, y: rect.minY + flare))
        left.addLine(to: CGPoint(x: body.minX + overlap, y: rect.minY))
        left.closeSubpath()
        path.addPath(left)

        var right = Path()
        right.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        right.addQuadCurve(to: CGPoint(x: body.maxX, y: rect.minY + flare), control: CGPoint(x: body.maxX, y: rect.minY))
        right.addLine(to: CGPoint(x: body.maxX - overlap, y: rect.minY + flare))
        right.addLine(to: CGPoint(x: body.maxX - overlap, y: rect.minY))
        right.closeSubpath()
        path.addPath(right)
        return path
    }

    private func islandPath(in rect: CGRect) -> Path {
        let limit = min(rect.width, rect.height) / 2
        return UnevenRoundedRectangle(
            topLeadingRadius: min(topRadius, limit), bottomLeadingRadius: min(bottomRadius, limit),
            bottomTrailingRadius: min(bottomRadius, limit), topTrailingRadius: min(topRadius, limit), style: .continuous
        ).path(in: rect)
    }
}

#Preview("Notch, closed and open") {
    VStack(spacing: 24) {
        NotchShape(topRadius: 8, bottomRadius: 12).frame(width: 200, height: 32)
        NotchShape(topRadius: 18, bottomRadius: 46).frame(width: 250, height: 170)
    }
    .padding(30)
}
