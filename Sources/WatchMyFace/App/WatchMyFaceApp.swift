import SwiftUI

@main
struct WatchMyFaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: delegate.model)
        } label: {
            MenuBarIcon(status: delegate.model.unlock.status)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: delegate.model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
        if LaunchOptions.showSettings { SettingsOpener.open() }
    }
}

/// Opens the Settings window from anywhere, including code that isn't a view.
enum SettingsOpener {
    static func open() {
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
