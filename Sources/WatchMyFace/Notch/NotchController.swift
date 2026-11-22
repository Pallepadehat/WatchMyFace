import AppKit
import OSLog
import Observation
import SwiftUI

/// A short message in the notch, beside the camera: an icon on the left, a word or two on the right.
struct NotchNotice: Equatable {
    var symbol: String
    var text: String
    var tint: Color = .white

    static let tryAgain = NotchNotice(symbol: "faceid", text: "Try Again", tint: .white)
    static let touchIDNeeded = NotchNotice(symbol: "touchid", text: "Touch ID", tint: .orange)
    static let noFaces = NotchNotice(symbol: "person.crop.circle.badge.questionmark", text: "Set Up", tint: .orange)
}

/// What the notch is showing.
enum NotchState: Equatable {
    /// The size of the camera housing, so it looks like nothing's there.
    case closed
    case scanning
    case success
    case failure
    case notice(NotchNotice)

    var isExpanded: Bool {
        switch self {
        case .scanning, .success, .failure: true
        case .closed, .notice: false
        }
    }

    var glyphPhase: FaceGlyph.Phase {
        switch self {
        case .scanning: .scanning
        case .success: .success
        case .failure: .failure
        case .closed, .notice: .idle
        }
    }
}

/// Runs the notch: what it shows, and its window.
///
/// Callers just set a state; ``NotchView`` animates to it with springs. ``close()`` waits for the closing spring to
/// finish before taking the window away, so the notch always shrinks back into the camera housing rather than
/// vanishing.
@Observable
final class NotchController {
    private(set) var state: NotchState = .closed
    private(set) var geometry: NotchGeometry
    /// Counts failures, so each one shakes the notch again.
    private(set) var failureCount = 0

    /// Called when the pointer moves onto the notch while it's showing a failure or a notice: hover to retry.
    @ObservationIgnored var onHover: (() -> Void)?

    @ObservationIgnored private var window: NotchWindow?
    @ObservationIgnored private var isOnLockScreen = false
    @ObservationIgnored private var closeTask: Task<Void, Never>?
    @ObservationIgnored private var hoverTimer: Timer?
    @ObservationIgnored private var pointerWasInside = false

    init() {
        geometry =
            NotchGeometry.preferredScreen().map(NotchGeometry.forScreen)
            ?? NotchGeometry(closedSize: CGSize(width: 92, height: 26), style: .island)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
    }

    var isVisible: Bool { window?.isVisible ?? false }

    /// Shows `state`, growing out of the housing if the notch wasn't showing.
    func show(_ newState: NotchState) {
        closeTask?.cancel()
        closeTask = nil
        if !isVisible {
            // Appear at the housing's size first, so there's something to grow from.
            state = .closed
            orderFront()
            // Let the closed frame render before the spring starts.
            DispatchQueue.main.async { [weak self] in self?.apply(newState) }
        } else {
            apply(newState)
        }
    }

    /// Shrinks back into the housing, then hides the window.
    func close() async {
        guard isVisible else { return }
        apply(.closed)
        let task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: NotchGeometry.closeDuration)
            guard !Task.isCancelled, let self, self.state == .closed else { return }
            self.orderOut()
        }
        closeTask = task
        await task.value
    }

    private func apply(_ newState: NotchState) {
        guard newState != state else { return }
        if newState == .failure { failureCount += 1 }
        switch newState {
        case .scanning: Haptics.perform(.generic)
        case .success: Haptics.perform(.levelChange)
        default: break
        }
        state = newState
        updateHoverTracking()
    }

    // MARK: Window

    private func orderFront() {
        let window = self.window ?? makeWindow()
        position(window)
        window.orderFrontRegardless()
        if LockMonitor.isScreenLocked, let space = LockScreenSpace.shared {
            space.add(window)
            isOnLockScreen = true
        }
        Log.notch.debug("Shown\(self.isOnLockScreen ? " on the lock screen" : "", privacy: .public)")
    }

    private func orderOut() {
        guard let window else { return }
        if isOnLockScreen {
            LockScreenSpace.shared?.remove(window)
            isOnLockScreen = false
        }
        window.orderOut(nil)
        updateHoverTracking()
    }

    private func makeWindow() -> NotchWindow {
        let window = NotchWindow(size: geometry.windowSize)
        window.contentView = NSHostingView(rootView: NotchView(controller: self))
        self.window = window
        return window
    }

    private func position(_ window: NotchWindow) {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height))
    }

    private func screensChanged() {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        let newGeometry = NotchGeometry.forScreen(screen)
        guard newGeometry != geometry else {
            if let window { position(window) }
            return
        }
        // A different housing (or none): the window is sized for the old one, so start a fresh one.
        geometry = newGeometry
        let wasVisible = isVisible
        orderOut()
        window = nil
        if wasVisible { orderFront() }
    }

    // MARK: Hover to retry

    /// While the notch offers a retry, watch where the pointer is. The window lets every click through (so nothing
    /// under it is blocked) and therefore gets no mouse events of its own; a few position checks a second do instead.
    private func updateHoverTracking() {
        let wantsHover: Bool
        switch state {
        case .failure, .notice: wantsHover = isVisible
        default: wantsHover = false
        }
        if wantsHover, hoverTimer == nil {
            pointerWasInside = pointerIsOverNotch()
            let timer = Timer(timeInterval: 1.0 / 20, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.checkPointer() }
            }
            RunLoop.main.add(timer, forMode: .common)
            hoverTimer = timer
        } else if !wantsHover {
            hoverTimer?.invalidate()
            hoverTimer = nil
        }
    }

    private func checkPointer() {
        let inside = pointerIsOverNotch()
        defer { pointerWasInside = inside }
        guard inside, !pointerWasInside else { return }
        Haptics.perform(.alignment)
        onHover?()
    }

    private func pointerIsOverNotch() -> Bool {
        guard let screen = NotchGeometry.preferredScreen() else { return false }
        let size = state.isExpanded ? geometry.expandedSize : geometry.compactSize
        let rect = NSRect(
            x: screen.frame.midX - size.width / 2 - 8, y: screen.frame.maxY - size.height - 8,
            width: size.width + 16, height: size.height + 8)
        return rect.contains(NSEvent.mouseLocation)
    }
}
