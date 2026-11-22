import AppKit
import SwiftUI

/// Which silhouette the panel has on a screen.
nonisolated enum NotchStyle: Equatable {
    /// Grows out of the camera housing, with the housing's inverted top corners.
    case notch
    /// A floating island just under the top edge, for screens without a notch.
    case island
}

/// The sizes the notch panel moves between. Pure numbers; ``NotchWindowController`` decides where they go.
///
/// The silhouette and the idea of sizing everything from the real housing come from glance
/// (https://github.com/jonnyoo/glance, MIT).
struct NotchGeometry: Equatable {
    /// The camera housing's size on this screen, or the island's resting size without one.
    let closedSize: CGSize
    let style: NotchStyle

    // MARK: Expanded (scanning, success, failure)

    /// The panel's body while scanning, laid out like the Now Playing panel: the camera housing's row on top, and
    /// below it a row with the Face ID glyph, a title and subtitle, and a lock.
    var expandedSize: CGSize {
        switch style {
        case .notch: CGSize(width: max(closedSize.width + 150, 344), height: closedSize.height + Self.contentRowHeight)
        case .island: CGSize(width: 320, height: Self.contentRowHeight + 8)
        }
    }

    /// The content row's height, below the housing.
    static let contentRowHeight: CGFloat = 70

    /// The Face ID glyph's size.
    static let glyphSize: CGFloat = 38

    // MARK: Compact (notices: "Touch ID to turn on", "Try again")

    /// Wider than the housing, a little taller, with an icon on the left and a word or two on the right.
    var compactSize: CGSize {
        switch style {
        case .notch: CGSize(width: closedSize.width + 2 * Self.compactFlank, height: closedSize.height + 6)
        case .island: CGSize(width: 210, height: 38)
        }
    }

    static let compactFlank: CGFloat = 92

    // MARK: Corners

    /// The top radius is also how far the inverted corners flare out into the menu bar. Kept small, like the real
    /// housing's: a MacBook's notch is nearly square, with just a hint of a curve where it meets the screen edge.
    func topRadius(expanded: Bool) -> CGFloat {
        switch style {
        case .notch: expanded ? 9 : 6
        case .island: expanded ? 34 : closedSize.height / 2
        }
    }

    /// Tight, continuous corners at the bottom, again like the housing, growing only a little as it opens.
    func bottomRadius(for size: CGSize, expanded: Bool) -> CGFloat {
        switch style {
        case .notch: expanded ? 26 : min(11, size.height / 2)
        case .island: expanded ? 34 : size.height / 2
        }
    }

    /// Extra width the flare adds outside the body, in notch style.
    func flare(topRadius: CGFloat) -> CGFloat {
        style == .notch ? topRadius * 2 : 0
    }

    // MARK: Island placement

    /// The island floats this far below the top of the screen.
    static let islandTopGap: CGFloat = 6

    // MARK: Window

    /// The window never changes size (resizing a window mid-animation stutters); it's big enough for the largest
    /// state plus room for the shadow, and SwiftUI animates inside it.
    var windowSize: CGSize {
        let body = CGSize(
            width: max(expandedSize.width + flare(topRadius: topRadius(expanded: true)), compactSize.width + flare(topRadius: 6)),
            height: max(expandedSize.height, compactSize.height))
        return CGSize(width: body.width + 2 * Self.shadowRoom, height: body.height + Self.shadowRoom + Self.islandTopGap)
    }

    static let shadowRoom: CGFloat = 30

    // MARK: Springs

    /// Opening overshoots a touch, like the Dynamic Island; closing settles without bouncing.
    static let openSpring = Animation.spring(response: 0.5, dampingFraction: 0.74)
    static let closeSpring = Animation.spring(response: 0.42, dampingFraction: 1)
    /// How long closing takes to look finished, before the window goes away.
    static let closeDuration: Duration = .milliseconds(460)

    // MARK: Screens

    static func forScreen(_ screen: NSScreen) -> NotchGeometry {
        guard screen.safeAreaInsets.top > 0,
            let left = screen.auxiliaryTopLeftArea?.width, let right = screen.auxiliaryTopRightArea?.width
        else {
            return NotchGeometry(closedSize: CGSize(width: 92, height: 26), style: .island)
        }
        // The housing is what the menu bar areas either side of it leave over.
        return NotchGeometry(
            closedSize: CGSize(width: screen.frame.width - left - right, height: screen.safeAreaInsets.top), style: .notch)
    }

    /// The built-in display if it has a notch, else the main screen.
    @MainActor
    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }
}
