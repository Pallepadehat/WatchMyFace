import FaceKit
import Foundation
import LocalAuthentication
import OSLog
import Observation
import OpenDirectory

nonisolated enum PasswordVaultError: LocalizedError {
    case wrongPassword
    case noPassword
    case authenticationFailed(String)

    var errorDescription: String? {
        switch self {
        case .wrongPassword: "That isn't your Mac's login password."
        case .noPassword: "There's no password saved yet. Finish setting up WatchMyFace first."
        case .authenticationFailed(let reason): reason
        }
    }
}

/// Your Mac's login password: the one thing face unlock needs to actually unlock, since macOS has no way for an
/// app to approve a login, only to type into the lock screen.
///
/// At rest it's in your login keychain. In memory it exists only while face unlock is *armed*: arming takes Touch
/// ID (or your password), and the copy in memory is wiped as soon as the unlock guardrails say so (see
/// ``UnlockPolicy``), or you turn face unlock off.
@Observable
final class PasswordVault {
    private static let account = "login-password"

    private(set) var hasStoredPassword = Keychain.contains(PasswordVault.account)
    @ObservationIgnored private var armed: SecretBytes?
    /// Mirrors `armed != nil`, observably (the secret itself stays out of observation).
    private(set) var isArmed = false

    /// Checks `password` is really this account's login password, then saves it. A wrong password saved would be
    /// typed at the lock screen and count against the account's failed attempts.
    func store(_ password: String) async throws {
        try await Self.verify(password)
        try Keychain.save(Data(password.utf8), as: Self.account, label: "WatchMyFace (login password)")
        hasStoredPassword = true
        load(password)
        Log.security.info("Password saved and armed")
    }

    /// Asks for Touch ID (or the password), then loads the password into memory.
    func arm(reason: String) async throws {
        guard hasStoredPassword else { throw PasswordVaultError.noPassword }
        let context = LAContext()
        context.localizedFallbackTitle = "Use Password…"
        do {
            try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            throw PasswordVaultError.authenticationFailed(error.localizedDescription)
        }
        guard let data = try Keychain.read(Self.account) else {
            hasStoredPassword = false
            throw PasswordVaultError.noPassword
        }
        armed = SecretBytes(data)
        isArmed = true
        Log.security.info("Armed")
    }

    /// Wipes the password from memory. It stays in the keychain.
    func disarm() {
        guard armed != nil else { return }
        armed?.wipe()
        armed = nil
        isArmed = false
        Log.security.info("Disarmed")
    }

    /// Removes the password from the keychain and memory.
    func forget() throws {
        disarm()
        try Keychain.delete(Self.account)
        hasStoredPassword = false
    }

    /// The armed password, for typing it. `nil` when disarmed.
    var armedPassword: SecretBytes? { armed }

    private func load(_ password: String) {
        armed?.wipe()
        armed = SecretBytes(utf8: password)
        isArmed = true
    }

    /// Asks Open Directory whether `password` is the current user's.
    private nonisolated static func verify(_ password: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            do {
                let node = try ODNode(session: ODSession.default(), type: ODNodeType(kODNodeTypeAuthentication))
                let record = try node.record(withRecordType: kODRecordTypeUsers, name: NSUserName(), attributes: nil)
                try record.verifyPassword(password)
            } catch {
                throw PasswordVaultError.wrongPassword
            }
        }.value
    }
}
