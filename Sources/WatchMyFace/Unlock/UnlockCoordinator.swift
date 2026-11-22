import FaceKit
import Foundation
import OSLog
import Observation

/// Face unlock, start to finish: notices the lock screen, looks for you, shows it in the notch, and types the
/// password when it's you. Also keeps the guardrails (``UnlockPolicy``): the password leaves memory the moment they
/// say face unlock has to stop.
@Observable
final class UnlockCoordinator {
    /// What face unlock can do right now, for the menu and Settings.
    enum Status: Equatable {
        /// No face enrolled or no password saved.
        case needsSetup
        /// Set up, but a guardrail has it off until Touch ID.
        case paused(UnlockPolicy.Block)
        case ready
        case scanning
    }

    private(set) var policy: UnlockPolicy
    private(set) var isScanning = false
    /// The last scan's outcome, in words, for the menu.
    private(set) var lastResult: String?

    @ObservationIgnored private let vault: PasswordVault
    @ObservationIgnored private let faces: FaceStore
    @ObservationIgnored private let scanner: FaceScanner
    @ObservationIgnored private let notch: NotchController
    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let lockMonitor = LockMonitor()
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var expiryTimer: Timer?

    init(vault: PasswordVault, faces: FaceStore, scanner: FaceScanner, notch: NotchController, preferences: Preferences) {
        self.vault = vault
        self.faces = faces
        self.scanner = scanner
        self.notch = notch
        self.preferences = preferences
        policy = UnlockPolicy(limits: preferences.unlockLimits)
        lockMonitor.onEvent = { [weak self] event in self?.handle(event) }
        notch.onHover = { [weak self] in self?.retry() }
    }

    var status: Status {
        if isScanning { return .scanning }
        guard faces.hasProfiles, vault.hasStoredPassword else { return .needsSetup }
        if let block = policy.block(at: .now) ?? (vault.isArmed ? nil : .notArmed) { return .paused(block) }
        return .ready
    }

    var embedder: any FaceEmbedder { scanner.recognizer.embedder }

    // MARK: Arming

    /// Touch ID, then face unlock is on.
    func arm() async throws {
        try await vault.arm(reason: "turn on face unlock")
        policy.limits = preferences.unlockLimits
        policy.arm(at: .now)
        lastResult = nil
    }

    /// After setup saved a new password: it's armed already, by having just been typed.
    func armAfterSetup() {
        policy.limits = preferences.unlockLimits
        policy.arm(at: .now)
    }

    /// After the limits change in Settings: they apply from now, and a guardrail the new ones trip stops face unlock.
    func applyLimits() {
        policy.limits = preferences.unlockLimits
        enforcePolicy()
    }

    func disarm() {
        policy.disarm()
        vault.disarm()
    }

    // MARK: Screen events

    private func handle(_ event: LockEvent) {
        let now = Date.now
        Log.unlock.debug("Event: \(String(describing: event), privacy: .public)")
        switch event {
        case .locked:
            policy.screenLocked(at: now)
            startExpiryChecks()
            if preferences.scanOnLock { scheduleScan(after: .seconds(1)) }
        case .woke:
            guard LockMonitor.isScreenLocked else { return }
            policy.screenLocked(at: now)
            startExpiryChecks()
            if preferences.scanOnWake { scheduleScan(after: .milliseconds(350)) }
        case .unlocked:
            cancelScan()
            policy.screenUnlocked(at: now)
            stopExpiryChecks()
            enforcePolicy()
            Task { await notch.close() }
        case .willSleep:
            cancelScan()
            Task { await notch.close() }
        }
    }

    /// Hovering over the notch after a miss.
    private func retry() {
        guard !isScanning else { return }
        if LockMonitor.isScreenLocked {
            scheduleScan(after: .zero)
        } else if notch.isVisible {
            Task { await notch.close() }
        }
    }

    // MARK: Scanning

    private func scheduleScan(after delay: Duration) {
        scanTask?.cancel()
        scanTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await unlockIfItsYou()
        }
    }

    private func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        scanner.cancel()
    }

    /// The lock screen flow. Checks every guardrail again just before typing, since a scan takes a moment.
    private func unlockIfItsYou() async {
        guard LockMonitor.isScreenLocked, !isScanning else { return }
        enforcePolicy()
        guard faces.hasProfiles, vault.hasStoredPassword else { return }
        guard vault.isArmed, policy.allowsUnlock(at: .now) else {
            await flash(.touchIDNeeded)
            return
        }

        let result = await scan()
        switch result {
        case .matched(let score):
            guard LockMonitor.isScreenLocked, policy.allowsUnlock(at: .now), let password = vault.armedPassword else {
                await notch.close()
                return
            }
            notch.show(.success)
            Log.unlock.info(
                "Matched: \(score.similarity, format: .fixed(precision: 3)), needed \(score.threshold, format: .fixed(precision: 3))")
            // Long enough to see the tick, then in.
            try? await Task.sleep(for: .milliseconds(650))
            do {
                try await Task.detached(priority: .userInitiated) { try PasswordTyper.type(password) }.value
            } catch {
                Log.unlock.error("Couldn't type the password: \(error.localizedDescription, privacy: .public)")
                lastResult = error.localizedDescription
            }
            await notch.close()
        case .noMatch, .noFace:
            policy.scanFailed(at: .now)
            enforcePolicy()
            notch.show(.failure)
            try? await Task.sleep(for: .milliseconds(900))
            guard LockMonitor.isScreenLocked else { return }
            await flash(policy.allowsUnlock(at: .now) ? .tryAgain : .touchIDNeeded, for: .seconds(12))
        case .failed(let error):
            Log.unlock.error("Scan failed: \(error.localizedDescription, privacy: .public)")
            lastResult = error.localizedDescription
            await notch.close()
        case .cancelled:
            break
        }
    }

    /// A scan with the notch showing it, used both at the lock screen and by "Try Face Unlock".
    private func scan() async -> ScanResult {
        isScanning = true
        defer { isScanning = false }
        notch.show(.scanning)
        let matcher = FaceMatcher(sensitivity: preferences.sensitivity, floor: embedder.similarityFloor)
        let request = ScanRequest(profiles: faces.profiles, matcher: matcher, requireBlink: preferences.requireBlink)
        let result = await scanner.scan(request, cameraID: preferences.cameraID)
        lastResult = Self.describe(result)
        return result
    }

    /// Try it while unlocked: the whole notch animation, with nothing typed.
    func tryFaceUnlock() {
        guard !isScanning, faces.hasProfiles else { return }
        scanTask?.cancel()
        scanTask = Task {
            switch await scan() {
            case .matched:
                notch.show(.success)
                try? await Task.sleep(for: .milliseconds(1100))
            case .noMatch, .noFace:
                notch.show(.failure)
                try? await Task.sleep(for: .milliseconds(1100))
            case .failed, .cancelled:
                break
            }
            await notch.close()
        }
    }

    private func flash(_ notice: NotchNotice, for duration: Duration = .seconds(3)) async {
        notch.show(.notice(notice))
        try? await Task.sleep(for: duration)
        if case .notice(notice) = notch.state { await notch.close() }
    }

    // MARK: Guardrails

    /// Wipes the password from memory once a guardrail has tripped.
    private func enforcePolicy() {
        guard vault.isArmed, let block = policy.block(at: .now) else { return }
        Log.unlock.info("Face unlock paused: \(String(describing: block), privacy: .public)")
        vault.disarm()
    }

    /// While locked, checks once a minute whether face unlock has run out, so the password doesn't linger in memory
    /// until the next scan.
    private func startExpiryChecks() {
        guard expiryTimer == nil else { return }
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.enforcePolicy() }
        }
        RunLoop.main.add(timer, forMode: .common)
        expiryTimer = timer
    }

    private func stopExpiryChecks() {
        expiryTimer?.invalidate()
        expiryTimer = nil
    }

    private static func describe(_ result: ScanResult) -> String {
        switch result {
        case .matched: "Recognized"
        case .noMatch: "Not recognized"
        case .noFace: "No face seen"
        case .failed(let error): error.localizedDescription
        case .cancelled: "Cancelled"
        }
    }
}
