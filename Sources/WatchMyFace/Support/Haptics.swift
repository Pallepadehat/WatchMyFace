import AppKit

/// Trackpad taps that go with the notch: a light one when it opens, a firmer one on success.
enum Haptics {
    static func perform(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard Preferences.shared.hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}
