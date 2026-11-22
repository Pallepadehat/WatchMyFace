import AppKit
import Observation

/// The steps of setting up, and what each needs before you can go on.
@Observable
final class SetupModel {
    enum Step: Int, CaseIterable {
        case welcome, permissions, faceScan, password, done
    }

    private(set) var step: Step
    let isAddingAppearance: Bool
    let enrollment: Enrollment

    private(set) var hasCamera = CameraSession.isAuthorized
    private(set) var hasAccessibility = PasswordTyper.isTrusted
    var appearanceName = ""
    var password = ""
    private(set) var isSavingPassword = false
    private(set) var passwordError: String?

    @ObservationIgnored private let model: AppModel
    @ObservationIgnored private var permissionTimer: Timer?
    @ObservationIgnored var onFinish: (() -> Void)?

    init(model: AppModel, addingAppearance: Bool) {
        self.model = model
        isAddingAppearance = addingAppearance
        enrollment = Enrollment(camera: model.scanner.camera, recognizer: model.scanner.recognizer)
        step = addingAppearance ? .faceScan : .welcome
        appearanceName = addingAppearance ? "Appearance \(model.faces.profiles.count + 1)" : NSFullUserName()
        if addingAppearance { Task { await enrollment.start(cameraID: model.preferences.cameraID) } }
    }

    var permissionsGranted: Bool { hasCamera && hasAccessibility }

    func go(to next: Step) {
        if step == .faceScan, next != .faceScan { enrollment.stop() }
        step = next
        switch next {
        case .permissions: startWatchingPermissions()
        case .faceScan:
            stopWatchingPermissions()
            Task { await enrollment.start(cameraID: model.preferences.cameraID) }
        default: stopWatchingPermissions()
        }
    }

    func next() {
        switch step {
        case .welcome: go(to: .permissions)
        case .permissions: go(to: .faceScan)
        case .faceScan:
            model.faces.add(enrollment.makeProfile(named: appearanceName.isEmpty ? "Face" : appearanceName))
            if isAddingAppearance || model.vault.hasStoredPassword { go(to: .done) } else { go(to: .password) }
        case .password: Task { await savePassword() }
        case .done: finish()
        }
    }

    // MARK: Permissions

    func requestCamera() {
        Task {
            if await CameraSession.requestAccess() {
                hasCamera = true
            } else {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
            }
        }
    }

    func requestAccessibility() {
        PasswordTyper.requestTrust()
    }

    /// Permissions are granted in System Settings, out of the app's sight; look again every second until they are.
    private func startWatchingPermissions() {
        guard permissionTimer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.hasCamera = CameraSession.isAuthorized
                self?.hasAccessibility = PasswordTyper.isTrusted
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }

    private func stopWatchingPermissions() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    // MARK: Password

    private func savePassword() async {
        isSavingPassword = true
        passwordError = nil
        defer { isSavingPassword = false }
        do {
            try await model.vault.store(password)
            password = ""
            model.unlock.armAfterSetup()
            go(to: .done)
        } catch {
            passwordError = error.localizedDescription
        }
    }

    // MARK: Finishing

    func finish() {
        enrollment.stop()
        stopWatchingPermissions()
        model.preferences.hasCompletedSetup = true
        onFinish?()
    }

    func cancel() {
        enrollment.stop()
        stopWatchingPermissions()
    }
}
