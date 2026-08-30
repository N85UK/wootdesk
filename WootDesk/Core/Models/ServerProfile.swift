import Foundation

/// Non-secret metadata for a saved Chatwoot server profile.
///
/// Notice: The access token is explicitly omitted from this model.
/// All sensitive credentials must be stored solely inside Apple Keychain.
public struct ServerProfile: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var displayName: String
    public var baseURL: URL
    public var selectedAccountID: Int
    public var selectedAccountName: String
    public var createdAt: Date
    public var lastUsedAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        baseURL: URL,
        selectedAccountID: Int,
        selectedAccountName: String,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.baseURL = baseURL
        self.selectedAccountID = selectedAccountID
        self.selectedAccountName = selectedAccountName
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}
