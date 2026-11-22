import AppKit

/// The borderless, see-through panel the notch is drawn in. Sits above the menu bar, full-screen apps and the
/// screen saver, never takes focus, and lets clicks through except over the notch itself.
final class NotchWindow: NSPanel {
    /// The highest level Core Graphics hands out publicly, plus one.
    private static let level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)

    init(size: CGSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        // The shadow is drawn by SwiftUI, around the shape, not the window's rectangle.
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        level = Self.level
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        // The notch's own springs do the showing and hiding; AppKit's fade on top would double it.
        animationBehavior = .none
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
