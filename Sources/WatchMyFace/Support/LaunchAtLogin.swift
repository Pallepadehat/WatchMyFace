import OSLog
import ServiceManagement

/// Opening at login, through the system's own login items list (System Settings › General › Login Items).
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.app.error("Couldn't change Open at Login: \(error.localizedDescription, privacy: .public)")
        }
    }
}
