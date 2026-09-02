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
    /// The Chatwoot user this profile authenticates as.
    ///
    /// Optional because profiles saved before per-agent push routing existed
    /// have no value for it, and a missing key must decode rather than fail.
    /// The push gateway uses it to send an assigned conversation only to the
    /// agent it belongs to.
    public var agentID: Int?
    public var createdAt: Date
    public var lastUsedAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        baseURL: URL,
        selectedAccountID: Int,
        selectedAccountName: String,
        agentID: Int? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.baseURL = baseURL
        self.selectedAccountID = selectedAccountID
        self.selectedAccountName = selectedAccountName
        self.agentID = agentID
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}
