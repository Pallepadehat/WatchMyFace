import AppKit
import OSLog
import Observation

/// Builds every part of the app once and wires them together. Views get what they need from here.
@Observable
final class AppModel {
    let preferences = Preferences.shared
    let vault = PasswordVault()
    let faces = FaceStore()
    let notch = NotchController()
    let updater = Updater()
    let scanner: FaceScanner
    let unlock: UnlockCoordinator

    @ObservationIgnored private lazy var setupWindow = SetupWindowController(model: self)

    init() {
        let recognizer = FaceRecognizer(embedder: FaceEmbedders.best())
        scanner = FaceScanner(camera: CameraSession(), recognizer: recognizer)
        unlock = UnlockCoordinator(vault: vault, faces: faces, scanner: scanner, notch: notch, preferences: preferences)
        Log.app.info("Using \(recognizer.embedder.displayName, privacy: .public)")
    }

    func start() {
        updater.start()
        if LaunchOptions.demoNotch {
            NotchDemo(notch: notch).start()
        } else if !preferences.hasCompletedSetup || LaunchOptions.showSetup {
            showSetup()
        } else if vault.hasStoredPassword {
            // Face unlock starts off after every launch: one Touch ID turns it on.
            Task { try? await unlock.arm() }
        }
    }

    func showSetup(_ purpose: SetupModel.Purpose = .setUp) {
        setupWindow.show(purpose)
    }
}
