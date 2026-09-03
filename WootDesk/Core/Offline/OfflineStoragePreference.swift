import Foundation

/// Reads and writes the agent's choice about protected offline storage.
public protocol OfflineStoragePreferenceStore: Sendable {
    func isEnabled() -> Bool
    func setEnabled(_ enabled: Bool)
}

/// The shipped preference, held in `UserDefaults`.
///
/// Offline storage is on by default. It holds only content the agent has
/// already been shown, protected at rest and excluded from backups, and the
/// agent can switch it off at any time.
public struct UserDefaultsOfflineStoragePreference: OfflineStoragePreferenceStore {
    private static let key = "dev.n85.wootdesk.offlineStorageEnabled"

    /// `UserDefaults` is documented as thread-safe but is not marked
    /// `Sendable`, so the reference is carried across isolation explicitly.
    private nonisolated(unsafe) let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func isEnabled() -> Bool {
        guard defaults.object(forKey: Self.key) != nil else { return true }
        return defaults.bool(forKey: Self.key)
    }

    public func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.key)
    }
}

/// An in-memory preference for tests and previews.
public final class InMemoryOfflineStoragePreference: OfflineStoragePreferenceStore, @unchecked Sendable {
    private let lock = NSLock()
    private var enabled: Bool

    public init(enabled: Bool = true) {
        self.enabled = enabled
    }

    public func isEnabled() -> Bool {
        lock.withLock { enabled }
    }

    public func setEnabled(_ newValue: Bool) {
        lock.withLock { enabled = newValue }
    }
}
