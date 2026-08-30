import Foundation

/// Defines secure storage operations for sensitive credentials.
public protocol CredentialStore: Sendable {
    /// Securely persists a token for the specified profile UUID.
    func saveToken(_ token: String, for profileID: UUID) throws

    /// Loads the persisted token for the given profile UUID.
    func loadToken(for profileID: UUID) throws -> String?

    /// Deletes the persisted token for the specified profile UUID.
    func deleteToken(for profileID: UUID) throws
}
