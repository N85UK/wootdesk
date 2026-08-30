import Foundation

/// An account within a Chatwoot instance that the authenticated user belongs to.
public struct ChatwootAccount: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let role: String?
    public let status: String?

    public init(
        id: Int,
        name: String,
        role: String? = nil,
        status: String? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.status = status
    }
}
