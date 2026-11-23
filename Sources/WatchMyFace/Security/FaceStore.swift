import CryptoKit
import FaceKit
import Foundation
import OSLog
import Observation

/// The enrolled faces, kept on disk encrypted.
///
/// A profile is only numbers (embeddings), never a picture, but they're still yours: the file is sealed with
/// AES-GCM under a key that lives in your keychain, so a copy of the file alone is useless.
@Observable
final class FaceStore {
    private(set) var profiles: [FaceProfile] = []

    @ObservationIgnored private let fileURL: URL
    private static let keyAccount = "face-store-key"

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "WatchMyFace", directoryHint: .isDirectory)) {
        fileURL = directory.appending(path: "Faces.sealed")
        load()
    }

    /// Whether anyone can unlock: blocked profiles alone (``FaceProfile/Role/blocked``) don't count.
    var hasProfiles: Bool { profiles.contains { $0.role == .allowed } }

    func add(_ profile: FaceProfile) {
        profiles.append(profile)
        save()
    }

    func update(_ profile: FaceProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
        save()
    }

    func remove(_ id: FaceProfile.ID) {
        profiles.removeAll { $0.id == id }
        save()
    }

    func removeAll() {
        profiles = []
        try? FileManager.default.removeItem(at: fileURL)
        try? Keychain.delete(Self.keyAccount)
    }

    private func load() {
        guard let sealed = try? Data(contentsOf: fileURL) else { return }
        do {
            guard let key = try Self.key(createIfMissing: false) else {
                Log.security.error("The faces file has no key in the keychain, so it can't be read")
                return
            }
            let data = try AES.GCM.open(AES.GCM.SealedBox(combined: sealed), using: key)
            profiles = try JSONDecoder().decode([FaceProfile].self, from: data)
        } catch {
            Log.security.error("Couldn't read the faces file: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save() {
        do {
            guard let key = try Self.key(createIfMissing: true) else { return }
            let data = try JSONEncoder().encode(profiles)
            guard let sealed = try AES.GCM.seal(data, using: key).combined else { return }
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try sealed.write(to: fileURL, options: .atomic)
        } catch {
            Log.security.error("Couldn't save the faces file: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func key(createIfMissing: Bool) throws -> SymmetricKey? {
        if let data = try Keychain.read(keyAccount) { return SymmetricKey(data: data) }
        guard createIfMissing else { return nil }
        let key = SymmetricKey(size: .bits256)
        try Keychain.save(key.withUnsafeBytes { Data($0) }, as: keyAccount, label: "WatchMyFace (face data key)")
        return key
    }
}
