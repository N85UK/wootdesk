import Foundation

/// In-memory implementation of `CredentialStore` for unit tests, previews, and testing.
public final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UUID: String] = [:]

    public init(initialTokens: [UUID: String] = [:]) {
        self.storage = initialTokens
    }

    public func saveToken(_ token: String, for profileID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[profileID] = token
    }

    public func loadToken(for profileID: UUID) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return storage[profileID]
    }

    public func deleteToken(for profileID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: profileID)
    }

    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}
