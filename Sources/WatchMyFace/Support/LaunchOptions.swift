import Foundation

/// Launch arguments for working on the app (see .github/CONTRIBUTING.md, "Handy debug flags").
enum LaunchOptions {
    private static let arguments = CommandLine.arguments

    /// Plays the notch through every state on a loop, without a camera: for working on how it looks.
    static var demoNotch: Bool { arguments.contains("--demo-notch") }
    /// Opens the setup window even when setup is done.
    static var showSetup: Bool { arguments.contains("--show-setup") }
    /// Opens Settings at launch.
    static var showSettings: Bool { arguments.contains("--show-settings") }
    /// Turns Sparkle on in a debug build, which otherwise leaves it off.
    static var startUpdater: Bool { arguments.contains("--start-updater") }
}
