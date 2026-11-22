import AppKit
import CoreGraphics

/// Something that happened to the screen.
enum LockEvent: Equatable {
    case locked
    case unlocked
    /// The display came back on: opening the lid, a key on a sleeping Mac, the screen saver ending.
    case woke
    case willSleep
}

/// Watches the screen lock and sleep, and reports each change through ``onEvent``.
///
/// The notifications are only hints: any app can post `com.apple.screenIsLocked`, so whether the screen is really
/// locked always comes from the window server (``isScreenLocked``).
final class LockMonitor {
    var onEvent: ((LockEvent) -> Void)?

    // Only touched on the main actor, and in deinit, once nothing else can.
    nonisolated(unsafe) private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init() {
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, "com.apple.screenIsLocked", .locked)
        observe(distributed, "com.apple.screenIsUnlocked", .unlocked)
        observe(distributed, "com.apple.screensaver.didstop", .woke)

        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.screensDidWakeNotification.rawValue, .woke)
        observe(workspace, NSWorkspace.didWakeNotification.rawValue, .woke)
        observe(workspace, NSWorkspace.willSleepNotification.rawValue, .willSleep)
    }

    deinit {
        for (center, observer) in observers { center.removeObserver(observer) }
    }

    /// Whether the screen is locked right now, according to the window server.
    nonisolated static var isScreenLocked: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return session["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    private func observe(_ center: NotificationCenter, _ name: String, _ event: LockEvent) {
        let observer = center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onEvent?(event) }
        }
        observers.append((center, observer))
    }
}
