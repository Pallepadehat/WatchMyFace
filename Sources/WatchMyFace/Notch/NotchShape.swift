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

    /// One closed outline, clockwise from the top-left tip of the left flare: down the flare's curve, down the left
    /// side, round the bottom, up the right side and out along the right flare. Drawn as a single contour so there's
    /// no seam anywhere: Liquid Glass lights every edge of a shape, inner ones included.
    private func notchPath(in rect: CGRect) -> Path {
        let flare = max(0, min(topRadius, rect.width / 4, rect.height / 2))
        let body = rect.insetBy(dx: flare, dy: 0)
        let bottom = max(0, min(bottomRadius, body.width / 2, body.height - flare))
        let shoulderY = rect.minY + flare

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: body.minX, y: shoulderY), control: CGPoint(x: body.minX, y: rect.minY))
        if let sides = ContinuousCorners.sidesAndBottom(of: body, radius: bottom) {
            for (index, segment) in sides.enumerated() {
                // The sides run up to the very top in the reference; ours stop at the flares.
                let end = index == sides.count - 1 ? CGPoint(x: segment.end.x, y: shoulderY) : segment.end
                segment.append(to: &path, ending: end)
            }
        } else {
            path.addArc(
                tangent1End: CGPoint(x: body.minX, y: body.maxY), tangent2End: CGPoint(x: body.maxX, y: body.maxY), radius: bottom)
            path.addArc(
                tangent1End: CGPoint(x: body.maxX, y: body.maxY), tangent2End: CGPoint(x: body.maxX, y: body.minY), radius: bottom)
            path.addLine(to: CGPoint(x: body.maxX, y: shoulderY))
        }
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: body.maxX, y: rect.minY))
        path.closeSubpath()
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

/// Apple's continuous ("squircle") corners, borrowed from SwiftUI. There's no API for the curve itself, so this
/// draws a rectangle with only its bottom corners rounded and takes its outline apart: everything except the
/// straight top edge, ordered from the top-left corner down the left side, round the bottom and up the right side.
/// Idea from glance (https://github.com/jonnyoo/glance, MIT); this version doesn't depend on the order SwiftUI emits
/// the outline in. `nil` if the outline isn't what's expected, and the caller draws plain round corners instead.
nonisolated private enum ContinuousCorners {
    struct Segment {
        enum Kind {
            case line
            case quad(CGPoint)
            case curve(CGPoint, CGPoint)
        }

        var start: CGPoint
        var end: CGPoint
        var kind: Kind

        var reversed: Segment {
            switch kind {
            case .line: Segment(start: end, end: start, kind: .line)
            case .quad(let control): Segment(start: end, end: start, kind: .quad(control))
            case .curve(let first, let second): Segment(start: end, end: start, kind: .curve(second, first))
            }
        }

        func append(to path: inout Path, ending end: CGPoint) {
            switch kind {
            case .line: path.addLine(to: end)
            case .quad(let control): path.addQuadCurve(to: end, control: control)
            case .curve(let first, let second): path.addCurve(to: end, control1: first, control2: second)
            }
        }
    }

    static func sidesAndBottom(of body: CGRect, radius: CGFloat) -> [Segment]? {
        let reference = UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: radius, bottomTrailingRadius: radius, topTrailingRadius: 0,
            style: .continuous
        ).path(in: body)

        var segments: [Segment] = []
        var start = CGPoint.zero
        var current = CGPoint.zero
        reference.forEach { element in
            switch element {
            case .move(let to):
                start = to
                current = to
            case .line(let to):
                segments.append(Segment(start: current, end: to, kind: .line))
                current = to
            case .quadCurve(let to, let control):
                segments.append(Segment(start: current, end: to, kind: .quad(control)))
                current = to
            case .curve(let to, let first, let second):
                segments.append(Segment(start: current, end: to, kind: .curve(first, second)))
                current = to
            case .closeSubpath:
                segments.append(Segment(start: current, end: start, kind: .line))
                current = start
            }
        }

        func near(_ a: CGPoint, _ b: CGPoint) -> Bool { abs(a.x - b.x) < 0.01 && abs(a.y - b.y) < 0.01 }
        let onTop = { (point: CGPoint) in abs(point.y - body.minY) < 0.01 }
        // Drop the top edge and the zero-size "corners" there.
        let kept = segments.filter { !near($0.start, $0.end) && !(onTop($0.start) && onTop($0.end)) }
        guard kept.count >= 3 else { return nil }

        let topLeft = CGPoint(x: body.minX, y: body.minY)
        let topRight = CGPoint(x: body.maxX, y: body.minY)
        // Make it start at the top-left, whichever way round SwiftUI drew it.
        var ordered = kept
        if let index = ordered.firstIndex(where: { near($0.start, topLeft) }) {
            ordered = Array(ordered[index...] + ordered[..<index])
        } else if let index = ordered.firstIndex(where: { near($0.end, topLeft) }) {
            ordered = Array(ordered[...index].reversed() + ordered[(index + 1)...].reversed()).map(\.reversed)
        } else {
            return nil
        }
        guard near(ordered[0].start, topLeft), let last = ordered.last, near(last.end, topRight) else { return nil }
        return ordered
    }
}
