import Foundation

/// Repository contract for persisting non-secret server profile metadata.
public protocol ServerProfileRepository: Sendable {
    /// Loads all saved server profiles.
    func loadProfiles() async throws -> [ServerProfile]

    /// Atomically persists the collection of server profiles.
    func saveProfiles(_ profiles: [ServerProfile]) async throws

    /// Loads the active profile UUID preference.
    func loadActiveProfileID() async throws -> UUID?

    /// Saves the active profile UUID preference.
    func saveActiveProfileID(_ id: UUID?) async throws
}
