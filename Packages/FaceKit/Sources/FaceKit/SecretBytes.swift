import Foundation

/// A secret (the Mac's password) held in memory only as long as it's needed, and overwritten with zeros when it's
/// let go, rather than left for the allocator to hand to someone else. Swift's `String` and `Data` copy themselves
/// freely and can't promise that, so the secret lives in one buffer this class owns.
public final class SecretBytes: @unchecked Sendable {
    private let buffer: UnsafeMutableRawBufferPointer
    private let lock = NSLock()
    private var isWiped = false

    public init(_ bytes: some Collection<UInt8>) {
        let storage = UnsafeMutableRawBufferPointer.allocate(byteCount: max(1, bytes.count), alignment: 1)
        storage.initializeMemory(as: UInt8.self, repeating: 0)
        _ = storage.initializeMemory(as: UInt8.self, fromContentsOf: bytes)
        buffer = storage
        count = bytes.count
    }

    /// Takes the string's UTF-8. The `String` itself still lives wherever the caller keeps it, so let it go quickly.
    public convenience init(utf8 string: String) {
        self.init(Array(string.utf8))
    }

    public let count: Int

    public var isEmpty: Bool { count == 0 }

    /// Lends the bytes to `body`, which must not keep them. Empty once ``wipe()`` has run.
    public func withBytes<Result>(_ body: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(UnsafeRawBufferPointer(rebasing: buffer[0..<(isWiped ? 0 : count)]))
    }

    /// Overwrites the bytes with zeros. Safe to call more than once.
    public func wipe() {
        lock.lock()
        defer { lock.unlock() }
        guard !isWiped else { return }
        // memset_s, unlike a plain loop or memset, isn't optimized away for memory that's about to be freed.
        _ = memset_s(buffer.baseAddress, buffer.count, 0, buffer.count)
        isWiped = true
    }

    deinit {
        wipe()
        buffer.deallocate()
    }
}
