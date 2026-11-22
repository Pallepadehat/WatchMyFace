import OSLog

/// The app's loggers, one per area. Watch them with:
///
///     /usr/bin/log stream --predicate 'subsystem == "com.pallepadehat.WatchMyFace"'
///
/// Nothing logged ever includes the password, and face data only as scores.
nonisolated enum Log {
    private static let subsystem = "com.pallepadehat.WatchMyFace"

    static let app = Logger(subsystem: subsystem, category: "App")
    static let camera = Logger(subsystem: subsystem, category: "Camera")
    static let recognition = Logger(subsystem: subsystem, category: "Recognition")
    static let unlock = Logger(subsystem: subsystem, category: "Unlock")
    static let security = Logger(subsystem: subsystem, category: "Security")
    static let notch = Logger(subsystem: subsystem, category: "Notch")
}
