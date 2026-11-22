import AppKit

/// The borderless, see-through panel the notch is drawn in. Sits above the menu bar, full-screen apps and the
/// screen saver, never takes focus, and lets clicks through except over the notch itself.
final class NotchWindow: NSPanel {
    /// The top of whatever layer it's in, so in the lock screen's space (see ``LockScreenSpace``) it sits above the
    /// lock screen's own windows, and outside it above the menu bar and full-screen apps.
    private static let level = NSWindow.Level(rawValue: Int(Int32.max - 1))

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
        // Allowed to draw before anyone's logged back in: the lock screen.
        canBecomeVisibleWithoutLogin = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
